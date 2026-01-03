import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../models/water_body_data.dart';
import '../services/spacetimedb/stdb_service.dart';
import '../utils/constants.dart';
import 'components/player.dart';
import 'components/tree.dart';
import 'world/lurelands_world.dart';

/// Main game class for Lurelands
class LurelandsGame extends FlameGame with HasCollisionDetection {
  /// SpacetimeDB service for multiplayer sync
  final SpacetimeDBService stdbService;

  /// Player ID for the local player
  final String playerId;

  /// Player name
  final String playerName;

  /// Player color (ARGB)
  final int playerColor;

  LurelandsGame({
    required this.stdbService,
    required this.playerId,
    this.playerName = 'Player',
    this.playerColor = 0xFFE74C3C,
  });

  Player? _player;
  late LurelandsWorld _lurelandsWorld;

  // Public getter for player (used by other components)
  Player? get player => _player;

  // Public getter for trees (used by player for collision checking)
  List<Tree> get trees => _lurelandsWorld.treeComponents;

  // Movement direction from joystick (set by UI)
  Vector2 joystickDirection = Vector2.zero();

  // Notifiers for UI
  final ValueNotifier<bool> isLoadedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> canCastNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isCastingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> debugModeNotifier = ValueNotifier(false);
  final ValueNotifier<double> castPowerNotifier = ValueNotifier(0.0);

  // Charging state
  bool _isCharging = false;
  double _castPower = 0.0;
  double _castAnimationTimer = 0.0;

  // Lure sit timer (auto-reel after duration)
  double _lureSitTimer = 0.0;

  /// All water bodies for collision/spawning checks
  List<WaterBodyData> get allWaterBodies => _lurelandsWorld.allWaterBodies;

  @override
  Color backgroundColor() => GameColors.grassGreen;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Preload all game assets to prevent frame drops during gameplay
    await images.loadAll([
      // Character sprites
      'characters/base_walk_strip8.png',
      'characters/base_idle_strip9.png',
      // Plant sprites
      'plants/tree_01_strip4.png',
      'plants/tree_02_strip4.png',
      'plants/sunflower.png',
    ]);

    // Get world state from server and build WorldState
    final serverWorldState = stdbService.worldState;
    final worldState = _buildWorldState(serverWorldState);

    // Create and set the custom world
    _lurelandsWorld = LurelandsWorld(worldState: worldState);
    world = _lurelandsWorld;

    // Join the world and get spawn position
    final spawnPosition = await stdbService.joinWorld(playerId, playerName, playerColor);

    // Determine player spawn position
    final spawnX = spawnPosition?.x ?? 1000.0;
    final spawnY = spawnPosition?.y ?? 1000.0;

    // Create the player at spawn position
    _player = Player(
      position: Vector2(spawnX, spawnY),
      equippedPoleTier: 1,
      playerName: playerName,
    );
    await world.add(_player!);

    // Set up camera to follow player with smooth tracking
    camera.viewfinder.anchor = Anchor.center;
    camera.follow(_player!, maxSpeed: 300);

    // Set camera bounds to prevent viewing outside the world
    camera.setBounds(
      Rect.fromLTWH(0, 0, GameConstants.worldWidth, GameConstants.worldHeight).toFlameRectangle(),
    );

