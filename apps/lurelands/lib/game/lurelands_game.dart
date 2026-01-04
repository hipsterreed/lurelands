import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/spacetimedb/stdb_service.dart';
import '../utils/constants.dart';
import 'components/caught_fish_animation.dart';
import 'components/player.dart';
import 'components/shop.dart';
import 'components/tiled_water.dart';
import 'components/tree.dart';
import 'world/lurelands_world.dart';

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

  // Public getter for shops
  List<Shop> get shops => _lurelandsWorld.shopComponents;

  // Movement direction from joystick (set by UI)
  Vector2 joystickDirection = Vector2.zero();

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
  List<TiledWaterData> get allTiledWaterData => _lurelandsWorld.allTiledWaterData;

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
  /// This ensures the camera stops at the world edge so the player
  /// can walk to the edge without the camera panning beyond it
  void _updateCameraBounds() {
    final viewportSize = size;
    final halfWidth = viewportSize.x / 2;
    final halfHeight = viewportSize.y / 2;

    // Only set bounds if we have a valid viewport size
    if (halfWidth <= 0 || halfHeight <= 0) return;

    // Ensure bounds don't become inverted if world is smaller than viewport
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

    // Preload all game assets to prevent frame drops during gameplay
    await images.loadAll([
      // Character sprites
      'characters/base_walk_strip8.png',
      'characters/base_idle_strip9.png',
      // Plant sprites
      'plants/tree_01_strip4.png',
      'plants/tree_02_strip4.png',
      'plants/sunflower.png',
      // Tilesets
      'tiles/nature.png',
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
    camera.follow(_player!, maxSpeed: 800);

    // Camera bounds will be set in onGameResize once we know viewport size

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
    
    // Update game time
    _gameTime += dt;

    final player = _player;
    if (player == null) return;

    // Handle player movement based on joystick input (not during minigame)
    if (fishingStateNotifier.value != FishingState.minigame) {
      player.move(joystickDirection, dt);

      // Sync position to server periodically (throttled in the service)
      if (joystickDirection.length > 0.1) {
        stdbService.updatePlayerPosition(
          player.position.x,
          player.position.y,
          player.facingAngle,
        );
      }
    }

    // Update casting state notifiers
    _updateCastingState(player);
    
    // Update nearby shop
    _updateNearbyShop(player);

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
        // Transition to waiting state when cast animation completes
        if (fishingStateNotifier.value == FishingState.casting) {
          // Check if bobber landed in water
          final castLine = player.castLine;
          if (castLine != null && _isBobberInWater(castLine.endPosition)) {
            _startWaitingForBite();
          } else {
            // Bobber didn't land in water - auto reel
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
        // Handled elsewhere
        break;

      case FishingState.waiting:
        // Count down to fish bite
        if (_biteTimer > 0) {
          _biteTimer -= dt;
          if (_biteTimer <= 0) {
            _triggerBite();
          }
        }
        // Auto-reel timeout
        if (_lureSitTimer > 0) {
          _lureSitTimer -= dt;
          if (_lureSitTimer <= 0) {
            _cancelFishing(player);
          }
        }
        break;

      case FishingState.bite:
        // Count down reaction window
        if (_biteReactionTimer > 0) {
          _biteReactionTimer -= dt;
          if (_biteReactionTimer <= 0) {
            // Player missed the bite - fish escapes
            _fishEscaped(player);
          }
        }
        break;

      case FishingState.minigame:
        // Minigame is handled by the overlay widget
        break;

      case FishingState.caught:
      case FishingState.escaped:
        // Terminal states - will be reset when starting new cast
        break;
    }
  }

  /// Start waiting for a fish to bite
  void _startWaitingForBite() {
    fishingStateNotifier.value = FishingState.waiting;
    // Random bite time between min and max
    _biteTimer = GameConstants.minBiteWait +
        _random.nextDouble() * (GameConstants.maxBiteWait - GameConstants.minBiteWait);
  }

  /// Trigger a fish bite - shake bobber and vibrate
  void _triggerBite() {
    fishingStateNotifier.value = FishingState.bite;
    _biteReactionTimer = GameConstants.biteReactionWindow;

    // Select a random fish based on water type and luck
    _selectHookedFish();

    // Trigger bobber shake animation
    final castLine = _player?.castLine;
    if (castLine != null) {
      castLine.startBiteAnimation();
    }

    // Haptic feedback
    HapticFeedback.mediumImpact();
  }

  /// Select which fish the player has hooked
  void _selectHookedFish() {
    if (_currentWaterType == null) return;

    final waterType = _currentWaterType!;
    
    // Weighted random tier selection (lower tiers more common)
    // Weights: Tier 1 = 50%, Tier 2 = 30%, Tier 3 = 15%, Tier 4 = 5%
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

    // Stop bobber shake
    final castLine = _player?.castLine;
    if (castLine != null) {
      castLine.stopBiteAnimation();
    }

    // Enter minigame
    fishingStateNotifier.value = FishingState.minigame;
  }

  /// Called when player misses the bite window
  void _fishEscaped(Player player) {
    fishingStateNotifier.value = FishingState.escaped;
    hookedFishNotifier.value = null;
    
    // Reel in automatically
    player.reelIn();
    stdbService.stopCasting();
    
    // Reset after a short delay (handled by UI showing message)
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
      // Get the bobber position (where the fish is caught)
      final bobberPosition = castLine.endPosition.clone();
      
      // Calculate target position: above the player's name label
      // Player name label is at Vector2(size.x / 2 + 20, 60) relative to player
      // In world coordinates, this is player.position + offset accounting for anchor
      final targetPosition = Vector2(
        player.position.x,
        player.position.y - 60, // Above the player's head/name
      );
      
      // Map tier to star rarity: tier 1-2 = 1 star, tier 3 = 2 stars, tier 4 = 3 stars
      final rarity = fish.tier <= 2 ? 1 : (fish.tier == 3 ? 2 : 3);
      
      // Create the caught fish animation
      final fishAnimation = CaughtFishAnimation(
        startPosition: bobberPosition,
        targetPosition: targetPosition,
        fishAssetPath: fish.assetPath,
        rarity: rarity,
        onComplete: () {
          // Animation complete - now show the "CAUGHT!" UI
          _completeFishCatch(fish);
        },
      );
      
      // Add animation to world
      world.add(fishAnimation);
      
      // Reel in the line immediately (fish is flying to player)
      player.reelIn();
      stdbService.stopCasting();
      
      // Set state to caught (but UI won't show full overlay until animation completes)
      fishingStateNotifier.value = FishingState.caught;
    } else {
      // Fallback if something is missing
      _completeFishCatch(fish);
    }
  }
  
  /// Complete the fish catch after animation
  void _completeFishCatch(HookedFish? fish) {
    // Add fish to inventory via server
    if (fish != null) {
      final itemId = GameItems.getFishId(fish.waterType, fish.tier);
      // Map tier to star rarity: tier 1-2 = 1 star, tier 3 = 2 stars, tier 4 = 3 stars
      final rarity = fish.tier <= 2 ? 1 : (fish.tier == 3 ? 2 : 3);
      final waterBodyId = _currentWaterBodyId ?? 'unknown';
      
      debugPrint('[Game] Caught fish: $itemId ($rarity star) from $waterBodyId');
      stdbService.catchFish(itemId, rarity, waterBodyId);
    }
    
    // Reel in if not already
    if (_player?.isCasting == true) {
      _player?.reelIn();
      stdbService.stopCasting();
    }
    
    // Reset state immediately - player can already move during caught state
    // and the animation has already played the celebration
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
    stdbService.stopCasting();
    fishingStateNotifier.value = FishingState.idle;
    hookedFishNotifier.value = null;
    _biteTimer = 0.0;
    _biteReactionTimer = 0.0;
    _lureSitTimer = 0.0;
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

    for (final tiledWater in allTiledWaterData) {
      if (tiledWater.isWithinCastingRange(playerPos.x, playerPos.y, castingBuffer)) {
        return true;
      }
    }
    return false;
  }

  /// Check if a position is inside any water body
  bool _isBobberInWater(Vector2 position) {
    for (final tiledWater in allTiledWaterData) {
      if (tiledWater.containsPoint(position.x, position.y)) {
        return true;
      }
    }
    return false;
  }

  /// Update the nearby shop notifier
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

  /// Get info about nearby water the player can cast into
  /// Returns (waterType, id) if near water, null otherwise
  ({WaterType waterType, String id})? getNearbyWaterInfo() {
    final player = _player;
    if (player == null) return null;

    final playerPos = player.position;
    const castingBuffer = 50.0;

    for (final tiledWater in allTiledWaterData) {
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

    // Handle based on current fishing state
    final state = fishingStateNotifier.value;
    
    // If fish is biting, this tap enters the minigame
    if (state == FishingState.bite) {
      onBiteTapped();
      return;
    }

    // If already casting/waiting, reel in instead
    if (player.isCasting || state == FishingState.waiting || state == FishingState.casting) {
      _cancelFishing(player);
      _castPower = 0.0;
      castPowerNotifier.value = 0.0;
      _castAnimationTimer = 0.0;
      return;
    }

    // Start charging if we can cast and are idle
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

    // If we were charging, execute the cast
    if (_isCharging) {
      _isCharging = false;
      final waterInfo = getNearbyWaterInfo();
      if (waterInfo != null) {
        player.startCasting(_castPower);
        _currentWaterType = waterInfo.waterType;
        _currentWaterBodyId = waterInfo.id;

        // Notify server about casting
        final castLine = player.castLine;
        if (castLine != null) {
          stdbService.startCasting(castLine.endPosition.x, castLine.endPosition.y);
        }

        // Set fishing state to casting
        fishingStateNotifier.value = FishingState.casting;

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
      _cancelFishing(player);
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

    for (final water in _lurelandsWorld.tiledWaterComponents) {
      for (final child in water.children) {
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
    fishingStateNotifier.dispose();
    hookedFishNotifier.dispose();
    nearbyShopNotifier.dispose();
    super.onRemove();
  }
}
