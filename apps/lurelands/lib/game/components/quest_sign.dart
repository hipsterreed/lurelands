import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../lurelands_game.dart';

/// Quest indicator state for the sign
enum QuestIndicatorState {
  none,       // No quests available
  available,  // New quest(s) available - yellow !
  completable, // Quest ready to turn in - green ?
}

/// A quest sign component that players can interact with to view/accept quests
class QuestSign extends PositionComponent with HasGameReference<LurelandsGame>, CollisionCallbacks {
  /// Unique identifier for this sign
  final String id;
  
  /// Display name of the sign
  final String name;
  
  /// Which storyline(s) this sign offers quests for
  /// If null, shows all quests. Otherwise only shows quests matching these storylines.
  final List<String>? storylines;
  
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
  
  // Quest indicator state (updated by game based on quest data)
  // Default to none - will be updated when quest data is available
  QuestIndicatorState _indicatorState = QuestIndicatorState.none;
  
  /// Update the indicator state (called by game when quest data changes)
  void setIndicatorState(QuestIndicatorState state) {
    _indicatorState = state;
  }
  
  // Hitbox for collision detection
  late RectangleHitbox _hitbox;
  
  // Sign sprite
  late Sprite _signSprite;
  
  // Scale factor for the sprite
  static const double _spriteScale = 3.0;
  
  // Getters for collision checking
  Vector2 get hitboxWorldPosition => _hitbox.absoluteCenter;
  Vector2 get hitboxSize => _hitbox.size;

  QuestSign({
    required Vector2 position,
    required this.id,
    this.name = 'Quest Board',
    this.storylines,
  }) : super(
         position: position,
         anchor: Anchor.bottomCenter,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Load the sign sprite
    _signSprite = await game.loadSprite('structures/sign.png');
    
    // Set size based on sprite dimensions scaled up
    final spriteWidth = _signSprite.srcSize.x * _spriteScale;
    final spriteHeight = _signSprite.srcSize.y * _spriteScale;
    size = Vector2(spriteWidth, spriteHeight);
    
    // Add rectangular hitbox at the base
    final hitboxWidth = size.x * 0.6;
    final hitboxHeight = size.y * 0.25;
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

    // Draw sign sprite
    _signSprite.render(
      canvas,
      size: size,
    );
    
    // Only draw quest indicator if there's something to show (WoW style)
    if (_indicatorState != QuestIndicatorState.none) {
      _drawQuestIndicator(canvas);
      
      // Draw interaction hint when player is nearby and there's a quest
      if (_playerNearby) {
        _drawInteractionHint(canvas);
      }
    }
  }

  void _drawQuestIndicator(Canvas canvas) {
    // Floating indicator above the sign - WoW style !/?
    final bobAmount = sin(game.currentTime() * 3) * 3;
    final indicatorY = -20.0 + bobAmount;
    
    // Colors based on state
    final Color indicatorColor;
    final String symbol;
    
    if (_indicatorState == QuestIndicatorState.completable) {
      indicatorColor = const Color(0xFF4CAF50); // Green for turn-in
      symbol = '?';
    } else {
      indicatorColor = const Color(0xFFFFD700); // Yellow/gold for new quest
      symbol = '!';
    }
    
    // Glow effect
    final glowPaint = Paint()
      ..color = indicatorColor.withAlpha(60)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      Offset(size.x / 2, indicatorY),
      16,
      glowPaint,
    );
    
    // Background circle
    final bgPaint = Paint()..color = const Color(0xDD000000);
    canvas.drawCircle(
      Offset(size.x / 2, indicatorY),
      14,
      bgPaint,
    );
    
    // Border
    final borderPaint = Paint()
      ..color = indicatorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(size.x / 2, indicatorY),
      14,
      borderPaint,
    );
    
    // Draw the symbol (! or ?)
    final textPainter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color: indicatorColor,
          fontSize: 18,
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
        indicatorY - textPainter.height / 2,
      ),
    );
  }

  void _drawInteractionHint(Canvas canvas) {
    // Small "Press to interact" hint below the main indicator
    final hintY = -45.0 + sin(game.currentTime() * 2) * 2;
    
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'TAP',
        style: TextStyle(
          color: Color(0xAAFFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Background pill
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x / 2, hintY),
        width: textPainter.width + 12,
        height: textPainter.height + 6,
      ),
      const Radius.circular(8),
    );
    final bgPaint = Paint()..color = const Color(0xAA000000);
    canvas.drawRRect(bgRect, bgPaint);
    
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        hintY - textPainter.height / 2,
      ),
    );
  }
  
  /// Check if a point is within interaction range
  bool isPointNearby(double x, double y) {
    final dx = x - position.x;
    final dy = y - position.y;
    return sqrt(dx * dx + dy * dy) < interactionRadius;
  }
}

