import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../../utils/constants.dart';
import '../lurelands_game.dart';
import '../world/tiled_map_world.dart';
import 'cast_line.dart';
import 'power_meter.dart';
import 'quest_sign.dart';
import 'shop.dart';
import 'tree.dart';
import 'wandering_npc.dart';

/// Player facing direction for 4-directional movement
enum PlayerDirection {
  down,
  left,
  up,
  right,
}

/// Player movement state
enum PlayerMovementState {
  idle,
  walking,
  running,
}

/// Player component - animated sprite that can move and fish
class Player extends PositionComponent with HasGameReference<LurelandsGame>, CollisionCallbacks {
  // Sprite configuration constants
  static const int _frameSize = 64;
  static const int _frameCount = 6;
  static const double _spriteScale = 2.5; // 64 * 2.5 = 160px
  static const double _walkStepTime = 0.12;
  static const double _runStepTime = 0.08;
  static const double _idleStepTime = 0.3;
  static const double _runThreshold = 0.7; // Joystick magnitude threshold for running
  static const double _runSpeedMultiplier = 1.4;

  // Hitbox configuration - small ellipse shape on player's body
  // Based on Tiled measurements: 11.35x4.87 at 64px, scaled 2.5x
  static const double _hitboxWidth = 28.0;
  static const double _hitboxHeight = 12.0;
  static const double _hitboxHalfWidth = _hitboxWidth / 2; // 14.0
  static const double _hitboxHalfHeight = _hitboxHeight / 2; // 6.0
  // Offset from player center to hitbox center (positive = below center)
  static const double _hitboxYOffset = 15.0;
  // Number of vertices for ellipse approximation
  static const int _ellipseSegments = 12;

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
          size: Vector2.all(_frameSize * _spriteScale), // 160x160
          anchor: Anchor.center,
        );

  final String? _playerName;

  CastLine? _castLine;

  // Sprite animation
  late SpriteAnimationComponent _animationComponent;

  // Animation maps by direction
  late Map<PlayerDirection, SpriteAnimation> _walkAnimations;
  late Map<PlayerDirection, SpriteAnimation> _runAnimations;
  late Map<PlayerDirection, SpriteAnimation> _idleAnimations;

  // Current state
  PlayerDirection _currentDirection = PlayerDirection.down;
  PlayerMovementState _movementState = PlayerMovementState.idle;

  // Movement state
  double _facingAngle = 0.0; // Radians, 0 = right (used for fishing cast direction)
  
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

    // Load the new character spritesheet (16x16 frames, 6 columns x 6 rows)
    final spritesheet = SpriteSheet(
      image: await game.images.load('characters/Fisherman_Fin.png'),
      srcSize: Vector2.all(_frameSize.toDouble()),
    );

    // Create walk animations for each direction
    // Rows: 0=down, 1=left, 2=up (right mirrors left)
    _walkAnimations = {
      PlayerDirection.down: spritesheet.createAnimation(
        row: 0,
        stepTime: _walkStepTime,
        from: 0,
        to: _frameCount,
      ),
      PlayerDirection.left: spritesheet.createAnimation(
        row: 1,
        stepTime: _walkStepTime,
        from: 0,
        to: _frameCount,
      ),
      PlayerDirection.up: spritesheet.createAnimation(
        row: 2,
        stepTime: _walkStepTime,
        from: 0,
        to: _frameCount,
      ),
      // Right uses left animation with horizontal flip (handled in _updateAnimation)
      PlayerDirection.right: spritesheet.createAnimation(
        row: 1,
        stepTime: _walkStepTime,
        from: 0,
        to: _frameCount,
      ),
    };

    // Create run animations for each direction
    // Rows: 3=down, 4=left, 5=up (right mirrors left)
    _runAnimations = {
      PlayerDirection.down: spritesheet.createAnimation(
        row: 3,
        stepTime: _runStepTime,
        from: 0,
        to: _frameCount,
      ),
      PlayerDirection.left: spritesheet.createAnimation(
        row: 4,
        stepTime: _runStepTime,
        from: 0,
        to: _frameCount,
      ),
      PlayerDirection.up: spritesheet.createAnimation(
        row: 5,
        stepTime: _runStepTime,
        from: 0,
        to: _frameCount,
      ),
      // Right uses left animation with horizontal flip
      PlayerDirection.right: spritesheet.createAnimation(
        row: 4,
        stepTime: _runStepTime,
        from: 0,
        to: _frameCount,
      ),
    };

    // Create idle animations (subtle breathing using first 3 frames of walk)
    _idleAnimations = {
      PlayerDirection.down: spritesheet.createAnimation(
        row: 0,
        stepTime: _idleStepTime,
        from: 0,
        to: 3,
      ),
      PlayerDirection.left: spritesheet.createAnimation(
        row: 1,
        stepTime: _idleStepTime,
        from: 0,
        to: 3,
      ),
      PlayerDirection.up: spritesheet.createAnimation(
        row: 2,
        stepTime: _idleStepTime,
        from: 0,
        to: 3,
      ),
      PlayerDirection.right: spritesheet.createAnimation(
        row: 1,
        stepTime: _idleStepTime,
        from: 0,
        to: 3,
      ),
    };

    // Initialize animation component with idle facing down
    _animationComponent = SpriteAnimationComponent(
      animation: _idleAnimations[PlayerDirection.down],
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    await add(_animationComponent);

    // Add ellipse collision hitbox using polygon approximation
    final ellipseCenter = Vector2(
      size.x / 2, // Center horizontally
      size.y / 2 + _hitboxYOffset, // Position below center
    );
    final ellipseVertices = _createEllipseVertices(
      _hitboxHalfWidth,
      _hitboxHalfHeight,
      _ellipseSegments,
      ellipseCenter,
    );
    final playerHitbox = PolygonHitbox(ellipseVertices);
    await add(playerHitbox);

    // Add power meter next to player (adjusted for new sprite size)
    final powerMeter = PowerMeter()
      ..position = Vector2(size.x / 2 + 20, size.y / 2 + 45);
    await add(powerMeter);

  }

  @override
  void update(double dt) {
    super.update(dt);
    // Update priority based on feet position for proper depth sorting
    // Player anchor is center, so feet are at position.y + offset
    priority = (position.y + 20).toInt();
  }

  /// Determine player direction from movement vector (dominant axis)
  PlayerDirection _getDirectionFromMovement(Vector2 direction) {
    if (direction.length < 0.1) {
      return _currentDirection; // Keep current direction when not moving
    }

    final absX = direction.x.abs();
    final absY = direction.y.abs();

    if (absX > absY) {
      // Horizontal movement is dominant
      return direction.x > 0 ? PlayerDirection.right : PlayerDirection.left;
    } else {
      // Vertical movement is dominant
      return direction.y > 0 ? PlayerDirection.down : PlayerDirection.up;
    }
  }

  /// Determine movement state from direction magnitude
  PlayerMovementState _getMovementState(Vector2 direction) {
    final magnitude = direction.length;
    if (magnitude < 0.1) {
      return PlayerMovementState.idle;
    } else if (magnitude >= _runThreshold) {
      return PlayerMovementState.running;
    } else {
      return PlayerMovementState.walking;
    }
  }

  /// Update the animation based on current direction and movement state
  void _updateAnimation() {
    final SpriteAnimation targetAnimation;

    switch (_movementState) {
      case PlayerMovementState.idle:
        targetAnimation = _idleAnimations[_currentDirection]!;
        break;
      case PlayerMovementState.walking:
        targetAnimation = _walkAnimations[_currentDirection]!;
        break;
      case PlayerMovementState.running:
        targetAnimation = _runAnimations[_currentDirection]!;
        break;
    }

    // Only update if animation changed
    if (_animationComponent.animation != targetAnimation) {
      _animationComponent.animation = targetAnimation;
      _animationComponent.animationTicker?.reset();
    }

    // Handle horizontal flip for right direction
    final shouldFlip = _currentDirection == PlayerDirection.right;
    if (_animationComponent.isFlippedHorizontally != shouldFlip) {
      _animationComponent.flipHorizontally();
    }
  }

  /// Move the player in a direction
  void move(Vector2 direction, double dt) {
    if (_isCasting) return; // Can't move while casting

    // Determine new direction and movement state
    final newDirection = _getDirectionFromMovement(direction);
    final newMovementState = _getMovementState(direction);

    // Check if state changed
    final stateChanged = newDirection != _currentDirection ||
        newMovementState != _movementState;

    // Update state
    _currentDirection = newDirection;
    _movementState = newMovementState;

    // Update animation if state changed
    if (stateChanged) {
      _updateAnimation();
    }

    if (newMovementState == PlayerMovementState.idle) return;

    // Calculate movement with speed based on state
    final speed = newMovementState == PlayerMovementState.running
        ? GameConstants.playerSpeed * _runSpeedMultiplier
        : GameConstants.playerSpeed;

    final movement = direction.normalized() * speed * dt;
    final newPosition = position + movement;

    // Clamp to world bounds
    newPosition.x = newPosition.x.clamp(
      GameConstants.playerSize / 2,
      TiledMapWorld.worldWidth - GameConstants.playerSize / 2,
    );
    newPosition.y = newPosition.y.clamp(
      GameConstants.playerSize / 2,
      TiledMapWorld.worldHeight - GameConstants.playerSize / 2,
    );

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

    // Update facing angle based on movement direction (used for fishing cast)
    _facingAngle = atan2(direction.y, direction.x);
  }

  /// Check if position would collide with any obstacle
  bool _wouldCollide(Vector2 newPos) {
    return _wouldCollideWithWater(newPos) ||
        _wouldCollideWithTree(newPos) ||
        _wouldCollideWithShop(newPos) ||
        _wouldCollideWithQuestSign(newPos) ||
        _wouldCollideWithNpc(newPos);
  }

  /// Calculate tangential slide position when colliding with a tree
  /// Returns null if no tree collision or slide isn't possible
  Vector2? _getTreeSlidePosition(Vector2 movement) {
    // Use average of half-width and half-height for circular approximation
    const playerHitboxRadius = (_hitboxHalfWidth + _hitboxHalfHeight) / 2;

    // Calculate hitbox center position (at player's feet)
    final hitboxCenterX = position.x;
    final hitboxCenterY = position.y + _hitboxYOffset;

    // Find the closest tree we're colliding with
    Tree? closestTree;
    double closestDistance = double.infinity;

    for (final tree in game.trees) {
      final hitboxWorldPos = tree.hitboxWorldPosition;
      final dx = hitboxCenterX - hitboxWorldPos.x;
      final dy = hitboxCenterY - hitboxWorldPos.y;
      final distance = sqrt(dx * dx + dy * dy);
      final collisionDistance = tree.hitboxRadius + playerHitboxRadius;

      // Check if we're near this tree (within collision range + small buffer)
      if (distance < collisionDistance + 5 && distance < closestDistance) {
        closestDistance = distance;
        closestTree = tree;
      }
    }

    if (closestTree == null) return null;

    // Calculate the normal (direction from tree center to player hitbox)
    final treePos = closestTree.hitboxWorldPosition;
    final toPlayer = Vector2(hitboxCenterX - treePos.x, hitboxCenterY - treePos.y);
    
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
    // Calculate hitbox center position (hitbox is at player's feet)
    final hitboxCenterX = newPos.x;
    final hitboxCenterY = newPos.y + _hitboxYOffset;

    // Check points around player hitbox using actual dimensions
    final checkPoints = [
      Vector2(hitboxCenterX, hitboxCenterY), // Center
      Vector2(hitboxCenterX - _hitboxHalfWidth, hitboxCenterY), // Left
      Vector2(hitboxCenterX + _hitboxHalfWidth, hitboxCenterY), // Right
      Vector2(hitboxCenterX, hitboxCenterY - _hitboxHalfHeight), // Top
      Vector2(hitboxCenterX, hitboxCenterY + _hitboxHalfHeight), // Bottom
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
    // Use average of half-width and half-height for circular approximation
    const playerHitboxRadius = (_hitboxHalfWidth + _hitboxHalfHeight) / 2;

    // Calculate hitbox center position (at player's feet)
    final hitboxCenterX = newPos.x;
    final hitboxCenterY = newPos.y + _hitboxYOffset;

    for (final tree in game.trees) {
      // Get the tree's hitbox position in world space
      final hitboxWorldPos = tree.hitboxWorldPosition;

      // Calculate distance from player hitbox center to tree hitbox center
      final dx = hitboxCenterX - hitboxWorldPos.x;
      final dy = hitboxCenterY - hitboxWorldPos.y;
      final distance = sqrt(dx * dx + dy * dy);

      // Check if player would overlap with tree hitbox
      if (distance < tree.hitboxRadius + playerHitboxRadius) {
        return true;
      }
    }
    return false;
  }

  bool _wouldCollideWithShop(Vector2 newPos) {
    // Use average of half-width and half-height for circular approximation
    const playerHitboxRadius = (_hitboxHalfWidth + _hitboxHalfHeight) / 2;

    // Calculate hitbox center position (at player's feet)
    final hitboxCenterX = newPos.x;
    final hitboxCenterY = newPos.y + _hitboxYOffset;

    for (final shop in game.shops) {
      // Get the shop's hitbox position and size in world space
      final hitboxCenter = shop.hitboxWorldPosition;
      final hitboxSize = shop.hitboxSize;

      // Calculate the half-extents of the shop hitbox
      final halfWidth = hitboxSize.x / 2;
      final halfHeight = hitboxSize.y / 2;

      // Find the closest point on the rectangle to the player hitbox center
      final closestX = hitboxCenterX.clamp(hitboxCenter.x - halfWidth, hitboxCenter.x + halfWidth);
      final closestY = hitboxCenterY.clamp(hitboxCenter.y - halfHeight, hitboxCenter.y + halfHeight);

      // Calculate distance from player hitbox center to closest point on rectangle
      final dx = hitboxCenterX - closestX;
      final dy = hitboxCenterY - closestY;
      final distance = sqrt(dx * dx + dy * dy);

      // Check if player would overlap with shop hitbox
      if (distance < playerHitboxRadius) {
        return true;
      }
    }
    return false;
  }

  bool _wouldCollideWithQuestSign(Vector2 newPos) {
    // Use average of half-width and half-height for circular approximation
    const playerHitboxRadius = (_hitboxHalfWidth + _hitboxHalfHeight) / 2;

    // Calculate hitbox center position (at player's feet)
    final hitboxCenterX = newPos.x;
    final hitboxCenterY = newPos.y + _hitboxYOffset;

    for (final sign in game.questSigns) {
      // Get the quest sign's hitbox position and size in world space
      final hitboxCenter = sign.hitboxWorldPosition;
      final hitboxSize = sign.hitboxSize;

      // Calculate the half-extents of the sign hitbox
      final halfWidth = hitboxSize.x / 2;
      final halfHeight = hitboxSize.y / 2;

      // Find the closest point on the rectangle to the player hitbox center
      final closestX = hitboxCenterX.clamp(hitboxCenter.x - halfWidth, hitboxCenter.x + halfWidth);
      final closestY = hitboxCenterY.clamp(hitboxCenter.y - halfHeight, hitboxCenter.y + halfHeight);

      // Calculate distance from player hitbox center to closest point on rectangle
      final dx = hitboxCenterX - closestX;
      final dy = hitboxCenterY - closestY;
      final distance = sqrt(dx * dx + dy * dy);

      // Check if player would overlap with quest sign hitbox
      if (distance < playerHitboxRadius) {
        return true;
      }
    }
    return false;
  }

  bool _wouldCollideWithNpc(Vector2 newPos) {
    // Use average of half-width and half-height for circular approximation
    const playerHitboxRadius = (_hitboxHalfWidth + _hitboxHalfHeight) / 2;

    // Calculate hitbox center position (at player's feet)
    final hitboxCenterX = newPos.x;
    final hitboxCenterY = newPos.y + _hitboxYOffset;

    for (final npc in game.wanderingNpcs) {
      // Get the NPC's hitbox position in world space
      final npcHitboxPos = npc.hitboxWorldPosition;
      final npcHitboxRadius = (npc.hitboxHalfWidth + npc.hitboxHalfHeight) / 2;

      // Calculate distance from player hitbox center to NPC hitbox center
      final dx = hitboxCenterX - npcHitboxPos.x;
      final dy = hitboxCenterY - npcHitboxPos.y;
      final distance = sqrt(dx * dx + dy * dy);

      // Check if player would overlap with NPC hitbox
      if (distance < playerHitboxRadius + npcHitboxRadius) {
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

  /// Creates vertices for an ellipse polygon approximation
  static List<Vector2> _createEllipseVertices(
    double halfWidth,
    double halfHeight,
    int segments,
    Vector2 center,
  ) {
    final vertices = <Vector2>[];
    for (int i = 0; i < segments; i++) {
      final angle = (2 * pi * i) / segments;
      vertices.add(Vector2(
        center.x + halfWidth * cos(angle),
        center.y + halfHeight * sin(angle),
      ));
    }
    return vertices;
  }
}
