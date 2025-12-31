import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../models/pond_data.dart';
import '../../utils/constants.dart';
import '../lurelands_game.dart';
import 'cast_line.dart';
import 'fishing_pole.dart';
import 'pond.dart';

/// Player component - a colored block that can move and fish
class Player extends PositionComponent
    with HasGameReference<LurelandsGame>, CollisionCallbacks {
  Player({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(GameConstants.playerSize),
          anchor: Anchor.center,
          priority: GameLayers.player.toInt(),
        );

  late FishingPole _fishingPole;
  CastLine? _castLine;

  // Movement state
  double _facingAngle = 0.0; // Radians, 0 = right

  // Casting state
  bool _isCasting = false;

  bool get isCasting => _isCasting;
  double get facingAngle => _facingAngle;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Add collision hitbox
    await add(RectangleHitbox());

    // Add fishing pole as child component
    _fishingPole = FishingPole();
    await add(_fishingPole);
  }

  @override
  void render(Canvas canvas) {
    // Draw player as a colored block
    final paint = Paint()..color = GameColors.playerDefault;
    canvas.drawRect(size.toRect(), paint);

    // Draw outline
    final outlinePaint = Paint()
      ..color = GameColors.playerOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(size.toRect(), outlinePaint);

    // Draw facing indicator (small triangle)
    _drawFacingIndicator(canvas);
  }

  void _drawFacingIndicator(Canvas canvas) {
    final centerX = size.x / 2;
    final centerY = size.y / 2;
    final indicatorSize = 6.0;

    final tipX = centerX + cos(_facingAngle) * (size.x / 2 + indicatorSize);
    final tipY = centerY + sin(_facingAngle) * (size.y / 2 + indicatorSize);

    final path = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(
        centerX + cos(_facingAngle + 2.5) * (size.x / 2 - 2),
        centerY + sin(_facingAngle + 2.5) * (size.y / 2 - 2),
      )
      ..lineTo(
        centerX + cos(_facingAngle - 2.5) * (size.x / 2 - 2),
        centerY + sin(_facingAngle - 2.5) * (size.y / 2 - 2),
      )
      ..close();

    final indicatorPaint = Paint()..color = GameColors.fishingPole;
    canvas.drawPath(path, indicatorPaint);
  }

  /// Move the player in a direction
  void move(Vector2 direction, double dt) {
    if (_isCasting) return; // Can't move while casting

    final movement = direction * GameConstants.playerSpeed * dt;
    final newPosition = position + movement;

    // Clamp to world bounds
    newPosition.x = newPosition.x.clamp(
      GameConstants.playerSize / 2,
      GameConstants.worldWidth - GameConstants.playerSize / 2,
    );
    newPosition.y = newPosition.y.clamp(
      GameConstants.playerSize / 2,
      GameConstants.worldHeight - GameConstants.playerSize / 2,
    );

    // Check for pond collision
    if (!_wouldCollideWithPond(newPosition)) {
      position = newPosition;
    }

    // Update facing angle based on movement direction
    if (direction.length > 0) {
      _facingAngle = atan2(direction.y, direction.x);
    }
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
    final directionToPond = Vector2(
      pond.x - position.x,
      pond.y - position.y,
    );
    directionToPond.normalize();

    // Update facing angle towards pond
    _facingAngle = atan2(directionToPond.y, directionToPond.x);

    // Cast line lands inside the pond
    final castDistance = min(
      GameConstants.maxCastDistance,
      sqrt(pow(pond.x - position.x, 2) + pow(pond.y - position.y, 2)) -
          GameConstants.playerSize,
    );

    final targetX = position.x + directionToPond.x * castDistance;
    final targetY = position.y + directionToPond.y * castDistance;

    // Create cast line
    _castLine = CastLine(
      startPosition: position.clone(),
      endPosition: Vector2(targetX, targetY),
    );
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
