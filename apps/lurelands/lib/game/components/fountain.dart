import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../lurelands_game.dart';

/// Animated fountain component rendered from Tiled map Props layer
class Fountain extends PositionComponent with HasGameReference<LurelandsGame> {
  /// Animation frame rate (seconds per frame)
  static const double _frameTime = 0.15;

  /// Sprite animation component
  late SpriteAnimationComponent _animationComponent;

  Fountain({
    required Vector2 position,
    required Vector2 size,
  }) : super(
          position: position,
          size: size,
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load the fountain spritesheet
    final image = await game.images.load('structures/Fountain_Anim.png');

    // Create sprite animation from spritesheet
    // 8 frames, each 32x48, arranged horizontally
    final spriteSheet = SpriteSheet(
      image: image,
      srcSize: Vector2(32, 48),
    );

    final animation = spriteSheet.createAnimation(
      row: 0,
      stepTime: _frameTime,
      from: 0,
      to: 8,
    );

    _animationComponent = SpriteAnimationComponent(
      animation: animation,
      size: size,
    );

    await add(_animationComponent);

    // Set priority based on Y position for depth sorting
    priority = position.y.toInt();
  }
}
