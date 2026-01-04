import 'package:flutter/material.dart';

import '../services/spacetimedb/stdb_service.dart';
import '../utils/constants.dart';

/// Stardew Valley-inspired backpack panel colors
class _BackpackColors {
  static const Color woodDark = Color(0xFF5D3A1A);
  static const Color woodMedium = Color(0xFF8B5A2B);
  static const Color woodLight = Color(0xFFA0724B);
  static const Color panelBg = Color(0xFF2D1810);
  static const Color slotBg = Color(0xFF4A3728);
  static const Color slotBorder = Color(0xFF6B4423);
  static const Color slotHighlight = Color(0xFF8B6914);
  static const Color slotEmpty = Color(0xFF3A2A1E);
  static const Color textLight = Color(0xFFF5E6D3);
  static const Color textGold = Color(0xFFFFD700);
  static const Color textMuted = Color(0xFF8B7355);
  static const Color star = Color(0xFFFFD700);
  static const Color divider = Color(0xFF6B4423);
  static const Color tabInactive = Color(0xFF3A2A1E);
}

/// Main tabs for the backpack
enum BackpackTab { inventory, skills, settings, debug }

/// Equipment slot types
enum EquipmentSlot { pole, ring, shoes, hat, chest, pants }

/// Stardew Valley-inspired backpack panel with tabs
class InventoryPanel extends StatefulWidget {
  final List<InventoryEntry> items;
  final int playerGold;
  final String playerName;
  final bool debugEnabled;
  final VoidCallback onClose;
  final VoidCallback onToggleDebug;
  final void Function(String) onUpdatePlayerName;

  const InventoryPanel({
    super.key,
    required this.items,
    required this.playerGold,
    required this.playerName,
    required this.debugEnabled,
    required this.onClose,
    required this.onToggleDebug,
    required this.onUpdatePlayerName,
  });

  @override
  State<InventoryPanel> createState() => _InventoryPanelState();
}

