import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../models/water_body_data.dart';
import '../../utils/constants.dart';

/// River component - an elongated body of water that flows across the map
class River extends PositionComponent with CollisionCallbacks {
  final RiverData data;

  River({required this.data})
    : super(
        position: Vector2(data.x, data.y),
        size: Vector2(data.length, data.width),
        anchor: Anchor.center,
        angle: data.rotation,
        priority: GameLayers.pond.toInt(),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Add rectangular hitbox for collision detection
    await add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    final halfLength = size.x / 2;
    final halfWidth = size.y / 2;

    // Draw shore/bank edges with rounded ends
    final shorePaint = Paint()..color = GameColors.pondShore;
    final shoreRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: size.x + 16, height: size.y + 16),
      const Radius.circular(20),
    );
    canvas.save();
    canvas.translate(halfLength, halfWidth);
    canvas.drawRRect(shoreRect, shorePaint);
    canvas.restore();

    // Draw main water body with rounded ends
    final waterPaint = Paint()..color = const Color(0xFF2980B9); // River blue
    final waterRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(12),
    );
    canvas.drawRRect(waterRect, waterPaint);

    // Draw center current (darker stripe)
    final currentPaint = Paint()..color = const Color(0xFF1F618D);
    final currentRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(halfLength, halfWidth),
        width: size.x - 20,
        height: size.y * 0.4,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(currentRect, currentPaint);

    // Draw flow lines
    _drawFlowLines(canvas, halfLength, halfWidth);

    // Draw ripples
    _drawRipples(canvas, halfLength, halfWidth);
  }

  void _drawFlowLines(Canvas canvas, double cx, double cy) {
    final flowPaint = Paint()
      ..color = GameColors.pondBlueLight.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final random = _SeededRandom(data.id.hashCode);

    // Draw flowing lines along the river
    for (var i = 0; i < 6; i++) {
      final yOffset = -size.y * 0.3 + i * (size.y * 0.6 / 5);
      final path = Path();
      path.moveTo(10, cy + yOffset);

      for (var x = 10.0; x < size.x - 10; x += 30) {
        final waveY = yOffset + (random.nextDouble() - 0.5) * 8;
        path.lineTo(x + 15, cy + waveY);
        path.lineTo(x + 30, cy + yOffset);
      }

      canvas.drawPath(path, flowPaint);
    }
  }

  void _drawRipples(Canvas canvas, double cx, double cy) {
    final ripplePaint = Paint()
      ..color = GameColors.pondBlueLight.withAlpha(40)
      ..style = PaintingStyle.fill;

    final random = _SeededRandom(data.id.hashCode * 3);

    // Draw small ripple circles
    for (var i = 0; i < 10; i++) {
      final x = 20 + random.nextDouble() * (size.x - 40);
      final y = 10 + random.nextDouble() * (size.y - 20);
      final radius = 4 + random.nextDouble() * 8;

      canvas.drawCircle(Offset(x, y), radius, ripplePaint);
    }
  }

  /// Check if a point is inside this river
  @override
  bool containsPoint(Vector2 point) {
    return data.containsPoint(point.x, point.y);
  }

  /// Check if a player position is within casting range
  bool isPlayerInCastingRange(Vector2 playerPos) {
    return data.isWithinCastingRange(playerPos.x, playerPos.y, GameConstants.castProximityRadius);
  }
}

/// Simple seeded random for consistent patterns
class _SeededRandom {
  int _seed;

  _SeededRandom(this._seed);

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }
}

