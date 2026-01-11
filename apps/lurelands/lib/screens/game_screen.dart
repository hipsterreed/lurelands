import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/lurelands_game.dart';
import '../models/player_state.dart';
import '../services/game_settings.dart';
import '../services/item_service.dart';
import '../services/spacetimedb/stdb_service.dart';
import '../utils/constants.dart';
import '../widgets/inventory_panel.dart';
import '../widgets/quest_dialog.dart';
import '../widgets/quest_panel.dart';
import '../widgets/shop_panel.dart';
import '../game/components/quest_sign.dart';
import '../game/components/shop.dart';

/// Bridge server URL (Bun/Elysia bridge to SpacetimeDB)
const String _bridgeUrl = 'wss://api.lurelands.com/ws';

/// Screen that hosts the Flame GameWidget with mobile touch controls
class GameScreen extends StatefulWidget {
  final String playerName;
  
  const GameScreen({super.key, this.playerName = 'Fisher'});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  LurelandsGame? _game;
  late SpacetimeDBService _stdbService;
  StreamSubscription<StdbConnectionState>? _connectionSubscription;
  StreamSubscription<List<InventoryEntry>>? _inventorySubscription;
  StreamSubscription<List<PlayerState>>? _playerSubscription;
  VoidCallback? _shopNotifierListener;
  final TextEditingController _nameController = TextEditingController();

  // Connection state (unused but kept for potential future use)
  // ignore: unused_field
  StdbConnectionState _connectionState = StdbConnectionState.disconnected;
  bool _isConnecting = true;
  String? _connectionError;
  
  // Inventory state
  bool _showInventory = false;
  List<InventoryEntry> _inventoryItems = [];
  int _playerGold = 0;
  String? _equippedPoleId; // Currently equipped fishing pole
  
  // Shop state
  bool _showShop = false;
  Shop? _nearbyShop;
  
  // Quest state
  bool _showQuestPanel = false;
  bool _showQuestDialog = false;
  QuestSign? _nearbyQuestSign;
  List<Quest> _quests = [];
  List<PlayerQuest> _playerQuests = [];
  VoidCallback? _questSignNotifierListener;
  StreamSubscription<({List<Quest> quests, List<PlayerQuest> playerQuests})>? _questSubscription;

  // Player stats (level/XP)
  PlayerStats? _playerStats;
  StreamSubscription<PlayerStats>? _playerStatsSubscription;
  StreamSubscription<LevelUpEvent>? _levelUpSubscription;
  bool _showLevelUpNotification = false;
  int _levelUpNewLevel = 1;

  @override
  void initState() {
    super.initState();
    _initializeConnection();
  }

