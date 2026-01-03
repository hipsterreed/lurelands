import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show Alignment, RadialGradient;

import '../../models/water_body_data.dart';
import '../../utils/constants.dart';
import '../../utils/seeded_random.dart';

/// Pond component - a circular body of water with animated ripples
class Pond extends PositionComponent with CollisionCallbacks {
  final PondData data;

  // Animation time
  double _time = 0;

  // Pre-computed ripple data for performance
  late List<_RippleData> _ripples;
  late List<_HighlightData> _highlights;

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

    // Pre-compute ripple positions
    _initRipples();
    _initHighlights();

    // Add circular hitbox for collision detection
    await add(CircleHitbox());
  }

  void _initRipples() {
    final random = SeededRandom(data.id.hashCode);
    _ripples = [];

    // Create 3-5 ripple sources at random positions
    final rippleCount = 3 + random.nextInt(3);
    for (var i = 0; i < rippleCount; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final dist = random.nextDouble() * data.radius * 0.6;
      _ripples.add(_RippleData(
        x: cos(angle) * dist,
        y: sin(angle) * dist,
        phaseOffset: random.nextDouble() * 2 * pi,
        speed: 0.8 + random.nextDouble() * 0.4,
        maxRadius: 20 + random.nextDouble() * 25,
      ));
    }
  }

  void _initHighlights() {
    final random = SeededRandom(data.id.hashCode * 2);
    _highlights = [];

    // Create shimmering highlight spots
    for (var i = 0; i < 6; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final dist = random.nextDouble() * data.radius * 0.7;
      _highlights.add(_HighlightData(
        x: cos(angle) * dist,
        y: sin(angle) * dist,
        baseRadius: 5 + random.nextDouble() * 12,
        phaseOffset: random.nextDouble() * 2 * pi,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final centerX = size.x / 2;
    final centerY = size.y / 2;
    final radius = data.radius;

    // Draw shore/edge
    final shorePaint = Paint()..color = GameColors.pondShore;
    canvas.drawCircle(Offset(centerX, centerY), radius + 8, shorePaint);

    // Draw main water body with radial gradient
    _drawWaterBody(canvas, centerX, centerY, radius);

    // Draw animated ripples
    _drawAnimatedRipples(canvas, centerX, centerY, radius);

    // Draw shimmering highlights
    _drawShimmeringHighlights(canvas, centerX, centerY, radius);

    // Draw subtle caustic patterns
    _drawCaustics(canvas, centerX, centerY, radius);
  }

  void _drawWaterBody(Canvas canvas, double cx, double cy, double radius) {
    // Create radial gradient for depth effect
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        GameColors.pondBlueDark, // Deep center
        GameColors.pondBlue, // Mid
        GameColors.pondBlueLight.withAlpha(200), // Edge
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawCircle(Offset(cx, cy), radius, paint);
  }

  void _drawAnimatedRipples(Canvas canvas, double cx, double cy, double radius) {
    for (final ripple in _ripples) {
      // Calculate animated ripple state
      final phase = (_time * ripple.speed + ripple.phaseOffset) % (2 * pi);
      final progress = phase / (2 * pi);

      // Draw 2 concentric expanding rings per ripple source
      for (var ring = 0; ring < 2; ring++) {
        final ringProgress = (progress + ring * 0.5) % 1.0;
        final currentRadius = ringProgress * ripple.maxRadius;
        final alpha = ((1.0 - ringProgress) * 60).toInt().clamp(0, 255);

        if (alpha > 5) {
          final ripplePaint = Paint()
            ..color = GameColors.pondBlueLight.withAlpha(alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 + (1.0 - ringProgress) * 1.5;

          canvas.drawCircle(
            Offset(cx + ripple.x, cy + ripple.y),
            currentRadius,
            ripplePaint,
          );
        }
      }
    }
  }

  void _drawShimmeringHighlights(Canvas canvas, double cx, double cy, double radius) {
    for (final highlight in _highlights) {
      // Oscillating size and opacity
      final shimmer = sin(_time * 2.5 + highlight.phaseOffset);
      final radiusMod = highlight.baseRadius * (0.7 + shimmer * 0.3);
      final alpha = (40 + shimmer * 25).toInt().clamp(15, 70);

      final highlightPaint = Paint()
        ..color = const Color(0xFFFFFFFF).withAlpha(alpha);

      canvas.drawCircle(
        Offset(cx + highlight.x, cy + highlight.y),
        radiusMod,
        highlightPaint,
      );
    }
  }

  void _drawCaustics(Canvas canvas, double cx, double cy, double radius) {
    // Subtle moving light patterns on the water surface
    final causticPaint = Paint()
      ..color = GameColors.pondBlueLight.withAlpha(25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final random = SeededRandom(data.id.hashCode * 3);

    for (var i = 0; i < 4; i++) {
      final baseAngle = (i / 4) * 2 * pi;
      final animAngle = baseAngle + _time * 0.3;
      final dist = radius * (0.3 + random.nextDouble() * 0.3);

      final path = Path();
      final startX = cx + cos(animAngle) * dist;
      final startY = cy + sin(animAngle) * dist;
      path.moveTo(startX, startY);

      // Draw wavy caustic line
      for (var j = 1; j <= 3; j++) {
        final segAngle = animAngle + j * 0.5;
        final segDist = dist + j * 10;
        final waveOffset = sin(_time * 2 + j) * 5;
        path.lineTo(
          cx + cos(segAngle) * segDist + waveOffset,
          cy + sin(segAngle) * segDist,
        );
      }

      canvas.drawPath(path, causticPaint);
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

/// Pre-computed ripple animation data
class _RippleData {
  final double x;
  final double y;
  final double phaseOffset;
  final double speed;
  final double maxRadius;

  _RippleData({
    required this.x,
    required this.y,
    required this.phaseOffset,
    required this.speed,
    required this.maxRadius,
  });
}

/// Pre-computed highlight animation data
class _HighlightData {
  final double x;
  final double y;
  final double baseRadius;
  final double phaseOffset;

  _HighlightData({
    required this.x,
    required this.y,
    required this.baseRadius,
    required this.phaseOffset,
  });
}
