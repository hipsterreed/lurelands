import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Shared color palette for all game panels
class PanelColors {
  PanelColors._();

  // Wood frame colors
  static const Color woodDark = Color(0xFF5D3A1A);
  static const Color woodMedium = Color(0xFF8B5A2B);
  static const Color woodLight = Color(0xFFA0724B);

  // Background colors
  static const Color panelBg = Color(0xFF2D1810);
  static const Color slotBg = Color(0xFF4A3728);
  static const Color slotBorder = Color(0xFF6B4423);
  static const Color slotHover = Color(0xFF5A4738);

  // Text colors
  static const Color textLight = Color(0xFFF5E6D3);
  static const Color textGold = Color(0xFFFFD700);
  static const Color textMuted = Color(0xFF8B7355);

  // Accent colors
  static const Color progressGreen = Color(0xFF4CAF50);
  static const Color star = Color(0xFFFFD700);
  static const Color divider = Color(0xFF6B4423);
}

/// Shared panel frame widget for consistent UI across all game panels
class GamePanelFrame extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onClose;
  final Widget child;
  final Widget? headerTrailing;

  const GamePanelFrame({
    super.key,
    required this.title,
    required this.icon,
    required this.onClose,
    required this.child,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final panelWidth = (screenSize.width * 0.95).clamp(500.0, 900.0);
    final panelHeight = (screenSize.height * 0.85).clamp(500.0, 700.0);

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withAlpha(150),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent tap from closing
            child: Container(
              width: panelWidth,
              height: panelHeight,
              decoration: _buildFrameDecoration(),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildFrameDecoration() {
    return BoxDecoration(
      color: PanelColors.panelBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: PanelColors.woodMedium, width: 6),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(220),
          blurRadius: 40,
          offset: const Offset(0, 20),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            PanelColors.woodDark,
            PanelColors.woodMedium,
            PanelColors.woodDark,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: const Border(
          bottom: BorderSide(color: PanelColors.woodLight, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PanelColors.slotBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: PanelColors.slotBorder, width: 2),
            ),
            child: Icon(
              icon,
              color: PanelColors.textGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          // Title
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: PanelColors.textLight,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          // Optional trailing widget
          if (headerTrailing != null) ...[
            headerTrailing!,
            const SizedBox(width: 12),
          ],
          // Close button
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PanelColors.slotBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: PanelColors.slotBorder, width: 2),
              ),
              child: const Icon(
                Icons.close,
                color: PanelColors.textLight,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Square tile for displaying rewards (gold, items, XP)
class RewardTile extends StatelessWidget {
  final IconData? icon;
  final String? assetPath;
  final String label;
  final String? sublabel;
  final double size;
  final Color? iconColor;

  const RewardTile({
    super.key,
    this.icon,
    this.assetPath,
    required this.label,
    this.sublabel,
    this.size = 64,
    this.iconColor,
  });

  /// Create a gold reward tile
  factory RewardTile.gold(int amount, {double size = 64}) {
    return RewardTile(
      icon: Icons.monetization_on,
      label: '$amount',
      sublabel: 'Gold',
      size: size,
      iconColor: PanelColors.textGold,
    );
  }

  /// Create an XP reward tile
  factory RewardTile.xp(int amount, {double size = 64}) {
    return RewardTile(
      icon: Icons.star,
      label: '$amount',
      sublabel: 'XP',
      size: size,
      iconColor: const Color(0xFF9C27B0),
    );
  }

  /// Create an item reward tile
  factory RewardTile.item({
    required String itemId,
    required int quantity,
    double size = 64,
  }) {
    final itemDef = GameItems.get(itemId);
    return RewardTile(
      assetPath: itemDef?.assetPath,
      icon: itemDef == null ? Icons.card_giftcard : null,
      label: 'x$quantity',
      sublabel: itemDef?.name ?? itemId,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size + 20, // Extra space for label
      decoration: BoxDecoration(
        color: PanelColors.slotBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: PanelColors.textGold.withAlpha(100),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon or image
          SizedBox(
            width: size * 0.5,
            height: size * 0.5,
            child: assetPath != null
                ? Image.asset(
                    assetPath!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.card_giftcard,
                      color: PanelColors.textLight,
                      size: size * 0.4,
                    ),
                  )
                : Icon(
                    icon ?? Icons.help,
                    color: iconColor ?? PanelColors.textLight,
                    size: size * 0.4,
                  ),
          ),
          const SizedBox(height: 4),
          // Label (quantity or amount)
          Text(
            label,
            style: TextStyle(
              color: iconColor ?? PanelColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Sublabel (item name or type)
          if (sublabel != null)
            Text(
              sublabel!,
              style: const TextStyle(
                color: PanelColors.textMuted,
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

/// A row of reward tiles
class RewardTilesRow extends StatelessWidget {
  final int? goldReward;
  final int? xpReward;
  final List<({String itemId, int quantity})> itemRewards;
  final double tileSize;

  const RewardTilesRow({
    super.key,
    this.goldReward,
    this.xpReward,
    this.itemRewards = const [],
    this.tileSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    if (goldReward != null && goldReward! > 0) {
      tiles.add(RewardTile.gold(goldReward!, size: tileSize));
    }

    if (xpReward != null && xpReward! > 0) {
      tiles.add(RewardTile.xp(xpReward!, size: tileSize));
    }

    for (final item in itemRewards) {
      tiles.add(RewardTile.item(
        itemId: item.itemId,
        quantity: item.quantity,
        size: tileSize,
      ));
    }

    if (tiles.isEmpty) {
      return const Text(
        'No rewards',
        style: TextStyle(color: PanelColors.textMuted, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tiles,
    );
  }
}
