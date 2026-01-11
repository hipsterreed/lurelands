import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../../utils/constants.dart';
import 'player.dart';

/// Fishing pole component attached to the player
class FishingPole extends PositionComponent with ParentIsA<Player>, HasGameReference {
  FishingPole()
      : super(
          priority: GameLayers.fishingPole.toInt(),
        );

  // Pole sprite dimensions (scaled up from 16x16)
  static const double poleWidth = 48.0;
  static const double poleHeight = 48.0;

  // Additional rotation when casting (tilted forward)
  static const double castRotationOffset = pi / 6; // 30 degrees

  // Cached sprites for each tier
  final Map<int, Sprite> _sprites = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Pre-load all pole sprites from spritesheet
    await _loadAllSprites();
  }

  Future<void> _loadAllSprites() async {
    // Load the spritesheet image
    final spritesheetPath = FishingPoleAsset.spritesheetPath.replaceFirst('assets/', '');
    final spritesheetImage = await game.images.load(spritesheetPath);

    // Create spritesheet with 16x16 sprite size
    final spritesheet = SpriteSheet(
      image: spritesheetImage,
      srcSize: Vector2(FishingPoleAsset.spriteSize, FishingPoleAsset.spriteSize),
    );

    // Load sprite for each tier
    for (int tier = 1; tier <= 4; tier++) {
      final poleAsset = ItemAssets.getFishingPole(tier);
      _sprites[tier] = spritesheet.getSprite(poleAsset.spriteRow, poleAsset.spriteColumn);
    }
  }

  Sprite? get _currentSprite {
    final tier = parent.equippedPoleTier;
    return _sprites[tier];
  }

  @override
  void render(Canvas canvas) {
    final player = parent;
    final angle = player.facingAngle;
    final sprite = _currentSprite;

    if (sprite != null) {
      // Position the pole at the edge of the player, rotated to face the direction
      final startX = cos(angle) * (GameConstants.playerSize / 2);
      final startY = sin(angle) * (GameConstants.playerSize / 2);

      canvas.save();

      // Move to pole position
      canvas.translate(startX, startY);

      // Rotate to face the direction (add PI/4 to account for sprite orientation)
      // Add extra rotation when casting to show the pole is extended
      final rotationAngle = player.isCasting
          ? angle + pi / 4 + castRotationOffset
          : angle + pi / 4;
      canvas.rotate(rotationAngle);

      // Draw the sprite centered
      sprite.render(
        canvas,
        position: Vector2(-poleWidth / 2, -poleHeight / 2),
        size: Vector2(poleWidth, poleHeight),
      );

      canvas.restore();
    } else {
      // Fallback: draw basic pole shape if sprites not loaded
      _renderFallbackPole(canvas, angle);
    }

    // Draw line hanging from tip when not casting
    if (!player.isCasting) {
      _drawHangingLine(canvas, angle);
    }
  }

  void _renderFallbackPole(Canvas canvas, double angle) {
    const poleLength = 24.0;
    const poleWidthStroke = 3.0;

    final startX = cos(angle) * (GameConstants.playerSize / 2);
    final startY = sin(angle) * (GameConstants.playerSize / 2);
    final endX = startX + cos(angle) * poleLength;
    final endY = startY + sin(angle) * poleLength;

    final polePaint = Paint()
      ..color = GameColors.fishingPole
      ..strokeWidth = poleWidthStroke
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), polePaint);

    final tipPaint = Paint()
      ..color = const Color(0xFF8B6914)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final tipStartX = endX - cos(angle) * 4;
    final tipStartY = endY - sin(angle) * 4;
    canvas.drawLine(Offset(tipStartX, tipStartY), Offset(endX, endY), tipPaint);
  }

  void _drawHangingLine(Canvas canvas, double angle) {
    final linePaint = Paint()
      ..color = GameColors.fishingLine
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Calculate pole tip position
    const poleLength = 24.0;
    final startX = cos(angle) * (GameConstants.playerSize / 2);
    final startY = sin(angle) * (GameConstants.playerSize / 2);
    final tipX = startX + cos(angle) * poleLength;
    final tipY = startY + sin(angle) * poleLength;

    // Draw a small hanging line with curve
    const hangLength = 8.0;
    canvas.drawLine(
      Offset(tipX, tipY),
      Offset(tipX + 2, tipY + hangLength),
      linePaint,
    );

    // Draw bobber at end
    final bobberPaint = Paint()..color = const Color(0xFFFF4444);
    canvas.drawCircle(Offset(tipX + 2, tipY + hangLength + 3), 3, bobberPaint);
  }
}
