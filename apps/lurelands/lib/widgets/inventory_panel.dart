import 'package:flutter/material.dart';

import '../services/spacetimedb/stdb_service.dart';
import '../utils/constants.dart';

/// Stardew Valley-inspired inventory panel colors
class _InventoryColors {
  static const Color woodDark = Color(0xFF5D3A1A);
  static const Color woodMedium = Color(0xFF8B5A2B);
  static const Color woodLight = Color(0xFFA0724B);
  static const Color panelBg = Color(0xFF2D1810);
  static const Color slotBg = Color(0xFF4A3728);
  static const Color slotBorder = Color(0xFF6B4423);
  static const Color slotHighlight = Color(0xFF8B6914);
  static const Color textLight = Color(0xFFF5E6D3);
  static const Color textGold = Color(0xFFFFD700);
  static const Color star = Color(0xFFFFD700);
}

/// Tab types for inventory sections
enum _InventoryTab { all, fish, equipment }

/// Stardew Valley-inspired inventory panel
class InventoryPanel extends StatefulWidget {
  final List<InventoryEntry> items;
  final int playerGold;
  final VoidCallback onClose;

  const InventoryPanel({
    super.key,
    required this.items,
    required this.playerGold,
    required this.onClose,
  });

  @override
  State<InventoryPanel> createState() => _InventoryPanelState();
}

class _InventoryPanelState extends State<InventoryPanel> {
  _InventoryTab _currentTab = _InventoryTab.all;

