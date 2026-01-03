import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show Alignment, LinearGradient;

import '../../models/water_body_data.dart';
import '../../utils/constants.dart';
import '../../utils/seeded_random.dart';

/// Ocean component - a large body of water with rolling waves and foam
class Ocean extends PositionComponent with CollisionCallbacks {
  final OceanData data;

  // Animation time
  double _time = 0;

  // Pre-computed wave and foam data
  late List<_WaveData> _waves;
  late List<_FoamParticle> _foamParticles;
  late List<_Sparkle> _sparkles;

  Ocean({required this.data})
    : super(
        position: Vector2(data.x, data.y),
        size: Vector2(data.width, data.height),
        anchor: Anchor.topLeft,
        priority: GameLayers.pond.toInt(),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _initWaves();
    _initFoam();
    _initSparkles();

    // Add rectangular hitbox for collision detection
    await add(RectangleHitbox());
  }

  void _initWaves() {
    _waves = [];
    final random = SeededRandom(data.id.hashCode);

    // Create wave lines at different depths
    for (var i = 0; i < 8; i++) {
      _waves.add(_WaveData(
        baseY: 40 + i * (size.y / 8),
        amplitude: 6 + random.nextDouble() * 8,
        frequency: 0.015 + random.nextDouble() * 0.01,
        speed: 0.8 + random.nextDouble() * 0.6,
        phaseOffset: random.nextDouble() * 2 * pi,
        alpha: 40 + random.nextInt(30),
      ));
    }
  }

  void _initFoam() {
    _foamParticles = [];
    final random = SeededRandom(data.id.hashCode * 2);

    // Create foam particles along the shore edge
    for (var i = 0; i < 40; i++) {
      _foamParticles.add(_FoamParticle(
        baseX: size.x - 8 - random.nextDouble() * 35,
        baseY: random.nextDouble() * size.y,
        radius: 3 + random.nextDouble() * 7,
        phaseOffset: random.nextDouble() * 2 * pi,
        driftSpeed: 0.5 + random.nextDouble() * 1.0,
      ));
    }
  }

