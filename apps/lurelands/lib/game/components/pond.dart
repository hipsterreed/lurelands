import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../models/water_body_data.dart';
import '../../utils/constants.dart';
import '../../utils/seeded_random.dart';

/// Pond component - a circular body of water
class Pond extends PositionComponent with CollisionCallbacks {
  final PondData data;

  Pond({required this.data})
    : super(
        position: Vector2(data.x, data.y),
        size: Vector2.all(data.radius * 2),
        anchor: Anchor.center,
        priority: GameLayers.pond.toInt(),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Add circular hitbox for collision detection
    // Default CircleHitbox fills the component as a circle inscribed in the bounds
    await add(CircleHitbox());
  }

  @override
  void render(Canvas canvas) {
    final centerX = size.x / 2;
    final centerY = size.y / 2;
    final radius = data.radius;

    // Draw shore/edge
    final shorePaint = Paint()..color = GameColors.pondShore;
    canvas.drawCircle(Offset(centerX, centerY), radius + 8, shorePaint);

    // Draw main water body
    final waterPaint = Paint()..color = GameColors.pondBlue;
    canvas.drawCircle(Offset(centerX, centerY), radius, waterPaint);

    // Draw darker center
    final deepPaint = Paint()..color = GameColors.pondBlueDark;
    canvas.drawCircle(Offset(centerX, centerY), radius * 0.6, deepPaint);

    // Draw water highlights
    _drawWaterHighlights(canvas, centerX, centerY, radius);

    // Draw ripple effect
    _drawRipples(canvas, centerX, centerY, radius);
  }

  void _drawWaterHighlights(Canvas canvas, double cx, double cy, double radius) {
    // Draw a few highlight circles
    final random = SeededRandom(data.id.hashCode);
    for (var i = 0; i < 5; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final dist = random.nextDouble() * radius * 0.7;
      final highlightRadius = 5 + random.nextDouble() * 15;

      final hx = cx + cos(angle) * dist;
      final hy = cy + sin(angle) * dist;

      final highlightPaint = Paint()..color = GameColors.pondBlueLight.withAlpha(64);
      canvas.drawCircle(Offset(hx, hy), highlightRadius, highlightPaint);
    }
  }

  void _drawRipples(Canvas canvas, double cx, double cy, double radius) {
    // Draw concentric ripple lines
    final ripplePaint = Paint()
      ..color = GameColors.pondBlueLight.withAlpha(32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var i = 1; i <= 3; i++) {
      final rippleRadius = radius * (0.3 + i * 0.2);
      canvas.drawCircle(Offset(cx, cy), rippleRadius, ripplePaint);
    }
  }

  /// Check if a point is inside this pond
  @override
  bool containsPoint(Vector2 point) {
    return data.containsPoint(point.x, point.y);
  }

  /// Check if a player position is within casting range
  bool isPlayerInCastingRange(Vector2 playerPos) {
    return data.isWithinCastingRange(playerPos.x, playerPos.y, GameConstants.castProximityRadius);
  }
}
