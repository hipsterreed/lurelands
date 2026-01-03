import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show Alignment, LinearGradient;

import '../../models/water_body_data.dart';
import '../../utils/constants.dart';
import '../../utils/seeded_random.dart';

/// Ocean component - a large rectangular body of water on the edge of the map
class Ocean extends PositionComponent with CollisionCallbacks {
  final OceanData data;

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

    // Add rectangular hitbox for collision detection
    await add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    // Draw shore/beach edge
    final shorePaint = Paint()..color = const Color(0xFFE8D4A8); // Sandy beach color
    final shoreRect = Rect.fromLTWH(-12, -12, size.x + 24, size.y + 24);
    canvas.drawRect(shoreRect, shorePaint);

    // Draw main water body
    final waterPaint = Paint()..color = const Color(0xFF1A5F7A); // Deep ocean blue
    canvas.drawRect(Offset.zero & Size(size.x, size.y), waterPaint);

    // Draw gradient for depth effect
    _drawDepthGradient(canvas);

    // Draw wave patterns
    _drawWaves(canvas);

    // Draw foam along the shore edge
    _drawFoam(canvas);
  }

  void _drawDepthGradient(Canvas canvas) {
    // Darker towards the edge of the map (away from land)
    final gradient = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [
        const Color(0xFF1A5F7A),
        const Color(0xFF0D3B4D),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Offset.zero & Size(size.x, size.y));
    canvas.drawRect(Offset.zero & Size(size.x, size.y), paint);
  }

  void _drawWaves(Canvas canvas) {
    final wavePaint = Paint()
      ..color = const Color(0xFF2E86AB).withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final random = SeededRandom(data.id.hashCode);
    
    // Draw horizontal wave lines
    for (var i = 0; i < 8; i++) {
      final y = 50 + i * (size.y / 8);
      final path = Path();
      path.moveTo(0, y);
      
      for (var x = 0.0; x < size.x; x += 40) {
        final waveHeight = 8 + random.nextDouble() * 12;
        path.quadraticBezierTo(
          x + 20, y + waveHeight,
          x + 40, y,
        );
      }
      
      canvas.drawPath(path, wavePaint);
    }
  }

  void _drawFoam(Canvas canvas) {
    final foamPaint = Paint()..color = const Color(0xFFFFFFFF).withAlpha(120);
    
    final random = SeededRandom(data.id.hashCode * 2);
    
    // Draw foam dots along the right edge (shore side)
    for (var i = 0; i < 30; i++) {
      final x = size.x - 5 - random.nextDouble() * 25;
      final y = random.nextDouble() * size.y;
      final radius = 3 + random.nextDouble() * 6;
      
      canvas.drawCircle(Offset(x, y), radius, foamPaint);
    }
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

