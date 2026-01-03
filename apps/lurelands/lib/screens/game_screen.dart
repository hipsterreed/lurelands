import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/lurelands_game.dart';
import '../models/player_state.dart';
import '../services/game_settings.dart';
import '../services/spacetimedb/stdb_service.dart';
import '../utils/constants.dart';
import '../widgets/inventory_panel.dart';

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

    // Use BridgeSpacetimeDBService to connect via Bun/Elysia bridge
    _stdbService = BridgeSpacetimeDBService();

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
    
    // Subscribe to player updates to track gold
    _playerSubscription = _stdbService.playerUpdates.listen((players) {
      if (mounted) {
        // Find local player and update gold
        final localPlayer = players.where((p) => p.id == playerId).firstOrNull;
        if (localPlayer != null && localPlayer.gold != _playerGold) {
          setState(() {
            _playerGold = localPlayer.gold;
          });
        }
      }
    });
    
    // Initialize inventory from current state
    _inventoryItems = _stdbService.inventory;

    setState(() {
      _isConnecting = false;
      _game = LurelandsGame(
        stdbService: _stdbService,
        playerId: playerId,
        playerName: playerName,
        playerColor: playerColor,
      );
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
              onClose: () => setState(() => _showInventory = false),
            ),
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
        // Show "CAUGHT!" message
        if (state == FishingState.caught) {
          return _buildCaughtMessage();
        }

        // Show "ESCAPED" message
        if (state == FishingState.escaped) {
          return _buildEscapedMessage();
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCaughtMessage() {
    return ValueListenableBuilder<HookedFish?>(
      valueListenable: _game!.hookedFishNotifier,
      builder: (context, fish, _) {
        return Positioned.fill(
          child: Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (fish != null)
                    Image.asset(
                      fish.assetPath,
                      width: 120,
                      height: 120,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.catching_pokemon,
                        size: 80,
                        color: GameColors.progressGreen,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: GameColors.progressGreen.withAlpha(230),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'CAUGHT!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
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
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error icon with pulsing animation
                Container(
                  width: 120,
                  height: 120,
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
                    size: 64,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Cannot Connect to Server',
                  style: TextStyle(
                    color: GameColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'The game server is not available.\nPlease check your connection and try again.',
                  style: TextStyle(
                    color: GameColors.textSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: GameColors.menuAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _bridgeUrl,
                    style: TextStyle(
                      color: GameColors.textSecondary.withAlpha(180),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Retry button
                SizedBox(
                  width: 220,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _retryConnection,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      'Retry Connection',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GameColors.pondBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Back to menu button
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: GameColors.textSecondary,
                    size: 20,
                  ),
                  label: Text(
                    'Back to Menu',
                    style: TextStyle(
                      color: GameColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
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
          // Menu button (top left)
          Positioned(
            top: 16,
            left: 16,
            child: PopupMenuButton<String>(
              color: GameColors.menuBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: GameColors.pondBlue.withAlpha(80),
                  width: 1,
                ),
              ),
              onSelected: (value) {
                if (value == 'settings') {
                  _showSettingsDialog();
                } else if (value == 'exit') {
                  _showExitDialog();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: GameColors.textPrimary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Settings',
                        style: TextStyle(color: GameColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'exit',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: GameColors.textPrimary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Exit',
                        style: TextStyle(color: GameColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
              child: Container(
                decoration: BoxDecoration(
                  color: GameColors.menuBackground.withAlpha(179),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.menu,
                  color: GameColors.textPrimary.withAlpha(204),
                  size: 28,
                ),
              ),
            ),
          ),
          // Inventory button (top right, before debug)
          Positioned(
            top: 16,
            right: 72,
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
          // Debug button (top right)
          Positioned(
            top: 16,
            right: 16,
            child: ValueListenableBuilder<bool>(
              valueListenable: _game!.debugModeNotifier,
              builder: (context, debugEnabled, _) {
                return IconButton(
                  onPressed: () => _game!.toggleDebugMode(),
                  icon: Icon(
                    Icons.bug_report,
                    color: debugEnabled
                        ? Colors.yellow
                        : GameColors.textPrimary.withAlpha(204),
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: debugEnabled
                        ? GameColors.pondBlue.withAlpha(200)
                        : GameColors.menuBackground.withAlpha(179),
                    padding: const EdgeInsets.all(12),
                  ),
                );
              },
            ),
          ),
        ],
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
            // Hide during minigame or result states
            if (fishingState == FishingState.minigame ||
                fishingState == FishingState.caught ||
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

        return ValueListenableBuilder<bool>(
          valueListenable: _game!.canCastNotifier,
          builder: (context, canCast, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: _game!.isCastingNotifier,
              builder: (context, isCasting, _) {
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
                              final poleTier = _game!.player?.equippedPoleTier ?? 1;
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

  void _showSettingsDialog() {
    // Get current player name from game
    final currentName = _game?.playerName ?? widget.playerName;
    _nameController.text = currentName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GameColors.menuBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: GameColors.pondBlue.withAlpha(80),
            width: 2,
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.settings, color: GameColors.pondBlue, size: 24),
            const SizedBox(width: 12),
            Text(
              'Settings',
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
              'Player Name',
              style: TextStyle(
                color: GameColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 16,
              style: TextStyle(color: GameColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter your name...',
                hintStyle: TextStyle(
                  color: GameColors.textSecondary.withAlpha(128),
                ),
                counterStyle: TextStyle(
                  color: GameColors.textSecondary.withAlpha(128),
                  fontSize: 10,
                ),
                filled: true,
                fillColor: GameColors.menuAccent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: GameColors.pondBlue,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: GameColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty && _game != null) {
                // Save to local settings
                await GameSettings.instance.setPlayerName(newName);
                // Update name in database
                _stdbService.updatePlayerName(newName);
                debugPrint('[GameScreen] Updated player name to: "$newName"');
              }
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.pondBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GameColors.menuBackground,
        title: Text(
          'Leave World?',
          style: TextStyle(color: GameColors.textPrimary),
        ),
        content: Text(
          'Return to the main menu?',
          style: TextStyle(color: GameColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Stay',
              style: TextStyle(color: GameColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.buttonPrimary,
            ),
            child: Text(
              'Leave',
              style: TextStyle(color: GameColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fishing minigame overlay - Stardew Valley style
class FishingMinigameOverlay extends StatefulWidget {
  final HookedFish fish;
  final VoidCallback onCaught;
  final VoidCallback onEscaped;

  const FishingMinigameOverlay({
    super.key,
    required this.fish,
    required this.onCaught,
    required this.onEscaped,
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
    final tierIndex = widget.fish.tier - 1;
    _fishSpeed = GameConstants.fishSpeedByTier[tierIndex];
    _barSize = GameConstants.barSizeByTier[tierIndex];
    _totalTime = GameConstants.minigameTimeoutByTier[tierIndex];
    _timeRemaining = _totalTime;

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
    // Apply gravity
    _barVelocity -= GameConstants.minigameBarGravity * dt / meterHeight;
    
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
                // Fish
                _buildFish(),
                // Control bar (green rectangle)
                _buildControlBar(),
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
    return Positioned(
      left: (meterWidth - 32) / 2,
      top: fishY,
      child: Image.asset(
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
