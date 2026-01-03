import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../utils/constants.dart';

/// A text label that displays the player name above the character.
class PlayerNameLabel extends PositionComponent {
  final String playerName;

  PlayerNameLabel({
    required this.playerName,
    required Vector2 position,
  }) : super(
          position: position,
          anchor: Anchor.bottomCenter,
        );

  late TextPaint _textPaint;
  late TextPaint _shadowPaint;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Main text paint
    _textPaint = TextPaint(
      style: const TextStyle(
        fontSize: 7,
        fontWeight: FontWeight.w600,
        color: GameColors.textPrimary,
        letterSpacing: 0.25,
      ),
    );

    // Shadow paint for better visibility
    _shadowPaint = TextPaint(
      style: TextStyle(
        fontSize: 7,
        fontWeight: FontWeight.w600,
        color: GameColors.menuBackground.withAlpha(180),
        letterSpacing: 0.25,
      ),
    );

    // Set size based on text
    final metrics = _textPaint.getLineMetrics(playerName);
    size = Vector2(metrics.width + 8, metrics.height + 4);
  }

  @override
  void render(ui.Canvas canvas) {
    // Draw background pill
    final bgRect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(-size.x / 2, -size.y, size.x, size.y),
      const ui.Radius.circular(5),
    );

    final bgPaint = ui.Paint()
      ..color = GameColors.menuBackground.withAlpha(160);
    canvas.drawRRect(bgRect, bgPaint);

    // Draw border
    final borderPaint = ui.Paint()
      ..color = GameColors.pondBlue.withAlpha(100)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 0.75;
    canvas.drawRRect(bgRect, borderPaint);

    // Draw text shadow (offset)
    _shadowPaint.render(
      canvas,
      playerName,
      Vector2(-size.x / 2 + 4 + 0.5, -size.y + 2 + 0.5),
    );

    // Draw text
    _textPaint.render(
      canvas,
      playerName,
      Vector2(-size.x / 2 + 4, -size.y + 2),
    );
  }
}

