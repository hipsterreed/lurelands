import 'package:flame/components.dart';

import '../lurelands_game.dart';

/// A decorative sunflower component
class Sunflower extends SpriteComponent with HasGameReference<LurelandsGame> {
  Sunflower({required Vector2 position})
    : super(
        position: position,
        anchor: Anchor.bottomCenter,
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    sprite = await game.loadSprite('plants/sunflower.png');
    
    // Scale up the sprite (2x)
    size = Vector2(sprite!.srcSize.x * 2, sprite!.srcSize.y * 2);
    
    // Set initial priority based on Y position
    priority = position.y.toInt();
  }
}

