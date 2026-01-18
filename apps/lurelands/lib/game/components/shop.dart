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

  /// Collision rectangles from Tiled (in local coordinates, already scaled)
  final List<Rect>? collisionRects;

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

  // Track if player is behind building (for transparency)
  bool _playerBehind = false;
  static const double _transparentOpacity = 0.4;

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
    this.collisionRects,
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

    // Add collision hitboxes - use Tiled collision data if available
    if (collisionRects != null && collisionRects!.isNotEmpty) {
      // Use collision rectangles from Tiled map
      // These are in local coordinates relative to the sprite's top-left
      // But our anchor is bottomCenter, so we need to adjust
      for (final rect in collisionRects!) {
        final hitbox = RectangleHitbox(
          size: Vector2(rect.width, rect.height),
          // Adjust position: rect is relative to top-left, we're anchored at bottom-center
          position: Vector2(rect.left, rect.top),
        );
        _hitbox ??= hitbox; // Store first hitbox for collision checking
        await add(hitbox);
      }
    } else {
      // Fallback: create default hitbox at the base of the building
      final hitboxWidth = size.x * 0.8;
      final hitboxHeight = size.y * 0.35;
      final hitboxOffsetY = size.y * 0.1;
      final hitbox = RectangleHitbox(
        size: Vector2(hitboxWidth, hitboxHeight),
        position: Vector2((size.x - hitboxWidth) / 2, size.y - hitboxHeight - hitboxOffsetY),
      );
      _hitbox = hitbox;
      await add(hitbox);
    }

    // Set priority based on Y position for depth sorting
    priority = position.y.toInt();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Check if player is nearby and/or behind the building
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

      // Check if player is behind the building (player Y is above building base, X overlaps)
      // Building anchor is bottomCenter, so position.y is the bottom of the building
      final buildingTop = position.y - size.y;
      final buildingLeft = position.x - size.x / 2;
      final buildingRight = position.x + size.x / 2;

      // Player is "behind" if their Y is less than building bottom (higher on screen)
      // and their X overlaps with building width
      _playerBehind = player.position.y < position.y &&
          player.position.y > buildingTop - 40 && // Give some buffer
          player.position.x > buildingLeft - 20 &&
          player.position.x < buildingRight + 20;
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
      if (_playerBehind) {
        // Draw semi-transparent when player is behind
        final paint = Paint()
          ..color = Color.fromRGBO(255, 255, 255, _transparentOpacity);
        _shopSprite!.render(
          canvas,
          size: size,
          overridePaint: paint,
        );
      } else {
        _shopSprite!.render(
          canvas,
          size: size,
        );
      }
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

