import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/game_save_service.dart';
import '../utils/constants.dart';
import 'components/caught_fish_animation.dart';
import 'components/player.dart';
import 'components/quest_sign.dart';
import 'components/shop.dart';
import 'components/tiled_water.dart';
import 'components/tree.dart';
import 'world/tiled_map_world.dart';

/// Fishing state machine states
enum FishingState {
  idle,           // Not fishing
  casting,        // Line is being cast (animation)
  waiting,        // Bobber in water, waiting for bite
  bite,           // Fish is biting! Player must tap quickly
  minigame,       // Player is in the fishing minigame
  caught,         // Fish was caught
  escaped,        // Fish got away
}

/// Data about the fish currently being caught
class HookedFish {
  final WaterType waterType;
  final int tier;
  final String assetPath;

  const HookedFish({
    required this.waterType,
    required this.tier,
    required this.assetPath,
  });
}

/// Main game class for Lurelands
/// Now uses local save instead of server sync
class LurelandsGame extends FlameGame with HasCollisionDetection {
  /// Game save service for local persistence
  final GameSaveService saveService;

  /// Player ID for the local player
  final String playerId;

  /// Player name
  final String playerName;

  /// Player color (ARGB)
  final int playerColor;

  LurelandsGame({
    required this.saveService,
    required this.playerId,
    this.playerName = 'Player',
    this.playerColor = 0xFFE74C3C,
  });

  Player? _player;
  late TiledMapWorld _tiledMapWorld;

  // Public getter for player (used by other components)
  Player? get player => _player;

  // Public getter for trees (used by player for collision checking)
  List<Tree> get trees => [];

  // Public getter for shops
  List<Shop> get shops => [];

  // Public getter for quest signs
  List<QuestSign> get questSigns => [];

  // Movement direction from joystick (set by UI)
  Vector2 joystickDirection = Vector2.zero();

  // Track if player was moving last frame (for stop detection)
  bool _wasMovingLastFrame = false;

  // Notifiers for UI
  final ValueNotifier<bool> isLoadedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> canCastNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isCastingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> debugModeNotifier = ValueNotifier(false);
  final ValueNotifier<double> castPowerNotifier = ValueNotifier(0.0);

  // Fishing state notifiers
  final ValueNotifier<FishingState> fishingStateNotifier = ValueNotifier(FishingState.idle);
  final ValueNotifier<HookedFish?> hookedFishNotifier = ValueNotifier(null);

  // Shop notifiers
  final ValueNotifier<Shop?> nearbyShopNotifier = ValueNotifier(null);

  // Quest sign notifiers
  final ValueNotifier<QuestSign?> nearbyQuestSignNotifier = ValueNotifier(null);

  // Charging state
  bool _isCharging = false;
  double _castPower = 0.0;
  double _castAnimationTimer = 0.0;

  // Lure sit timer (auto-reel after duration)
  double _lureSitTimer = 0.0;

  // Game time for animations
  double _gameTime = 0.0;

  // Fish bite state
  double _biteTimer = 0.0;
  double _biteReactionTimer = 0.0;

  // Current water info for fishing
  WaterType? _currentWaterType;
  String? _currentWaterBodyId;

  final Random _random = Random();

  /// All tiled water data for collision/spawning checks
  List<TiledWaterData> get allTiledWaterData => _tiledMapWorld.allTiledWaterData;

  /// All dock walkable areas (player can walk on docks over water)
  List<Rect> get dockAreas => _tiledMapWorld.dockAreas;

  /// Check if a world position is inside water (tile-based, accurate)
  bool isInsideWater(double x, double y) => _tiledMapWorld.isInsideWater(x, y);

  /// Check if a world position collides with tile collision objects or collision layer
  bool isCollisionAt(double x, double y) => _tiledMapWorld.isCollisionAt(x, y);

  /// Get current game time for animations
  double currentTime() => _gameTime;

