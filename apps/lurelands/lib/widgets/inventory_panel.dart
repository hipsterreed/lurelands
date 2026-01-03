import 'package:flutter/material.dart';

import '../services/spacetimedb/stdb_service.dart';
import '../utils/constants.dart';

/// Inventory panel widget showing player's items grouped by type
class InventoryPanel extends StatelessWidget {
  final List<InventoryEntry> items;
  final VoidCallback onClose;

  const InventoryPanel({
    super.key,
    required this.items,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Group items by type
    final fishItems = items.where((e) => e.itemId.startsWith('fish_')).toList();
    final poleItems = items.where((e) => e.itemId.startsWith('pole_')).toList();
    final lureItems = items.where((e) => e.itemId.startsWith('lure_')).toList();

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent tap from closing panel
            child: Container(
              width: 340,
              constraints: const BoxConstraints(maxHeight: 500),
              decoration: BoxDecoration(
                color: GameColors.menuBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: GameColors.pondBlue.withAlpha(100),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(100),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  _buildHeader(),
                  // Content
                  Flexible(
                    child: items.isEmpty
                        ? _buildEmptyState()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (fishItems.isNotEmpty) ...[
                                  _buildSectionHeader('Fish', Icons.water),
                                  const SizedBox(height: 8),
                                  _buildItemGrid(fishItems),
                                  const SizedBox(height: 16),
                                ],
                                if (poleItems.isNotEmpty) ...[
                                  _buildSectionHeader('Fishing Rods', Icons.phishing),
                                  const SizedBox(height: 8),
                                  _buildItemGrid(poleItems),
                                  const SizedBox(height: 16),
                                ],
                                if (lureItems.isNotEmpty) ...[
                                  _buildSectionHeader('Lures', Icons.catching_pokemon),
                                  const SizedBox(height: 8),
                                  _buildItemGrid(lureItems),
                                ],
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: GameColors.menuAccent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.backpack,
            color: GameColors.pondBlue,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Inventory',
            style: TextStyle(
              color: GameColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Item count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: GameColors.pondBlue.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${items.fold<int>(0, (sum, e) => sum + e.quantity)} items',
              style: TextStyle(
                color: GameColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Close button
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close,
              color: GameColors.textSecondary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: GameColors.textSecondary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            'No items yet',
            style: TextStyle(
              color: GameColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Catch some fish to fill your inventory!',
            style: TextStyle(
              color: GameColors.textSecondary.withAlpha(150),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: GameColors.pondBlue,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: GameColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildItemGrid(List<InventoryEntry> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) => _InventoryItemTile(entry: item)).toList(),
    );
  }
}

/// Individual inventory item tile
class _InventoryItemTile extends StatelessWidget {
  final InventoryEntry entry;

  const _InventoryItemTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final itemDef = GameItems.get(entry.itemId);
    final isFish = entry.itemId.startsWith('fish_');

    return Tooltip(
      message: itemDef?.name ?? entry.itemId,
      child: Container(
        width: 72,
        height: 84,
        decoration: BoxDecoration(
          color: GameColors.menuAccent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getRarityColor(entry.rarity).withAlpha(100),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Item icon
            SizedBox(
              width: 40,
              height: 40,
              child: itemDef != null
                  ? Image.asset(
                      itemDef.assetPath,
                      errorBuilder: (_, __, ___) => Icon(
                        _getDefaultIcon(entry.itemId),
                        color: GameColors.pondBlue,
                        size: 28,
                      ),
                    )
                  : Icon(
                      _getDefaultIcon(entry.itemId),
                      color: GameColors.pondBlue,
                      size: 28,
                    ),
            ),
            const SizedBox(height: 4),
            // Stars (for fish)
            if (isFish && entry.rarity > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  entry.rarity,
                  (i) => Icon(
                    Icons.star,
                    size: 10,
                    color: _getRarityColor(entry.rarity),
                  ),
                ),
              ),
            // Quantity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: GameColors.pondBlue.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'x${entry.quantity}',
                style: TextStyle(
                  color: GameColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRarityColor(int rarity) {
    switch (rarity) {
      case 1:
        return Colors.grey;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.amber;
      default:
        return GameColors.textSecondary;
    }
  }

  IconData _getDefaultIcon(String itemId) {
    if (itemId.startsWith('fish_')) return Icons.water;
    if (itemId.startsWith('pole_')) return Icons.phishing;
    if (itemId.startsWith('lure_')) return Icons.catching_pokemon;
    return Icons.inventory_2;
  }
}

