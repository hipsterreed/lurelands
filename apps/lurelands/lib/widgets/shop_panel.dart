import 'package:flutter/material.dart';

import '../services/spacetimedb/stdb_service.dart';
import '../utils/constants.dart';

/// Shop panel colors - rustic market theme
class _ShopColors {
  static const Color woodDark = Color(0xFF4A3728);
  static const Color woodMedium = Color(0xFF6D5241);
  static const Color woodLight = Color(0xFF8B7355);
  static const Color panelBg = Color(0xFF2A1F17);
  static const Color slotBg = Color(0xFF3D2E23);
  static const Color slotBorder = Color(0xFF5D4433);
  static const Color slotHover = Color(0xFF7D6243);
  static const Color textLight = Color(0xFFF5E6D3);
  static const Color textGold = Color(0xFFFFD700);
  static const Color textMuted = Color(0xFF8B7355);
  static const Color sellButton = Color(0xFF4CAF50);
  static const Color sellButtonHover = Color(0xFF66BB6A);
  static const Color divider = Color(0xFF5D4433);
  static const Color star = Color(0xFFFFD700);
}

/// Shop panel widget for buying/selling items
class ShopPanel extends StatefulWidget {
  final List<InventoryEntry> playerItems;
  final int playerGold;
  final String shopName;
  final VoidCallback onClose;
  final void Function(InventoryEntry item, int quantity) onSellItem;

  const ShopPanel({
    super.key,
    required this.playerItems,
    required this.playerGold,
    required this.shopName,
    required this.onClose,
    required this.onSellItem,
  });

  @override
  State<ShopPanel> createState() => _ShopPanelState();
}

