import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';

import '../../utils/constants.dart';

/// Animated fish that flies from bobber to player and bounces when caught
class CaughtFishAnimation extends PositionComponent {
  final Vector2 startPosition;  // Bobber position
  final Vector2 targetPosition; // Above player name
  final String fishAssetPath;
  final int spriteColumn;
  final int spriteRow;
  final int rarity; // Number of stars (1-3)
  final VoidCallback? onComplete;

  CaughtFishAnimation({
    required this.startPosition,
    required this.targetPosition,
    required this.fishAssetPath,
    required this.spriteColumn,
    required this.spriteRow,
    this.rarity = 1,
    this.onComplete,
  }) : super(
          position: startPosition.clone(),
          size: Vector2(28, 28),
          anchor: Anchor.center,
          priority: GameLayers.ui.toInt(),
        );

  // Animation phases
  static const double _flyDuration = 0.6;
  static const double _bounceDuration = 1.0;
  static const double _fadeDuration = 0.3;

  // Spritesheet configuration
  static const double _spriteSize = 16.0;

  // State
  late ui.Image _spritesheetImage;
  late ui.Rect _srcRect;
  double _timer = 0.0;
  _AnimationPhase _phase = _AnimationPhase.flying;
  double _opacity = 1.0;
  double _scale = 0.5;
  double _rotation = 0.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load spritesheet image
    try {
      final data = await rootBundle.load(fishAssetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _spritesheetImage = frame.image;

      // Calculate source rectangle for this fish sprite
      _srcRect = ui.Rect.fromLTWH(
        spriteColumn * _spriteSize,
        spriteRow * _spriteSize,
        _spriteSize,
        _spriteSize,
      );
    } catch (e) {
      // Fallback - create a placeholder
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawCircle(
        const ui.Offset(24, 24),
        20,
        ui.Paint()..color = const ui.Color(0xFFFF9800),
      );
      final picture = recorder.endRecording();
      _spritesheetImage = await picture.toImage(48, 48);
      _srcRect = ui.Rect.fromLTWH(0, 0, 48, 48);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    _timer += dt;

    switch (_phase) {
      case _AnimationPhase.flying:
        _updateFlying(dt);
        break;
      case _AnimationPhase.bouncing:
        _updateBouncing(dt);
        break;
      case _AnimationPhase.fading:
        _updateFading(dt);
        break;
    }
  }

  void _updateFlying(double dt) {
    final progress = (_timer / _flyDuration).clamp(0.0, 1.0);
    
    // Ease out curve for smooth deceleration
    final easedProgress = Curves.easeOutCubic.transform(progress);
    
    // Calculate position with arc (parabolic path)
    final dx = targetPosition.x - startPosition.x;
    final dy = targetPosition.y - startPosition.y;
    
    // Arc height - higher arc for longer distances
    final distance = startPosition.distanceTo(targetPosition);
    final arcHeight = distance * 0.3;
    
    // Position along arc
    position.x = startPosition.x + dx * easedProgress;
    
    // Parabolic arc: y offset that peaks at progress = 0.5
    final arcOffset = -4 * arcHeight * progress * (progress - 1);
    position.y = startPosition.y + dy * easedProgress - arcOffset;
    
    // Scale up as it approaches
    _scale = 0.5 + 0.8 * easedProgress;
    
    // Rotate based on movement direction (fish "swims" through air)
    _rotation = sin(progress * pi * 3) * 0.2;
    
    // Transition to bouncing phase
    if (progress >= 1.0) {
      _timer = 0.0;
      _phase = _AnimationPhase.bouncing;
      _scale = 1.3; // Pop effect on arrival
      HapticFeedback.mediumImpact();
    }
  }

  void _updateBouncing(double dt) {
    final progress = (_timer / _bounceDuration).clamp(0.0, 1.0);
    
    // Damped bounce animation
    // Multiple bounces that decrease in amplitude
    final bounceFrequency = 4.0; // Number of bounces
    final dampening = 1.0 - progress;
    final bounce = sin(progress * pi * bounceFrequency * 2) * dampening;
    
    // Vertical bounce
    position.y = targetPosition.y - bounce * 15;
    
    // Scale bounce (squash and stretch)
    final scaleBounce = 1.0 + bounce * 0.15;
    _scale = scaleBounce;
    
    // Slight rotation wobble
    _rotation = bounce * 0.1;
    
    // Transition to fading phase
    if (progress >= 1.0) {
      _timer = 0.0;
      _phase = _AnimationPhase.fading;
      position = targetPosition.clone();
      _scale = 1.0;
      _rotation = 0.0;
    }
  }

  void _updateFading(double dt) {
    final progress = (_timer / _fadeDuration).clamp(0.0, 1.0);
    
    // Fade out with slight scale up (dissipate effect)
    _opacity = 1.0 - Curves.easeIn.transform(progress);
    _scale = 1.0 + progress * 0.3;
    
    // Float upward slightly while fading
    position.y = targetPosition.y - progress * 20;
    
    // Remove when complete
    if (progress >= 1.0) {
      onComplete?.call();
      removeFromParent();
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (_opacity <= 0) return;

    canvas.save();
    
    // Apply transformations
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(_rotation);
    canvas.scale(_scale);
    canvas.translate(-size.x / 2, -size.y / 2);

    // Draw rarity stars above the fish
    _drawRarityStars(canvas);

    // Draw fish with opacity
    final paint = ui.Paint();
    if (_opacity < 1.0) {
      paint.color = ui.Color.fromRGBO(255, 255, 255, _opacity);
    }

    final dstRect = ui.Rect.fromLTWH(0, 0, size.x, size.y);

    canvas.drawImageRect(_spritesheetImage, _srcRect, dstRect, paint);

    // Draw sparkle effect during bounce phase
    if (_phase == _AnimationPhase.bouncing) {
      _drawSparkles(canvas);
    }

    canvas.restore();
  }

  void _drawRarityStars(ui.Canvas canvas) {
    if (rarity <= 0) return;
    
    final starSize = 8.0;
    final starSpacing = 10.0;
    final totalWidth = rarity * starSpacing;
    final startX = (size.x - totalWidth) / 2 + starSpacing / 2;
    final starY = -4.0; // Above the fish
    
    final starPaint = ui.Paint()
      ..color = ui.Color.fromRGBO(255, 193, 7, _opacity) // Amber color
      ..style = ui.PaintingStyle.fill;
    
    final shadowPaint = ui.Paint()
      ..color = ui.Color.fromRGBO(0, 0, 0, 0.5 * _opacity)
      ..style = ui.PaintingStyle.fill;
    
    for (var i = 0; i < rarity; i++) {
      final x = startX + i * starSpacing;
      // Draw shadow
      _drawStarShape(canvas, x + 0.5, starY + 1, starSize * 0.6, shadowPaint);
      // Draw star
      _drawStarShape(canvas, x, starY, starSize * 0.6, starPaint);
    }
  }

  void _drawStarShape(ui.Canvas canvas, double x, double y, double radius, ui.Paint paint) {
    final path = ui.Path();
    const points = 5;
    const innerRadius = 0.4; // Inner radius as fraction of outer
    
    for (var i = 0; i < points * 2; i++) {
      final angle = (i * pi / points) - pi / 2;
      final r = i.isEven ? radius : radius * innerRadius;
      final px = x + cos(angle) * r;
      final py = y + sin(angle) * r;
      
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }

  void _drawSparkles(ui.Canvas canvas) {
    final progress = (_timer / _bounceDuration).clamp(0.0, 1.0);
    final sparkleOpacity = (1.0 - progress) * _opacity;
    
    if (sparkleOpacity <= 0) return;

    final sparklePaint = ui.Paint()
      ..color = ui.Color.fromRGBO(255, 255, 150, sparkleOpacity)
      ..style = ui.PaintingStyle.fill;

    // Draw small star sparkles around the fish
    final random = Random(42); // Fixed seed for consistent sparkles
    for (var i = 0; i < 6; i++) {
      final angle = (i / 6) * pi * 2 + progress * pi;
      final radius = 30 + random.nextDouble() * 15;
      final sparkleX = size.x / 2 + cos(angle) * radius;
      final sparkleY = size.y / 2 + sin(angle) * radius;
      
      // Pulsing size
      final sparkleSize = 3 + sin(progress * pi * 4 + i) * 2;
      
      // Draw 4-pointed star
      _drawStar(canvas, sparkleX, sparkleY, sparkleSize, sparklePaint);
    }
  }

  void _drawStar(ui.Canvas canvas, double x, double y, double size, ui.Paint paint) {
    final path = ui.Path();
    
    // 4-pointed star
    path.moveTo(x, y - size);
    path.lineTo(x + size * 0.3, y - size * 0.3);
    path.lineTo(x + size, y);
    path.lineTo(x + size * 0.3, y + size * 0.3);
    path.lineTo(x, y + size);
    path.lineTo(x - size * 0.3, y + size * 0.3);
    path.lineTo(x - size, y);
    path.lineTo(x - size * 0.3, y - size * 0.3);
    path.close();
    
    canvas.drawPath(path, paint);
  }
}

enum _AnimationPhase {
  flying,   // Moving from bobber to player
  bouncing, // Celebratory bounce above player
  fading,   // Fade out and disappear
}

