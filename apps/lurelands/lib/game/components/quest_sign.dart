import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../lurelands_game.dart';

/// A quest sign component that players can interact with to view/accept quests
class QuestSign extends PositionComponent with HasGameReference<LurelandsGame>, CollisionCallbacks {
  /// Unique identifier for this sign
  final String id;
  
  /// Display name of the sign
  final String name;
  
  /// Interaction radius - how close player needs to be to interact
  static const double interactionRadius = 60.0;
  
  // Shake animation state (when player is near)
  double _shakeTime = 0;
  bool _isShaking = false;
  static const double _shakeDuration = 0.3;
  static const double _shakeIntensity = 0.02;
  
  // Track player proximity
  bool _playerNearby = false;
  bool get isPlayerNearby => _playerNearby;
  
  // Hitbox for collision detection
  late RectangleHitbox _hitbox;
  
  // Getters for collision checking
  Vector2 get hitboxWorldPosition => _hitbox.absoluteCenter;
  Vector2 get hitboxSize => _hitbox.size;

  QuestSign({
    required Vector2 position,
    required this.id,
    this.name = 'Quest Board',
  }) : super(
         position: position,
         anchor: Anchor.bottomCenter,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Set size for the sign (wooden post style) - larger for visibility
    size = Vector2(48, 80);
    
    // Add rectangular hitbox at the base
    final hitboxWidth = size.x * 0.8;
    final hitboxHeight = size.y * 0.3;
    _hitbox = RectangleHitbox(
      size: Vector2(hitboxWidth, hitboxHeight),
      position: Vector2((size.x - hitboxWidth) / 2, size.y - hitboxHeight - 4),
    );
    await add(_hitbox);
    
    // Set priority high enough to be visible above ground but below player at same Y
    priority = position.y.toInt() + 100;
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

    // Draw sign post
    _drawSignPost(canvas);
    
    // Draw interaction indicator when player is nearby
    if (_playerNearby) {
      _drawInteractionIndicator(canvas);
    }
  }

  void _drawSignPost(Canvas canvas) {
    // Wooden post
    final postPaint = Paint()..color = const Color(0xFF8B4513);
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 5, size.y - 50, 10, 50),
      postPaint,
    );
    
    // Sign board background
    final boardPaint = Paint()..color = const Color(0xFFA0724B);
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y * 0.55),
      const Radius.circular(6),
    );
    canvas.drawRRect(boardRect, boardPaint);
    
    // Sign board border
    final borderPaint = Paint()
      ..color = const Color(0xFF5D3A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(boardRect, borderPaint);
    
    // Question mark icon on sign
    final textPainter = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          color: const Color(0xFFFFD700),
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        (size.y * 0.55 - textPainter.height) / 2,
      ),
    );
  }

  void _drawInteractionIndicator(Canvas canvas) {
    // Draw a floating indicator above the sign
    final indicatorY = -16.0 + sin(game.currentTime() * 3) * 4;
    
    // Background circle
    final bgPaint = Paint()..color = const Color(0xDD000000);
    canvas.drawCircle(
      Offset(size.x / 2, indicatorY),
      12,
      bgPaint,
    );
    
    // Exclamation icon
    final iconPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;
    
    // Draw exclamation mark
    canvas.drawCircle(
      Offset(size.x / 2, indicatorY + 4),
      2,
      iconPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.x / 2, indicatorY - 2),
        width: 3,
        height: 8,
      ),
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

