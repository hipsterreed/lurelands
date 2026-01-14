import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../lurelands_game.dart';

/// A shop building component that players can interact with
class Shop extends PositionComponent with HasGameReference<LurelandsGame>, CollisionCallbacks {
  /// Unique identifier for this shop
  final String id;

  /// Display name of the shop
  final String name;

  /// Pre-loaded sprite for the shop (from Tiled map)
  final Sprite? sprite;

  /// Size of the shop sprite
  final Vector2? spriteSize;

  /// Interaction radius - how close player needs to be to interact
  static const double interactionRadius = 80.0;

  // Shake animation state (when player is near)
  double _shakeTime = 0;
  bool _isShaking = false;
  static const double _shakeDuration = 0.3;
  static const double _shakeIntensity = 0.02;

  // Track player proximity
  bool _playerNearby = false;
  bool get isPlayerNearby => _playerNearby;

  // Shop building sprite
  Sprite? _shopSprite;

  // Hitbox for collision detection
  RectangleHitbox? _hitbox;

  // Getters for collision checking
  Vector2 get hitboxWorldPosition => _hitbox?.absoluteCenter ?? position;
  Vector2 get hitboxSize => _hitbox?.size ?? size;

  Shop({
    required Vector2 position,
    required this.id,
    this.name = 'Shop',
    this.sprite,
    this.spriteSize,
  }) : super(
         position: position,
         anchor: Anchor.bottomCenter,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Use pre-loaded sprite if provided
    _shopSprite = sprite;

    // Set size from provided spriteSize or use a default
    if (spriteSize != null) {
      size = spriteSize!;
    } else if (_shopSprite != null) {
      final srcSize = _shopSprite!.srcSize;
      size = Vector2(srcSize.x * 2, srcSize.y * 2);
    } else {
      // Default size if no sprite
      size = Vector2(100, 100);
    }

    // Add rectangular hitbox at the base of the building
    // Make it smaller than the full sprite to feel natural (just the base/foundation)
    final hitboxWidth = size.x * 0.8;
    final hitboxHeight = size.y * 0.35; // Just the bottom portion
    final hitboxOffsetY = size.y * 0.1; // Move hitbox up from the very bottom
    final hitbox = RectangleHitbox(
      size: Vector2(hitboxWidth, hitboxHeight),
      position: Vector2((size.x - hitboxWidth) / 2, size.y - hitboxHeight - hitboxOffsetY),
    );
    _hitbox = hitbox;
    await add(hitbox);

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
    if (_shopSprite != null) {
      _shopSprite!.render(
        canvas,
        size: size,
      );
    }
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

