import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show Alignment, LinearGradient;

import '../../models/water_body_data.dart';
import '../../utils/constants.dart';
import '../../utils/seeded_random.dart';

/// River component - an elongated body of water with flowing animation
class River extends PositionComponent with CollisionCallbacks {
  final RiverData data;

  // Animation time
  double _time = 0;

  // Pre-computed flow particle data
  late List<_FlowParticle> _flowParticles;
  late List<_RippleSpot> _rippleSpots;

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

    _initFlowParticles();
    _initRippleSpots();

    // Add rectangular hitbox for collision detection
    await add(RectangleHitbox());
  }

  void _initFlowParticles() {
    final random = SeededRandom(data.id.hashCode);
    _flowParticles = [];

    // Create flow particles across the river
    for (var i = 0; i < 15; i++) {
      _flowParticles.add(_FlowParticle(
        startX: random.nextDouble() * size.x,
        y: 8 + random.nextDouble() * (size.y - 16),
        speed: 30 + random.nextDouble() * 40,
        length: 15 + random.nextDouble() * 25,
        alpha: 30 + random.nextInt(40),
      ));
    }
  }

  void _initRippleSpots() {
    final random = SeededRandom(data.id.hashCode * 2);
    _rippleSpots = [];

    // Create stationary ripple spots (like rocks causing disturbance)
    for (var i = 0; i < 5; i++) {
      _rippleSpots.add(_RippleSpot(
        x: 30 + random.nextDouble() * (size.x - 60),
        y: 10 + random.nextDouble() * (size.y - 20),
        phaseOffset: random.nextDouble() * 2 * pi,
        maxRadius: 8 + random.nextDouble() * 10,
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

    // Draw main water body with gradient
    _drawWaterBody(canvas);

    // Draw center current (darker stripe)
    _drawCurrentStripe(canvas, halfLength, halfWidth);

    // Draw animated flow lines
    _drawFlowingParticles(canvas);

    // Draw ripple spots
    _drawRippleSpots(canvas);

    // Draw edge foam
    _drawEdgeFoam(canvas, halfWidth);
  }

  void _drawWaterBody(Canvas canvas) {
    // Create gradient from edges to center (lighter edges, darker center)
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF5DADE2).withAlpha(180), // Light edge
        const Color(0xFF2980B9), // River blue
        const Color(0xFF2980B9), // River blue
        const Color(0xFF5DADE2).withAlpha(180), // Light edge
      ],
      stops: const [0.0, 0.2, 0.8, 1.0],
    );

    final waterRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(12),
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.drawRRect(waterRect, paint);
  }

  void _drawCurrentStripe(Canvas canvas, double cx, double cy) {
    final currentPaint = Paint()..color = const Color(0xFF1F618D);
    final currentRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.x - 20,
        height: size.y * 0.35,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(currentRect, currentPaint);
  }

  void _drawFlowingParticles(Canvas canvas) {
    for (final particle in _flowParticles) {
      // Calculate current position (looping across river width)
      final currentX = (particle.startX + _time * particle.speed) % (size.x + particle.length);
      final displayX = currentX - particle.length;

      // Only draw if visible
      if (displayX < size.x && currentX > 0) {
        final flowPaint = Paint()
          ..color = GameColors.pondBlueLight.withAlpha(particle.alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

        // Draw flowing line with slight wave
        final waveOffset = sin(_time * 3 + particle.startX * 0.1) * 2;
        final path = Path();
        path.moveTo(displayX.clamp(0, size.x), particle.y + waveOffset);
        path.lineTo(currentX.clamp(0, size.x), particle.y - waveOffset);

        canvas.drawPath(path, flowPaint);
      }
    }
  }

  void _drawRippleSpots(Canvas canvas) {
    for (final spot in _rippleSpots) {
      // Animated concentric ripples
      for (var ring = 0; ring < 2; ring++) {
        final phase = (_time * 1.5 + spot.phaseOffset + ring * pi) % (2 * pi);
        final progress = phase / (2 * pi);
        final currentRadius = progress * spot.maxRadius;
        final alpha = ((1.0 - progress) * 50).toInt().clamp(0, 255);

        if (alpha > 5) {
          final ripplePaint = Paint()
            ..color = GameColors.pondBlueLight.withAlpha(alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;

          canvas.drawCircle(
            Offset(spot.x, spot.y),
            currentRadius,
            ripplePaint,
          );
        }
      }
    }
  }

  void _drawEdgeFoam(Canvas canvas, double halfWidth) {
    final random = SeededRandom(data.id.hashCode * 3);
    final foamPaint = Paint()..color = const Color(0xFFFFFFFF).withAlpha(60);

    // Draw foam bubbles along top and bottom edges
    for (var i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.x;
      final isTop = i % 2 == 0;
      final baseY = isTop ? 4.0 : size.y - 4;
      final yOffset = sin(_time * 2 + x * 0.05) * 2;
      final radius = 2 + random.nextDouble() * 3;

      canvas.drawCircle(Offset(x, baseY + yOffset), radius, foamPaint);
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

/// Flow particle data for animation
class _FlowParticle {
  final double startX;
  final double y;
  final double speed;
  final double length;
  final int alpha;

  _FlowParticle({
    required this.startX,
    required this.y,
    required this.speed,
    required this.length,
    required this.alpha,
  });
}

/// Ripple spot data
class _RippleSpot {
  final double x;
  final double y;
  final double phaseOffset;
  final double maxRadius;

  _RippleSpot({
    required this.x,
    required this.y,
    required this.phaseOffset,
    required this.maxRadius,
  });
}
