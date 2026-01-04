import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../lurelands_game.dart';

/// A shop building component that players can interact with
class Shop extends PositionComponent with HasGameReference<LurelandsGame> {
  /// Unique identifier for this shop
  final String id;
  
  /// Display name of the shop
  final String name;
  
  /// Interaction radius - how close player needs to be to interact
  static const double interactionRadius = 80.0;
  
  // Visual dimensions
  static const double shopWidth = 96.0;
  static const double shopHeight = 112.0;
  
  // Shake animation state (when player is near)
  double _shakeTime = 0;
  bool _isShaking = false;
  static const double _shakeDuration = 0.3;
  static const double _shakeIntensity = 0.02;
  
  // Track player proximity
  bool _playerNearby = false;
  bool get isPlayerNearby => _playerNearby;

  Shop({
    required Vector2 position,
    required this.id,
    this.name = 'Shop',
  }) : super(
         position: position,
         size: Vector2(shopWidth, shopHeight),
         anchor: Anchor.bottomCenter,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Set priority based on Y position for depth sorting
    priority = position.y.toInt();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Check if player is nearby
    final player = game.player;
    if (player != null) {
      final dx = player.position.x - position.x;
      final dy = player.position.y - position.y;
      final distance = sqrt(dx * dx + dy * dy);
      final wasNearby = _playerNearby;
      _playerNearby = distance < interactionRadius;
      
      // Trigger shake when player enters proximity
      if (_playerNearby && !wasNearby) {
        _isShaking = true;
        _shakeTime = 0;
      }
    }

    // Animate shake
    if (_isShaking) {
      _shakeTime += dt;

      if (_shakeTime < _shakeDuration) {
        final progress = _shakeTime / _shakeDuration;
        final damping = 1.0 - progress;
        final oscillation = sin(_shakeTime * 20);
        angle = oscillation * _shakeIntensity * damping;
      } else {
        angle = 0;
        _isShaking = false;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw shop building
    _drawShopBuilding(canvas);
    
    // Draw interaction indicator when player is nearby
    if (_playerNearby) {
      _drawInteractionIndicator(canvas);
    }
  }

  void _drawShopBuilding(Canvas canvas) {
    // Base/foundation
    final basePaint = Paint()..color = const Color(0xFF5D4037);
    canvas.drawRect(
      Rect.fromLTWH(4, size.y - 12, size.x - 8, 12),
      basePaint,
    );
    
    // Main building body
    final wallPaint = Paint()..color = const Color(0xFFD7CCC8);
    canvas.drawRect(
      Rect.fromLTWH(8, 32, size.x - 16, size.y - 44),
      wallPaint,
    );
    
    // Wood frame outline
    final framePaint = Paint()
      ..color = const Color(0xFF6D4C41)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(
      Rect.fromLTWH(8, 32, size.x - 16, size.y - 44),
      framePaint,
    );
    
    // Roof
    final roofPath = Path()
      ..moveTo(0, 36)
      ..lineTo(size.x / 2, 0)
      ..lineTo(size.x, 36)
      ..close();
    final roofPaint = Paint()..color = const Color(0xFF8D6E63);
    canvas.drawPath(roofPath, roofPaint);
    
    // Roof outline
    final roofOutlinePaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(roofPath, roofOutlinePaint);
    
    // Door
    final doorPaint = Paint()..color = const Color(0xFF4E342E);
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 12, size.y - 52, 24, 40),
      doorPaint,
    );
    
    // Door knob
    final knobPaint = Paint()..color = const Color(0xFFFFD54F);
    canvas.drawCircle(
      Offset(size.x / 2 + 6, size.y - 32),
      3,
      knobPaint,
    );
    
    // Window on left
    final windowPaint = Paint()..color = const Color(0xFF81D4FA);
    canvas.drawRect(
      Rect.fromLTWH(14, 48, 18, 18),
      windowPaint,
    );
    final windowFramePaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(14, 48, 18, 18),
      windowFramePaint,
    );
    // Window cross
    canvas.drawLine(Offset(23, 48), Offset(23, 66), windowFramePaint);
    canvas.drawLine(Offset(14, 57), Offset(32, 57), windowFramePaint);
    
    // Window on right
    canvas.drawRect(
      Rect.fromLTWH(size.x - 32, 48, 18, 18),
      windowPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x - 32, 48, 18, 18),
      windowFramePaint,
    );
    canvas.drawLine(Offset(size.x - 23, 48), Offset(size.x - 23, 66), windowFramePaint);
    canvas.drawLine(Offset(size.x - 32, 57), Offset(size.x - 14, 57), windowFramePaint);
    
    // Sign above door
    final signPaint = Paint()..color = const Color(0xFF8D6E63);
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 20, 36, 40, 14),
      signPaint,
    );
    final signBorderPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 20, 36, 40, 14),
      signBorderPaint,
    );
    
    // "SHOP" text on sign (simplified as dots for pixel art feel)
    final textPaint = Paint()..color = const Color(0xFFFFFFFF);
    // S
    canvas.drawRect(Rect.fromLTWH(size.x / 2 - 14, 40, 2, 6), textPaint);
    // H
    canvas.drawRect(Rect.fromLTWH(size.x / 2 - 8, 40, 2, 6), textPaint);
    // O
    canvas.drawRect(Rect.fromLTWH(size.x / 2 - 2, 40, 2, 6), textPaint);
    // P
    canvas.drawRect(Rect.fromLTWH(size.x / 2 + 4, 40, 2, 6), textPaint);
  }

  void _drawInteractionIndicator(Canvas canvas) {
    // Draw a floating indicator above the shop
    final indicatorY = -10.0 + sin(game.currentTime() * 3) * 4;
    
    // Background circle
    final bgPaint = Paint()..color = const Color(0xDD000000);
    canvas.drawCircle(
      Offset(size.x / 2, indicatorY),
      14,
      bgPaint,
    );
    
    // "E" or tap icon
    final iconPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Draw a simple hand/tap icon
    // Finger pointing down
    canvas.drawLine(
      Offset(size.x / 2, indicatorY - 6),
      Offset(size.x / 2, indicatorY + 6),
      iconPaint,
    );
    canvas.drawLine(
      Offset(size.x / 2 - 4, indicatorY + 2),
      Offset(size.x / 2, indicatorY + 6),
      iconPaint,
    );
    canvas.drawLine(
      Offset(size.x / 2 + 4, indicatorY + 2),
      Offset(size.x / 2, indicatorY + 6),
      iconPaint,
    );
  }
  
  /// Check if a point is within interaction range
  bool isPointNearby(double x, double y) {
    final dx = x - position.x;
    final dy = y - position.y;
    return sqrt(dx * dx + dy * dy) < interactionRadius;
  }
}

