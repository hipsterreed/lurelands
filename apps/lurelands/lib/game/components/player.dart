import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../../models/pond_data.dart';
import '../../utils/constants.dart';
import '../lurelands_game.dart';
import 'cast_line.dart';
import 'pond.dart';

/// Player component - animated sprite that can move and fish
class Player extends PositionComponent with HasGameReference<LurelandsGame>, CollisionCallbacks {
  Player({required Vector2 position})
    : super(
        position: position,
        size: Vector2(216, 144), // 2.25x scale of sprite frame (96x64)
        anchor: Anchor.center,
      );

  CastLine? _castLine;

  // Sprite animation
  late SpriteAnimationComponent _animationComponent;
  late SpriteAnimation _walkAnimation;
  late SpriteAnimation _idleAnimation;
  bool _isMoving = false;
  bool _facingRight = true;

  // Movement state
  double _facingAngle = 0.0; // Radians, 0 = right

  // Casting state
  bool _isCasting = false;

  bool get isCasting => _isCasting;
  double get facingAngle => _facingAngle;

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
    // Compact hitbox matching character body
    await add(RectangleHitbox(size: Vector2(50, 60), position: Vector2((size.x - 50) / 2, size.y - 105)));
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

    // Check for pond collision
    if (!_wouldCollideWithPond(newPosition)) {
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

  bool _wouldCollideWithPond(Vector2 newPos) {
    for (final pond in game.ponds) {
      // Check if new position would be inside pond (with some margin)
      final margin = GameConstants.playerSize / 2 + 5;
      final dx = newPos.x - pond.x;
      final dy = newPos.y - pond.y;
      final distance = sqrt(dx * dx + dy * dy);

      if (distance < pond.radius - margin) {
        return true;
      }
    }
    return false;
  }

  /// Start casting into a pond
  void startCasting(PondData pond) {
    if (_isCasting) return;

    _isCasting = true;

    // Calculate cast target - towards the pond center from player
    final directionToPond = Vector2(pond.x - position.x, pond.y - position.y);
    directionToPond.normalize();

    // Update facing angle towards pond
    _facingAngle = atan2(directionToPond.y, directionToPond.x);

    // Cast line lands inside the pond
    final castDistance = min(
      GameConstants.maxCastDistance,
      sqrt(pow(pond.x - position.x, 2) + pow(pond.y - position.y, 2)) - GameConstants.playerSize,
    );

    final targetX = position.x + directionToPond.x * castDistance;
    final targetY = position.y + directionToPond.y * castDistance;

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
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    // Push player out of ponds
    if (other is Pond) {
      final pushDirection = position - other.position;
      pushDirection.normalize();
      position += pushDirection * 5;
    }
  }
}
