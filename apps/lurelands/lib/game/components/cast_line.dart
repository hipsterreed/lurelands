import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';

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
  
  // Bite shake animation
  bool _isBiting = false;
  double _biteShakeTime = 0.0;
  double _biteShakeOffsetX = 0.0;

  // Lure sprite
  late ui.Image _lureImage;
  static const double _lureSize = 24.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load lure image from assets/items/ (not assets/images/)
    final data = await rootBundle.load('assets/items/lure_1.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _lureImage = frame.image;

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
      
      // Bite shake animation (rapid horizontal shake)
      if (_isBiting) {
        _biteShakeTime += dt * 40; // Fast shake
        _biteShakeOffsetX = sin(_biteShakeTime) * GameConstants.bobberShakeIntensity;
      } else {
        _biteShakeOffsetX = 0.0;
      }
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
  void render(ui.Canvas canvas) {
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

  void _drawLine(ui.Canvas canvas, Vector2 start, Vector2 end) {
    final linePaint = ui.Paint()
      ..color = GameColors.fishingLineCast
      ..strokeWidth = 1.5
      ..style = ui.PaintingStyle.stroke;

    // Draw line with slight curve (catenary-like)
    final midX = (start.x + end.x) / 2;
    final midY = (start.y + end.y) / 2 + 10 * (1 - _animationProgress);

    // Simple approximation with two line segments
    canvas.drawLine(ui.Offset(start.x, start.y), ui.Offset(midX, midY), linePaint);
    canvas.drawLine(ui.Offset(midX, midY), ui.Offset(end.x, end.y), linePaint);
  }

  void _drawBobber(ui.Canvas canvas, Vector2 pos) {
    final bobberX = pos.x + _biteShakeOffsetX;
    final bobberY = pos.y + _bobberBobOffset;

    // Draw lure sprite centered at position
    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      _lureImage.width.toDouble(),
      _lureImage.height.toDouble(),
    );
    final dstRect = ui.Rect.fromCenter(
      center: ui.Offset(bobberX, bobberY),
      width: _lureSize,
      height: _lureSize,
    );
    canvas.drawImageRect(_lureImage, srcRect, dstRect, ui.Paint());
  }

  void _drawSplash(ui.Canvas canvas, Vector2 pos) {
    // Animated ripples
    final rippleTime = _bobberBobTime * 0.5;
    for (var i = 0; i < 3; i++) {
      final phase = (rippleTime + i * 0.5) % 2.0;
      if (phase < 1.5) {
        final radius = 8 + phase * 20;
        final alpha = ((1.5 - phase) / 1.5 * 0.4 * 255).toInt();
        final ripplePaint = ui.Paint()
          ..color = ui.Color.fromARGB(alpha, 255, 255, 255)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(ui.Offset(pos.x, pos.y), radius, ripplePaint);
      }
    }
  }

  /// Start reeling in the line
  void startReeling() {
    _isReeling = true;
    _isBiting = false;
  }

  /// Start bite shake animation (fish is biting!)
  void startBiteAnimation() {
    _isBiting = true;
    _biteShakeTime = 0.0;
  }

  /// Stop bite shake animation
  void stopBiteAnimation() {
    _isBiting = false;
    _biteShakeOffsetX = 0.0;
  }
}