  void _initSparkles() {
    _sparkles = [];
    final random = SeededRandom(data.id.hashCode * 3);

    // Create sun sparkle points
    for (var i = 0; i < 12; i++) {
      _sparkles.add(_Sparkle(
        x: random.nextDouble() * size.x * 0.8,
        y: random.nextDouble() * size.y,
        phaseOffset: random.nextDouble() * 2 * pi,
        twinkleSpeed: 2 + random.nextDouble() * 2,
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
    // Draw shore/beach edge
    _drawShore(canvas);

    // Draw main water body with gradient
    _drawWaterBody(canvas);

    // Draw animated waves
    _drawWaves(canvas);

    // Draw moving foam
    _drawFoam(canvas);

    // Draw sun sparkles
    _drawSparkles(canvas);

    // Draw shore foam line
    _drawShoreFoam(canvas);
  }

  void _drawShore(Canvas canvas) {
    final shorePaint = Paint()..color = const Color(0xFFE8D4A8); // Sandy beach
    final shoreRect = Rect.fromLTWH(-12, -12, size.x + 24, size.y + 24);
    canvas.drawRect(shoreRect, shorePaint);
  }

  void _drawWaterBody(Canvas canvas) {
    // Create depth gradient (darker away from shore)
    final gradient = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [
        const Color(0xFF2E86AB), // Lighter near shore
        const Color(0xFF1A5F7A), // Mid ocean
        const Color(0xFF0D4D63), // Deep
        const Color(0xFF0A3D4F), // Very deep
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Offset.zero & Size(size.x, size.y));
    canvas.drawRect(Offset.zero & Size(size.x, size.y), paint);
  }

  void _drawWaves(Canvas canvas) {
    for (final wave in _waves) {
      final wavePaint = Paint()
        ..color = const Color(0xFF5DADE2).withAlpha(wave.alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final path = Path();
      var started = false;

      for (var x = 0.0; x < size.x; x += 4) {
        // Animated sine wave
        final waveY = wave.baseY +
            sin((x * wave.frequency) + (_time * wave.speed) + wave.phaseOffset) *
                wave.amplitude;

        if (!started) {
          path.moveTo(x, waveY);
          started = true;
        } else {
          path.lineTo(x, waveY);
        }
      }

      canvas.drawPath(path, wavePaint);
    }
  }

  void _drawFoam(Canvas canvas) {
    for (final foam in _foamParticles) {
      // Animate foam movement
      final driftX = sin(_time * foam.driftSpeed + foam.phaseOffset) * 8;
      final driftY = cos(_time * foam.driftSpeed * 0.7 + foam.phaseOffset) * 4;

      // Pulsing opacity
      final pulse = sin(_time * 1.5 + foam.phaseOffset);
      final alpha = (100 + pulse * 30).toInt().clamp(70, 140);

      final foamPaint = Paint()..color = const Color(0xFFFFFFFF).withAlpha(alpha);

      canvas.drawCircle(
        Offset(foam.baseX + driftX, foam.baseY + driftY),
        foam.radius,
        foamPaint,
      );
    }
  }

  void _drawSparkles(Canvas canvas) {
    for (final sparkle in _sparkles) {
      // Twinkling effect
      final twinkle = (sin(_time * sparkle.twinkleSpeed + sparkle.phaseOffset) + 1) / 2;
      final alpha = (twinkle * 120).toInt();

      if (alpha > 20) {
        final sparklePaint = Paint()
          ..color = const Color(0xFFFFFFFF).withAlpha(alpha);

        // Draw small cross/star shape
        final radius = 2 + twinkle * 3;
        canvas.drawCircle(Offset(sparkle.x, sparkle.y), radius, sparklePaint);

        // Add glow
        final glowPaint = Paint()
          ..color = const Color(0xFFFFFFFF).withAlpha((alpha * 0.3).toInt());
        canvas.drawCircle(Offset(sparkle.x, sparkle.y), radius * 2, glowPaint);
      }
    }
  }

  void _drawShoreFoam(Canvas canvas) {
    // Animated foam line along the shore (right edge)
    final foamLinePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final path = Path();
    path.moveTo(size.x - 2, 0);

    for (var y = 0.0; y < size.y; y += 8) {
      // Wavy shore foam
      final waveX = size.x - 2 - sin(_time * 2 + y * 0.02) * 6 - 
          sin(_time * 0.8 + y * 0.05) * 3;
      path.lineTo(waveX, y);
    }

    canvas.drawPath(path, foamLinePaint);

    // Secondary foam line
    final foamLine2Paint = Paint()
      ..color = const Color(0xFFFFFFFF).withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path2 = Path();
    path2.moveTo(size.x - 8, 0);

    for (var y = 0.0; y < size.y; y += 8) {
      final waveX = size.x - 8 - sin(_time * 1.5 + y * 0.03 + pi) * 8;
      path2.lineTo(waveX, y);
    }

    canvas.drawPath(path2, foamLine2Paint);
  }

  /// Check if a point is inside this ocean
  @override
  bool containsPoint(Vector2 point) {
    return data.containsPoint(point.x, point.y);
  }

  /// Check if a player position is within casting range
  bool isPlayerInCastingRange(Vector2 playerPos) {
    return data.isWithinCastingRange(playerPos.x, playerPos.y, GameConstants.castProximityRadius);
  }
}

/// Wave animation data
class _WaveData {
  final double baseY;
  final double amplitude;
  final double frequency;
  final double speed;
  final double phaseOffset;
  final int alpha;

  _WaveData({
    required this.baseY,
    required this.amplitude,
    required this.frequency,
    required this.speed,
    required this.phaseOffset,
    required this.alpha,
  });
}

/// Foam particle data
class _FoamParticle {
  final double baseX;
  final double baseY;
  final double radius;
  final double phaseOffset;
  final double driftSpeed;

  _FoamParticle({
    required this.baseX,
    required this.baseY,
    required this.radius,
    required this.phaseOffset,
    required this.driftSpeed,
  });
}

/// Sparkle/glint data
class _Sparkle {
  final double x;
  final double y;
  final double phaseOffset;
  final double twinkleSpeed;

  _Sparkle({
    required this.x,
    required this.y,
    required this.phaseOffset,
    required this.twinkleSpeed,
  });
}