  Future<void> _initializeConnection() async {
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    // Load item definitions from API before connecting
    final httpUrl = _wsUrlToHttpUrl(_bridgeUrl);
    final itemsLoaded = await ItemService.instance.loadItems(httpUrl);

    // Check if items loaded successfully - show error if items are missing
    if (!itemsLoaded && ItemService.instance.missingItems.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _connectionError = 'Missing items in database:\n${ItemService.instance.missingItems.join(", ")}';
      });
      return;
    }

    // Use BridgeSpacetimeDBService to connect via Bun/Elysia bridge
    _stdbService = BridgeSpacetimeDBService();

    // Health check - verify bridge is healthy and SpacetimeDB is connected
    debugPrint('[GameScreen] Performing health check...');
    final healthResult = await _stdbService.checkHealth(_bridgeUrl);

    if (!healthResult.healthy) {
      if (!mounted) return;
      final errorMsg = healthResult.spacetimedb == 'disconnected'
          ? 'Server database is disconnected. Please try again later.'
          : healthResult.spacetimedb == 'unreachable'
              ? 'Could not reach server. Check your internet connection.'
              : 'Server is experiencing issues (${healthResult.status})';
      setState(() {
        _isConnecting = false;
        _connectionError = errorMsg;
      });
      return;
    }
    debugPrint('[GameScreen] Health check passed!');

    // Listen to connection state changes
    _connectionSubscription = _stdbService.connectionStateStream.listen((state) {
      debugPrint('[GameScreen] Connection state: $state');
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }
    });

    debugPrint('[GameScreen] Connecting to bridge at: $_bridgeUrl');

    // Attempt to connect to bridge
    final connected = await _stdbService.connect(_bridgeUrl);
    
    debugPrint('[GameScreen] Connection result: $connected');

    if (!mounted) return;

    if (connected) {
      // Successfully connected - create the game
      debugPrint('[GameScreen] Connected! Creating game...');
      await _createGame();
    } else {
      // Connection failed - show error screen
      debugPrint('[GameScreen] Connection FAILED');
      setState(() {
        _isConnecting = false;
        _connectionError = 'Could not connect to server at $_bridgeUrl';
      });
    }
  }

  /// Convert WebSocket URL to HTTP URL for API calls
  String _wsUrlToHttpUrl(String wsUrl) {
    return wsUrl
        .replaceFirst('wss://', 'https://')
        .replaceFirst('ws://', 'http://')
        .replaceFirst('/ws', '');
  }

  Future<void> _createGame() async {
    final settings = GameSettings.instance;
    
    // Get player data from centralized settings
    final playerId = await settings.getPlayerId();
    final playerColor = await settings.getPlayerColor();

    // Use player name passed from main menu (will be saved to DB when joining)
    final playerName = widget.playerName;
    debugPrint('[GameScreen] Creating game with playerId: "$playerId", playerName: "$playerName"');

    // Subscribe to inventory updates
    _inventorySubscription = _stdbService.inventoryUpdates.listen((items) {
      if (mounted) {
        setState(() {
          _inventoryItems = items;
        });
      }
    });
    
    // Subscribe to player updates to track gold and equipped pole
    _playerSubscription = _stdbService.playerUpdates.listen((players) {
      if (mounted) {
        // Find local player and update state
        final localPlayer = players.where((p) => p.id == playerId).firstOrNull;
        if (localPlayer != null) {
          bool needsUpdate = false;
          if (localPlayer.gold != _playerGold) {
            _playerGold = localPlayer.gold;
            needsUpdate = true;
          }
          if (localPlayer.equippedPoleId != _equippedPoleId) {
            _equippedPoleId = localPlayer.equippedPoleId;
            needsUpdate = true;
            
            // Sync the equipped pole tier to the game's Player component
            // This affects cast distance and pole sprite
            if (_game?.player != null) {
              _game!.player!.equippedPoleTier = localPlayer.equippedPoleTier;
            }
          }
          if (needsUpdate) {
            setState(() {});
          }
        }
      }
    });
    
    // Initialize inventory from current state
    _inventoryItems = _stdbService.inventory;

    final game = LurelandsGame(
      stdbService: _stdbService,
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
    
    // Subscribe to quest updates
    _questSubscription = _stdbService.questUpdates.listen((data) {
      if (mounted) {
        setState(() {
          _quests = data.quests;
          _playerQuests = data.playerQuests;
        });
        // Update quest sign indicators
        _updateQuestSignIndicators();
      }
    });

    // Subscribe to player stats updates (level/XP)
    _playerStatsSubscription = _stdbService.playerStatsStream.listen((stats) {
      if (mounted) {
        setState(() {
          _playerStats = stats;
        });
      }
    });

    // Subscribe to level up events for notifications
    _levelUpSubscription = _stdbService.levelUpStream.listen((event) {
      if (mounted) {
        setState(() {
          _showLevelUpNotification = true;
          _levelUpNewLevel = event.newLevel;
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

    // Initialize with current data
    _quests = _stdbService.quests;
    _playerQuests = _stdbService.playerQuests;
    _playerStats = _stdbService.playerStats;

    setState(() {
      _isConnecting = false;
      _game = game;
    });
    
    // Update quest sign indicators with initial data
    // Need to delay slightly to ensure game world is loaded
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _updateQuestSignIndicators();
    });
  }

  Future<void> _retryConnection() async {
    // Dispose old service
    _stdbService.dispose();
    _connectionSubscription?.cancel();

    // Try again
    await _initializeConnection();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _inventorySubscription?.cancel();
    _playerSubscription?.cancel();
    _questSubscription?.cancel();
    _playerStatsSubscription?.cancel();
    _levelUpSubscription?.cancel();
    if (_shopNotifierListener != null && _game != null) {
      _game!.nearbyShopNotifier.removeListener(_shopNotifierListener!);
    }
    if (_questSignNotifierListener != null && _game != null) {
      _game!.nearbyQuestSignNotifier.removeListener(_questSignNotifierListener!);
    }
    _stdbService.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show connecting screen
    if (_isConnecting) {
      return Scaffold(
        body: _buildConnectingScreen(),
      );
    }

    // Show connection error screen
    if (_connectionError != null || _game == null) {
      return Scaffold(
        body: _buildConnectionErrorScreen(),
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
            errorBuilder: (context, error) => _buildErrorScreen(error),
          ),
          // Mobile controls overlay
          _buildMobileControls(),
          // HUD overlay
          _buildHUD(),
          // Fishing minigame overlay
          _buildFishingMinigameOverlay(),
          // Fishing state messages (bite alert, caught, escaped)
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
                setState(() {}); // Refresh to show debug state
              },
              onUpdatePlayerName: (newName) async {
                await GameSettings.instance.setPlayerName(newName);
                _stdbService.updatePlayerName(newName);
              },
              equippedPoleId: _equippedPoleId,
              onEquipPole: (poleItemId) {
                _stdbService.equipPole(poleItemId);
              },
              onUnequipPole: () {
                _stdbService.unequipPole();
              },
              onResetGold: () {
                _stdbService.setGold(0);
                setState(() {
                  _playerGold = 0;
                });
              },
              onResetPosition: () {
                _game?.resetPlayerPosition();
                setState(() => _showInventory = false);
              },
              onResetQuests: () {
                _stdbService.resetAllQuests();
                setState(() {
                  _playerQuests = [];
                });
              },
              onExitToMenu: () {
                setState(() => _showInventory = false);
                Navigator.of(context).pushReplacementNamed('/');
              },
              quests: _quests,
              playerQuests: _playerQuests,
              onAcceptQuest: _onAcceptQuest,
              onCompleteQuest: _onCompleteQuest,
              playerLevel: _playerStats?.level ?? 1,
              playerXp: _playerStats?.xp ?? 0,
              playerXpToNextLevel: _playerStats?.xpToNextLevel ?? 100,
            ),
          // Shop panel overlay
          if (_showShop && _nearbyShop != null)
            ShopPanel(
              // Filter out equipped items - they shouldn't be sellable while equipped
              playerItems: _equippedPoleId == null
                  ? _inventoryItems
                  : _inventoryItems.where((item) => item.itemId != _equippedPoleId).toList(),
              playerGold: _playerGold,
              shopName: _nearbyShop!.name,
              onClose: () => setState(() => _showShop = false),
              onSellItem: _onSellItem,
              onBuyItem: _onBuyItem,
            ),
          // Shop interaction button (when near shop)
          if (_nearbyShop != null && !_showShop && !_showInventory && !_showQuestPanel)
            _buildShopButton(),
          // Quest panel overlay (full quest journal or sign-filtered view)
          if (_showQuestPanel)
            QuestPanel(
              quests: _quests,
              playerQuests: _playerQuests,
              onClose: () => setState(() => _showQuestPanel = false),
              onAcceptQuest: _onAcceptQuest,
              onCompleteQuest: _onCompleteQuest,
              signId: _nearbyQuestSign?.id,
              signName: _nearbyQuestSign?.name,
              storylines: _nearbyQuestSign?.storylines,
            ),
          // Quest dialog overlay (WoW-style) - only for new quests
          if (_showQuestDialog && _nearbyQuestSign != null)
            Builder(
              builder: (context) {
                final questToShow = QuestSignHelper.getQuestToShow(
                  allQuests: _quests,
                  playerQuests: _playerQuests,
                  signId: _nearbyQuestSign!.id,
                  storylines: _nearbyQuestSign!.storylines,
                );
                
                if (questToShow == null) {
                  // No quests available - close dialog
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _showQuestDialog = false);
                  });
                  return const SizedBox.shrink();
                }
                
                final playerQuest = _playerQuests
                    .where((pq) => pq.questId == questToShow.id)
                    .firstOrNull;
                
                // Only show dialog for new/available quests, not active ones
                if (playerQuest?.isActive == true) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _showQuestDialog = false;
                        _showQuestPanel = true;
                      });
                    }
                  });
                  return const SizedBox.shrink();
                }
                
                return QuestOfferDialog(
                  quest: questToShow,
                  playerQuest: playerQuest,
                  signName: _nearbyQuestSign!.name,
                  onClose: () => setState(() => _showQuestDialog = false),
                  onAccept: () {
                    _onAcceptQuest(questToShow.id);
                    // Close after accepting - player can view in backpack
                    setState(() => _showQuestDialog = false);
                  },
                  onComplete: (playerQuest?.isActive ?? false) && 
                              playerQuest!.areRequirementsMet(questToShow)
                      ? () {
                          _onCompleteQuest(questToShow.id);
                          // Stay open to show next quest or close if none
                        }
                      : null,
                );
              },
            ),
          // Quest sign interaction button (when near quest sign with available, completable, or active quests)
          if (_nearbyQuestSign != null && !_showQuestPanel && !_showQuestDialog && !_showInventory && !_showShop &&
              (QuestSignHelper.hasAvailableOrCompletableQuests(
                allQuests: _quests,
                playerQuests: _playerQuests,
                signId: _nearbyQuestSign!.id,
                storylines: _nearbyQuestSign!.storylines,
              ) ||
              QuestSignHelper.hasActiveQuest(
                allQuests: _quests,
                playerQuests: _playerQuests,
                signId: _nearbyQuestSign!.id,
                storylines: _nearbyQuestSign!.storylines,
              )))
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
        // Show "ESCAPED" message only - caught state just shows the fish animation
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

  Widget _buildConnectingScreen() {
    return Container(
      color: GameColors.menuBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated fishing pole icon
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
              onEnd: () {},
              child: Icon(
                Icons.phishing,
                color: GameColors.pondBlue,
                size: 80,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Connecting to Server...',
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
            const SizedBox(height: 24),
            Text(
              _bridgeUrl,
              style: TextStyle(
                color: GameColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionErrorScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GameColors.menuBackground,
            const Color(0xFF0D1117),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left side - Error icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GameColors.playerDefault.withAlpha(30),
                    border: Border.all(
                      color: GameColors.playerDefault.withAlpha(100),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    color: GameColors.playerDefault,
                    size: 48,
                  ),
                ),
                const SizedBox(width: 40),
                // Right side - Text and buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cannot Connect to Server',
                      style: TextStyle(
                        color: GameColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The game server is not available.\nPlease check your connection and try again.',
                      style: TextStyle(
                        color: GameColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: GameColors.menuAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _bridgeUrl,
                        style: TextStyle(
                          color: GameColors.textSecondary.withAlpha(180),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Buttons row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: _retryConnection,
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            label: const Text(
                              'Retry Connection',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GameColors.pondBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed('/');
                          },
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: GameColors.textSecondary,
                            size: 18,
                          ),
                          label: Text(
                            'Back to Menu',
                            style: TextStyle(
                              color: GameColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
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
            CircularProgressIndicator(color: GameColors.pondBlue),
            const SizedBox(height: 24),
            Text(
              'Loading world...',
              style: TextStyle(color: GameColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(Object error) {
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
            Text(
              error.toString(),
              style: TextStyle(color: GameColors.textSecondary, fontSize: 14),
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
          // Connection quality indicator (top left)
          Positioned(
            top: 16,
            left: 16,
            child: _buildConnectionIndicator(),
          ),
          // Level up notification (center top)
          if (_showLevelUpNotification)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: _buildLevelUpNotification(),
            ),
          // Inventory/Backpack button (top right)
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
                    // Item count badge
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

  /// Build connection quality indicator
  Widget _buildConnectionIndicator() {
    return StreamBuilder<ConnectionQuality>(
      stream: _stdbService.connectionQualityStream,
      initialData: _stdbService.connectionQuality,
      builder: (context, snapshot) {
        final quality = snapshot.data ?? ConnectionQuality.excellent;

        // Only show if not excellent (don't clutter good connections)
        if (quality == ConnectionQuality.excellent) {
          return const SizedBox.shrink();
        }

        final (icon, color, label) = switch (quality) {
          ConnectionQuality.excellent => (Icons.signal_cellular_4_bar, Colors.green, 'Excellent'),
          ConnectionQuality.good => (Icons.signal_cellular_4_bar, Colors.green, 'Good'),
          ConnectionQuality.fair => (Icons.signal_cellular_alt, Colors.yellow, 'Fair'),
          ConnectionQuality.poor => (Icons.signal_cellular_alt_2_bar, Colors.orange, 'Poor'),
          ConnectionQuality.critical => (Icons.signal_cellular_0_bar, Colors.red, 'Poor Connection'),
        };

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: GameColors.menuBackground.withAlpha(180),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              if (quality == ConnectionQuality.poor || quality == ConnectionQuality.critical)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontSize: 10),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Build level up notification toast
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
              BoxShadow(
                color: Colors.black.withAlpha(150),
                blurRadius: 8,
                offset: const Offset(0, 4),
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

        // Hide controls during minigame (it handles its own input)
        return ValueListenableBuilder<FishingState>(
          valueListenable: _game!.fishingStateNotifier,
          builder: (context, fishingState, _) {
            // Hide during minigame or escaped states (allow movement during caught)
            if (fishingState == FishingState.minigame ||
                fishingState == FishingState.escaped) {
              return const SizedBox.shrink();
            }

            return SafeArea(
              child: Stack(
                children: [
                  // Virtual joystick on the left (hide during bite)
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
                  // Action buttons on the right
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
        // Special pulsing button during bite
        if (fishingState == FishingState.bite) {
          return _buildBiteTapButton();
        }

        // Check if player has a pole equipped
        final hasPoleEquipped = _equippedPoleId != null;

        return ValueListenableBuilder<bool>(
          valueListenable: _game!.canCastNotifier,
          builder: (context, canCast, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: _game!.isCastingNotifier,
              builder: (context, isCasting, _) {
                // If no pole equipped, show disabled state
                if (!hasPoleEquipped) {
                  return _buildNoPoleButton();
                }

                final isActive = canCast || isCasting;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cast/Reel button
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
                              // Use cached _equippedPoleId to derive tier, avoiding flicker
                              // from server broadcast timing during walking
                              int poleTier = 1;
                              if (_equippedPoleId != null && _equippedPoleId!.startsWith('pole_')) {
                                poleTier = int.tryParse(_equippedPoleId!.split('_').last) ?? 1;
                              }
                              final poleAsset = ItemAssets.getFishingPole(poleTier);
                              final imagePath =
                                  isCasting ? poleAsset.casted : poleAsset.normal;
                              return Image.asset(
                                imagePath,
                                width: 40,
                                height: 40,
                                opacity: AlwaysStoppedAnimation(isActive ? 1.0 : 0.5),
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

  /// Build the cast button when no fishing pole is equipped
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
                  // Faded pole icon
                  Icon(
                    Icons.phishing,
                    size: 36,
                    color: GameColors.textSecondary.withAlpha(100),
                  ),
                  // Red X overlay
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

  /// Show a message when the player tries to fish without a pole
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
                      "If you lost yours, you can get a free one from the shop!",
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
        // Pulsing tap button
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
              child: Center(
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
            shadows: [
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

  /// Build the shop interaction button (appears when near a shop)
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

  /// Build the quest sign interaction button (appears when near a quest sign)
  Widget _buildQuestSignButton() {
    // Check if there's a quest ready to turn in (filtered by this sign's id and storylines)
    final hasCompletable = QuestSignHelper.hasCompletableQuest(
      allQuests: _quests,
      playerQuests: _playerQuests,
      signId: _nearbyQuestSign?.id,
      storylines: _nearbyQuestSign?.storylines,
    );
    final hasAvailable = QuestSignHelper.hasAvailableOrCompletableQuests(
      allQuests: _quests,
      playerQuests: _playerQuests,
      signId: _nearbyQuestSign?.id,
      storylines: _nearbyQuestSign?.storylines,
    );
    final hasActive = QuestSignHelper.hasActiveQuest(
      allQuests: _quests,
      playerQuests: _playerQuests,
      signId: _nearbyQuestSign?.id,
      storylines: _nearbyQuestSign?.storylines,
    );
    
    // Colors based on quest state (priority: completable > available > active)
    final Color buttonColor;
    final String buttonText;
    final IconData buttonIcon;
    
    if (hasCompletable) {
      buttonColor = const Color(0xFF4CAF50);  // Green for turn-in
      buttonText = 'TURN IN QUEST';
      buttonIcon = Icons.check_circle;
    } else if (hasAvailable) {
      buttonColor = const Color(0xFFFFD700); // Gold for new quest
      buttonText = 'NEW QUEST!';
      buttonIcon = Icons.priority_high;
    } else if (hasActive) {
      buttonColor = const Color(0xFF888888); // Gray for in-progress
      buttonText = 'VIEW QUEST';
      buttonIcon = Icons.assignment;
    } else {
      buttonColor = const Color(0xFF888888);
      buttonText = 'VIEW QUESTS';
      buttonIcon = Icons.assignment;
    }
    
    return Positioned(
      bottom: 160,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            // Always show the panel (list → details view)
            setState(() => _showQuestPanel = true);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: GameColors.menuBackground.withAlpha(230),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: buttonColor,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: buttonColor.withAlpha(100),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  buttonIcon,
                  color: buttonColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  buttonText,
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

  /// Handle accepting a quest
  void _onAcceptQuest(String questId) {
    _stdbService.acceptQuest(questId);
  }

  /// Handle completing a quest
  void _onCompleteQuest(String questId) {
    _stdbService.completeQuest(questId);
  }

  /// Update quest sign indicators based on current quest state
  void _updateQuestSignIndicators() {
    if (_game == null) return;

    _game!.updateQuestSignIndicators(
      allQuests: _quests,
      playerQuests: _playerQuests,
      hasCompletableCheck: ({
        required List<dynamic> allQuests,
        required List<dynamic> playerQuests,
        String? signId,
        List<String>? storylines,
      }) => QuestSignHelper.hasCompletableQuest(
        allQuests: allQuests.cast<Quest>(),
        playerQuests: playerQuests.cast<PlayerQuest>(),
        signId: signId,
        storylines: storylines,
      ),
      hasAvailableCheck: ({
        required List<dynamic> allQuests,
        required List<dynamic> playerQuests,
        String? signId,
        List<String>? storylines,
      }) => QuestSignHelper.hasAvailableOrCompletableQuests(
        allQuests: allQuests.cast<Quest>(),
        playerQuests: playerQuests.cast<PlayerQuest>(),
        signId: signId,
        storylines: storylines,
      ),
      hasActiveCheck: ({
        required List<dynamic> allQuests,
        required List<dynamic> playerQuests,
        String? signId,
        List<String>? storylines,
      }) => QuestSignHelper.hasActiveQuest(
        allQuests: allQuests.cast<Quest>(),
        playerQuests: playerQuests.cast<PlayerQuest>(),
        signId: signId,
        storylines: storylines,
      ),
    );
  }

  /// Handle selling an item
  void _onSellItem(InventoryEntry item, int quantity) {
    final itemDef = GameItems.get(item.itemId);
    if (itemDef == null) return;

    final sellPrice = itemDef.getSellPrice(item.rarity);
    final totalGold = sellPrice * quantity;

    debugPrint('[GameScreen] Selling ${item.itemId} x$quantity for ${totalGold}g');
    
    // Call the sell item method on the service
    _stdbService.sellItem(item.itemId, item.rarity, quantity);
    
    // Optimistically update local gold
    setState(() {
      _playerGold += totalGold;
    });
  }

  /// Handle buying an item from the shop
  void _onBuyItem(String itemId, int price) {
    if (_playerGold < price) {
      debugPrint('[GameScreen] Not enough gold to buy $itemId');
      return;
    }

    debugPrint('[GameScreen] Buying $itemId for ${price}g');
    
    // Call the buy item method on the service
    _stdbService.buyItem(itemId, price);
    
    // Optimistically update local gold
    setState(() {
      _playerGold -= price;
    });
  }
}

/// Fishing minigame overlay - Stardew Valley style
class FishingMinigameOverlay extends StatefulWidget {
  final HookedFish fish;
  final VoidCallback onCaught;
  final VoidCallback onEscaped;
  final int poleTier; // Equipped pole tier (1-4) affects control and bar size

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
  // Minigame dimensions
  static const double meterWidth = 60.0;
  static const double meterHeight = 320.0;
  static const double progressMeterWidth = 24.0;
  static const double frameThickness = 8.0;

  // Game state
  late double _fishPosition; // 0.0 (bottom) to 1.0 (top)
  late double _fishTarget;   // Where fish is moving to
  late double _fishVelocity;
  late double _barPosition;  // 0.0 (bottom) to 1.0 (top)
  late double _barVelocity;
  late double _progress;     // 0.0 to 1.0
  late double _barSize;      // As fraction of meter height
  late double _gravityMultiplier; // Pole tier bonus for control

  // Fish movement AI
  double _directionChangeTimer = 0.0;
  double _fishSpeed = 1.0;

  // Timeout timer
  late double _timeRemaining;
  late double _totalTime;

  // Animation
  late AnimationController _animController;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();

    // Initialize based on fish tier
    final fishTierIndex = widget.fish.tier - 1;
    _fishSpeed = GameConstants.fishSpeedByTier[fishTierIndex];
    _totalTime = GameConstants.minigameTimeoutByTier[fishTierIndex];
    _timeRemaining = _totalTime;
    
    // Calculate pole tier bonuses
    final poleTierIndex = (widget.poleTier - 1).clamp(0, 3);
    _gravityMultiplier = GameConstants.poleGravityMultiplier[poleTierIndex];
    
    // Bar size = base size (from fish tier) + pole bonus
    // Better poles give bigger bar, especially helpful for harder fish
    final baseBarSize = GameConstants.barSizeByTier[fishTierIndex];
    final poleBonus = GameConstants.poleBarSizeBonus[poleTierIndex];
    _barSize = baseBarSize + poleBonus;

    // Start positions
    _fishPosition = 0.5;
    _fishTarget = 0.5;
    _fishVelocity = 0.0;
    _barPosition = 0.3;
    _barVelocity = 0.0;
    _progress = GameConstants.minigameStartProgress;
    _directionChangeTimer = 0.5;

    // Start game loop
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1), // Runs indefinitely
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

    if (dt > 0.1) return; // Skip large dt (e.g., from background)

    setState(() {
      _updateFish(dt);
      _updateBar(dt);
      _updateProgress(dt);
      _updateTimeout(dt);
    });

    // Check win/lose conditions
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
    // Fish AI - periodically pick new target
    _directionChangeTimer -= dt;
    if (_directionChangeTimer <= 0) {
      // More frequent direction changes for harder fish
      _directionChangeTimer = 0.5 + (1.0 - _fishSpeed / 2.0) * Random().nextDouble();
      _fishTarget = Random().nextDouble();
    }

    // Move towards target with smooth acceleration
    final targetDiff = _fishTarget - _fishPosition;
    _fishVelocity += targetDiff * 8.0 * _fishSpeed * dt;
    _fishVelocity *= 0.95; // Damping
    _fishVelocity = _fishVelocity.clamp(-2.0 * _fishSpeed, 2.0 * _fishSpeed);
    
    _fishPosition += _fishVelocity * dt;
    _fishPosition = _fishPosition.clamp(0.0, 1.0);
  }

  void _updateBar(double dt) {
    // Apply gravity (higher tier poles = more gravity = more control)
    _barVelocity -= GameConstants.minigameBarGravity * _gravityMultiplier * dt / meterHeight;
    
    // Clamp velocity
    final maxVel = GameConstants.minigameBarMaxSpeed / meterHeight;
    _barVelocity = _barVelocity.clamp(-maxVel, maxVel);
    
    // Update position
    _barPosition += _barVelocity * dt;
    _barPosition = _barPosition.clamp(0.0, 1.0 - _barSize);
  }

  void _updateProgress(double dt) {
    // Check if bar overlaps fish
    final fishCenter = _fishPosition;
    final fishHalfSize = 0.08; // Fish hitbox size as fraction
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
    // Boost bar upward
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
                // Timer display
                _buildTimerDisplay(),
                const SizedBox(height: 16),
                // Meters row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Main fishing meter
                    _buildFishingMeter(),
                    const SizedBox(width: 12),
                    // Progress meter
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
    
    // Color changes as time runs low
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
        // Time text
        Text(
          '${seconds}s',
          style: TextStyle(
            color: timerColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Timer bar
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
                // Water bubbles/decoration
                ..._buildWaterDecorations(),
                // Control bar (green rectangle)
                _buildControlBar(),
                // Fish (on top so it's visible over the bar)
                _buildFish(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildWaterDecorations() {
    // Simple animated bubbles
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
    // Map tier to star rarity: tier 1-2 = 1 star, tier 3 = 2 stars, tier 4 = 3 stars
    final rarity = widget.fish.tier <= 2 ? 1 : (widget.fish.tier == 3 ? 2 : 3);
    
    return Positioned(
      left: (meterWidth - 32) / 2,
      top: fishY,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stars above the fish
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
          // Fish image
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
    // Color interpolation based on progress
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
            // Direction indicators
            _buildDirectionIndicators(),
            // Knob
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

    // Clamp to max distance
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

    // Normalize direction to 0-1 range
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

/// Painter for direction indicators on joystick
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

    // Up arrow
    _drawArrow(canvas, center, -pi / 2, arrowSize, paint);
    // Down arrow
    _drawArrow(canvas, center, pi / 2, arrowSize, paint);
    // Left arrow
    _drawArrow(canvas, center, pi, arrowSize, paint);
    // Right arrow
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
