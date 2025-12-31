import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';

import '../../utils/constants.dart';

/// Cast fishing line component - shows the line in water when casting
class CastLine extends PositionComponent {
  final Vector2 startPosition;
  final Vector2 endPosition;

  CastLine({
    required this.startPosition,
    required this.endPosition,
  }) : super(priority: GameLayers.castLine.toInt());

  // Animation state
  double _animationProgress = 0.0;
  bool _isReeling = false;
  bool _castComplete = false;
  double _bobberBobOffset = 0.0;
  double _bobberBobTime = 0.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Start cast animation
    _animateCast();
  }

  void _animateCast() {
    // Simple manual animation - Flame effects can be complex
    // We'll handle this in update()
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Handle cast animation
    if (!_castComplete && !_isReeling) {
      _animationProgress += dt / GameConstants.castAnimationDuration;
      if (_animationProgress >= 1.0) {
        _animationProgress = 1.0;
        _castComplete = true;
      }
    }

    // Bobber bobbing animation
    if (_castComplete && !_isReeling) {
      _bobberBobTime += dt * 3;
      _bobberBobOffset = sin(_bobberBobTime) * 3;
    }

    // Handle reeling animation
    if (_isReeling) {
      _animationProgress -= dt / GameConstants.reelAnimationDuration;
      if (_animationProgress <= 0) {
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_animationProgress <= 0) return;

    // Calculate current line end based on animation progress
    final easeProgress = Curves.easeOut.transform(_animationProgress);
    final currentEnd = Vector2(
      startPosition.x + (endPosition.x - startPosition.x) * easeProgress,
      startPosition.y + (endPosition.y - startPosition.y) * easeProgress,
    );

    // Draw fishing line
    _drawLine(canvas, startPosition, currentEnd);

    // Draw bobber at line end
    if (_animationProgress > 0.3) {
      _drawBobber(canvas, currentEnd);
    }

    // Draw splash effect when line lands
    if (_castComplete && !_isReeling) {
      _drawSplash(canvas, endPosition);
    }
  }

  void _drawLine(Canvas canvas, Vector2 start, Vector2 end) {
    final linePaint = Paint()
      ..color = GameColors.fishingLineCast
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw line with slight curve (catenary-like)
    final midX = (start.x + end.x) / 2;
    final midY = (start.y + end.y) / 2 + 10 * (1 - _animationProgress);

    // Simple approximation with two line segments
    canvas.drawLine(Offset(start.x, start.y), Offset(midX, midY), linePaint);
    canvas.drawLine(Offset(midX, midY), Offset(end.x, end.y), linePaint);
  }

  void _drawBobber(Canvas canvas, Vector2 pos) {
    final bobberY = pos.y + _bobberBobOffset;

    // White top
    final whitePaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(Offset(pos.x, bobberY - 2), 4, whitePaint);

    // Red bottom
    final redPaint = Paint()..color = const Color(0xFFFF3333);
    canvas.drawCircle(Offset(pos.x, bobberY + 2), 4, redPaint);

    // Outline
    final outlinePaint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(pos.x, bobberY), 5, outlinePaint);
  }

  void _drawSplash(Canvas canvas, Vector2 pos) {
    // Animated ripples
    final rippleTime = _bobberBobTime * 0.5;
    for (var i = 0; i < 3; i++) {
      final phase = (rippleTime + i * 0.5) % 2.0;
      if (phase < 1.5) {
        final radius = 8 + phase * 20;
        final alpha = ((1.5 - phase) / 1.5 * 0.4 * 255).toInt();
        final ripplePaint = Paint()
          ..color = Color.fromARGB(alpha, 255, 255, 255)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(Offset(pos.x, pos.y), radius, ripplePaint);
      }
    }
  }

  /// Start reeling in the line
  void startReeling() {
    _isReeling = true;
  }
}
