import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../../utils/constants.dart';
import '../lurelands_game.dart';
import 'cast_line.dart';
import 'player_name_label.dart';
import 'power_meter.dart';
import 'quest_sign.dart';
import 'shop.dart';
import 'tree.dart';

/// Player component - animated sprite that can move and fish
class Player extends PositionComponent with HasGameReference<LurelandsGame>, CollisionCallbacks {
  Player({
    required Vector2 position,
    int equippedPoleTier = 1,
    int equippedLureTier = 1,
    String? playerName,
  })  : _equippedPoleTier = equippedPoleTier,
        _equippedLureTier = equippedLureTier,
        _playerName = playerName,
        super(
          position: position,
          size: Vector2(216, 144), // 2.25x scale of sprite frame (96x64)
          anchor: Anchor.center,
        );

  final String? _playerName;

  CastLine? _castLine;

  // Sprite animation
  late SpriteAnimationComponent _animationComponent;
  late SpriteAnimation _walkAnimation;
  late SpriteAnimation _idleAnimation;
  bool _isMoving = false;
  bool _facingRight = true;

  // Movement state
  double _facingAngle = 0.0; // Radians, 0 = right
  
  // Track current collisions
  final Set<Tree> _collidingTrees = {};
  final Set<Shop> _collidingShops = {};
  final Set<QuestSign> _collidingQuestSigns = {};

  // Casting state
  bool _isCasting = false;

  // Equipment state
  int _equippedPoleTier;
  int _equippedLureTier;

  bool get isCasting => _isCasting;
  double get facingAngle => _facingAngle;
  int get equippedPoleTier => _equippedPoleTier;
  int get equippedLureTier => _equippedLureTier;
  CastLine? get castLine => _castLine;

  set equippedPoleTier(int tier) {
    assert(tier >= 1 && tier <= 4, 'Pole tier must be between 1 and 4');
    _equippedPoleTier = tier;
  }

