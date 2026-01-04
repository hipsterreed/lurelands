import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../../utils/constants.dart';
import '../lurelands_game.dart';
import 'cast_line.dart';
import 'player_name_label.dart';
import 'pond.dart';
import 'power_meter.dart';
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
  final Set<Pond> _collidingPonds = {};

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

    // Check for collisions BEFORE moving (Flame best practice: predictive collision detection)
    if (!_wouldCollideWithWater(newPosition) && !_wouldCollideWithTree(newPosition)) {
      position = newPosition;
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
    
    // Check tiled water bodies
    for (final tiledWater in game.allTiledWaterData) {
      for (final point in checkPoints) {
        if (tiledWater.containsPoint(point.x, point.y)) {
          // Check if this point is on a dock (docks allow walking over water)
          if (!_isOnDock(point)) {
            return true;
          }
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
    if (other is Pond) {
      _collidingPonds.add(other);
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is Tree) {
      _collidingTrees.remove(other);
    }
    if (other is Pond) {
      _collidingPonds.remove(other);
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    // Collisions are prevented before they happen, so this shouldn't fire often
    // But if it does (e.g., from external forces), we can handle it here if needed
  }
}