    // Mark game as loaded
    isLoadedNotifier.value = true;
  }

  /// Build WorldState from server data with fallbacks
  WorldState _buildWorldState(WorldState serverWorldState) {
    final ponds = serverWorldState.ponds.isNotEmpty
        ? serverWorldState.ponds
        : fallbackWorldState.ponds;

    final rivers = serverWorldState.rivers.isNotEmpty
        ? serverWorldState.rivers
        : fallbackWorldState.rivers;

    final ocean = serverWorldState.ocean ?? fallbackWorldState.ocean;

    return WorldState(
      ponds: ponds,
      rivers: rivers,
      ocean: ocean,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    final player = _player;
    if (player == null) return;

    // Handle player movement based on joystick input
    player.move(joystickDirection, dt);

    // Sync position to server periodically (throttled in the service)
    if (joystickDirection.length > 0.1) {
      stdbService.updatePlayerPosition(
        player.position.x,
        player.position.y,
        player.facingAngle,
      );
    }

    // Update casting state notifiers
    _updateCastingState(player);

    // Handle charging power meter
    if (_isCharging) {
      _castPower += GameConstants.castChargeRate * dt;
      if (_castPower > 1.0) _castPower = 1.0;
      castPowerNotifier.value = _castPower;
    }

    // Handle cast animation timer (hide power bar when lure lands)
    if (_castAnimationTimer > 0) {
      _castAnimationTimer -= dt;
      if (_castAnimationTimer <= 0) {
        _castPower = 0.0;
        castPowerNotifier.value = 0.0;
      }
    }

    // Handle lure sit timer (auto-reel after duration)
    if (player.isCasting && _lureSitTimer > 0) {
      _lureSitTimer -= dt;
      if (_lureSitTimer <= 0) {
        player.reelIn();
        stdbService.stopCasting();
        _lureSitTimer = 0.0;
      }
    }
  }

  void _updateCastingState(Player player) {
    // Update can cast
    final canCast = _isPlayerNearWater(player);
    if (canCastNotifier.value != canCast) {
      canCastNotifier.value = canCast;
    }

    // Update is casting
    if (isCastingNotifier.value != player.isCasting) {
      isCastingNotifier.value = player.isCasting;
    }
  }

  bool _isPlayerNearWater(Player player) {
    final playerPos = player.position;
    const castingBuffer = 50.0;

    // Check all water bodies
    for (final waterBody in allWaterBodies) {
      if (waterBody.isWithinCastingRange(playerPos.x, playerPos.y, castingBuffer)) {
        return true;
      }
    }
    return false;
  }

  /// Get the water body the player can cast into, if any
  WaterBodyData? getNearbyWaterBody() {
    final player = _player;
    if (player == null) return null;

    final playerPos = player.position;
    const castingBuffer = 50.0;

    for (final waterBody in allWaterBodies) {
      if (waterBody.isWithinCastingRange(playerPos.x, playerPos.y, castingBuffer)) {
        return waterBody;
      }
    }
    return null;
  }

  /// Called from UI when cast button is held down
  void onCastHoldStart() {
    final player = _player;
    if (player == null) return;

    // If already casting, reel in instead
    if (player.isCasting) {
      player.reelIn();
      stdbService.stopCasting();
      // Reset power and timers when reeling in
      _castPower = 0.0;
      castPowerNotifier.value = 0.0;
      _castAnimationTimer = 0.0;
      _lureSitTimer = 0.0;
      return;
    }

    // Start charging if we can cast
    if (canCastNotifier.value) {
      _isCharging = true;
      _castPower = 0.0;
      castPowerNotifier.value = 0.0;
    }
  }

  /// Called from UI when cast button is released
  void onCastRelease() {
    final player = _player;
    if (player == null) return;

    // If we were charging, execute the cast
    if (_isCharging) {
      _isCharging = false;
      final nearbyWater = getNearbyWaterBody();
      if (nearbyWater != null) {
        player.startCasting(nearbyWater, _castPower);

        // Notify server about casting
        final castLine = player.castLine;
        if (castLine != null) {
          stdbService.startCasting(castLine.endPosition.x, castLine.endPosition.y);
        }

        // Start timer to hide power bar when lure lands
        _castAnimationTimer = GameConstants.castAnimationDuration;
        // Start lure sit timer for auto-reel
        _lureSitTimer = GameConstants.lureSitDuration;
      } else {
        // No water body nearby, reset power
        _castPower = 0.0;
        castPowerNotifier.value = 0.0;
      }
    }
  }

  /// Called from UI when reel button is pressed
  void onReelPressed() {
    final player = _player;
    if (player == null) return;

    if (player.isCasting) {
      player.reelIn();
      stdbService.stopCasting();
      _lureSitTimer = 0.0;
    }
  }

  /// Toggle debug mode for player, ponds, and trees
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

    for (final pond in _lurelandsWorld.pondComponents) {
      for (final child in pond.children) {
        if (child is ShapeHitbox) {
          child.debugMode = enabled;
        }
      }
    }

    for (final tree in _lurelandsWorld.treeComponents) {
      for (final child in tree.children) {
        if (child is ShapeHitbox) {
          child.debugMode = enabled;
        }
      }
    }
  }

  @override
  void onRemove() {
    // Leave the world when game is disposed
    stdbService.leaveWorld();

    isLoadedNotifier.dispose();
    canCastNotifier.dispose();
    isCastingNotifier.dispose();
    debugModeNotifier.dispose();
    castPowerNotifier.dispose();
    super.onRemove();
  }
}
