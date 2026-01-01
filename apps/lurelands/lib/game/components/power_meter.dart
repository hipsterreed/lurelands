import 'dart:ui';

import 'package:flame/components.dart';

import '../../utils/constants.dart';
import '../lurelands_game.dart';

/// Power meter component that displays next to the player when charging a cast
class PowerMeter extends PositionComponent with HasGameReference<LurelandsGame> {
  PowerMeter()
      : super(
          size: Vector2(10, 70), // Taller meter
          anchor: Anchor.bottomCenter,
        );

  // Meter styling
  static const double borderWidth = 1.5;
  static const double cornerRadius = 4.0;
  static const int sectionCount = 6; // More sections for finer control

  double _displayPower = 0.0;
  double _targetPower = 0.0;

  @override
  void update(double dt) {
    super.update(dt);

    // Get current power from game
    _targetPower = game.castPowerNotifier.value;

    // Smooth animation towards target
    if (_displayPower < _targetPower) {
      _displayPower += dt * 4; // Fast follow
      if (_displayPower > _targetPower) _displayPower = _targetPower;
    } else if (_displayPower > _targetPower) {
      _displayPower -= dt * 8; // Fast reset
      if (_displayPower < 0) _displayPower = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    // Only show when there's power to display
    if (_displayPower <= 0.01) return;

    final meterHeight = size.y;
    final meterWidth = size.x;

    // Background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-meterWidth / 2, -meterHeight, meterWidth, meterHeight),
      const Radius.circular(cornerRadius),
    );

    final bgPaint = Paint()
      ..color = GameColors.menuBackground.withAlpha(200);
    canvas.drawRRect(bgRect, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = GameColors.pondBlue.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(bgRect, borderPaint);

    // Fill based on power
    final fillHeight = (meterHeight - 4) * _displayPower;
    if (fillHeight > 0) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -meterWidth / 2 + 2,
          -2 - fillHeight,
          meterWidth - 4,
          fillHeight,
        ),
        const Radius.circular(cornerRadius - 1),
      );

      // Gradient effect based on power level
      final fillColor = _displayPower > 0.7
          ? const Color(0xFF00E5FF) // Bright cyan at high power
          : GameColors.pondBlueLight;

      final fillPaint = Paint()..color = fillColor;
      canvas.drawRRect(fillRect, fillPaint);

      // Glow at high power
      if (_displayPower > 0.5) {
        final glowPaint = Paint()
          ..color = fillColor.withAlpha((80 * _displayPower).toInt())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawRRect(fillRect, glowPaint);
      }
    }

    // Level markers (show section dividers)
    final markerPaint = Paint()
      ..color = GameColors.textSecondary.withAlpha(120)
      ..strokeWidth = 1;

    for (var i = 1; i < sectionCount; i++) {
      final y = -meterHeight * (i / sectionCount);
      canvas.drawLine(
        Offset(-meterWidth / 2 + 2, y),
        Offset(meterWidth / 2 - 2, y),
        markerPaint,
      );
    }

    // Draw percentage markers on side (at 50% and 100%)
    final labelPaint = Paint()
      ..color = GameColors.textSecondary.withAlpha(150)
      ..strokeWidth = 2;
    
    // 50% mark (thicker line)
    final halfY = -meterHeight * 0.5;
    canvas.drawLine(
      Offset(-meterWidth / 2 - 2, halfY),
      Offset(-meterWidth / 2 + 3, halfY),
      labelPaint,
    );
    
    // 100% mark (thicker line at top)
    final topY = -meterHeight + 2;
    canvas.drawLine(
      Offset(-meterWidth / 2 - 2, topY),
      Offset(-meterWidth / 2 + 3, topY),
      labelPaint,
    );
  }
}

