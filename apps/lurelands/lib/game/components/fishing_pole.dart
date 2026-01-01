import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../utils/constants.dart';
import 'player.dart';

/// Fishing pole component attached to the player
class FishingPole extends PositionComponent with ParentIsA<Player>, HasGameReference {
  FishingPole()
      : super(
          priority: GameLayers.fishingPole.toInt(),
        );

  // Pole sprite dimensions
  static const double poleWidth = 48.0;
  static const double poleHeight = 48.0;

  // Cached sprites for each tier (normal and casted)
  final Map<int, Sprite> _normalSprites = {};
  final Map<int, Sprite> _castedSprites = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Pre-load all pole sprites
    await _loadAllSprites();
  }

  Future<void> _loadAllSprites() async {
    for (int tier = 1; tier <= 4; tier++) {
      final poleAsset = ItemAssets.getFishingPole(tier);
      
      // Load normal sprite (strip path prefix for Flame's image loader)
      final normalPath = poleAsset.normal.replaceFirst('assets/', '');
      final normalImage = await game.images.load(normalPath);
      _normalSprites[tier] = Sprite(normalImage);
      
      // Load casted sprite
      final castedPath = poleAsset.casted.replaceFirst('assets/', '');
      final castedImage = await game.images.load(castedPath);
      _castedSprites[tier] = Sprite(castedImage);
    }
  }

  Sprite? get _currentSprite {
    final tier = parent.equippedPoleTier;
    if (parent.isCasting) {
      return _castedSprites[tier];
    }
    return _normalSprites[tier];
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
      canvas.rotate(angle + pi / 4);
      
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
