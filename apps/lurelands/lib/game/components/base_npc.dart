import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../lurelands_game.dart';

/// Quest indicator state for NPCs - WoW style
enum NpcQuestIndicator {
  none,        // No quests for this NPC
  available,   // New quest available - yellow !
  completable, // Quest ready to turn in - yellow ?
  inProgress,  // Quest active but not complete - gray ?
}

/// Base class for all NPC characters in the game
abstract class BaseNpc extends PositionComponent
    with HasGameReference<LurelandsGame>, CollisionCallbacks {
  /// Unique identifier for this NPC
  final String id;

  /// Display name of the NPC
  final String name;

  /// Optional title (e.g., "Lumberjack", "Bartender")
  final String? title;

  /// Interaction radius - how close player needs to be to interact
  static const double interactionRadius = 60.0;

  /// Track player proximity
  bool _playerNearby = false;
  bool get isPlayerNearby => _playerNearby;

  /// Base position for reference (some NPCs bob, some don't)
  late Vector2 basePosition;

  /// Quest indicator state (updated by game based on quest data)
  NpcQuestIndicator _questIndicator = NpcQuestIndicator.none;

  /// Update the quest indicator state (called by game when quest data changes)
  void setQuestIndicator(NpcQuestIndicator indicator) {
    _questIndicator = indicator;
  }

  /// Get current quest indicator state
  NpcQuestIndicator get questIndicator => _questIndicator;

  BaseNpc({
    required Vector2 position,
    required this.id,
    required this.name,
    this.title,
  }) : super(
          position: position,
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    basePosition = position.clone();
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
      _playerNearby = distance < interactionRadius;
    }

    // Update priority based on Y position for depth sorting
    priority = position.y.toInt();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw quest indicator if NPC has quest-related state
    if (_questIndicator != NpcQuestIndicator.none) {
      _drawQuestIndicator(canvas);
    }
  }

  /// Draw the quest indicator (! or ?) above the NPC's head
  void _drawQuestIndicator(Canvas canvas) {
    // Floating indicator above the NPC - WoW style !/?
    final bobAmount = sin(game.currentTime() * 3) * 3;
    final indicatorY = -size.y - 10.0 + bobAmount;

    // Colors and symbol based on state
    final Color indicatorColor;
    final String symbol;

    switch (_questIndicator) {
      case NpcQuestIndicator.available:
        indicatorColor = const Color(0xFFFFD700); // Yellow for new quest
        symbol = '!';
        break;
      case NpcQuestIndicator.completable:
        indicatorColor = const Color(0xFFFFD700); // Yellow for turn-in ready
        symbol = '?';
        break;
      case NpcQuestIndicator.inProgress:
        indicatorColor = const Color(0xFF888888); // Gray for in-progress
        symbol = '?';
        break;
      case NpcQuestIndicator.none:
        return; // Don't draw anything
    }

    final centerX = size.x / 2;

    // Glow effect
    final glowPaint = Paint()
      ..color = indicatorColor.withAlpha(60)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      Offset(centerX, indicatorY),
      16,
      glowPaint,
    );

    // Background circle
    final bgPaint = Paint()..color = const Color(0xDD000000);
    canvas.drawCircle(
      Offset(centerX, indicatorY),
      14,
      bgPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = indicatorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(centerX, indicatorY),
      14,
      borderPaint,
    );

    // Draw the symbol (! or ?)
    final textPainter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color: indicatorColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        indicatorY - textPainter.height / 2,
      ),
    );
  }

  void _drawNameplate(Canvas canvas) {
    final nameY = -10.0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(1, 1),
              blurRadius: 2,
              color: Color(0xFF000000),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Background for name
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x / 2, nameY),
        width: textPainter.width + 10,
        height: textPainter.height + 4,
      ),
      const Radius.circular(4),
    );
    final bgPaint = Paint()..color = const Color(0x99000000);
    canvas.drawRRect(bgRect, bgPaint);

    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        nameY - textPainter.height / 2,
      ),
    );

    // Draw title if present
    if (title != null) {
      final titlePainter = TextPainter(
        text: TextSpan(
          text: title,
          style: TextStyle(
            color: const Color(0xFFFFD700).withAlpha(200),
            fontSize: 9,
            fontStyle: FontStyle.italic,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      titlePainter.layout();
      titlePainter.paint(
        canvas,
        Offset(
          (size.x - titlePainter.width) / 2,
          nameY + textPainter.height / 2 + 2,
        ),
      );
    }
  }

  /// Check if a point is within interaction range
  bool isPointNearby(double x, double y) {
    final dx = x - position.x;
    final dy = y - position.y;
    return sqrt(dx * dx + dy * dy) < interactionRadius;
  }
}
