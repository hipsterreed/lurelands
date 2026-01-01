import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../lurelands_game.dart';

/// Tree type enum
enum TreeType { round, pine }

/// A decorative tree component
class Tree extends SpriteComponent with HasGameReference<LurelandsGame>, CollisionCallbacks {
  final TreeType type;
  final int variant; // 0-3 for which tree in the strip

  Tree({required Vector2 position, required this.type, required this.variant}) : super(position: position, anchor: Anchor.bottomCenter);

  // Shake animation state
  double _shakeTime = 0;
  bool _isShaking = false;
  static const double _shakeProximity = 35.0;
  static const double _shakeDuration = 0.5;
  static const double _shakeIntensity = 0.04; // radians (subtle for trees)

  // Track player movement to re-trigger shake
  Vector2? _lastPlayerPos;
  bool _playerWasInside = false;

  // Hitbox reference for debug mode
  late CircleHitbox _hitbox;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    if (type == TreeType.round) {
      // tree_01_strip4.png: 128x34, 4 trees, each 32x34
      final sheet = SpriteSheet(image: await game.images.load('plants/tree_01_strip4.png'), srcSize: Vector2(32, 34));
      sprite = sheet.getSprite(0, variant);
      size = Vector2(32 * 3, 34 * 3); // 3x scale
    } else {
      // tree_02_strip4.png: 112x43, 4 trees, each 28x43
      final sheet = SpriteSheet(image: await game.images.load('plants/tree_02_strip4.png'), srcSize: Vector2(28, 43));
      sprite = sheet.getSprite(0, variant);
      size = Vector2(28 * 3, 43 * 3); // 3x scale
    }

    // Add circular hitbox at the base of the tree (trunk area)
    final hitboxRadius = size.x * 0.05;
    _hitbox = CircleHitbox(radius: hitboxRadius, position: Vector2(size.x / 2, size.y - hitboxRadius - 25), anchor: Anchor.center);
    await add(_hitbox);

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
      final dy = (player.position.y + 20) - position.y;
      final distance = sqrt(dx * dx + dy * dy);
      final isInside = distance < _shakeProximity;

      // Check if player is moving
      final isMoving = _lastPlayerPos != null && (player.position - _lastPlayerPos!).length > 0.5;

      // Trigger shake when entering or moving inside
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

  /// Factory to create a random tree
  static Tree random(Vector2 position, Random rng) {
    final type = rng.nextBool() ? TreeType.round : TreeType.pine;
    final variant = rng.nextInt(4);
    return Tree(position: position, type: type, variant: variant);
  }
}