class _InventoryPanelState extends State<InventoryPanel> {
  BackpackTab _currentTab = BackpackTab.inventory;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.playerName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final panelWidth = (screenSize.width * 0.92).clamp(400.0, 620.0);
    final panelHeight = (screenSize.height * 0.85).clamp(500.0, 720.0);

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
                  _buildMainTabBar(),
                  Expanded(child: _buildTabContent()),
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
      color: _BackpackColors.panelBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _BackpackColors.woodMedium, width: 6),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(200),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: _BackpackColors.woodLight.withAlpha(40),
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
            _BackpackColors.woodDark,
            _BackpackColors.woodMedium,
            _BackpackColors.woodDark,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: Border(
          bottom: BorderSide(color: _BackpackColors.woodLight, width: 2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _BackpackColors.slotBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _BackpackColors.slotBorder, width: 2),
            ),
            child: Icon(
              Icons.backpack,
              color: _BackpackColors.textGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'BACKPACK',
            style: TextStyle(
              color: _BackpackColors.textLight,
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
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _BackpackColors.slotBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _BackpackColors.slotBorder, width: 2),
              ),
              child: Icon(
                Icons.close,
                color: _BackpackColors.textLight,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _BackpackColors.woodDark.withAlpha(180),
        border: Border(
          bottom: BorderSide(color: _BackpackColors.divider, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMainTab(BackpackTab.inventory, Icons.backpack),
          const SizedBox(width: 8),
          _buildMainTab(BackpackTab.skills, Icons.auto_awesome),
          const SizedBox(width: 8),
          _buildMainTab(BackpackTab.settings, Icons.settings),
          const SizedBox(width: 8),
          _buildMainTab(BackpackTab.debug, Icons.bug_report),
        ],
      ),
    );
  }

  Widget _buildMainTab(BackpackTab tab, IconData icon) {
    final isSelected = _currentTab == tab;
    final isDebug = tab == BackpackTab.debug;

    return GestureDetector(
      onTap: () => setState(() => _currentTab = tab),
      child: Container(
        width: 44,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? _BackpackColors.slotHighlight
              : _BackpackColors.tabInactive,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? _BackpackColors.textGold
                : _BackpackColors.slotBorder,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _BackpackColors.textGold.withAlpha(40),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? _BackpackColors.textGold
                    : _BackpackColors.textMuted,
              ),
              // Debug indicator dot
              if (isDebug && widget.debugEnabled)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _BackpackColors.panelBg,
                        width: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case BackpackTab.inventory:
        return _buildInventoryTab();
      case BackpackTab.skills:
        return _buildSkillsTab();
      case BackpackTab.settings:
        return _buildSettingsTab();
      case BackpackTab.debug:
        return _buildDebugTab();
    }
  }

  // ============== INVENTORY TAB ==============

  Widget _buildInventoryTab() {
    return Column(
      children: [
        // Inventory grid (3 rows x 10 cols)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: _buildInventoryGrid(),
        ),
        // Divider
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _BackpackColors.divider.withAlpha(0),
                _BackpackColors.divider,
                _BackpackColors.divider,
                _BackpackColors.divider.withAlpha(0),
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        // Character + Equipment + Player Info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: _buildCharacterSection(),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryGrid() {
    const int columns = 10;
    const int rows = 3;
    const int totalSlots = columns * rows;

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotSize = (constraints.maxWidth - (columns - 1) * 3) / columns;
        final clampedSize = slotSize.clamp(32.0, 48.0); // Smaller slots
        
        return Wrap(
          spacing: 3,
          runSpacing: 3,
          children: List.generate(totalSlots, (index) {
            final item = index < widget.items.length ? widget.items[index] : null;
            return SizedBox(
              width: clampedSize,
              height: clampedSize * 1.1, // Slightly taller for gold value
              child: item != null
                  ? _InventorySlot(entry: item)
                  : _EmptySlot(),
            );
          }),
        );
      },
    );
  }

  Widget _buildCharacterSection() {
    return Row(
      children: [
        // Left equipment slots + Character + Right equipment slots
        Expanded(
          child: Center(child: _buildEquipmentArea()),
        ),
        // Vertical divider
        Container(
          width: 2,
          height: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: _BackpackColors.divider,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        // Player info
        Expanded(
          child: Center(child: _buildPlayerInfo()),
        ),
      ],
    );
  }

  Widget _buildEquipmentArea() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left equipment slots (Pole, Ring, Shoes)
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _EquipmentSlotWidget(
              slot: EquipmentSlot.pole,
              icon: Icons.phishing,
              label: 'Pole',
            ),
            const SizedBox(height: 4),
            _EquipmentSlotWidget(
              slot: EquipmentSlot.ring,
              icon: Icons.radio_button_unchecked,
              label: 'Ring',
            ),
            const SizedBox(height: 4),
            _EquipmentSlotWidget(
              slot: EquipmentSlot.shoes,
              icon: Icons.directions_walk,
              label: 'Shoes',
            ),
          ],
        ),
        const SizedBox(width: 8),
        // Character sprite
        _buildCharacterSprite(),
        const SizedBox(width: 8),
        // Right equipment slots (Hat, Chest, Pants)
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _EquipmentSlotWidget(
              slot: EquipmentSlot.hat,
              icon: Icons.face,
              label: 'Hat',
            ),
            const SizedBox(height: 4),
            _EquipmentSlotWidget(
              slot: EquipmentSlot.chest,
              icon: Icons.checkroom,
              label: 'Chest',
            ),
            const SizedBox(height: 4),
            _EquipmentSlotWidget(
              slot: EquipmentSlot.pants,
              icon: Icons.accessibility,
              label: 'Pants',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCharacterSprite() {
    // Height matches 3 equipment slots (38*3 + 4*2 spacing = 122)
    // TODO: Add character sprite display
    return Container(
      width: 70,
      height: 122,
      decoration: BoxDecoration(
        color: _BackpackColors.slotBg.withAlpha(150),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _BackpackColors.slotBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            offset: const Offset(1, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.person,
          color: _BackpackColors.textMuted.withAlpha(100),
          size: 40,
        ),
      ),
    );
  }

  Widget _buildPlayerInfo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Player name
        Text(
          widget.playerName,
          style: TextStyle(
            color: _BackpackColors.textGold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withAlpha(150),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Divider line
        Container(
          height: 1,
          width: 60,
          color: _BackpackColors.divider,
        ),
        const SizedBox(height: 8),
        // Gold display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _BackpackColors.slotBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _BackpackColors.textGold.withAlpha(80),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.monetization_on,
                color: _BackpackColors.textGold,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${_formatGold(widget.playerGold)}g',
                style: TextStyle(
                  color: _BackpackColors.textGold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Item count
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2,
              color: _BackpackColors.textMuted,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.items.fold<int>(0, (sum, e) => sum + e.quantity)} items',
              style: TextStyle(
                color: _BackpackColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
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

  // ============== SKILLS TAB ==============

  Widget _buildSkillsTab() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _BackpackColors.slotBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _BackpackColors.slotBorder, width: 2),
            ),
            child: Icon(
              Icons.lock_outline,
              color: _BackpackColors.textMuted,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'SKILLS',
            style: TextStyle(
              color: _BackpackColors.textLight,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Coming Soon',
            style: TextStyle(
              color: _BackpackColors.textMuted,
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Level up your fishing abilities!',
            style: TextStyle(
              color: _BackpackColors.textMuted.withAlpha(150),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============== SETTINGS TAB ==============

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Text(
            'PLAYER',
            style: TextStyle(
              color: _BackpackColors.textGold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          // Player name field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _BackpackColors.slotBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _BackpackColors.slotBorder, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Player Name',
                  style: TextStyle(
                    color: _BackpackColors.textLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        maxLength: 16,
                        style: TextStyle(color: _BackpackColors.textLight),
                        decoration: InputDecoration(
                          hintText: 'Enter your name...',
                          hintStyle: TextStyle(
                            color: _BackpackColors.textMuted.withAlpha(128),
                          ),
                          counterStyle: TextStyle(
                            color: _BackpackColors.textMuted.withAlpha(128),
                            fontSize: 10,
                          ),
                          filled: true,
                          fillColor: _BackpackColors.panelBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: _BackpackColors.textGold,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        final newName = _nameController.text.trim();
                        if (newName.isNotEmpty) {
                          widget.onUpdatePlayerName(newName);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _BackpackColors.slotHighlight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _BackpackColors.textGold,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: _BackpackColors.textGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============== DEBUG TAB ==============

  Widget _buildDebugTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Text(
            'DEBUG OPTIONS',
            style: TextStyle(
              color: _BackpackColors.textGold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          // Debug mode toggle
          GestureDetector(
            onTap: widget.onToggleDebug,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _BackpackColors.slotBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.debugEnabled
                      ? Colors.yellow.withAlpha(150)
                      : _BackpackColors.slotBorder,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bug_report,
                    color: widget.debugEnabled
                        ? Colors.yellow
                        : _BackpackColors.textMuted,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Debug Mode',
                          style: TextStyle(
                            color: _BackpackColors.textLight,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Show debug overlays and hitboxes',
                          style: TextStyle(
                            color: _BackpackColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.debugEnabled
                          ? Colors.yellow.withAlpha(50)
                          : _BackpackColors.panelBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: widget.debugEnabled
                            ? Colors.yellow
                            : _BackpackColors.slotBorder,
                        width: 2,
                      ),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 150),
                      alignment: widget.debugEnabled
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: widget.debugEnabled
                              ? Colors.yellow
                              : _BackpackColors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual inventory slot with item
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
        color: _BackpackColors.panelBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _BackpackColors.woodMedium, width: 2),
      ),
      textStyle: TextStyle(color: _BackpackColors.textLight, fontSize: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _BackpackColors.slotBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _BackpackColors.slotBorder, width: 2),
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
                  // Inner highlight
                  Positioned(
                    top: 2,
                    left: 2,
                    right: 6,
                    height: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _BackpackColors.woodLight.withAlpha(40),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  // Item icon
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
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
                      top: 1,
                      left: 1,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          entry.rarity,
                          (i) => Icon(
                            Icons.star,
                            size: 7,
                            color: _BackpackColors.star,
                          ),
                        ),
                      ),
                    ),
                  // Quantity badge
                  if (entry.quantity > 1)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _BackpackColors.panelBg.withAlpha(220),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'x${entry.quantity}',
                          style: TextStyle(
                            color: _BackpackColors.textLight,
                            fontSize: 8,
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
              padding: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: _BackpackColors.woodDark.withAlpha(200),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(2),
                ),
              ),
              child: Text(
                '${stackValue}g',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _BackpackColors.textGold,
                  fontSize: 8,
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
    return Icon(icon, color: _BackpackColors.textLight, size: 20);
  }
}

/// Empty inventory slot placeholder
class _EmptySlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _BackpackColors.slotEmpty,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _BackpackColors.slotBorder.withAlpha(100),
          width: 1,
        ),
      ),
    );
  }
}

/// Equipment slot widget
class _EquipmentSlotWidget extends StatelessWidget {
  final EquipmentSlot slot;
  final IconData icon;
  final String label;

  const _EquipmentSlotWidget({
    required this.slot,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label (Empty)',
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _BackpackColors.slotEmpty,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _BackpackColors.slotBorder,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              offset: const Offset(1, 1),
              blurRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            color: _BackpackColors.textMuted.withAlpha(100),
            size: 18,
          ),
        ),
      ),
    );
  }
}
