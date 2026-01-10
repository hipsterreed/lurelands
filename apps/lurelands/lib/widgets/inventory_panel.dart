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
enum BackpackTab { inventory, quests, skills, settings, debug }

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
  final String? equippedPoleId; // Currently equipped pole item ID
  final void Function(String poleItemId)? onEquipPole; // Called when player equips a pole
  final VoidCallback? onUnequipPole; // Called when player unequips a pole
  final VoidCallback? onResetGold; // Called when player resets gold to 0 (debug)
  final VoidCallback? onResetPosition; // Called when player resets position (debug)
  final VoidCallback? onResetQuests; // Called when player resets all quests (debug)
  final VoidCallback? onExitToMenu; // Called when player wants to exit to main menu
  // Quest-related props
  final List<Quest> quests;
  final List<PlayerQuest> playerQuests;
  final void Function(String questId)? onAcceptQuest;
  final void Function(String questId)? onCompleteQuest;

  const InventoryPanel({
    super.key,
    required this.items,
    required this.playerGold,
    required this.playerName,
    required this.debugEnabled,
    required this.onClose,
    required this.onToggleDebug,
    required this.onUpdatePlayerName,
    this.equippedPoleId,
    this.onEquipPole,
    this.onUnequipPole,
    this.onResetGold,
    this.onResetPosition,
    this.onResetQuests,
    this.onExitToMenu,
    this.quests = const [],
    this.playerQuests = const [],
    this.onAcceptQuest,
    this.onCompleteQuest,
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
          _buildMainTab(BackpackTab.quests, Icons.assignment),
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
      case BackpackTab.quests:
        return _buildQuestsTab();
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

  /// Get inventory items that are not currently equipped
  List<InventoryEntry> get _displayedInventoryItems {
    // Filter out the equipped pole from display
    if (widget.equippedPoleId == null) {
      return widget.items;
    }
    return widget.items.where((item) => item.itemId != widget.equippedPoleId).toList();
  }

  Widget _buildInventoryGrid() {
    const int columns = 10;
    const int rows = 3;
    const int totalSlots = columns * rows;
    
    final displayItems = _displayedInventoryItems;

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotSize = (constraints.maxWidth - (columns - 1) * 3) / columns;
        final clampedSize = slotSize.clamp(32.0, 48.0); // Smaller slots
        
        return Wrap(
          spacing: 3,
          runSpacing: 3,
          children: List.generate(totalSlots, (index) {
            final item = index < displayItems.length ? displayItems[index] : null;
            return SizedBox(
              width: clampedSize,
              height: clampedSize * 1.1, // Slightly taller for gold value
              child: item != null
                  ? _InventorySlot(
                      entry: item,
                      onTap: item.itemId.startsWith('pole_') && widget.onEquipPole != null
                          ? () => widget.onEquipPole!(item.itemId)
                          : null,
                    )
                  : _EmptySlot(),
            );
          }),
        );
      },
    );
  }

  Widget _buildCharacterSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Player name + Equipment
        Expanded(
          child: Column(
            children: [
              // Player name above equipment
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  widget.playerName,
                  style: TextStyle(
                    color: _BackpackColors.textGold,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withAlpha(150),
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              // Equipment area
              Expanded(
                child: Center(child: _buildEquipmentArea()),
              ),
            ],
          ),
        ),
        // Vertical divider
        Container(
          width: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: _BackpackColors.divider,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        // Right: Stats panel
        Expanded(
          child: _buildPlayerInfo(),
        ),
      ],
    );
  }

  Widget _buildEquipmentArea() {
    // Find the equipped pole entry for display
    InventoryEntry? equippedPoleEntry;
    if (widget.equippedPoleId != null) {
      equippedPoleEntry = widget.items
          .where((item) => item.itemId == widget.equippedPoleId)
          .firstOrNull;
    }
    
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
              equippedItem: equippedPoleEntry,
              onTap: widget.equippedPoleId != null && widget.onUnequipPole != null
                  ? widget.onUnequipPole
                  : null,
              onDrop: widget.onEquipPole,
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

  /// Get pole tier from equipped pole ID
  int get _equippedPoleTier {
    if (widget.equippedPoleId == null) return 1;
    if (widget.equippedPoleId!.startsWith('pole_')) {
      return int.tryParse(widget.equippedPoleId!.split('_').last) ?? 1;
    }
    return 1;
  }

  Widget _buildPlayerInfo() {
    final poleTier = _equippedPoleTier;
    final poleItem = widget.equippedPoleId != null 
        ? GameItems.get(widget.equippedPoleId!) 
        : null;
    final statColor = _getStatColor(poleTier);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gold display at top-right
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${_formatGold(widget.playerGold)}g',
                    style: TextStyle(
                      color: _BackpackColors.textGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Pole name with tier indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.phishing,
                size: 10,
                color: statColor,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  poleItem?.name ?? 'No Pole',
                  style: TextStyle(
                    color: poleItem != null ? statColor : _BackpackColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Stats grid - 2 columns
          // Row 1: Cast + Control
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  Icons.straighten,
                  'Cast',
                  '${_getCastDistance(poleTier).toInt()}',
                  statColor,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _buildStatTile(
                  Icons.speed,
                  'Ctrl',
                  '+${((_getGravityMultiplier(poleTier) - 1) * 100).toInt()}%',
                  statColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Row 2: Bar Bonus + Items
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  Icons.expand,
                  'Bar+',
                  '+${(_getBarBonus(poleTier) * 100).toInt()}%',
                  statColor,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _buildStatTile(
                  Icons.inventory_2,
                  'Items',
                  '${widget.items.fold<int>(0, (sum, e) => sum + e.quantity)}',
                  _BackpackColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(IconData icon, String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: _BackpackColors.slotEmpty,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _BackpackColors.slotBorder.withAlpha(150),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 8, color: _BackpackColors.textMuted),
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  color: _BackpackColors.textMuted,
                  fontSize: 7,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  double _getCastDistance(int poleTier) {
    const distances = [100.0, 140.0, 180.0, 220.0];
    return distances[(poleTier - 1).clamp(0, 3)];
  }

  double _getGravityMultiplier(int poleTier) {
    return GameConstants.poleGravityMultiplier[(poleTier - 1).clamp(0, 3)];
  }

  double _getBarBonus(int poleTier) {
    return GameConstants.poleBarSizeBonus[(poleTier - 1).clamp(0, 3)];
  }

  Color _getStatColor(int poleTier) {
    switch (poleTier) {
      case 1:
        return _BackpackColors.textLight;
      case 2:
        return const Color(0xFF7CFC00); // Green
      case 3:
        return const Color(0xFF00BFFF); // Blue
      case 4:
        return const Color(0xFFFFD700); // Gold
      default:
        return _BackpackColors.textLight;
    }
  }

  String _formatGold(int gold) {
    if (gold >= 1000000) {
      return '${(gold / 1000000).toStringAsFixed(1)}M';
    } else if (gold >= 1000) {
      return '${(gold / 1000).toStringAsFixed(1)}K';
    }
    return gold.toString();
  }

  // ============== QUESTS TAB ==============

  Widget _buildQuestsTab() {
    // Separate quests by status (Active and Completed only - Available quests are found at signs)
    final activeQuests = <Quest>[];
    final completedQuests = <Quest>[];

    for (final quest in widget.quests) {
      final pq = widget.playerQuests.where((p) => p.questId == quest.id).firstOrNull;

      if (pq != null && pq.isActive) {
        activeQuests.add(quest);
      } else if (pq != null && pq.isCompleted) {
        completedQuests.add(quest);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active quests section
          if (activeQuests.isNotEmpty) ...[
            _buildQuestSectionHeader('ACTIVE QUESTS', activeQuests.length),
            const SizedBox(height: 8),
            ...activeQuests.map((q) => _buildQuestCard(q, isActive: true)),
            const SizedBox(height: 16),
          ],

          // Completed quests section
          if (completedQuests.isNotEmpty) ...[
            _buildQuestSectionHeader('COMPLETED', completedQuests.length),
            const SizedBox(height: 8),
            ...completedQuests.map((q) => _buildQuestCard(q, isCompleted: true)),
          ],

          // Empty state
          if (activeQuests.isEmpty && completedQuests.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.assignment_outlined,
                    color: _BackpackColors.textMuted.withAlpha(100),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No quests yet',
                    style: TextStyle(
                      color: _BackpackColors.textMuted,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Visit a quest board to find available quests',
                    style: TextStyle(
                      color: _BackpackColors.textMuted.withAlpha(150),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: _BackpackColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _BackpackColors.slotBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: _BackpackColors.textLight,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestCard(Quest quest, {bool isActive = false, bool isCompleted = false}) {
    final pq = widget.playerQuests.where((p) => p.questId == quest.id).firstOrNull;
    final canComplete = isActive && pq != null && pq.areRequirementsMet(quest);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? (canComplete ? const Color(0xFF2D4A2D) : _BackpackColors.slotBg)
            : (isCompleted ? _BackpackColors.slotBg.withAlpha(150) : _BackpackColors.slotBg),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? (canComplete ? const Color(0xFF4CAF50) : _BackpackColors.slotHighlight)
              : (isCompleted ? _BackpackColors.slotBorder.withAlpha(100) : _BackpackColors.slotBorder),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(
                quest.isStoryQuest ? Icons.auto_stories : Icons.today,
                color: isCompleted 
                    ? _BackpackColors.textMuted 
                    : (quest.isStoryQuest ? _BackpackColors.textGold : _BackpackColors.textMuted),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quest.title,
                  style: TextStyle(
                    color: isCompleted ? _BackpackColors.textMuted : _BackpackColors.textLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (isCompleted)
                Icon(Icons.check_circle, color: const Color(0xFF4CAF50), size: 18),
            ],
          ),
          if (quest.storyline != null) ...[
            const SizedBox(height: 4),
            Text(
              quest.storyline!.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                color: _BackpackColors.textMuted.withAlpha(180),
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            quest.description,
            style: TextStyle(
              color: isCompleted 
                  ? _BackpackColors.textMuted.withAlpha(150) 
                  : _BackpackColors.textMuted,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          // Progress for active quests
          if (isActive && pq != null) ...[
            const SizedBox(height: 8),
            _buildQuestProgress(quest, pq),
          ],
          
          // Rewards preview
          if (!isCompleted) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (quest.goldReward > 0) ...[
                  Icon(Icons.monetization_on, color: _BackpackColors.textGold, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${quest.goldReward}',
                    style: TextStyle(color: _BackpackColors.textGold, fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                ],
                for (final item in quest.itemRewards) ...[
                  Icon(Icons.card_giftcard, color: _BackpackColors.textLight, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    GameItems.get(item.itemId)?.name ?? item.itemId,
                    style: TextStyle(color: _BackpackColors.textLight, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
          
          // Complete button for active quests that are completable
          if (canComplete && widget.onCompleteQuest != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onCompleteQuest!(quest.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('COMPLETE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestProgress(Quest quest, PlayerQuest pq) {
    final widgets = <Widget>[];

    // Specific fish requirements
    for (final entry in quest.requiredFish.entries) {
      final progress = pq.fishProgress[entry.key] ?? 0;
      final met = progress >= entry.value;
      final itemName = GameItems.get(entry.key)?.name ?? entry.key;
      widgets.add(_buildProgressRow(itemName, progress, entry.value, met));
    }

    // Total fish requirement
    if (quest.totalFishRequired != null) {
      final progress = pq.totalFishCaught;
      final met = progress >= quest.totalFishRequired!;
      widgets.add(_buildProgressRow('Total Fish', progress, quest.totalFishRequired!, met));
    }

    // Min rarity requirement
    if (quest.minRarityRequired != null) {
      final progress = pq.maxRarityCaught;
      final met = progress >= quest.minRarityRequired!;
      widgets.add(_buildProgressRow(
        '${quest.minRarityRequired}-star Fish', 
        met ? 1 : 0, 
        1, 
        met,
      ));
    }

    return Column(children: widgets);
  }

  Widget _buildProgressRow(String label, int current, int required, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            color: met ? const Color(0xFF4CAF50) : _BackpackColors.textMuted,
            size: 12,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _BackpackColors.textLight,
                fontSize: 10,
              ),
            ),
          ),
          Text(
            '$current/$required',
            style: TextStyle(
              color: met ? const Color(0xFF4CAF50) : _BackpackColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
          const SizedBox(height: 24),
          // Game section header
          Text(
            'GAME',
            style: TextStyle(
              color: _BackpackColors.textGold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          // Exit to Menu button
          if (widget.onExitToMenu != null)
            GestureDetector(
              onTap: widget.onExitToMenu,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _BackpackColors.slotBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8B4513).withAlpha(150),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.exit_to_app,
                      color: const Color(0xFFCD853F),
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exit to Menu',
                            style: TextStyle(
                              color: _BackpackColors.textLight,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Return to the main menu',
                            style: TextStyle(
                              color: _BackpackColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: const Color(0xFF8B4513).withAlpha(150),
                      size: 24,
                    ),
                  ],
                ),
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
          const SizedBox(height: 16),
          // Reset Gold button
          if (widget.onResetGold != null)
            GestureDetector(
              onTap: widget.onResetGold,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _BackpackColors.slotBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withAlpha(150),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.money_off,
                      color: Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset Gold',
                            style: TextStyle(
                              color: _BackpackColors.textLight,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Set gold to 0 (Current: ${widget.playerGold}g)',
                            style: TextStyle(
                              color: _BackpackColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.red.withAlpha(150),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Reset Position button
          if (widget.onResetPosition != null)
            GestureDetector(
              onTap: widget.onResetPosition,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _BackpackColors.slotBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withAlpha(150),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset Position',
                            style: TextStyle(
                              color: _BackpackColors.textLight,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Teleport to safe location if stuck',
                            style: TextStyle(
                              color: _BackpackColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.blue.withAlpha(150),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Reset Quests button
          if (widget.onResetQuests != null)
            GestureDetector(
              onTap: widget.onResetQuests,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _BackpackColors.slotBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withAlpha(150),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_return,
                      color: Colors.orange,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset Quests',
                            style: TextStyle(
                              color: _BackpackColors.textLight,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Remove all quest progress (${widget.playerQuests.length} quests)',
                            style: TextStyle(
                              color: _BackpackColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.orange.withAlpha(150),
                      size: 24,
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
  final VoidCallback? onTap;

  const _InventorySlot({required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final itemDef = GameItems.get(entry.itemId);
    final isFish = entry.itemId.startsWith('fish_');
    final isPole = entry.itemId.startsWith('pole_');
    final stackValue = (itemDef?.getSellPrice(entry.rarity) ?? 0) * entry.quantity;
    
    // Build tooltip message - add equip hint for poles
    String tooltipMessage = '${itemDef?.name ?? entry.itemId}\n${itemDef?.description ?? ""}\nValue: ${stackValue}g';
    if (isPole && onTap != null) {
      tooltipMessage += '\n\nTap or drag to equip';
    }

    final slotContent = _buildSlotContent(itemDef, isFish, isPole, stackValue);

    // Make poles draggable
    if (isPole && onTap != null) {
      return Draggable<InventoryEntry>(
        data: entry,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _BackpackColors.slotBg.withAlpha(230),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _BackpackColors.textGold, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _BackpackColors.textGold.withAlpha(100),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: itemDef != null
                  ? Image.asset(
                      itemDef.assetPath,
                      fit: BoxFit.contain,
                      width: 32,
                      height: 32,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.phishing,
                        color: _BackpackColors.textGold,
                        size: 24,
                      ),
                    )
                  : Icon(Icons.phishing, color: _BackpackColors.textGold, size: 24),
            ),
          ),
        ),
        childWhenDragging: Container(
          decoration: BoxDecoration(
            color: _BackpackColors.slotEmpty.withAlpha(150),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _BackpackColors.slotBorder.withAlpha(100),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Tooltip(
            message: tooltipMessage,
            preferBelow: false,
            decoration: BoxDecoration(
              color: _BackpackColors.panelBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _BackpackColors.woodMedium, width: 2),
            ),
            textStyle: TextStyle(color: _BackpackColors.textLight, fontSize: 12),
            child: slotContent,
          ),
        ),
      );
    }

    // Non-draggable items
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltipMessage,
        preferBelow: false,
        decoration: BoxDecoration(
          color: _BackpackColors.panelBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _BackpackColors.woodMedium, width: 2),
        ),
        textStyle: TextStyle(color: _BackpackColors.textLight, fontSize: 12),
        child: slotContent,
      ),
    );
  }

  Widget _buildSlotContent(ItemDefinition? itemDef, bool isFish, bool isPole, int stackValue) {
    return Container(
      decoration: BoxDecoration(
        color: _BackpackColors.slotBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isPole && onTap != null 
              ? _BackpackColors.slotHighlight // Highlight equippable poles
              : _BackpackColors.slotBorder, 
          width: 2,
        ),
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

/// Equipment slot widget with drag-and-drop support
class _EquipmentSlotWidget extends StatelessWidget {
  final EquipmentSlot slot;
  final IconData icon;
  final String label;
  final InventoryEntry? equippedItem; // The item equipped in this slot
  final VoidCallback? onTap; // Called when slot is tapped (to unequip)
  final void Function(String poleItemId)? onDrop; // Called when a pole is dropped

  const _EquipmentSlotWidget({
    required this.slot,
    required this.icon,
    required this.label,
    this.equippedItem,
    this.onTap,
    this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final hasItem = equippedItem != null;
    final itemDef = hasItem ? GameItems.get(equippedItem!.itemId) : null;
    
    // Build tooltip message
    String tooltipMessage;
    if (hasItem && itemDef != null) {
      tooltipMessage = '${itemDef.name}\n${itemDef.description}\n\nTap to unequip';
    } else {
      tooltipMessage = '$label (Empty)\n\nDrag a pole here to equip';
    }
    
    // Only make pole slot a drag target
    final isPoleSlot = slot == EquipmentSlot.pole;
    
    if (isPoleSlot && onDrop != null) {
      return DragTarget<InventoryEntry>(
        onWillAcceptWithDetails: (details) {
          // Only accept poles
          return details.data.itemId.startsWith('pole_');
        },
        onAcceptWithDetails: (details) {
          onDrop!(details.data.itemId);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return _buildSlotWidget(
            hasItem: hasItem,
            itemDef: itemDef,
            tooltipMessage: tooltipMessage,
            isDropTarget: true,
            isHovering: isHovering,
          );
        },
      );
    }
    
    return _buildSlotWidget(
      hasItem: hasItem,
      itemDef: itemDef,
      tooltipMessage: tooltipMessage,
      isDropTarget: false,
      isHovering: false,
    );
  }
  
  Widget _buildSlotWidget({
    required bool hasItem,
    required ItemDefinition? itemDef,
    required String tooltipMessage,
    required bool isDropTarget,
    required bool isHovering,
  }) {
    // Determine colors based on state
    Color borderColor;
    Color bgColor;
    List<BoxShadow> shadows = [
      BoxShadow(
        color: Colors.black.withAlpha(40),
        offset: const Offset(1, 1),
        blurRadius: 1,
      ),
    ];
    
    if (isHovering) {
      // Hovering with a valid pole - bright highlight
      borderColor = Colors.greenAccent;
      bgColor = Colors.greenAccent.withAlpha(40);
      shadows.add(BoxShadow(
        color: Colors.greenAccent.withAlpha(100),
        blurRadius: 8,
        spreadRadius: 2,
      ));
    } else if (hasItem) {
      // Has equipped item
      borderColor = _BackpackColors.textGold;
      bgColor = _BackpackColors.slotBg;
      shadows.add(BoxShadow(
        color: _BackpackColors.textGold.withAlpha(30),
        blurRadius: 4,
        spreadRadius: 0,
      ));
    } else {
      // Empty slot
      borderColor = _BackpackColors.slotBorder;
      bgColor = _BackpackColors.slotEmpty;
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltipMessage,
        preferBelow: false,
        decoration: BoxDecoration(
          color: _BackpackColors.panelBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _BackpackColors.woodMedium, width: 2),
        ),
        textStyle: TextStyle(color: _BackpackColors.textLight, fontSize: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: borderColor,
              width: isHovering ? 3 : 2,
            ),
            boxShadow: shadows,
          ),
          child: Center(
            child: hasItem && itemDef != null
                ? Padding(
                    padding: const EdgeInsets.all(2),
                    child: Image.asset(
                      itemDef.assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        icon,
                        color: _BackpackColors.textGold,
                        size: 18,
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    color: isHovering 
                        ? Colors.greenAccent 
                        : _BackpackColors.textMuted.withAlpha(100),
                    size: 18,
                  ),
          ),
        ),
      ),
    );
  }
}
