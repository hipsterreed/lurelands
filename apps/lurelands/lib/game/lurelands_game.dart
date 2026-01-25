import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../data/fishing_poles.dart';
import '../data/quests.dart';
import '../services/game_save_service.dart';
import '../utils/constants.dart';
import 'components/base_npc.dart';
import 'components/caught_fish_animation.dart';
import 'components/fishing_debug_overlay.dart';
import 'components/player.dart';
import 'components/quest_sign.dart';
import 'components/shop.dart';
import 'components/tiled_water.dart';
import 'components/tree.dart';
import 'components/wandering_npc.dart';
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
  final int spriteColumn;
  final int spriteRow;

  const HookedFish({
    required this.waterType,
    required this.tier,
    required this.assetPath,
    required this.spriteColumn,
    required this.spriteRow,
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

  // Public getter for shops (from the Tiled map world)
  List<Shop> get shops => isLoadedNotifier.value ? _tiledMapWorld.shops : [];

  // Public getter for quest signs
  List<QuestSign> get questSigns => [];

  // List of wandering NPCs (for collision detection)
  final List<WanderingNpc> _wanderingNpcs = [];
  List<WanderingNpc> get wanderingNpcs => _wanderingNpcs;

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

  // NPC notifiers (for quest interactions)
  final ValueNotifier<WanderingNpc?> nearbyNpcNotifier = ValueNotifier(null);

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

    final minX = halfWidth.clamp(0.0, TiledMapWorld.worldWidth / 2);
    final minY = halfHeight.clamp(0.0, TiledMapWorld.worldHeight / 2);
    final maxX = (TiledMapWorld.worldWidth - halfWidth).clamp(TiledMapWorld.worldWidth / 2, TiledMapWorld.worldWidth);
    final maxY = (TiledMapWorld.worldHeight - halfHeight).clamp(TiledMapWorld.worldHeight / 2, TiledMapWorld.worldHeight);

    camera.setBounds(
      Rect.fromLTRB(minX, minY, maxX, maxY).toFlameRectangle(),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Preload all game assets
    await images.loadAll([
      // Player sprite
      'characters/Fisherman_Fin.png',
      // NPC sprites
      'characters/lumberjack_male.png',
      'characters/miner_male.png',
      'characters/bartender_male.png',
      'characters/bartender_female.png',
      'characters/chef_female.png',
      'characters/farmer_male.png',
      'characters/farmer_female.png',
    ]);

    // Create and set the Tiled map world
    debugPrint('[LurelandsGame] Creating TiledMapWorld...');
    _tiledMapWorld = TiledMapWorld();
    world = _tiledMapWorld;

    // Get spawn position from save or use map default
    final save = saveService.currentSave;
    final spawnX = save?.playerX ?? _tiledMapWorld.playerSpawnPoint.x;
    final spawnY = save?.playerY ?? _tiledMapWorld.playerSpawnPoint.y;
    final facingAngle = save?.facingAngle ?? 0.0;
    final equippedPoleId = save?.equippedPoleId ?? 'pole_1';
    final equippedPoleTier = _getPoleTierFromId(equippedPoleId);

    debugPrint('[LurelandsGame] Player spawn position: ($spawnX, $spawnY), facing: $facingAngle');

    // Create the player at spawn position with saved facing direction
    _player = Player(
      position: Vector2(spawnX, spawnY),
      equippedPoleTier: equippedPoleTier,
      equippedPoleId: equippedPoleId,
      playerName: playerName,
      facingAngle: facingAngle,
    );
    await world.add(_player!);
    debugPrint('[LurelandsGame] Player added to world');

    // Add fishing debug overlay (renders only when debug mode is on)
    await world.add(FishingDebugOverlay());

    // Spawn wandering NPCs near the spawn point
    await _spawnWanderingNpcs(Vector2(spawnX, spawnY));

    // Set up camera to follow player with smooth tracking
    camera.viewfinder.anchor = Anchor.center;

    // Start camera offset from player for a smooth pan-in effect
    camera.viewfinder.position = Vector2(spawnX + 600, spawnY - 400);
    camera.follow(_player!, maxSpeed: 450); // Smooth pan speed

    // Add FPS counter for performance debugging
    add(FpsTextComponent(
      position: Vector2(60, 50),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Color(0xFF000000), blurRadius: 2)],
        ),
      ),
    ));

    // Mark game as loaded
    isLoadedNotifier.value = true;
  }

  /// Get pole tier from pole ID using FishingPoles registry
  int _getPoleTierFromId(String? poleId) {
    if (poleId == null) return 1;
    final pole = FishingPoles.get(poleId);
    if (pole != null) {
      return pole.tier;
    }
    return 1;
  }

  /// Spawn wandering NPCs around the given center position
  /// NPCs are mapped to story characters for quests
  Future<void> _spawnWanderingNpcs(Vector2 center) async {
    // Story NPCs for Act 1 quests
    final npcConfigs = <WanderingNpc>[
      // Ellie - Keeps records, manages the lien situation
      // Quest giver for: The Lien Notice, Keeping Records
      BartenderFemaleNpc(
        id: 'npc_ellie',
        position: center + Vector2(100, 140),
        name: 'Ellie',
        title: 'Record Keeper',
      ),
      // Eli - Old fisherman, player's mentor figure
      // Quest giver for: Old Waters, A Modest Win, Across the River
      FarmerMaleNpc(
        id: 'npc_eli',
        position: center + Vector2(180, 80),
        name: 'Eli',
        title: 'Old Fisherman',
      ),
      // Thomas - Town elder who remembers the old days
      // Quest giver for: Tradition Not Hope, What the Water Remembers
      LumberjackNpc(
        id: 'npc_thomas',
        position: center + Vector2(-120, -80),
        name: 'Thomas',
        title: 'Town Elder',
      ),
      // Lena - Runs the market, handles economy
      // Quest giver for: Worth Something Again, One More Payment
      ChefNpc(
        id: 'npc_lena',
        position: center + Vector2(-150, 50),
        name: 'Lena',
        title: 'Shopkeeper',
      ),
      // Mara - Builder/repair person
      // Quest giver for: Things That Used to Work, The Broken Span
      MinerNpc(
        id: 'npc_mara',
        position: center + Vector2(150, -60),
        name: 'Mara',
        title: 'Builder',
      ),
      // Harlan - Mysterious figure who knows strange things
      // Quest giver for: Voices at the Edge
      BartenderMaleNpc(
        id: 'npc_harlan',
        position: center + Vector2(-80, 120),
        name: 'Harlan',
        title: 'Drifter',
      ),
    ];

    // Add all NPCs to the world and track them
    for (final npc in npcConfigs) {
      await world.add(npc);
      _wanderingNpcs.add(npc);
    }

    debugPrint('[LurelandsGame] Spawned ${npcConfigs.length} wandering NPCs');
  }

  /// Update quest indicators for all NPCs based on current quest progress
  /// Call this when quest progress changes (accept, progress, complete)
  void updateNpcQuestIndicators(List<QuestProgress> questProgress) {
    debugPrint('[LurelandsGame] updateNpcQuestIndicators called with ${questProgress.length} progress entries');
    debugPrint('[LurelandsGame] NPCs to update: ${_wanderingNpcs.length}');
    for (final npc in _wanderingNpcs) {
      final indicator = _calculateNpcQuestIndicator(npc.id, questProgress);
      debugPrint('[LurelandsGame] NPC ${npc.id} -> indicator: $indicator');
      npc.setQuestIndicator(indicator);
    }
  }

  /// Calculate what quest indicator an NPC should show
  NpcQuestIndicator _calculateNpcQuestIndicator(String npcId, List<QuestProgress> questProgress) {
    // Get all quests this NPC gives
    final npcQuests = Quests.getByNpc(npcId);
    debugPrint('[LurelandsGame] NPC $npcId has ${npcQuests.length} quests: ${npcQuests.map((q) => q.id).toList()}');
    if (npcQuests.isEmpty) return NpcQuestIndicator.none;

    // Check for completable quests first (highest priority - yellow ?)
    for (final quest in npcQuests) {
      final progress = questProgress.where((p) => p.questId == quest.id).firstOrNull;
      if (progress != null && progress.isActive && progress.areAllObjectivesMet(quest)) {
        return NpcQuestIndicator.completable;
      }
    }

    // Check for in-progress quests (gray ?)
    for (final quest in npcQuests) {
      final progress = questProgress.where((p) => p.questId == quest.id).firstOrNull;
      if (progress != null && progress.isActive) {
        return NpcQuestIndicator.inProgress;
      }
    }

    // Check for available quests (yellow !)
    for (final quest in npcQuests) {
      final progress = questProgress.where((p) => p.questId == quest.id).firstOrNull;
      // Quest is available if: not started AND prerequisites met
      if (progress == null) {
        if (Quests.arePrerequisitesMet(quest, questProgress)) {
          return NpcQuestIndicator.available;
        }
      }
    }

    return NpcQuestIndicator.none;
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

    // Update nearby NPC
    _updateNearbyNpc(player);

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

    // Snap camera to whole pixels to prevent tile seam artifacts
    final cameraPos = camera.viewfinder.position;
    camera.viewfinder.position = Vector2(
      cameraPos.x.roundToDouble(),
      cameraPos.y.roundToDouble(),
    );
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
      spriteColumn: fishAsset.spriteColumn,
      spriteRow: fishAsset.spriteRow,
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
        spriteColumn: fish.spriteColumn,
        spriteRow: fish.spriteRow,
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

    // Use optimized tile-based proximity check (only checks nearby tiles)
    return _tiledMapWorld.isPlayerNearWater(playerPos, castingBuffer);
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
    // Use precise tile-based water detection (checks collision areas on fishable tiles)
    return _tiledMapWorld.isInsideWater(position.x, position.y);
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

  void _updateNearbyNpc(Player player) {
    WanderingNpc? nearestNpc;
    for (final npc in _wanderingNpcs) {
      if (npc.isPlayerNearby) {
        nearestNpc = npc;
        break;
      }
    }
    if (nearbyNpcNotifier.value != nearestNpc) {
      nearbyNpcNotifier.value = nearestNpc;
    }
  }

  /// Set conversation state for an NPC (stops them from walking during dialog)
  void setNpcInConversation(String npcId, bool inConversation) {
    for (final npc in _wanderingNpcs) {
      if (npc.id == npcId) {
        npc.setInConversation(inConversation);
        break;
      }
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

    const castingBuffer = 50.0;
    // Use optimized tile-based check
    return _tiledMapWorld.getNearbyWaterInfo(player.position, castingBuffer);
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

    for (final npc in wanderingNpcs) {
      for (final child in npc.children) {
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
    nearbyNpcNotifier.dispose();
    super.onRemove();
  }
}
