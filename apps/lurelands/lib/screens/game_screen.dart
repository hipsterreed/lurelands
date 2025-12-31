import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/lurelands_game.dart';
import '../utils/constants.dart';

/// Screen that hosts the Flame GameWidget with mobile touch controls
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late LurelandsGame _game;

  @override
  void initState() {
    super.initState();
    _game = LurelandsGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Game canvas
          GameWidget(
            game: _game,
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

  Widget _buildLoadingScreen() {
    return Container(
      color: GameColors.menuBackground,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: GameColors.pondBlue,
            ),
            const SizedBox(height: 24),
            Text(
              'Loading world...',
              style: TextStyle(
                color: GameColors.textPrimary,
                fontSize: 18,
              ),
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
            Icon(
              Icons.error_outline,
              color: GameColors.playerDefault,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              'Error loading game',
              style: TextStyle(
                color: GameColors.textPrimary,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                color: GameColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD() {
    return Positioned(
      top: 16,
      left: 16,
      child: SafeArea(
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
    );
  }

  Widget _buildMobileControls() {
    return ValueListenableBuilder<bool>(
      valueListenable: _game.isLoadedNotifier,
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
                    _game.joystickDirection = Vector2(direction.dx, direction.dy);
                  },
                ),
              ),
              // Action buttons on the right
              Positioned(
                right: 30,
                bottom: 30,
                child: _buildActionButtons(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return ValueListenableBuilder<bool>(
      valueListenable: _game.canCastNotifier,
      builder: (context, canCast, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _game.isCastingNotifier,
          builder: (context, isCasting, _) {
            final isActive = canCast || isCasting;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cast/Reel button
                GestureDetector(
                  onTapDown: (_) {
                    if (isCasting) {
                      _game.onReelPressed();
                    } else {
                      _game.onCastPressed();
                    }
                  },
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
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        isCasting ? Icons.replay : Icons.phishing,
                        color: isActive
                            ? GameColors.textPrimary
                            : GameColors.textSecondary.withAlpha(128),
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isCasting
                      ? 'REEL'
                      : canCast
                          ? 'CAST'
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
          border: Border.all(
            color: GameColors.pondBlue.withAlpha(100),
            width: 2,
          ),
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
                  duration: _isDragging
                      ? Duration.zero
                      : const Duration(milliseconds: 100),
                  width: _knobRadius * 2,
                  height: _knobRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isDragging
                        ? GameColors.pondBlue
                        : GameColors.pondBlue.withAlpha(180),
                    border: Border.all(
                      color: GameColors.pondBlueLight,
                      width: 2,
                    ),
                    boxShadow: _isDragging
                        ? [
                            BoxShadow(
                              color: GameColors.pondBlue.withAlpha(100),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
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
      ..lineTo(
        tipX - cos(angle - 0.5) * size,
        tipY - sin(angle - 0.5) * size,
      )
      ..lineTo(
        tipX - cos(angle + 0.5) * size,
        tipY - sin(angle + 0.5) * size,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
