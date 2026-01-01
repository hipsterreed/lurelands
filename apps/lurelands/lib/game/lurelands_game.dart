import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../models/pond_data.dart';
import '../utils/constants.dart';
import 'components/player.dart';
import 'components/pond.dart';
import 'components/sunflower.dart';

/// Main game class for Lurelands
class LurelandsGame extends FlameGame with HasCollisionDetection {
  Player? _player;
  final List<Pond> _pondComponents = [];

  // Public getter for player (used by other components)
  Player? get player => _player;

  // Movement direction from joystick (set by UI)
  Vector2 joystickDirection = Vector2.zero();

  // Notifiers for UI
  final ValueNotifier<bool> isLoadedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> canCastNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isCastingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> debugModeNotifier = ValueNotifier(false);

  // Static pond data for the world
  final List<PondData> ponds = [
    const PondData(id: 'pond_1', x: 400, y: 400, radius: 120),
    const PondData(id: 'pond_2', x: 1500, y: 300, radius: 100),
    const PondData(id: 'pond_3', x: 800, y: 1400, radius: 140),
    const PondData(id: 'pond_4', x: 1600, y: 1500, radius: 90),
  ];

  @override
  Color backgroundColor() => GameColors.grassGreen;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Add ground
    await world.add(Ground());

    // Add ponds
    for (final pondData in ponds) {
      final pond = Pond(data: pondData);
      _pondComponents.add(pond);
      await world.add(pond);
    }

    // Add random sunflowers around the map
    await _spawnSunflowers();

    // Create the player at world center
    _player = Player(position: Vector2(GameConstants.worldWidth / 2, GameConstants.worldHeight / 2));
    await world.add(_player!);

    // Set up camera to follow player
    camera.viewfinder.anchor = Anchor.center;
    camera.follow(_player!);

    // Mark game as loaded
    isLoadedNotifier.value = true;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final player = _player;
    if (player == null) return;

    // Handle player movement based on joystick input
    player.move(joystickDirection, dt);

    // Update casting state notifiers
    _updateCastingState(player);
  }

  void _updateCastingState(Player player) {
    // Update can cast
    final canCast = _isPlayerNearPond(player);
    if (canCastNotifier.value != canCast) {
      canCastNotifier.value = canCast;
    }

    // Update is casting
    if (isCastingNotifier.value != player.isCasting) {
      isCastingNotifier.value = player.isCasting;
    }
  }

  bool _isPlayerNearPond(Player player) {
    final playerPos = player.position;
    // Player hitbox is roughly 50x60, so use ~30px as player "radius"
    const playerHitboxRadius = 30.0;
    // Small buffer zone where casting is allowed (when hitboxes are close)
    const castingBuffer = 20.0;
    
    for (final pond in ponds) {
      final dx = playerPos.x - pond.x;
      final dy = playerPos.y - pond.y;
      final distance = sqrt(dx * dx + dy * dy);
      // Distance from player hitbox edge to pond hitbox edge
      final edgeDistance = distance - pond.radius - playerHitboxRadius;
      
      // Enable casting when hitbox edges are within the buffer zone
      if (edgeDistance <= castingBuffer && edgeDistance >= -playerHitboxRadius) {
        return true;
      }
    }
    return false;
  }

  /// Get the pond the player can cast into, if any
  PondData? getNearbyPond() {
    final player = _player;
    if (player == null) return null;

    final playerPos = player.position;
    const playerHitboxRadius = 30.0;
    const castingBuffer = 20.0;
    
    for (final pond in ponds) {
      final dx = playerPos.x - pond.x;
      final dy = playerPos.y - pond.y;
      final distance = sqrt(dx * dx + dy * dy);
      final edgeDistance = distance - pond.radius - playerHitboxRadius;
      
      if (edgeDistance <= castingBuffer && edgeDistance >= -playerHitboxRadius) {
        return pond;
      }
    }
    return null;
  }

  /// Called from UI when cast button is pressed
  void onCastPressed() {
    final player = _player;
    if (player == null) return;

    if (!player.isCasting && canCastNotifier.value) {
      final nearbyPond = getNearbyPond();
      if (nearbyPond != null) {
        player.startCasting(nearbyPond);
      }
    }
  }

  /// Called from UI when reel button is pressed
  void onReelPressed() {
    final player = _player;
    if (player == null) return;

    if (player.isCasting) {
      player.reelIn();
    }
  }

  /// Spawn sunflowers randomly around the map
  Future<void> _spawnSunflowers() async {
    final random = Random(123); // Seeded for consistent placement
    const count = 30;
    
    for (var i = 0; i < count; i++) {
      final x = 100 + random.nextDouble() * (GameConstants.worldWidth - 200);
      final y = 100 + random.nextDouble() * (GameConstants.worldHeight - 200);
      
      // Don't place sunflowers inside ponds
      bool insidePond = false;
      for (final pond in ponds) {
        if (pond.containsPoint(x, y)) {
          insidePond = true;
          break;
        }
      }
      
      if (!insidePond) {
        await world.add(Sunflower(position: Vector2(x, y)));
      }
    }
  }

  /// Toggle debug mode for player and ponds
  void toggleDebugMode() {
    debugModeNotifier.value = !debugModeNotifier.value;
    final enabled = debugModeNotifier.value;
    
    // Only set debug mode on hitboxes (not parent components) to avoid clutter
    if (_player != null) {
      for (final child in _player!.children) {
        if (child is ShapeHitbox) {
          child.debugMode = enabled;
        }
      }
    }
    
    for (final pond in _pondComponents) {
      for (final child in pond.children) {
        if (child is ShapeHitbox) {
          child.debugMode = enabled;
        }
      }
    }
  }

  @override
  void onRemove() {
    isLoadedNotifier.dispose();
    canCastNotifier.dispose();
    isCastingNotifier.dispose();
    debugModeNotifier.dispose();
    super.onRemove();
  }
}

/// Ground component - fills the world with grass
class Ground extends PositionComponent {
  Ground() : super(position: Vector2.zero(), size: Vector2(GameConstants.worldWidth, GameConstants.worldHeight), priority: 0);

  @override
  void render(Canvas canvas) {
    // Draw base grass color
    final basePaint = Paint()..color = GameColors.grassGreen;
    canvas.drawRect(size.toRect(), basePaint);

    // Draw some grass texture/variation
    final lightPaint = Paint()..color = GameColors.grassGreenLight;
    final darkPaint = Paint()..color = GameColors.grassGreenDark;

    // Draw random grass patches for visual interest
    final random = _SeededRandom(42);
    for (var i = 0; i < 200; i++) {
      final x = random.nextDouble() * size.x;
      final y = random.nextDouble() * size.y;
      final patchSize = 20 + random.nextDouble() * 40;
      final isLight = random.nextBool();

      canvas.drawCircle(Offset(x, y), patchSize, isLight ? lightPaint : darkPaint);
    }
  }
}

/// Simple seeded random for consistent patterns
class _SeededRandom {
  int _seed;

  _SeededRandom(this._seed);

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }

  bool nextBool() => nextDouble() > 0.5;
}
