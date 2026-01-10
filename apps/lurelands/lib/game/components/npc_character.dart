import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../lurelands_game.dart';

/// Quest indicator state for NPCs (same as QuestSign)
enum NpcIndicatorState {
  none,        // No quests available
  available,   // New quest(s) available - yellow !
  completable, // Quest ready to turn in - green ?
  inProgress,  // Quest active but not complete - grayed out !
}

/// An NPC character component that players can interact with
class NpcCharacter extends PositionComponent with HasGameReference<LurelandsGame>, CollisionCallbacks {
  /// Unique identifier for this NPC (matches database ID)
  final String id;

  /// Display name of the NPC
  final String name;

  /// Optional title (e.g., "Guild Master")
  final String? title;

  /// Whether this NPC can give quests
  final bool canGiveQuests;

  /// Whether this NPC can trade
  final bool canTrade;

  /// Sprite ID for custom sprites (future use)
  final String? spriteId;

  /// Interaction radius - how close player needs to be to interact
  static const double interactionRadius = 60.0;

  // Idle animation state (subtle bobbing)
  double _idleTime = 0;
  static const double _idleBobSpeed = 2.0;
  static const double _idleBobAmount = 2.0;

  // Track player proximity
  bool _playerNearby = false;
  bool get isPlayerNearby => _playerNearby;

  // Quest indicator state
  NpcIndicatorState _indicatorState = NpcIndicatorState.none;

  /// Update the indicator state
  void setIndicatorState(NpcIndicatorState state) {
    _indicatorState = state;
  }

  // Hitbox for collision detection
  late RectangleHitbox _hitbox;

  // NPC sprite
  late Sprite _npcSprite;

  // Scale factor for the sprite
  static const double _spriteScale = 2.5;

  // Base position for bobbing animation
  late Vector2 _basePosition;

  NpcCharacter({
    required Vector2 position,
    required this.id,
    required this.name,
    this.title,
    this.canGiveQuests = true,
    this.canTrade = false,
    this.spriteId,
  }) : super(
         position: position,
         anchor: Anchor.bottomCenter,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Store base position for animation
    _basePosition = position.clone();

    // Load the NPC sprite (use a generic villager sprite for now)
    // In the future, this could be based on spriteId
    _npcSprite = await game.loadSprite('characters/npc_villager.png');

    // Set size based on sprite dimensions scaled up
    final spriteWidth = _npcSprite.srcSize.x * _spriteScale;
    final spriteHeight = _npcSprite.srcSize.y * _spriteScale;
    size = Vector2(spriteWidth, spriteHeight);

    // Add rectangular hitbox at the base
    final hitboxWidth = size.x * 0.5;
    final hitboxHeight = size.y * 0.2;
    _hitbox = RectangleHitbox(
      size: Vector2(hitboxWidth, hitboxHeight),
      position: Vector2((size.x - hitboxWidth) / 2, size.y - hitboxHeight - 4),
    );
    await add(_hitbox);

    // Set priority based on Y position
    priority = position.y.toInt() + 100;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Idle bobbing animation
    _idleTime += dt;
    final bobOffset = sin(_idleTime * _idleBobSpeed) * _idleBobAmount;
    position.y = _basePosition.y + bobOffset;

    // Check if player is nearby
    final player = game.player;
    if (player != null) {
      final dx = player.position.x - _basePosition.x;
      final dy = player.position.y - _basePosition.y;
      final distance = sqrt(dx * dx + dy * dy);
      _playerNearby = distance < interactionRadius;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw NPC sprite
    _npcSprite.render(
      canvas,
      size: size,
    );

    // Draw name above NPC
    _drawNameplate(canvas);

    // Draw quest indicator if there's something to show
    if (_indicatorState != NpcIndicatorState.none) {
      _drawQuestIndicator(canvas);
    }

    // Draw interaction hint when player is nearby
    if (_playerNearby) {
      _drawInteractionHint(canvas);
    }
  }

  void _drawNameplate(Canvas canvas) {
    // Draw NPC name above the character
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

  void _drawQuestIndicator(Canvas canvas) {
    // Floating indicator above the NPC - WoW style !/?
    final bobAmount = sin(game.currentTime() * 3) * 3;
    final indicatorY = -35.0 + bobAmount;

    // Colors based on state
    final Color indicatorColor;
    final String symbol;

    if (_indicatorState == NpcIndicatorState.completable) {
      indicatorColor = const Color(0xFF4CAF50); // Green for turn-in
      symbol = '?';
    } else if (_indicatorState == NpcIndicatorState.inProgress) {
      indicatorColor = const Color(0xFF888888); // Gray for in-progress
      symbol = '!';
    } else {
      indicatorColor = const Color(0xFFFFD700); // Yellow/gold for new quest
      symbol = '!';
    }

    // Glow effect
    final glowPaint = Paint()
      ..color = indicatorColor.withAlpha(60)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      Offset(size.x / 2, indicatorY),
      16,
      glowPaint,
    );

    // Background circle
    final bgPaint = Paint()..color = const Color(0xDD000000);
    canvas.drawCircle(
      Offset(size.x / 2, indicatorY),
      14,
      bgPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = indicatorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(size.x / 2, indicatorY),
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
        (size.x - textPainter.width) / 2,
        indicatorY - textPainter.height / 2,
      ),
    );
  }

  void _drawInteractionHint(Canvas canvas) {
    // Small "TAP to talk" hint below the quest indicator
    final hintY = -60.0 + sin(game.currentTime() * 2) * 2;

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'TAP',
        style: TextStyle(
          color: Color(0xAAFFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Background pill
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x / 2, hintY),
        width: textPainter.width + 12,
        height: textPainter.height + 6,
      ),
      const Radius.circular(8),
    );
    final bgPaint = Paint()..color = const Color(0xAA000000);
    canvas.drawRRect(bgRect, bgPaint);

    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        hintY - textPainter.height / 2,
      ),
    );
  }

  /// Check if a point is within interaction range
  bool isPointNearby(double x, double y) {
    final dx = x - _basePosition.x;
    final dy = y - _basePosition.y;
    return sqrt(dx * dx + dy * dy) < interactionRadius;
  }
}
