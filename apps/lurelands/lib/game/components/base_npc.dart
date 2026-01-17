import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../lurelands_game.dart';

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
