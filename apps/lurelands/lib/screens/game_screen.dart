import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/lurelands_game.dart';
import '../services/spacetimedb/stdb_service.dart';
import '../utils/constants.dart';

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

  // Connection state (unused but kept for potential future use)
  // ignore: unused_field
  StdbConnectionState _connectionState = StdbConnectionState.disconnected;
  bool _isConnecting = true;
  String? _connectionError;

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
      _createGame();
    } else {
      // Connection failed - show error screen
      debugPrint('[GameScreen] Connection FAILED');
      setState(() {
        _isConnecting = false;
        _connectionError = 'Could not connect to server at $_bridgeUrl';
      });
    }
  }

  void _createGame() {
    // Generate a unique player ID (in production, use proper auth)
    final playerId = 'player_${DateTime.now().millisecondsSinceEpoch}';

    // Use player name passed from main menu (will be saved to DB when joining)
    final playerName = widget.playerName;
    debugPrint('[GameScreen] Creating game with playerName: "$playerName"');

    setState(() {
      _isConnecting = false;
      _game = LurelandsGame(
        stdbService: _stdbService,
        playerId: playerId,
        playerName: playerName,
        playerColor: 0xFFE74C3C,
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
    _stdbService.dispose();
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
        ],
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
            child: IconButton(
              onPressed: () => _showExitDialog(),
              icon: Icon(
                Icons.menu,
                color: GameColors.textPrimary.withAlpha(204),
                size: 28,
              ),
              style: IconButton.styleFrom(
                backgroundColor: GameColors.menuBackground.withAlpha(179),
                padding: const EdgeInsets.all(12),
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

        return SafeArea(
          child: Stack(
            children: [
              // Virtual joystick on the left
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
  }

  Widget _buildActionButtons() {
    if (_game == null) return const SizedBox.shrink();

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
