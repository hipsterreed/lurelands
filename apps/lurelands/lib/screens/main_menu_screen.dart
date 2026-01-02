import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../utils/constants.dart';
import 'game_screen.dart';

/// Main menu screen with "Enter World" button - mobile optimized
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();

    // Initialize name controller with current name
    _nameController.text = SettingsService.instance.playerName;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _enterWorld() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              GameColors.menuBackground,
              GameColors.menuAccent,
              GameColors.menuBackground.withAlpha(230),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Settings button (top right)
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  onPressed: _showSettingsDialog,
                  icon: Icon(
                    Icons.settings,
                    color: GameColors.textSecondary,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: GameColors.menuAccent.withAlpha(200),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              // Main content
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title
                      _buildTitle(),
                      const SizedBox(height: 16),
                      // Subtitle
                      _buildSubtitle(),
                      const SizedBox(height: 60),
                      // Enter World Button
                      _buildEnterButton(),
                      const SizedBox(height: 30),
                      // Version info
                      _buildVersionInfo(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          GameColors.pondBlueLight,
          GameColors.pondBlue,
          GameColors.grassGreenLight,
        ],
      ).createShader(bounds),
      child: const Text(
        'LURELANDS',
        style: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w900,
          letterSpacing: 8,
          color: Colors.white,
          shadows: [
            Shadow(
              offset: Offset(0, 4),
              blurRadius: 20,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Cast your line, discover the waters',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w300,
        letterSpacing: 3,
        color: GameColors.textSecondary,
      ),
    );
  }

  Widget _buildEnterButton() {
    return GestureDetector(
      onTap: _enterWorld,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
        decoration: BoxDecoration(
          color: GameColors.buttonPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: GameColors.pondBlue.withAlpha(128),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: GameColors.pondBlue.withAlpha(80),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.water,
              size: 28,
              color: GameColors.pondBlueLight,
            ),
            const SizedBox(width: 16),
            const Text(
              'ENTER WORLD',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Text(
      'v0.1.0 - Phase 1',
      style: TextStyle(
        fontSize: 11,
        color: GameColors.textSecondary.withAlpha(128),
      ),
    );
  }

  void _showSettingsDialog() {
    _nameController.text = SettingsService.instance.playerName;

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
            onPressed: () {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty) {
                SettingsService.instance.playerName = newName;
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
}