  @override
  Color backgroundColor() => GameColors.grassGreen;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _updateCameraBounds();
  }

  /// Update camera bounds to account for viewport size
  void _updateCameraBounds() {
    final viewportSize = size;
    final halfWidth = viewportSize.x / 2;
    final halfHeight = viewportSize.y / 2;

    if (halfWidth <= 0 || halfHeight <= 0) return;

    final minX = halfWidth.clamp(0.0, GameConstants.worldWidth / 2);
    final minY = halfHeight.clamp(0.0, GameConstants.worldHeight / 2);
    final maxX = (GameConstants.worldWidth - halfWidth).clamp(GameConstants.worldWidth / 2, GameConstants.worldWidth);
    final maxY = (GameConstants.worldHeight - halfHeight).clamp(GameConstants.worldHeight / 2, GameConstants.worldHeight);

    camera.setBounds(
      Rect.fromLTRB(minX, minY, maxX, maxY).toFlameRectangle(),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Preload all game assets
    await images.loadAll([
      'characters/base_walk_strip8.png',
      'characters/base_idle_strip9.png',
    ]);

    // Create and set the Tiled map world
    debugPrint('[LurelandsGame] Creating TiledMapWorld...');
    _tiledMapWorld = TiledMapWorld();
    world = _tiledMapWorld;

    // Get spawn position from save or use map default
    final save = saveService.currentSave;
    final spawnX = save?.playerX ?? _tiledMapWorld.playerSpawnPoint.x;
    final spawnY = save?.playerY ?? _tiledMapWorld.playerSpawnPoint.y;
    final equippedPoleTier = _getPoleTierFromId(save?.equippedPoleId);

    debugPrint('[LurelandsGame] Player spawn position: ($spawnX, $spawnY)');

    // Create the player at spawn position
    _player = Player(
      position: Vector2(spawnX, spawnY),
      equippedPoleTier: equippedPoleTier,
      playerName: playerName,
    );
    await world.add(_player!);
    debugPrint('[LurelandsGame] Player added to world');

    // Set up camera to follow player with smooth tracking
    camera.viewfinder.anchor = Anchor.center;
    camera.follow(_player!, maxSpeed: 800);

    // Mark game as loaded
    isLoadedNotifier.value = true;
  }

  /// Get pole tier from pole ID (e.g., "pole_2" -> 2)
  int _getPoleTierFromId(String? poleId) {
    if (poleId == null) return 1;
    if (poleId.startsWith('pole_')) {
      return int.tryParse(poleId.split('_').last) ?? 1;
    }
    return 1;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _gameTime += dt;

    final player = _player;
    if (player == null) return;

    // Handle player movement (not during minigame)
    if (fishingStateNotifier.value != FishingState.minigame) {
      player.move(joystickDirection, dt);

      final isMovingNow = joystickDirection.length > 0.1;

      // Save position periodically when moving (throttled by save service)
      if (isMovingNow) {
        saveService.updatePlayerPosition(
          player.position.x,
          player.position.y,
          player.facingAngle,
        );
      }

      _wasMovingLastFrame = isMovingNow;
    }

    // Update casting state notifiers
    _updateCastingState(player);

    // Update nearby shop
    _updateNearbyShop(player);

    // Update nearby quest sign
    _updateNearbyQuestSign(player);

    // Handle charging power meter
    if (_isCharging) {
      _castPower += GameConstants.castChargeRate * dt;
      if (_castPower > 1.0) _castPower = 1.0;
      castPowerNotifier.value = _castPower;
    }

    // Handle cast animation timer
    if (_castAnimationTimer > 0) {
      _castAnimationTimer -= dt;
      if (_castAnimationTimer <= 0) {
        _castPower = 0.0;
        castPowerNotifier.value = 0.0;
        if (fishingStateNotifier.value == FishingState.casting) {
          final castLine = player.castLine;
          if (castLine != null && _isBobberInWater(castLine.endPosition)) {
            _startWaitingForBite();
          } else {
            _cancelFishing(player);
          }
        }
      }
    }

    // Handle fishing state machine
    _updateFishingState(dt, player);
  }

  /// Update the fishing state machine
  void _updateFishingState(double dt, Player player) {
    switch (fishingStateNotifier.value) {
      case FishingState.idle:
      case FishingState.casting:
        break;

      case FishingState.waiting:
        if (_biteTimer > 0) {
          _biteTimer -= dt;
          if (_biteTimer <= 0) {
            _triggerBite();
          }
        }
        if (_lureSitTimer > 0) {
          _lureSitTimer -= dt;
          if (_lureSitTimer <= 0) {
            _cancelFishing(player);
          }
        }
        break;

      case FishingState.bite:
        if (_biteReactionTimer > 0) {
          _biteReactionTimer -= dt;
          if (_biteReactionTimer <= 0) {
            _fishEscaped(player);
          }
        }
        break;

      case FishingState.minigame:
        break;

      case FishingState.caught:
      case FishingState.escaped:
        break;
    }
  }

  /// Start waiting for a fish to bite
  void _startWaitingForBite() {
    fishingStateNotifier.value = FishingState.waiting;
    _biteTimer = GameConstants.minBiteWait +
        _random.nextDouble() * (GameConstants.maxBiteWait - GameConstants.minBiteWait);
  }

  /// Trigger a fish bite
  void _triggerBite() {
    fishingStateNotifier.value = FishingState.bite;
    _biteReactionTimer = GameConstants.biteReactionWindow;

    _selectHookedFish();

    final castLine = _player?.castLine;
    if (castLine != null) {
      castLine.startBiteAnimation();
    }

    HapticFeedback.mediumImpact();
  }

  /// Select which fish the player has hooked
  void _selectHookedFish() {
    if (_currentWaterType == null) return;

    final waterType = _currentWaterType!;

    // Weighted random tier selection
    final roll = _random.nextDouble();
    int tier;
    if (roll < 0.50) {
      tier = 1;
    } else if (roll < 0.80) {
      tier = 2;
    } else if (roll < 0.95) {
      tier = 3;
    } else {
      tier = 4;
    }

    final fishAsset = FishAssets.getFish(waterType, tier);
    hookedFishNotifier.value = HookedFish(
      waterType: waterType,
      tier: tier,
      assetPath: fishAsset.path,
    );
  }

  /// Called when player successfully taps during bite window
  void onBiteTapped() {
    if (fishingStateNotifier.value != FishingState.bite) return;

    final castLine = _player?.castLine;
    if (castLine != null) {
      castLine.stopBiteAnimation();
    }

    fishingStateNotifier.value = FishingState.minigame;
  }

  /// Called when player misses the bite window
  void _fishEscaped(Player player) {
    fishingStateNotifier.value = FishingState.escaped;
    hookedFishNotifier.value = null;

    player.reelIn();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (fishingStateNotifier.value == FishingState.escaped) {
        fishingStateNotifier.value = FishingState.idle;
      }
    });
  }

  /// Called when fish is caught in minigame
  void onFishCaught() {
    final fish = hookedFishNotifier.value;
    final player = _player;
    final castLine = player?.castLine;

    if (fish != null && player != null && castLine != null) {
      final bobberPosition = castLine.endPosition.clone();

      final targetPosition = Vector2(
        player.position.x,
        player.position.y - 60,
      );

      // Map tier to star rarity
      final rarity = fish.tier <= 2 ? 1 : (fish.tier == 3 ? 2 : 3);

      final fishAnimation = CaughtFishAnimation(
        startPosition: bobberPosition,
        targetPosition: targetPosition,
        fishAssetPath: fish.assetPath,
        rarity: rarity,
        onComplete: () {
          _completeFishCatch(fish);
        },
      );

      world.add(fishAnimation);

      player.reelIn();

      fishingStateNotifier.value = FishingState.caught;
    } else {
      _completeFishCatch(fish);
    }
  }

  /// Complete the fish catch after animation
  void _completeFishCatch(HookedFish? fish) {
    if (fish != null) {
      final itemId = GameItems.getFishId(fish.waterType, fish.tier);
      final rarity = fish.tier <= 2 ? 1 : (fish.tier == 3 ? 2 : 3);

      debugPrint('[Game] Caught fish: $itemId ($rarity star)');

      // Add to local save
      saveService.catchFish(itemId, rarity);
    }

    if (_player?.isCasting == true) {
      _player?.reelIn();
    }

    fishingStateNotifier.value = FishingState.idle;
    hookedFishNotifier.value = null;
  }

  /// Called when fish escapes during minigame
  void onFishEscapedMinigame() {
    if (_player != null) {
      _fishEscaped(_player!);
    }
  }

  /// Cancel fishing and reset state
  void _cancelFishing(Player player) {
    player.reelIn();
    fishingStateNotifier.value = FishingState.idle;
    hookedFishNotifier.value = null;
    _biteTimer = 0.0;
    _biteReactionTimer = 0.0;
    _lureSitTimer = 0.0;
  }

  void _updateCastingState(Player player) {
    final canCast = _isPlayerNearWater(player);
    if (canCastNotifier.value != canCast) {
      canCastNotifier.value = canCast;
    }

    if (isCastingNotifier.value != player.isCasting) {
      isCastingNotifier.value = player.isCasting;
    }
  }

  bool _isPlayerNearWater(Player player) {
    final playerPos = player.position;
    const castingBuffer = 50.0;

    final onDock = _isOnDock(playerPos);

    for (final tiledWater in allTiledWaterData) {
      if (onDock && tiledWater.containsPoint(playerPos.x, playerPos.y)) {
        return true;
      }
      if (tiledWater.isWithinCastingRange(playerPos.x, playerPos.y, castingBuffer)) {
        return true;
      }
    }
    return false;
  }

  bool _isOnDock(Vector2 pos) {
    for (final dockRect in dockAreas) {
      if (dockRect.contains(Offset(pos.x, pos.y))) {
        return true;
      }
    }
    return false;
  }

  bool _isBobberInWater(Vector2 position) {
    for (final tiledWater in allTiledWaterData) {
      if (tiledWater.containsPoint(position.x, position.y)) {
        return true;
      }
    }
    return false;
  }

  void _updateNearbyShop(Player player) {
    Shop? nearestShop;
    for (final shop in shops) {
      if (shop.isPlayerNearby) {
        nearestShop = shop;
        break;
      }
    }
    if (nearbyShopNotifier.value != nearestShop) {
      nearbyShopNotifier.value = nearestShop;
    }
  }

  void _updateNearbyQuestSign(Player player) {
    QuestSign? nearestSign;
    for (final sign in questSigns) {
      if (sign.isPlayerNearby) {
        nearestSign = sign;
        break;
      }
    }
    if (nearbyQuestSignNotifier.value != nearestSign) {
      nearbyQuestSignNotifier.value = nearestSign;
    }
  }

  /// Update quest sign indicators based on quest data
  void updateQuestSignIndicators({
    required List<dynamic> allQuests,
    required List<dynamic> playerQuests,
    required bool Function({
      required List<dynamic> allQuests,
      required List<dynamic> playerQuests,
      String? signId,
      List<String>? storylines,
    }) hasCompletableCheck,
    required bool Function({
      required List<dynamic> allQuests,
      required List<dynamic> playerQuests,
      String? signId,
      List<String>? storylines,
    }) hasAvailableCheck,
    required bool Function({
      required List<dynamic> allQuests,
      required List<dynamic> playerQuests,
      String? signId,
      List<String>? storylines,
    }) hasActiveCheck,
  }) {
    for (final sign in questSigns) {
      final hasCompletable = hasCompletableCheck(
        allQuests: allQuests,
        playerQuests: playerQuests,
        signId: sign.id,
        storylines: sign.storylines,
      );
      final hasAvailable = hasAvailableCheck(
        allQuests: allQuests,
        playerQuests: playerQuests,
        signId: sign.id,
        storylines: sign.storylines,
      );
      final hasActive = hasActiveCheck(
        allQuests: allQuests,
        playerQuests: playerQuests,
        signId: sign.id,
        storylines: sign.storylines,
      );

      if (hasCompletable) {
        sign.setIndicatorState(QuestIndicatorState.completable);
      } else if (hasAvailable) {
        sign.setIndicatorState(QuestIndicatorState.available);
      } else if (hasActive) {
        sign.setIndicatorState(QuestIndicatorState.inProgress);
      } else {
        sign.setIndicatorState(QuestIndicatorState.none);
      }
    }
  }

  /// Get info about nearby water the player can cast into
  ({WaterType waterType, String id})? getNearbyWaterInfo() {
    final player = _player;
    if (player == null) return null;

    final playerPos = player.position;
    const castingBuffer = 50.0;

    final onDock = _isOnDock(playerPos);

    for (final tiledWater in allTiledWaterData) {
      if (onDock && tiledWater.containsPoint(playerPos.x, playerPos.y)) {
        return (waterType: tiledWater.waterType, id: tiledWater.id);
      }
      if (tiledWater.isWithinCastingRange(playerPos.x, playerPos.y, castingBuffer)) {
        return (waterType: tiledWater.waterType, id: tiledWater.id);
      }
    }

    return null;
  }

  /// Called from UI when cast button is held down
  void onCastHoldStart() {
    final player = _player;
    if (player == null) return;

    final state = fishingStateNotifier.value;

    if (state == FishingState.bite) {
      onBiteTapped();
      return;
    }

    if (player.isCasting || state == FishingState.waiting || state == FishingState.casting) {
      _cancelFishing(player);
      _castPower = 0.0;
      castPowerNotifier.value = 0.0;
      _castAnimationTimer = 0.0;
      return;
    }

    if (canCastNotifier.value && state == FishingState.idle) {
      _isCharging = true;
      _castPower = 0.0;
      castPowerNotifier.value = 0.0;
    }
  }

  /// Called from UI when cast button is released
  void onCastRelease() {
    final player = _player;
    if (player == null) return;

    if (_isCharging) {
      _isCharging = false;
      final waterInfo = getNearbyWaterInfo();
      if (waterInfo != null) {
        player.startCasting(_castPower);
        _currentWaterType = waterInfo.waterType;
        _currentWaterBodyId = waterInfo.id;

        fishingStateNotifier.value = FishingState.casting;
        _castAnimationTimer = GameConstants.castAnimationDuration;
        _lureSitTimer = GameConstants.lureSitDuration;
      } else {
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
      _cancelFishing(player);
    }
  }

  /// Toggle debug mode
  void toggleDebugMode() {
    debugModeNotifier.value = !debugModeNotifier.value;
    final enabled = debugModeNotifier.value;

    if (_player != null) {
      for (final child in _player!.children) {
        if (child is ShapeHitbox) {
          child.debugMode = enabled;
        }
      }
    }

    for (final tree in trees) {
      for (final child in tree.children) {
        if (child is ShapeHitbox) {
          child.debugMode = enabled;
        }
      }
    }
  }

  /// Reset player to the map spawn position
  void resetPlayerPosition() {
    if (_player != null) {
      final spawnPoint = _tiledMapWorld.playerSpawnPoint;
      _player!.position = spawnPoint.clone();
      saveService.updatePlayerPosition(spawnPoint.x, spawnPoint.y, 0);
      debugPrint('[LurelandsGame] Reset player position to spawn point: $spawnPoint');
    }
  }

  @override
  void onRemove() {
    // Save before disposing
    saveService.save();

    isLoadedNotifier.dispose();
    canCastNotifier.dispose();
    isCastingNotifier.dispose();
    debugModeNotifier.dispose();
    castPowerNotifier.dispose();
    fishingStateNotifier.dispose();
    hookedFishNotifier.dispose();
    nearbyShopNotifier.dispose();
    nearbyQuestSignNotifier.dispose();
    super.onRemove();
  }
}
