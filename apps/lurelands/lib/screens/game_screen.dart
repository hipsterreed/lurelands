import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/fishing_poles.dart';
import '../game/lurelands_game.dart';
import '../services/game_save_service.dart';
import '../services/game_settings.dart';
import '../utils/constants.dart';
import '../widgets/inventory_panel.dart';
import '../widgets/quest_panel.dart';
import '../widgets/shop_panel.dart';
import '../widgets/spritesheet_sprite.dart' as sprites;
import '../game/components/quest_sign.dart';
import '../game/components/shop.dart';

/// Screen that hosts the Flame GameWidget with mobile touch controls
/// Now uses local save instead of server connection
class GameScreen extends StatefulWidget {
  final String playerName;

  const GameScreen({super.key, this.playerName = 'Fisher'});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  LurelandsGame? _game;
  final GameSaveService _saveService = GameSaveService.instance;

  StreamSubscription<List<InventoryItem>>? _inventorySubscription;
  StreamSubscription<GameSaveData>? _statsSubscription;
  StreamSubscription<int>? _levelUpSubscription;
  StreamSubscription<List<QuestProgress>>? _questSubscription;

  VoidCallback? _shopNotifierListener;
  VoidCallback? _questSignNotifierListener;

  bool _isLoading = true;
  String? _loadError;

  // Inventory state
  bool _showInventory = false;
  List<InventoryItem> _inventoryItems = [];
  int _playerGold = 0;
  String? _equippedPoleId;

  // Shop state
  bool _showShop = false;
  Shop? _nearbyShop;

  // Quest state
  bool _showQuestPanel = false;
  QuestSign? _nearbyQuestSign;
  List<QuestProgress> _questProgress = [];

  // Player stats
  int _playerLevel = 1;
  int _playerXp = 0;
  int _playerXpToNextLevel = 100;
  bool _showLevelUpNotification = false;
  int _levelUpNewLevel = 1;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final settings = GameSettings.instance;
      await settings.init();

      final playerId = await settings.getPlayerId();
      final playerColor = await settings.getPlayerColor();
      final playerName = widget.playerName;

      debugPrint('[GameScreen] Initializing with playerId: "$playerId", playerName: "$playerName"');

      // Load or create save
      final save = await _saveService.loadOrCreateSave(
        playerId: playerId,
        playerName: playerName,
        playerColor: playerColor,
      );

      if (!mounted) return;

      // Subscribe to inventory updates
      _inventorySubscription = _saveService.inventoryUpdates.listen((items) {
        debugPrint('[GameScreen] Received inventory update: ${items.length} items');
        if (mounted) {
          setState(() {
            _inventoryItems = items;
          });
        }
      });

      // Subscribe to stats updates
      _statsSubscription = _saveService.statsUpdates.listen((saveData) {
        if (mounted) {
          setState(() {
            _playerGold = saveData.gold;
            _equippedPoleId = saveData.equippedPoleId;
            _playerLevel = saveData.level;
            _playerXp = saveData.xp;
            _playerXpToNextLevel = saveData.xpToNextLevel;
          });
        }
      });

