import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../models/water_body_data.dart';
import '../services/spacetimedb/stdb_service.dart';
import '../utils/constants.dart';
import 'components/ocean.dart';
import 'components/player.dart';
import 'components/pond.dart';
import 'components/river.dart';
import 'components/sunflower.dart';
import 'components/tree.dart';

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
  final List<Pond> _pondComponents = [];
  final List<River> _riverComponents = [];
  Ocean? _oceanComponent;
  final List<Tree> _treeComponents = [];

  // Public getter for player (used by other components)
  Player? get player => _player;

  // Public getter for trees (used by player for collision checking)
  List<Tree> get trees => _treeComponents;

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

  // Water body data from server (or fallback)
  List<PondData> _ponds = [];
  List<RiverData> _rivers = [];
  OceanData? _ocean;

  /// All water bodies for collision/spawning checks
  List<WaterBodyData> get allWaterBodies => [
        ..._ponds,
        ..._rivers,
        if (_ocean != null) _ocean!,
      ];

  @override
  Color backgroundColor() => GameColors.grassGreen;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Get world state from server
    final worldState = stdbService.worldState;

    // Use server data if available, otherwise use fallback
    _ponds = worldState.ponds.isNotEmpty
        ? worldState.ponds
        : const [
            PondData(id: 'pond_1', x: 600, y: 600, radius: 100),
            PondData(id: 'pond_2', x: 1400, y: 1200, radius: 80),
          ];

    _rivers = worldState.rivers.isNotEmpty
        ? worldState.rivers
        : const [
            RiverData(id: 'river_1', x: 1000, y: 400, width: 80, length: 600, rotation: 0.3),
          ];

    _ocean = worldState.ocean ??
        const OceanData(id: 'ocean_1', x: 0, y: 0, width: 250, height: 2000);

    // Add ground
    await world.add(Ground());

    // Add ocean (on left side)
    if (_ocean != null) {
      _oceanComponent = Ocean(data: _ocean!);
      await world.add(_oceanComponent!);
    }

    // Add rivers
    for (final riverData in _rivers) {
      final river = River(data: riverData);
      _riverComponents.add(river);
      await world.add(river);
    }

    // Add ponds
    for (final pondData in _ponds) {
      final pond = Pond(data: pondData);
      _pondComponents.add(pond);
      await world.add(pond);
    }

    // Add random sunflowers around the map
    await _spawnSunflowers();

    // Add random trees around the map
    await _spawnTrees();

    // Join the world and get spawn position
    final spawnPosition = await stdbService.joinWorld(playerId, playerName, playerColor);

    // Determine player spawn position
    final spawnX = spawnPosition?.x ?? 1000.0;
    final spawnY = spawnPosition?.y ?? 1000.0;

    // Create the player at spawn position
    _player = Player(
      position: Vector2(spawnX, spawnY),
      equippedPoleTier: 1,
    );
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

  /// Check if a point is inside any water body
  bool _isInsideWater(double x, double y) {
    for (final waterBody in allWaterBodies) {
      if (waterBody.containsPoint(x, y)) {
        return true;
      }
    }
    return false;
  }

  /// Spawn sunflowers randomly around the map
  Future<void> _spawnSunflowers() async {
    final random = Random(123); // Seeded for consistent placement
    const count = 30;

    for (var i = 0; i < count; i++) {
      // Start after ocean area
      final x = 300 + random.nextDouble() * (GameConstants.worldWidth - 400);
      final y = 100 + random.nextDouble() * (GameConstants.worldHeight - 200);

      // Don't place sunflowers inside any water body
      if (!_isInsideWater(x, y)) {
        await world.add(Sunflower(position: Vector2(x, y)));
      }
    }
  }

  /// Spawn trees randomly around the map
  Future<void> _spawnTrees() async {
    final random = Random(456); // Different seed for variety
    const count = 20;

    for (var i = 0; i < count; i++) {
      // Start after ocean area
      final x = 350 + random.nextDouble() * (GameConstants.worldWidth - 450);
      final y = 150 + random.nextDouble() * (GameConstants.worldHeight - 300);

      // Don't place trees inside any water body
      if (!_isInsideWater(x, y)) {
        final tree = Tree.random(Vector2(x, y), random);
        _treeComponents.add(tree);
        await world.add(tree);
      }
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

    for (final pond in _pondComponents) {
      for (final child in pond.children) {
        if (child is ShapeHitbox) {
          child.debugMode = enabled;
        }
      }
    }

    for (final tree in _treeComponents) {
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

/// Ground component - fills the world with grass
class Ground extends PositionComponent {
  Ground()
      : super(
            position: Vector2.zero(),
            size: Vector2(GameConstants.worldWidth, GameConstants.worldHeight),
            priority: 0);

  // Checker tile size
  static const double tileSize = 48.0;

  @override
  void render(Canvas canvas) {
    final lightPaint = Paint()..color = GameColors.grassGreen;
    // Slightly darker shade of the base green
    final darkPaint = Paint()..color = const Color(0xFF437320);

    // Draw checkered pattern
    final tilesX = (size.x / tileSize).ceil();
    final tilesY = (size.y / tileSize).ceil();

    for (var row = 0; row < tilesY; row++) {
      for (var col = 0; col < tilesX; col++) {
        final isLight = (row + col) % 2 == 0;
        final rect = Rect.fromLTWH(
          col * tileSize,
          row * tileSize,
          tileSize,
          tileSize,
        );
        canvas.drawRect(rect, isLight ? lightPaint : darkPaint);
      }
    }
  }
}
