import 'package:flutter/material.dart';

import '../services/game_settings.dart';
import '../widgets/panel_frame.dart';
import 'game_screen.dart';

/// Main menu screen with "Enter World" button - mobile optimized
/// Now uses local save only (no server connection)
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
  String _playerName = 'Fisher';
  bool _isLoadingPlayerData = true;

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
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoadingPlayerData = true;
    });

    final settings = GameSettings.instance;

    // Load player name from local settings
    _playerName = await settings.getPlayerName();
    debugPrint('[MainMenu] Loaded from local settings - Name: $_playerName');

    if (mounted) {
      setState(() {
        _isLoadingPlayerData = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _enterWorld() {
    print('[MainMenu] Entering world with playerName: "$_playerName"');
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GameScreen(playerName: _playerName),
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
    // Show loading screen while fetching player data
    if (_isLoadingPlayerData) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                PanelColors.woodDark,
                PanelColors.panelBg,
                PanelColors.woodDark,
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: PanelColors.textGold,
                ),
                SizedBox(height: 16),
                Text(
                  'Loading...',
                  style: TextStyle(
                    color: PanelColors.textLight,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PanelColors.woodDark,
              PanelColors.panelBg,
              PanelColors.woodDark,
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
                child: GestureDetector(
                  onTap: _showSettingsDialog,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PanelColors.slotBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: PanelColors.slotBorder,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: PanelColors.textLight,
                      size: 24,
                    ),
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
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          PanelColors.textGold,
          PanelColors.woodLight,
          PanelColors.textGold,
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
    return const Text(
      'Cast your line, discover the waters',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w300,
        letterSpacing: 3,
        color: PanelColors.textMuted,
      ),
    );
  }

  Widget _buildEnterButton() {
    return GestureDetector(
      onTap: _enterWorld,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              PanelColors.woodDark,
              PanelColors.woodMedium,
              PanelColors.woodDark,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: PanelColors.textGold.withAlpha(180),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: PanelColors.textGold.withAlpha(60),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.water,
              size: 28,
              color: PanelColors.textGold,
            ),
            SizedBox(width: 16),
            Text(
              'ENTER WORLD',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
                color: PanelColors.textLight,
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
        color: PanelColors.textMuted.withAlpha(150),
      ),
    );
  }

  void _showSettingsDialog() {
    _nameController.text = _playerName;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: PanelColors.panelBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: PanelColors.woodMedium,
            width: 4,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: PanelColors.slotBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: PanelColors.slotBorder, width: 2),
              ),
              child: const Icon(Icons.settings, color: PanelColors.textGold, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Settings',
              style: TextStyle(
                color: PanelColors.textLight,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Player Name',
              style: TextStyle(
                color: PanelColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 16,
              style: const TextStyle(color: PanelColors.textLight),
              decoration: InputDecoration(
                hintText: 'Enter your name...',
                hintStyle: TextStyle(
                  color: PanelColors.textMuted.withAlpha(150),
                ),
                counterStyle: TextStyle(
                  color: PanelColors.textMuted.withAlpha(150),
                  fontSize: 10,
                ),
                filled: true,
                fillColor: PanelColors.slotBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: PanelColors.slotBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: PanelColors.slotBorder, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: PanelColors.textGold,
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: PanelColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _nameController.text.trim();
              debugPrint('[MainMenu] Settings save - newName: "$newName"');
              if (newName.isNotEmpty) {
                setState(() {
                  _playerName = newName;
                });

                // Save to local settings only (no server sync needed)
                await GameSettings.instance.setPlayerName(newName);
                debugPrint('[MainMenu] Settings save - name saved locally: "$newName"');
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PanelColors.woodMedium,
              foregroundColor: PanelColors.textLight,
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