      // Subscribe to level up events
      _levelUpSubscription = _saveService.levelUpStream.listen((newLevel) {
        if (mounted) {
          setState(() {
            _showLevelUpNotification = true;
            _levelUpNewLevel = newLevel;
          });
          // Auto-hide after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _showLevelUpNotification = false;
              });
            }
          });
        }
      });

      // Subscribe to quest progress updates
      _questSubscription = _saveService.questProgressUpdates.listen((progress) {
        if (mounted) {
          setState(() {
            _questProgress = progress;
          });
        }
      });

      // Emit current state now that subscriptions are set up
      // (Broadcast streams don't buffer, so we need to request current state explicitly)
      _saveService.emitCurrentState();

      // Initialize from current save
      _inventoryItems = save.inventory;
      _playerGold = save.gold;
      _equippedPoleId = save.equippedPoleId;
      _playerLevel = save.level;
      _playerXp = save.xp;
      _playerXpToNextLevel = save.xpToNextLevel;
      _questProgress = save.questProgress;

      // Create the game
      final game = LurelandsGame(
        saveService: _saveService,
        playerId: playerId,
        playerName: playerName,
        playerColor: playerColor,
      );

      // Listen to nearby shop changes
      _shopNotifierListener = () {
        if (mounted) {
          setState(() {
            _nearbyShop = game.nearbyShopNotifier.value;
          });
        }
      };
      game.nearbyShopNotifier.addListener(_shopNotifierListener!);

      // Listen to nearby quest sign changes
      _questSignNotifierListener = () {
        if (mounted) {
          setState(() {
            _nearbyQuestSign = game.nearbyQuestSignNotifier.value;
          });
        }
      };
      game.nearbyQuestSignNotifier.addListener(_questSignNotifierListener!);

      setState(() {
        _isLoading = false;
        _game = game;
      });

      debugPrint('[GameScreen] Game initialized successfully');
    } catch (e) {
      debugPrint('[GameScreen] Error initializing game: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Error loading game: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _inventorySubscription?.cancel();
    _statsSubscription?.cancel();
    _levelUpSubscription?.cancel();
    _questSubscription?.cancel();
    if (_shopNotifierListener != null && _game != null) {
      _game!.nearbyShopNotifier.removeListener(_shopNotifierListener!);
    }
    if (_questSignNotifierListener != null && _game != null) {
      _game!.nearbyQuestSignNotifier.removeListener(_questSignNotifierListener!);
    }
    // Save on dispose
    _saveService.save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen
    if (_isLoading) {
      return Scaffold(
        body: _buildLoadingScreen(),
      );
    }

    // Show error screen
    if (_loadError != null || _game == null) {
      return Scaffold(
        body: _buildErrorScreen(_loadError ?? 'Unknown error'),
      );
    }

    // Show game
    return Scaffold(
      body: Stack(
        children: [
          // Game canvas
          GameWidget(
            game: _game!,
            loadingBuilder: (context) => _buildLoadingScreen(),
            errorBuilder: (context, error) => _buildErrorScreen(error.toString()),
          ),
          // Mobile controls overlay
          _buildMobileControls(),
          // HUD overlay
          _buildHUD(),
          // Fishing minigame overlay
          _buildFishingMinigameOverlay(),
          // Fishing state messages (escaped)
          _buildFishingStateOverlay(),
          // Inventory panel overlay
          if (_showInventory)
            InventoryPanel(
              items: _inventoryItems,
              playerGold: _playerGold,
              playerName: widget.playerName,
              debugEnabled: _game?.debugModeNotifier.value ?? false,
              onClose: () => setState(() => _showInventory = false),
              onToggleDebug: () {
                _game?.toggleDebugMode();
                setState(() {});
              },
              onUpdatePlayerName: (newName) async {
                await GameSettings.instance.setPlayerName(newName);
                _saveService.updatePlayerName(newName);
              },
              equippedPoleId: _equippedPoleId,
              onEquipPole: (poleItemId) {
                _saveService.equipPole(poleItemId);
                // Update player component pole ID and tier
                if (_game?.player != null) {
                  _game!.player!.equippedPoleId = poleItemId;
                }
              },
              onUnequipPole: () {
                _saveService.unequipPole();
                if (_game?.player != null) {
                  _game!.player!.equippedPoleId = 'pole_1';
                }
              },
              onResetGold: () {
                _saveService.setGold(0);
              },
              onResetPosition: () {
                _game?.resetPlayerPosition();
                setState(() => _showInventory = false);
              },
              onResetQuests: () {
                _saveService.resetAllQuests();
              },
              onExitToMenu: () {
                _saveService.save();
                setState(() => _showInventory = false);
                Navigator.of(context).pushReplacementNamed('/');
              },
              quests: [], // Local quests will be defined in constants later
              playerQuests: [], // Using _questProgress instead
              onAcceptQuest: _onAcceptQuest,
              onCompleteQuest: _onCompleteQuest,
              playerLevel: _playerLevel,
              playerXp: _playerXp,
              playerXpToNextLevel: _playerXpToNextLevel,
            ),
          // Shop panel overlay
          if (_showShop && _nearbyShop != null)
            ShopPanel(
              playerItems: _equippedPoleId == null
                  ? _inventoryItems
                  : _inventoryItems
                      .where((item) => item.itemId != _equippedPoleId)
                      .toList(),
              playerGold: _playerGold,
              shopName: _nearbyShop!.name,
              onClose: () => setState(() => _showShop = false),
              onSellItem: _onSellItem,
              onBuyItem: _onBuyItem,
            ),
          // Shop interaction button
          if (_nearbyShop != null && !_showShop && !_showInventory && !_showQuestPanel)
            _buildShopButton(),
          // Quest panel overlay
          if (_showQuestPanel)
            QuestPanel(
              quests: [], // Local quests - can be defined in constants
              playerQuests: [], // Using local _questProgress
              onClose: () => setState(() => _showQuestPanel = false),
              onAcceptQuest: _onAcceptQuest,
              onCompleteQuest: _onCompleteQuest,
              signId: _nearbyQuestSign?.id,
              signName: _nearbyQuestSign?.name,
              storylines: _nearbyQuestSign?.storylines,
            ),
          // Quest sign button
          if (_nearbyQuestSign != null && !_showQuestPanel && !_showInventory && !_showShop)
            _buildQuestSignButton(),
        ],
      ),
    );
  }

  Widget _buildFishingMinigameOverlay() {
    if (_game == null) return const SizedBox.shrink();

    return ValueListenableBuilder<FishingState>(
      valueListenable: _game!.fishingStateNotifier,
      builder: (context, state, _) {
        if (state != FishingState.minigame) return const SizedBox.shrink();

        return ValueListenableBuilder<HookedFish?>(
          valueListenable: _game!.hookedFishNotifier,
          builder: (context, fish, _) {
            if (fish == null) return const SizedBox.shrink();

            return FishingMinigameOverlay(
              fish: fish,
              onCaught: () => _game!.onFishCaught(),
              onEscaped: () => _game!.onFishEscapedMinigame(),
              poleTier: _game!.player?.equippedPoleTier ?? 1,
            );
          },
        );
      },
    );
  }

  Widget _buildFishingStateOverlay() {
    if (_game == null) return const SizedBox.shrink();

    return ValueListenableBuilder<FishingState>(
      valueListenable: _game!.fishingStateNotifier,
      builder: (context, state, _) {
        if (state == FishingState.escaped) {
          return _buildEscapedMessage();
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEscapedMessage() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: GameColors.progressRed.withAlpha(200),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Fish Escaped!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: GameColors.menuBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.rotate(
                  angle: sin(value * pi * 2) * 0.2,
                  child: child,
                );
              },
              child: Icon(
                Icons.phishing,
                color: GameColors.pondBlue,
                size: 80,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Loading Game...',
              style: TextStyle(
                color: GameColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: GameColors.menuAccent,
                valueColor: AlwaysStoppedAnimation(GameColors.pondBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Container(
      color: GameColors.menuBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: GameColors.playerDefault, size: 64),
            const SizedBox(height: 24),
            Text(
              'Error loading game',
              style: TextStyle(color: GameColors.textPrimary, fontSize: 20),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error,
                style: TextStyle(color: GameColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GameColors.pondBlue,
              ),
              child: const Text('Back to Menu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD() {
    if (_game == null) return const SizedBox.shrink();

    return SafeArea(
      child: Stack(
        children: [
          // Level up notification
          if (_showLevelUpNotification)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: _buildLevelUpNotification(),
            ),
          // Inventory/Backpack button
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => setState(() => _showInventory = true),
              child: Container(
                decoration: BoxDecoration(
                  color: GameColors.menuBackground.withAlpha(179),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    Icon(
                      Icons.backpack,
                      color: GameColors.textPrimary.withAlpha(204),
                      size: 28,
                    ),
                    if (_inventoryItems.isNotEmpty)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: GameColors.pondBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_inventoryItems.fold<int>(0, (sum, e) => sum + e.quantity)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelUpNotification() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFB8860B),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withAlpha(100),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.arrow_upward,
                color: Color(0xFF2D1810),
                size: 28,
              ),
              const SizedBox(height: 4),
              const Text(
                'LEVEL UP!',
                style: TextStyle(
                  color: Color(0xFF2D1810),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Level $_levelUpNewLevel',
                style: const TextStyle(
                  color: Color(0xFF5D3A1A),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileControls() {
    if (_game == null) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: _game!.isLoadedNotifier,
      builder: (context, isLoaded, _) {
        if (!isLoaded) return const SizedBox.shrink();

        return ValueListenableBuilder<FishingState>(
          valueListenable: _game!.fishingStateNotifier,
          builder: (context, fishingState, _) {
            if (fishingState == FishingState.minigame ||
                fishingState == FishingState.escaped) {
              return const SizedBox.shrink();
            }

            return SafeArea(
              child: Stack(
                children: [
                  if (fishingState != FishingState.bite)
                    Positioned(
                      left: 30,
                      bottom: 30,
                      child: VirtualJoystick(
                        onDirectionChanged: (direction) {
                          _game!.joystickDirection = Vector2(direction.dx, direction.dy);
                        },
                      ),
                    ),
                  Positioned(right: 30, bottom: 30, child: _buildActionButtons()),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons() {
    if (_game == null) return const SizedBox.shrink();

    return ValueListenableBuilder<FishingState>(
      valueListenable: _game!.fishingStateNotifier,
      builder: (context, fishingState, _) {
        if (fishingState == FishingState.bite) {
          return _buildBiteTapButton();
        }

        final hasPoleEquipped = _equippedPoleId != null;

        return ValueListenableBuilder<bool>(
          valueListenable: _game!.canCastNotifier,
          builder: (context, canCast, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: _game!.isCastingNotifier,
              builder: (context, isCasting, _) {
                if (!hasPoleEquipped) {
                  return _buildNoPoleButton();
                }

                final isActive = canCast || isCasting;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTapDown: (_) => _game!.onCastHoldStart(),
                      onTapUp: (_) => _game!.onCastRelease(),
                      onTapCancel: () => _game!.onCastRelease(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? GameColors.pondBlue
                              : GameColors.menuBackground.withAlpha(128),
                          border: Border.all(
                            color: isActive
                                ? GameColors.pondBlueLight
                                : GameColors.textSecondary.withAlpha(64),
                            width: 3,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: GameColors.pondBlue.withAlpha(128),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Builder(
                            builder: (context) {
                              // Get the correct sprite from FishingPoles registry
                              final pole = FishingPoles.get(_equippedPoleId ?? 'pole_1') ?? FishingPoles.defaultPole;
                              final castRotation = isCasting ? pi / 6 : 0.0;
                              return sprites.SpritesheetSprite(
                                column: pole.spriteColumn,
                                row: pole.spriteRow,
                                size: 40,
                                opacity: isActive ? 1.0 : 0.5,
                                rotation: castRotation,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCasting
                          ? 'REEL'
                          : canCast
                              ? 'HOLD'
                              : '',
                      style: TextStyle(
                        color: GameColors.textPrimary.withAlpha(200),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNoPoleButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _showNoPoleMessage,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GameColors.menuBackground.withAlpha(128),
              border: Border.all(
                color: GameColors.textSecondary.withAlpha(80),
                width: 3,
              ),
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.phishing,
                    size: 36,
                    color: GameColors.textSecondary.withAlpha(100),
                  ),
                  Icon(
                    Icons.close,
                    size: 48,
                    color: GameColors.progressRed.withAlpha(180),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'NO POLE',
          style: TextStyle(
            color: GameColors.progressRed.withAlpha(180),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showNoPoleMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GameColors.menuBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: GameColors.progressRed.withAlpha(120),
            width: 2,
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: GameColors.progressOrange, size: 28),
            const SizedBox(width: 12),
            Text(
              'No Fishing Pole!',
              style: TextStyle(
                color: GameColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You need a fishing pole equipped to fish.',
              style: TextStyle(
                color: GameColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GameColors.menuAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: GameColors.pondBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Open your backpack to equip your fishing pole!",
                      style: TextStyle(
                        color: GameColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.pondBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildBiteTapButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1.1),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: GestureDetector(
            onTapDown: (_) => _game!.onCastHoldStart(),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GameColors.progressOrange,
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: GameColors.progressOrange.withAlpha(200),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.touch_app,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'TAP!',
          style: TextStyle(
            color: GameColors.progressOrange,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(
                color: Colors.black,
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShopButton() {
    return Positioned(
      bottom: 160,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => setState(() => _showShop = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: GameColors.menuBackground.withAlpha(230),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: GameColors.pondBlue,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: GameColors.pondBlue.withAlpha(100),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storefront,
                  color: GameColors.pondBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'OPEN SHOP',
                  style: TextStyle(
                    color: GameColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestSignButton() {
    return Positioned(
      bottom: 160,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => setState(() => _showQuestPanel = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: GameColors.menuBackground.withAlpha(230),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFD700),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withAlpha(100),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.assignment,
                  color: Color(0xFFFFD700),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'VIEW QUESTS',
                  style: TextStyle(
                    color: GameColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onAcceptQuest(String questId) {
    _saveService.acceptQuest(questId);
  }

  void _onCompleteQuest(Quest quest) {
    _saveService.completeQuest(
      quest.id,
      goldReward: quest.goldReward,
      xpReward: quest.xpReward,
      itemRewards: quest.itemRewards,
    );
  }

  void _onSellItem(dynamic item, int quantity) {
    final itemDef = GameItems.get(item.itemId);
    if (itemDef == null) return;

    _saveService.sellItem(item.itemId, item.rarity, quantity);
  }

  void _onBuyItem(String itemId, int price) {
    _saveService.buyItem(itemId, price);
  }
}

/// Fishing minigame overlay - Stardew Valley style
class FishingMinigameOverlay extends StatefulWidget {
  final HookedFish fish;
  final VoidCallback onCaught;
  final VoidCallback onEscaped;
  final int poleTier;

  const FishingMinigameOverlay({
    super.key,
    required this.fish,
    required this.onCaught,
    required this.onEscaped,
    this.poleTier = 1,
  });

  @override
  State<FishingMinigameOverlay> createState() => _FishingMinigameOverlayState();
}

class _FishingMinigameOverlayState extends State<FishingMinigameOverlay>
    with SingleTickerProviderStateMixin {
  static const double meterWidth = 60.0;
  static const double meterHeight = 320.0;
  static const double progressMeterWidth = 24.0;
  static const double frameThickness = 8.0;

  late double _fishPosition;
  late double _fishTarget;
  late double _fishVelocity;
  late double _barPosition;
  late double _barVelocity;
  late double _progress;
  late double _barSize;
  late double _gravityMultiplier;

  double _directionChangeTimer = 0.0;
  double _fishSpeed = 1.0;

  late double _timeRemaining;
  late double _totalTime;

  late AnimationController _animController;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();

    final fishTierIndex = widget.fish.tier - 1;
    _fishSpeed = GameConstants.fishSpeedByTier[fishTierIndex];
    _totalTime = GameConstants.minigameTimeoutByTier[fishTierIndex];
    _timeRemaining = _totalTime;

    final poleTierIndex = (widget.poleTier - 1).clamp(0, 3);
    _gravityMultiplier = GameConstants.poleGravityMultiplier[poleTierIndex];

    final baseBarSize = GameConstants.barSizeByTier[fishTierIndex];
    final poleBonus = GameConstants.poleBarSizeBonus[poleTierIndex];
    _barSize = baseBarSize + poleBonus;

    _fishPosition = 0.5;
    _fishTarget = 0.5;
    _fishVelocity = 0.0;
    _barPosition = 0.3;
    _barVelocity = 0.0;
    _progress = GameConstants.minigameStartProgress;
    _directionChangeTimer = 0.5;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_gameLoop);
    _animController.forward();
    _lastUpdate = DateTime.now();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _gameLoop() {
    final now = DateTime.now();
    final dt = _lastUpdate != null
        ? (now.difference(_lastUpdate!).inMicroseconds / 1000000.0)
        : 0.016;
    _lastUpdate = now;

    if (dt > 0.1) return;

    setState(() {
      _updateFish(dt);
      _updateBar(dt);
      _updateProgress(dt);
      _updateTimeout(dt);
    });

    if (_progress >= 1.0) {
      widget.onCaught();
    } else if (_progress <= 0.0 || _timeRemaining <= 0.0) {
      widget.onEscaped();
    }
  }

  void _updateTimeout(double dt) {
    _timeRemaining -= dt;
    if (_timeRemaining < 0) _timeRemaining = 0;
  }

  void _updateFish(double dt) {
    _directionChangeTimer -= dt;
    if (_directionChangeTimer <= 0) {
      _directionChangeTimer = 0.5 + (1.0 - _fishSpeed / 2.0) * Random().nextDouble();
      _fishTarget = Random().nextDouble();
    }

    final targetDiff = _fishTarget - _fishPosition;
    _fishVelocity += targetDiff * 8.0 * _fishSpeed * dt;
    _fishVelocity *= 0.95;
    _fishVelocity = _fishVelocity.clamp(-2.0 * _fishSpeed, 2.0 * _fishSpeed);

    _fishPosition += _fishVelocity * dt;
    _fishPosition = _fishPosition.clamp(0.0, 1.0);
  }

  void _updateBar(double dt) {
    _barVelocity -= GameConstants.minigameBarGravity * _gravityMultiplier * dt / meterHeight;

    final maxVel = GameConstants.minigameBarMaxSpeed / meterHeight;
    _barVelocity = _barVelocity.clamp(-maxVel, maxVel);

    _barPosition += _barVelocity * dt;
    _barPosition = _barPosition.clamp(0.0, 1.0 - _barSize);
  }

  void _updateProgress(double dt) {
    final fishCenter = _fishPosition;
    const fishHalfSize = 0.08;
    final barTop = _barPosition + _barSize;
    final barBottom = _barPosition;

    final isOnFish = fishCenter >= barBottom - fishHalfSize &&
        fishCenter <= barTop + fishHalfSize;

    if (isOnFish) {
      _progress += GameConstants.minigameProgressFillRate * dt;
    } else {
      _progress -= GameConstants.minigameProgressDrainRate * dt;
    }
    _progress = _progress.clamp(0.0, 1.0);
  }

  void _onTap() {
    _barVelocity = GameConstants.minigameBarBoost / meterHeight;
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTapDown: (_) => _onTap(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black54,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTimerDisplay(),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildFishingMeter(),
                    const SizedBox(width: 12),
                    _buildProgressMeter(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay() {
    final timePercent = _timeRemaining / _totalTime;
    final seconds = _timeRemaining.ceil();

    Color timerColor;
    if (timePercent > 0.5) {
      timerColor = Colors.white;
    } else if (timePercent > 0.25) {
      timerColor = GameColors.progressOrange;
    } else {
      timerColor = GameColors.progressRed;
    }

    return Column(
      children: [
        Text(
          '${seconds}s',
          style: TextStyle(
            color: timerColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: meterWidth + progressMeterWidth + frameThickness * 3 + 12,
          height: 8,
          decoration: BoxDecoration(
            color: GameColors.menuBackground,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: (meterWidth + progressMeterWidth + frameThickness * 3 + 10) * timePercent,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      timerColor.withAlpha(200),
                      timerColor,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFishingMeter() {
    return Container(
      width: meterWidth + frameThickness * 2,
      height: meterHeight + frameThickness * 2,
      decoration: BoxDecoration(
        color: GameColors.woodFrame,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GameColors.woodFrameDark, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(frameThickness),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  GameColors.minigameWaterTop,
                  GameColors.minigameWaterBottom,
                ],
              ),
            ),
            child: Stack(
              children: [
                ..._buildWaterDecorations(),
                _buildControlBar(),
                _buildFish(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildWaterDecorations() {
    return [
      Positioned(
        left: 8,
        bottom: 20 + sin(_animController.value * pi * 4) * 10,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withAlpha(60),
          ),
        ),
      ),
      Positioned(
        right: 12,
        bottom: 60 + sin(_animController.value * pi * 3 + 1) * 15,
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withAlpha(40),
          ),
        ),
      ),
    ];
  }

  Widget _buildFish() {
    final fishY = (1.0 - _fishPosition) * (meterHeight - 40);
    final rarity = widget.fish.tier <= 2 ? 1 : (widget.fish.tier == 3 ? 2 : 3);

    return Positioned(
      left: (meterWidth - 32) / 2,
      top: fishY,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              rarity,
              (i) => Icon(
                Icons.star,
                size: 10,
                color: Colors.amber,
                shadows: [
                  Shadow(
                    color: Colors.black.withAlpha(180),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Image.asset(
            widget.fish.assetPath,
            width: 32,
            height: 32,
            errorBuilder: (_, __, ___) => Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.catching_pokemon, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    final barHeight = _barSize * meterHeight;
    final barY = (1.0 - _barPosition - _barSize) * meterHeight;

    return Positioned(
      left: 4,
      right: 4,
      top: barY,
      height: barHeight,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              GameColors.catchBarGreen.withAlpha(200),
              GameColors.catchBarGreenLight.withAlpha(220),
              GameColors.catchBarGreen.withAlpha(200),
            ],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.white.withAlpha(150),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: GameColors.catchBarGreen.withAlpha(100),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressMeter() {
    Color progressColor;
    if (_progress < 0.33) {
      progressColor = Color.lerp(
        GameColors.progressRed,
        GameColors.progressOrange,
        _progress / 0.33,
      )!;
    } else if (_progress < 0.66) {
      progressColor = Color.lerp(
        GameColors.progressOrange,
        GameColors.progressGreen,
        (_progress - 0.33) / 0.33,
      )!;
    } else {
      progressColor = GameColors.progressGreen;
    }

    return Container(
      width: progressMeterWidth + frameThickness,
      height: meterHeight + frameThickness * 2,
      decoration: BoxDecoration(
        color: GameColors.woodFrame,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: GameColors.woodFrameDark, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(frameThickness / 2),
        child: Container(
          decoration: BoxDecoration(
            color: GameColors.menuBackground,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: progressMeterWidth - frameThickness,
              height: _progress * (meterHeight - frameThickness),
              decoration: BoxDecoration(
                color: progressColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: progressColor.withAlpha(150),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Virtual joystick for mobile movement control
class VirtualJoystick extends StatefulWidget {
  final void Function(Offset direction) onDirectionChanged;
  final double size;

  const VirtualJoystick({
    super.key,
    required this.onDirectionChanged,
    this.size = 140,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _knobPosition = Offset.zero;
  bool _isDragging = false;

  double get _knobRadius => widget.size * 0.2;
  double get _baseRadius => widget.size * 0.5;
  double get _maxKnobDistance => _baseRadius - _knobRadius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GameColors.menuBackground.withAlpha(128),
          border: Border.all(color: GameColors.pondBlue.withAlpha(100), width: 2),
        ),
        child: Stack(
          children: [
            _buildDirectionIndicators(),
            Center(
              child: Transform.translate(
                offset: _knobPosition,
                child: AnimatedContainer(
                  duration: _isDragging ? Duration.zero : const Duration(milliseconds: 100),
                  width: _knobRadius * 2,
                  height: _knobRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isDragging
                        ? GameColors.pondBlue
                        : GameColors.pondBlue.withAlpha(180),
                    border: Border.all(color: GameColors.pondBlueLight, width: 2),
                    boxShadow: _isDragging
                        ? [
                            BoxShadow(
                              color: GameColors.pondBlue.withAlpha(100),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionIndicators() {
    return Center(
      child: SizedBox(
        width: widget.size * 0.6,
        height: widget.size * 0.6,
        child: CustomPaint(
          painter: _DirectionIndicatorPainter(
            color: GameColors.textSecondary.withAlpha(64),
          ),
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final localPosition = details.localPosition - center;

    final distance = localPosition.distance;
    final clampedDistance = min(distance, _maxKnobDistance);

    Offset newPosition;
    if (distance > 0) {
      newPosition = Offset(
        localPosition.dx / distance * clampedDistance,
        localPosition.dy / distance * clampedDistance,
      );
    } else {
      newPosition = Offset.zero;
    }

    setState(() {
      _knobPosition = newPosition;
    });

    final normalizedDirection = Offset(
      newPosition.dx / _maxKnobDistance,
      newPosition.dy / _maxKnobDistance,
    );
    widget.onDirectionChanged(normalizedDirection);
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _knobPosition = Offset.zero;
    });
    widget.onDirectionChanged(Offset.zero);
  }
}

class _DirectionIndicatorPainter extends CustomPainter {
  final Color color;

  _DirectionIndicatorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final arrowSize = size.width * 0.15;

    _drawArrow(canvas, center, -pi / 2, arrowSize, paint);
    _drawArrow(canvas, center, pi / 2, arrowSize, paint);
    _drawArrow(canvas, center, pi, arrowSize, paint);
    _drawArrow(canvas, center, 0, arrowSize, paint);
  }

  void _drawArrow(
      Canvas canvas, Offset center, double angle, double size, Paint paint) {
    final distance = center.dx * 0.7;
    final tipX = center.dx + cos(angle) * distance;
    final tipY = center.dy + sin(angle) * distance;

    final path = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(tipX - cos(angle - 0.5) * size, tipY - sin(angle - 0.5) * size)
      ..lineTo(tipX - cos(angle + 0.5) * size, tipY - sin(angle + 0.5) * size)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