  List<InventoryEntry> get _filteredItems {
    switch (_currentTab) {
      case _InventoryTab.all:
        return widget.items;
      case _InventoryTab.fish:
        return widget.items.where((e) => e.itemId.startsWith('fish_')).toList();
      case _InventoryTab.equipment:
        return widget.items.where((e) => 
          e.itemId.startsWith('pole_') || e.itemId.startsWith('lure_')
        ).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final panelWidth = (screenSize.width * 0.9).clamp(380.0, 560.0);
    final panelHeight = (screenSize.height * 0.8).clamp(450.0, 650.0);

    return GestureDetector(
      onTap: widget.onClose,
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
                  _buildTabBar(),
                  Expanded(child: _buildItemGrid()),
                  _buildFooter(),
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
      color: _InventoryColors.panelBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _InventoryColors.woodMedium, width: 6),
      boxShadow: [
        // Outer shadow
        BoxShadow(
          color: Colors.black.withAlpha(180),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        // Inner wood frame effect
        BoxShadow(
          color: _InventoryColors.woodLight.withAlpha(60),
          blurRadius: 0,
          spreadRadius: -2,
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _InventoryColors.woodDark,
            _InventoryColors.woodMedium,
            _InventoryColors.woodDark,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: _InventoryColors.woodLight, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Backpack icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _InventoryColors.slotBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _InventoryColors.slotBorder, width: 2),
            ),
            child: Icon(
              Icons.backpack,
              color: _InventoryColors.textGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Text(
            'INVENTORY',
            style: TextStyle(
              color: _InventoryColors.textLight,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              shadows: [
                Shadow(
                  color: Colors.black.withAlpha(150),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          const Spacer(),
          // Close button
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _InventoryColors.slotBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _InventoryColors.slotBorder, width: 2),
              ),
              child: Icon(
                Icons.close,
                color: _InventoryColors.textLight,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _InventoryColors.woodDark.withAlpha(150),
        border: Border(
          bottom: BorderSide(color: _InventoryColors.slotBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildTab(_InventoryTab.all, 'All', Icons.grid_view),
          const SizedBox(width: 8),
          _buildTab(_InventoryTab.fish, 'Fish', Icons.water),
          const SizedBox(width: 8),
          _buildTab(_InventoryTab.equipment, 'Gear', Icons.build),
        ],
      ),
    );
  }

  Widget _buildTab(_InventoryTab tab, String label, IconData icon) {
    final isSelected = _currentTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _InventoryColors.slotHighlight : _InventoryColors.slotBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? _InventoryColors.textGold : _InventoryColors.slotBorder,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: _InventoryColors.textGold.withAlpha(50),
              blurRadius: 6,
              spreadRadius: 0,
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? _InventoryColors.textGold : _InventoryColors.textLight,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _InventoryColors.textGold : _InventoryColors.textLight,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemGrid() {
    final items = _filteredItems;
    
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6, // More columns for smaller items
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.85, // Slightly taller for gold value
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _InventorySlot(entry: items[index]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: _InventoryColors.slotBorder,
          ),
          const SizedBox(height: 16),
          Text(
            'No items yet',
            style: TextStyle(
              color: _InventoryColors.textLight.withAlpha(150),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Catch some fish to get started!',
            style: TextStyle(
              color: _InventoryColors.textLight.withAlpha(100),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final totalItems = widget.items.fold<int>(0, (sum, e) => sum + e.quantity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _InventoryColors.woodDark,
            _InventoryColors.woodMedium,
            _InventoryColors.woodDark,
          ],
        ),
        border: Border(
          top: BorderSide(color: _InventoryColors.woodLight, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Item count
          Row(
            children: [
              Icon(Icons.inventory_2, size: 16, color: _InventoryColors.textLight),
              const SizedBox(width: 6),
              Text(
                '$totalItems items',
                style: TextStyle(
                  color: _InventoryColors.textLight,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          // Player's total gold
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _InventoryColors.slotBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _InventoryColors.textGold.withAlpha(100), width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.monetization_on, size: 18, color: _InventoryColors.textGold),
                const SizedBox(width: 6),
                Text(
                  '${widget.playerGold}g',
                  style: TextStyle(
                    color: _InventoryColors.textGold,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual inventory slot (Stardew-style) - smaller with gold value
class _InventorySlot extends StatelessWidget {
  final InventoryEntry entry;

  const _InventorySlot({required this.entry});

  @override
  Widget build(BuildContext context) {
    final itemDef = GameItems.get(entry.itemId);
    final isFish = entry.itemId.startsWith('fish_');
    final stackValue = (itemDef?.getSellPrice(entry.rarity) ?? 0) * entry.quantity;

    return Tooltip(
      message: '${itemDef?.name ?? entry.itemId}\n${itemDef?.description ?? ""}\nValue: ${stackValue}g',
      preferBelow: false,
      decoration: BoxDecoration(
        color: _InventoryColors.panelBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _InventoryColors.woodMedium, width: 2),
      ),
      textStyle: TextStyle(color: _InventoryColors.textLight, fontSize: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _InventoryColors.slotBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _InventoryColors.slotBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              offset: const Offset(1, 2),
              blurRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Main content area
            Expanded(
              child: Stack(
                children: [
                  // Inner highlight (top-left)
                  Positioned(
                    top: 2,
                    left: 2,
                    right: 6,
                    height: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _InventoryColors.woodLight.withAlpha(40),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  // Item icon centered
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: itemDef != null
                          ? Image.asset(
                              itemDef.assetPath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _buildFallbackIcon(),
                            )
                          : _buildFallbackIcon(),
                    ),
                  ),
                  // Stars (top-left for fish)
                  if (isFish && entry.rarity > 0)
                    Positioned(
                      top: 2,
                      left: 2,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(entry.rarity, (i) => Icon(
                          Icons.star,
                          size: 8,
                          color: _InventoryColors.star,
                        )),
                      ),
                    ),
                  // Quantity badge (top-right)
                  if (entry.quantity > 1)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: _InventoryColors.panelBg.withAlpha(220),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'x${entry.quantity}',
                          style: TextStyle(
                            color: _InventoryColors.textLight,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Gold value bar at bottom
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: _InventoryColors.woodDark.withAlpha(200),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
              ),
              child: Text(
                '${stackValue}g',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _InventoryColors.textGold,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    IconData icon;
    if (entry.itemId.startsWith('fish_')) {
      icon = Icons.water;
    } else if (entry.itemId.startsWith('pole_')) {
      icon = Icons.phishing;
    } else if (entry.itemId.startsWith('lure_')) {
      icon = Icons.catching_pokemon;
    } else {
      icon = Icons.inventory_2;
    }
    return Icon(icon, color: _InventoryColors.textLight, size: 24);
  }
}
