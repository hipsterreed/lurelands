import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../utils/constants.dart';
import 'player.dart';

/// Fishing pole component attached to the player
class FishingPole extends PositionComponent with ParentIsA<Player> {
  FishingPole()
      : super(
          priority: GameLayers.fishingPole.toInt(),
        );

  // Pole dimensions
  static const double poleLength = 24.0;
  static const double poleWidth = 3.0;

  @override
  void render(Canvas canvas) {
    final player = parent;
    final angle = player.facingAngle;

    // Calculate pole start (at edge of player, from center)
    final startX = cos(angle) * (GameConstants.playerSize / 2);
    final startY = sin(angle) * (GameConstants.playerSize / 2);

    // Calculate pole end
    final endX = startX + cos(angle) * poleLength;
    final endY = startY + sin(angle) * poleLength;

    // Draw pole
    final polePaint = Paint()
      ..color = GameColors.fishingPole
      ..strokeWidth = poleWidth
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), polePaint);

    // Draw pole tip (slightly lighter)
    final tipPaint = Paint()
      ..color = const Color(0xFF8B6914)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final tipStartX = endX - cos(angle) * 4;
    final tipStartY = endY - sin(angle) * 4;
    canvas.drawLine(Offset(tipStartX, tipStartY), Offset(endX, endY), tipPaint);

    // Draw line hanging from tip when not casting
    if (!player.isCasting) {
      _drawHangingLine(canvas, endX, endY);
    }
  }

  void _drawHangingLine(Canvas canvas, double tipX, double tipY) {
    final linePaint = Paint()
      ..color = GameColors.fishingLine
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw a small hanging line with curve
    final hangLength = 8.0;
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