  set equippedLureTier(int tier) {
    assert(tier >= 1 && tier <= 4, 'Lure tier must be between 1 and 4');
    _equippedLureTier = tier;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load walk sprite sheet (768x64, 8 frames, each 96x64)
    final walkSheet = SpriteSheet(image: await game.images.load('characters/base_walk_strip8.png'), srcSize: Vector2(96, 64));

    // Load idle sprite sheet (864x64, 9 frames, each 96x64)
    final idleSheet = SpriteSheet(image: await game.images.load('characters/base_idle_strip9.png'), srcSize: Vector2(96, 64));

    // Create walk animation (8 frames)
    _walkAnimation = walkSheet.createAnimation(row: 0, stepTime: 0.1, from: 0, to: 8);

    // Create idle animation (9 frames)
    _idleAnimation = idleSheet.createAnimation(row: 0, stepTime: 0.15, from: 0, to: 9);

    // Add animation component
    _animationComponent = SpriteAnimationComponent(animation: _idleAnimation, size: size, anchor: Anchor.center, position: size / 2);
    await add(_animationComponent);

    // Add smaller collision hitbox (centered on character body, not full sprite frame)
    // Compact hitbox matching character body - reduced top portion
    const hitboxWidth = 50.0;
    const hitboxHeight = 50.0; // Reduced from 60 to reduce top collision area
    final playerHitbox = RectangleHitbox(
      size: Vector2(hitboxWidth, hitboxHeight),
      position: Vector2((size.x - hitboxWidth) / 2, size.y - 95), // Adjusted to keep bottom edge aligned
    );
    await add(playerHitbox);

    // Add power meter next to player
    final powerMeter = PowerMeter()
      ..position = Vector2(size.x / 2 + 25, size.y / 2 + 55);
    await add(powerMeter);

    // Add player name label above the character
    if (_playerName != null && _playerName.isNotEmpty) {
      final nameLabel = PlayerNameLabel(
        playerName: _playerName,
        position: Vector2(size.x / 2 + 20, 60), // Positioned above the sprite
      );
      await add(nameLabel);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Update priority based on feet position for proper depth sorting
    // Player anchor is center, so feet are at position.y + offset
    priority = (position.y + 20).toInt();
  }

  /// Move the player in a direction
  void move(Vector2 direction, double dt) {
    if (_isCasting) return; // Can't move while casting

    final isMovingNow = direction.length > 0;

    // Switch animation based on movement state
    if (isMovingNow != _isMoving) {
      _isMoving = isMovingNow;
      _animationComponent.animation = _isMoving ? _walkAnimation : _idleAnimation;
    }

    if (!isMovingNow) return;

    final movement = direction * GameConstants.playerSpeed * dt;
    final newPosition = position + movement;

    // Clamp to world bounds
    newPosition.x = newPosition.x.clamp(GameConstants.playerSize / 2, GameConstants.worldWidth - GameConstants.playerSize / 2);
    newPosition.y = newPosition.y.clamp(GameConstants.playerSize / 2, GameConstants.worldHeight - GameConstants.playerSize / 2);

    // Axis-separated collision resolution (wall sliding)
    // Try full movement first, then fall back to single-axis movement
    if (!_wouldCollide(newPosition)) {
      position = newPosition;
    } else {
      // Full movement blocked - try sliding along each axis
      final xOnlyPosition = Vector2(newPosition.x, position.y);
      final yOnlyPosition = Vector2(position.x, newPosition.y);
      
      final canMoveX = !_wouldCollide(xOnlyPosition);
      final canMoveY = !_wouldCollide(yOnlyPosition);
      
      if (canMoveX && canMoveY) {
        // Both axes work individually - prefer the dominant movement direction
        if (movement.x.abs() >= movement.y.abs()) {
          position = xOnlyPosition;
        } else {
          position = yOnlyPosition;
        }
      } else if (canMoveX) {
        position = xOnlyPosition;
      } else if (canMoveY) {
        position = yOnlyPosition;
      } else {
        // Neither axis works - try tangential sliding for circular obstacles (trees)
        final slidePosition = _getTreeSlidePosition(movement);
        if (slidePosition != null && !_wouldCollide(slidePosition)) {
          position = slidePosition;
        }
      }
    }

    // Update facing direction (flip sprite for left/right)
    if (direction.x != 0) {
      final shouldFaceRight = direction.x > 0;
      if (shouldFaceRight != _facingRight) {
        _facingRight = shouldFaceRight;
        _animationComponent.flipHorizontally();
      }
    }

    // Update facing angle based on movement direction
    _facingAngle = atan2(direction.y, direction.x);
  }

  /// Check if position would collide with any obstacle
  bool _wouldCollide(Vector2 newPos) {
    return _wouldCollideWithWater(newPos) ||
        _wouldCollideWithTree(newPos) ||
        _wouldCollideWithShop(newPos) ||
        _wouldCollideWithQuestSign(newPos);
  }

  /// Calculate tangential slide position when colliding with a tree
  /// Returns null if no tree collision or slide isn't possible
  Vector2? _getTreeSlidePosition(Vector2 movement) {
    const playerHitboxRadius = 25.0;
    
    // Find the closest tree we're colliding with
    Tree? closestTree;
    double closestDistance = double.infinity;
    
    for (final tree in game.trees) {
      final hitboxWorldPos = tree.hitboxWorldPosition;
      final dx = position.x - hitboxWorldPos.x;
      final dy = position.y - hitboxWorldPos.y;
      final distance = sqrt(dx * dx + dy * dy);
      final collisionDistance = tree.hitboxRadius + playerHitboxRadius;
      
      // Check if we're near this tree (within collision range + small buffer)
      if (distance < collisionDistance + 5 && distance < closestDistance) {
        closestDistance = distance;
        closestTree = tree;
      }
    }
    
    if (closestTree == null) return null;
    
    // Calculate the normal (direction from tree center to player)
    final treePos = closestTree.hitboxWorldPosition;
    final toPlayer = Vector2(position.x - treePos.x, position.y - treePos.y);
    
    if (toPlayer.length < 0.001) return null; // Player is at tree center (edge case)
    toPlayer.normalize();
    
    // Calculate tangent (perpendicular to normal)
    // Choose the tangent direction that aligns with the movement
    final tangent1 = Vector2(-toPlayer.y, toPlayer.x);
    final tangent2 = Vector2(toPlayer.y, -toPlayer.x);
    
    // Pick the tangent that's more aligned with our intended movement
    final dot1 = tangent1.dot(movement);
    final dot2 = tangent2.dot(movement);
    final slideTangent = dot1.abs() > dot2.abs() ? tangent1 : tangent2;
    
    // Project movement onto the tangent
    final slideAmount = movement.dot(slideTangent);
    if (slideAmount.abs() < 0.001) return null; // No meaningful slide
    
    // Apply slide movement
    final slideMovement = slideTangent * slideAmount;
    return position + slideMovement;
  }

  bool _wouldCollideWithWater(Vector2 newPos) {
    // Player hitbox is roughly 50x50, so use ~25px as player "radius"
    const playerHitboxRadius = 25.0;

    // Check points around player hitbox
    final checkPoints = [
      newPos,
      Vector2(newPos.x - playerHitboxRadius, newPos.y),
      Vector2(newPos.x + playerHitboxRadius, newPos.y),
      Vector2(newPos.x, newPos.y - playerHitboxRadius),
      Vector2(newPos.x, newPos.y + playerHitboxRadius),
    ];

    // Use collision detection (checks tile collision objects + collision layer)
    for (final point in checkPoints) {
      if (game.isCollisionAt(point.x, point.y)) {
        // Check if this point is on a dock (docks allow walking over water)
        if (!_isOnDock(point)) {
          return true;
        }
      }
    }

    return false;
  }
  
  /// Check if a point is on a walkable dock
  bool _isOnDock(Vector2 point) {
    for (final dockRect in game.dockAreas) {
      if (dockRect.contains(Offset(point.x, point.y))) {
        return true;
      }
    }
    return false;
  }

  bool _wouldCollideWithTree(Vector2 newPos) {
    // Player hitbox is roughly 50x50, so use ~25px as player "radius"
    const playerHitboxRadius = 25.0;
    
    for (final tree in game.trees) {
      // Get the tree's hitbox position in world space
      final hitboxWorldPos = tree.hitboxWorldPosition;
      
      // Calculate distance from player to tree hitbox center
      final dx = newPos.x - hitboxWorldPos.x;
      final dy = newPos.y - hitboxWorldPos.y;
      final distance = sqrt(dx * dx + dy * dy);
      
      // Check if player would overlap with tree hitbox
      if (distance < tree.hitboxRadius + playerHitboxRadius) {
        return true;
      }
    }
    return false;
  }

  bool _wouldCollideWithShop(Vector2 newPos) {
    // Player hitbox is roughly 50x50, so use ~25px as player "radius"
    const playerHitboxRadius = 25.0;
    
    for (final shop in game.shops) {
      // Get the shop's hitbox position and size in world space
      final hitboxCenter = shop.hitboxWorldPosition;
      final hitboxSize = shop.hitboxSize;
      
      // Calculate the half-extents of the shop hitbox
      final halfWidth = hitboxSize.x / 2;
      final halfHeight = hitboxSize.y / 2;
      
      // Find the closest point on the rectangle to the player
      final closestX = (newPos.x).clamp(hitboxCenter.x - halfWidth, hitboxCenter.x + halfWidth);
      final closestY = (newPos.y).clamp(hitboxCenter.y - halfHeight, hitboxCenter.y + halfHeight);
      
      // Calculate distance from player to closest point on rectangle
      final dx = newPos.x - closestX;
      final dy = newPos.y - closestY;
      final distance = sqrt(dx * dx + dy * dy);
      
      // Check if player would overlap with shop hitbox
      if (distance < playerHitboxRadius) {
        return true;
      }
    }
    return false;
  }

  bool _wouldCollideWithQuestSign(Vector2 newPos) {
    const playerHitboxRadius = 25.0;
    
    for (final sign in game.questSigns) {
      // Get the quest sign's hitbox position and size in world space
      final hitboxCenter = sign.hitboxWorldPosition;
      final hitboxSize = sign.hitboxSize;
      
      // Calculate the half-extents of the sign hitbox
      final halfWidth = hitboxSize.x / 2;
      final halfHeight = hitboxSize.y / 2;
      
      // Find the closest point on the rectangle to the player
      final closestX = (newPos.x).clamp(hitboxCenter.x - halfWidth, hitboxCenter.x + halfWidth);
      final closestY = (newPos.y).clamp(hitboxCenter.y - halfHeight, hitboxCenter.y + halfHeight);
      
      // Calculate distance from player to closest point on rectangle
      final dx = newPos.x - closestX;
      final dy = newPos.y - closestY;
      final distance = sqrt(dx * dx + dy * dy);
      
      // Check if player would overlap with quest sign hitbox
      if (distance < playerHitboxRadius) {
        return true;
      }
    }
    return false;
  }

  /// Start casting into water
  /// [power] is a value from 0.0 to 1.0 representing the charge level
  /// Cast distance is based on equipped pole's max distance and power level
  /// Casts in the direction the player is currently facing
  void startCasting(double power) {
    if (_isCasting) return;

    _isCasting = true;

    // Cast in the direction the player is facing
    final castDirection = Vector2(cos(_facingAngle), sin(_facingAngle));

    // Get the equipped pole's max cast distance
    final poleAsset = ItemAssets.getFishingPole(_equippedPoleTier);
    final maxDistance = poleAsset.maxCastDistance;

    // Calculate cast distance based on power and pole's max distance
    // Higher tier poles can cast further!
    final castDistance = GameConstants.minCastDistance + 
        (maxDistance - GameConstants.minCastDistance) * power;

    final targetX = position.x + castDirection.x * castDistance;
    final targetY = position.y + castDirection.y * castDistance;

    // Create cast line
    _castLine = CastLine(startPosition: position.clone(), endPosition: Vector2(targetX, targetY));
    game.world.add(_castLine!);
  }

  /// Reel in the fishing line
  void reelIn() {
    if (!_isCasting) return;

    _isCasting = false;

    // Remove cast line
    if (_castLine != null) {
      _castLine!.startReeling();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    // Track collisions for other purposes (e.g., shake effects on trees)
    if (other is Tree) {
      _collidingTrees.add(other);
    }
    if (other is Shop) {
      _collidingShops.add(other);
    }
    if (other is QuestSign) {
      _collidingQuestSigns.add(other);
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Tree) {
      _collidingTrees.remove(other);
    }
    if (other is Shop) {
      _collidingShops.remove(other);
    }
    if (other is QuestSign) {
      _collidingQuestSigns.remove(other);
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    // Collisions are prevented before they happen, so this shouldn't fire often
    // But if it does (e.g., from external forces), we can handle it here if needed
  }
}
