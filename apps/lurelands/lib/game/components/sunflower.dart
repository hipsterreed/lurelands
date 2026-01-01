import 'dart:math';

import 'package:flame/components.dart';

import '../lurelands_game.dart';

/// A decorative sunflower component
class Sunflower extends SpriteComponent with HasGameReference<LurelandsGame> {
  Sunflower({required Vector2 position})
    : super(
        position: position,
        anchor: Anchor.bottomCenter,
      );

  // Shake animation state
  double _shakeTime = 0;
  bool _isShaking = false;
  static const double _shakeProximity = 25.0; // Smaller hitbox
  static const double _shakeDuration = 0.4;
  static const double _shakeIntensity = 0.06; // radians
  
  // Track player movement to re-trigger shake
  Vector2? _lastPlayerPos;
  bool _playerWasInside = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    sprite = await game.loadSprite('plants/sunflower.png');
    
    // Scale up the sprite (2x)
    size = Vector2(sprite!.srcSize.x * 2, sprite!.srcSize.y * 2);
    
    // Set initial priority based on Y position
    priority = position.y.toInt();
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Check if player is nearby
    final player = game.player;
    if (player != null) {
      final dx = player.position.x - position.x;
      final dy = (player.position.y + 20) - position.y; // Use player's feet position
      final distance = sqrt(dx * dx + dy * dy);
      final isInside = distance < _shakeProximity;
      
      // Check if player is moving
      final isMoving = _lastPlayerPos != null && 
          (player.position - _lastPlayerPos!).length > 0.5;
      
      // Trigger shake when:
      // 1. Player just entered the zone, OR
      // 2. Player is inside and moving (and not already shaking)
      if (isInside && !_isShaking) {
        if (!_playerWasInside || isMoving) {
          _isShaking = true;
          _shakeTime = 0;
        }
      }
      
      _playerWasInside = isInside;
      _lastPlayerPos = player.position.clone();
    }
    
    // Animate shake
    if (_isShaking) {
      _shakeTime += dt;
      
      if (_shakeTime < _shakeDuration) {
        // Damped oscillation for natural shake
        final progress = _shakeTime / _shakeDuration;
        final damping = 1.0 - progress; // Fade out
        final oscillation = sin(_shakeTime * 25); // Fast wiggle
        angle = oscillation * _shakeIntensity * damping;
      } else {
        // Reset when done
        angle = 0;
        _isShaking = false;
      }
    }
  }
}