class _ShopPanelState extends State<ShopPanel> {
  InventoryEntry? _selectedItem;
  int _sellQuantity = 1;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final panelWidth = (screenSize.width * 0.95).clamp(500.0, 900.0);
    final panelHeight = (screenSize.height * 0.85).clamp(500.0, 700.0);

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black.withAlpha(180),
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
                  Expanded(
                    child: Row(
                      children: [
                        // Player inventory (left side)
                        Expanded(
                          child: _buildPlayerInventory(),
                        ),
                        // Divider
                        Container(
                          width: 3,
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                _ShopColors.divider.withAlpha(0),
                                _ShopColors.divider,
                                _ShopColors.divider,
                                _ShopColors.divider.withAlpha(0),
                              ],
                            ),
                          ),
                        ),
                        // Merchant area (right side) - empty for now
                        Expanded(
                          child: _buildMerchantArea(),
                        ),
                      ],
                    ),
                  ),
                  // Bottom action bar
                  _buildActionBar(),
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
      color: _ShopColors.panelBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _ShopColors.woodMedium, width: 6),
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
            _ShopColors.woodDark,
            _ShopColors.woodMedium,
            _ShopColors.woodDark,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border(
          bottom: BorderSide(color: _ShopColors.woodLight, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Shop icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _ShopColors.slotBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _ShopColors.slotBorder, width: 2),
            ),
            child: Icon(
              Icons.storefront,
              color: _ShopColors.textGold,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          // Shop name
          Text(
            widget.shopName.toUpperCase(),
            style: TextStyle(
              color: _ShopColors.textLight,
              fontSize: 22,
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
          // Gold display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _ShopColors.slotBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _ShopColors.textGold.withAlpha(80),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.monetization_on,
                  color: _ShopColors.textGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_formatGold(widget.playerGold)}g',
                  style: TextStyle(
                    color: _ShopColors.textGold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Close button
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _ShopColors.slotBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _ShopColors.slotBorder, width: 2),
              ),
              child: Icon(
                Icons.close,
                color: _ShopColors.textLight,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerInventory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'YOUR ITEMS',
            style: TextStyle(
              color: _ShopColors.textGold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        // Inventory grid
        Expanded(
          child: widget.playerItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: _ShopColors.textMuted,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No items to sell',
                        style: TextStyle(
                          color: _ShopColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildInventoryGrid(),
                ),
        ),
      ],
    );
  }

  Widget _buildInventoryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 5;
        final slotSize = (constraints.maxWidth - (columns - 1) * 6) / columns;
        final clampedSize = slotSize.clamp(48.0, 72.0);

        return SingleChildScrollView(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.playerItems.map((item) {
              final isSelected = _selectedItem?.stackKey == item.stackKey;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedItem = null;
                    } else {
                      _selectedItem = item;
                      _sellQuantity = 1;
                    }
                  });
                },
                child: _InventorySlot(
                  entry: item,
                  size: clampedSize,
                  isSelected: isSelected,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildMerchantArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'MERCHANT',
            style: TextStyle(
              color: _ShopColors.textGold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        // Empty merchant inventory placeholder
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  color: _ShopColors.textMuted.withAlpha(100),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: _ShopColors.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Merchant inventory\nwill be available later',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ShopColors.textMuted.withAlpha(150),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    final itemDef = _selectedItem != null ? GameItems.get(_selectedItem!.itemId) : null;
    final sellPrice = itemDef?.getSellPrice(_selectedItem?.rarity ?? 1) ?? 0;
    final totalPrice = sellPrice * _sellQuantity;
    final maxQuantity = _selectedItem?.quantity ?? 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ShopColors.woodDark.withAlpha(200),
        border: Border(
          top: BorderSide(color: _ShopColors.divider, width: 2),
        ),
      ),
      child: _selectedItem != null
          ? Row(
              children: [
                // Selected item preview
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _ShopColors.slotBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _ShopColors.textGold, width: 2),
                  ),
                  child: itemDef != null
                      ? Image.asset(
                          itemDef.assetPath,
                          width: 32,
                          height: 32,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.inventory_2,
                            color: _ShopColors.textLight,
                            size: 28,
                          ),
                        )
                      : Icon(
                          Icons.inventory_2,
                          color: _ShopColors.textLight,
                          size: 28,
                        ),
                ),
                const SizedBox(width: 12),
                // Item name and price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        itemDef?.name ?? _selectedItem!.itemId,
                        style: TextStyle(
                          color: _ShopColors.textLight,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${sellPrice}g each',
                            style: TextStyle(
                              color: _ShopColors.textGold,
                              fontSize: 12,
                            ),
                          ),
                          if (_selectedItem!.rarity > 0) ...[
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                _selectedItem!.rarity,
                                (i) => Icon(
                                  Icons.star,
                                  size: 10,
                                  color: _ShopColors.star,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Quantity selector
                if (maxQuantity > 1) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: _ShopColors.slotBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _ShopColors.slotBorder, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildQuantityButton(
                          Icons.remove,
                          () {
                            if (_sellQuantity > 1) {
                              setState(() => _sellQuantity--);
                            }
                          },
                        ),
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: Text(
                            '$_sellQuantity',
                            style: TextStyle(
                              color: _ShopColors.textLight,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildQuantityButton(
                          Icons.add,
                          () {
                            if (_sellQuantity < maxQuantity) {
                              setState(() => _sellQuantity++);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Sell button
                GestureDetector(
                  onTap: () {
                    if (_selectedItem != null) {
                      widget.onSellItem(_selectedItem!, _sellQuantity);
                      setState(() {
                        _selectedItem = null;
                        _sellQuantity = 1;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _ShopColors.sellButton,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _ShopColors.sellButtonHover,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _ShopColors.sellButton.withAlpha(100),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SELL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.monetization_on,
                          color: _ShopColors.textGold,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${totalPrice}g',
                          style: TextStyle(
                            color: _ShopColors.textGold,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                'Select an item to sell',
                style: TextStyle(
                  color: _ShopColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          color: _ShopColors.textLight,
          size: 18,
        ),
      ),
    );
  }

  String _formatGold(int gold) {
    if (gold >= 1000000) {
      return '${(gold / 1000000).toStringAsFixed(1)}M';
    } else if (gold >= 1000) {
      return '${(gold / 1000).toStringAsFixed(1)}K';
    }
    return gold.toString();
  }
}

/// Individual inventory slot in shop
class _InventorySlot extends StatelessWidget {
  final InventoryEntry entry;
  final double size;
  final bool isSelected;

  const _InventorySlot({
    required this.entry,
    required this.size,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final itemDef = GameItems.get(entry.itemId);
    final isFish = entry.itemId.startsWith('fish_');
    final sellPrice = (itemDef?.getSellPrice(entry.rarity) ?? 0) * entry.quantity;

    return Container(
      width: size,
      height: size * 1.15,
      decoration: BoxDecoration(
        color: isSelected ? _ShopColors.slotHover : _ShopColors.slotBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? _ShopColors.textGold : _ShopColors.slotBorder,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: _ShopColors.textGold.withAlpha(60),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Main content area
          Expanded(
            child: Stack(
              children: [
                // Item icon
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
                // Stars (for fish)
                if (isFish && entry.rarity > 0)
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        entry.rarity,
                        (i) => Icon(
                          Icons.star,
                          size: 8,
                          color: _ShopColors.star,
                        ),
                      ),
                    ),
                  ),
                // Quantity badge
                if (entry.quantity > 1)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _ShopColors.panelBg.withAlpha(230),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'x${entry.quantity}',
                        style: TextStyle(
                          color: _ShopColors.textLight,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Gold value bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: _ShopColors.woodDark.withAlpha(220),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(4),
              ),
            ),
            child: Text(
              '${sellPrice}g',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ShopColors.textGold,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
    return Icon(icon, color: _ShopColors.textLight, size: 24);
  }
}

