import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/quest_models.dart';
import '../services/game_save_service.dart';
import '../utils/constants.dart';
import 'spritesheet_sprite.dart';

/// Type alias for backward compatibility - panels now use InventoryItem
typedef InventoryEntry = InventoryItem;

/// Type alias for PlayerQuest
typedef PlayerQuest = QuestProgress;

/// Frosted glass color scheme for the v2 panel
class _FrostColors {
  static const Color glassBg = Color(0x40FFFFFF);
  static const Color glassBorder = Color(0x60FFFFFF);
  static const Color slotBg = Color(0x30FFFFFF);
  static const Color slotBorder = Color(0x50FFFFFF);
  static const Color slotHighlight = Color(0x80FFD700);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xCCFFFFFF);
  static const Color textGold = Color(0xFFFFD700);
  static const Color textMuted = Color(0x99FFFFFF);
  static const Color divider = Color(0x40FFFFFF);
  static const Color closeButton = Color(0x60FFFFFF);
}

/// Main tabs for the backpack v2
enum BackpackTabV2 { inventory, quests, skills, settings, debug }

/// Equipment slot types
enum EquipmentSlotV2 { pole, ring, shoes, hat, chest, pants }

/// Full-screen frosted glass inventory panel
class InventoryPanelV2 extends StatefulWidget {
  final List<InventoryEntry> items;
  final int playerGold;
  final String playerName;
  final bool debugEnabled;
  final VoidCallback onClose;
  final VoidCallback onToggleDebug;
  final void Function(String) onUpdatePlayerName;
  final String? equippedPoleId;
  final void Function(String poleItemId)? onEquipPole;
  final VoidCallback? onUnequipPole;
  final VoidCallback? onResetGold;
  final VoidCallback? onResetPosition;
  final VoidCallback? onResetQuests;
  final VoidCallback? onExitToMenu;
  final List<Quest> quests;
  final List<PlayerQuest> playerQuests;
  final void Function(String questId)? onAcceptQuest;
  final void Function(Quest quest)? onCompleteQuest;
  final int playerLevel;
  final int playerXp;
  final int playerXpToNextLevel;

  const InventoryPanelV2({
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
    this.playerLevel = 1,
    this.playerXp = 0,
    this.playerXpToNextLevel = 100,
  });

  @override
  State<InventoryPanelV2> createState() => _InventoryPanelV2State();
}

class _InventoryPanelV2State extends State<InventoryPanelV2>
    with SingleTickerProviderStateMixin {
  BackpackTabV2 _currentTab = BackpackTabV2.inventory;
  final TextEditingController _nameController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.playerName;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleClose() {
    _animationController.reverse().then((_) => widget.onClose());
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: _handleClose,
          child: Stack(
            children: [
              // Frosted glass background
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Colors.black.withAlpha(100),
                ),
              ),
              // Main content - vertical tabs on left, content on right
              Row(
                children: [
                  // Left side: vertical tab column (full height, no safe area)
                  _buildVerticalTabColumn(),
                  // Right side: main content area (with safe area)
                  Expanded(
                    child: SafeArea(
                      left: false, // Don't add left padding, nav bar handles it
                      child: GestureDetector(
                        onTap: () {}, // Prevent tap from closing
                        child: Stack(
                          children: [
                            // Content area
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: _buildTabContent(),
                            ),
                            // Close button top right
                            Positioned(
                              top: 16,
                              right: 16,
                              child: GestureDetector(
                                onTap: _handleClose,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _FrostColors.closeButton,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: _FrostColors.textPrimary,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalTabColumn() {
    const double tabColumnWidth = 64.0;
    const double tabPadding = 8.0;

    return Container(
      width: tabColumnWidth,
      decoration: BoxDecoration(
        color: const Color(0x50000000), // Darker transparent background
        border: Border(
          right: BorderSide(color: _FrostColors.glassBorder, width: 1),
        ),
      ),
      padding: EdgeInsets.only(left: tabPadding, top: 48, bottom: 48, right: tabPadding),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildVerticalTabButton(BackpackTabV2.inventory, 10, 2), // backpack icon
          const SizedBox(height: 8),
          _buildVerticalTabButton(BackpackTabV2.quests, 7, 1), // scroll/quest icon
          const SizedBox(height: 8),
          _buildVerticalTabButton(BackpackTabV2.skills, 5, 0), // star icon
          const SizedBox(height: 8),
          _buildVerticalTabButton(BackpackTabV2.settings, 8, 1), // gear icon
          if (widget.debugEnabled) ...[
            const SizedBox(height: 8),
            _buildVerticalTabButton(BackpackTabV2.debug, 11, 2), // bug icon (using exclamation)
          ],
        ],
      ),
    );
  }

  Widget _buildVerticalTabButton(BackpackTabV2 tab, int spriteCol, int spriteRow) {
    final isSelected = _currentTab == tab;
    const double tabSize = 44.0;

    return GestureDetector(
      onTap: () => setState(() => _currentTab = tab),
      child: Container(
        width: tabSize,
        height: tabSize,
        decoration: BoxDecoration(
          color: isSelected ? _FrostColors.glassBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: _FrostColors.glassBorder, width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: SpritesheetSprite(
          column: spriteCol,
          row: spriteRow,
          size: 28,
          opacity: isSelected ? 1.0 : 0.5,
          assetPath: 'assets/images/ui/UI_Icons.png',
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return Container(
      decoration: BoxDecoration(
        color: _FrostColors.glassBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _FrostColors.glassBorder, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: switch (_currentTab) {
          BackpackTabV2.inventory => _buildInventoryTab(),
          BackpackTabV2.quests => _buildQuestsTab(),
          BackpackTabV2.skills => _buildSkillsTab(),
          BackpackTabV2.settings => _buildSettingsTab(),
          BackpackTabV2.debug => _buildDebugTab(),
        },
      ),
    );
  }

  Widget _buildInventoryTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Equipment section
          const Text(
            'Equipment',
            style: TextStyle(
              color: _FrostColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildEquipmentRow(),
          const SizedBox(height: 24),
          Container(height: 1, color: _FrostColors.divider),
          const SizedBox(height: 24),
          // Inventory section
          const Text(
            'Inventory',
            style: TextStyle(
              color: _FrostColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildInventoryGrid()),
        ],
      ),
    );
  }

  Widget _buildEquipmentRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildEquipmentSlot(EquipmentSlotV2.pole, Icons.phishing),
        _buildEquipmentSlot(EquipmentSlotV2.hat, Icons.face),
        _buildEquipmentSlot(EquipmentSlotV2.chest, Icons.checkroom),
        _buildEquipmentSlot(EquipmentSlotV2.ring, Icons.album),
        _buildEquipmentSlot(EquipmentSlotV2.shoes, Icons.ice_skating),
      ],
    );
  }

  Widget _buildEquipmentSlot(EquipmentSlotV2 slot, IconData placeholderIcon) {
    final isEquipped = slot == EquipmentSlotV2.pole && widget.equippedPoleId != null;
    final equippedItem = isEquipped
        ? widget.items.where((item) => item.itemId == widget.equippedPoleId).firstOrNull
        : null;

    return GestureDetector(
      onTap: isEquipped ? widget.onUnequipPole : null,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isEquipped ? _FrostColors.slotHighlight : _FrostColors.slotBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEquipped ? _FrostColors.textGold : _FrostColors.slotBorder,
            width: isEquipped ? 2 : 1,
          ),
        ),
        child: Center(
          child: equippedItem != null
              ? _buildItemSprite(equippedItem, size: 40)
              : Icon(
                  placeholderIcon,
                  color: _FrostColors.textMuted,
                  size: 28,
                ),
        ),
      ),
    );
  }

  Widget _buildInventoryGrid() {
    const columns = 5;
    const totalSlots = 25;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: totalSlots,
      itemBuilder: (context, index) {
        final item = index < widget.items.length ? widget.items[index] : null;
        final isEquipped = item?.itemId == widget.equippedPoleId;

        return GestureDetector(
          onTap: item != null && item.itemId.startsWith('pole_') && !isEquipped
              ? () => widget.onEquipPole?.call(item.itemId)
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: isEquipped ? _FrostColors.slotHighlight : _FrostColors.slotBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isEquipped ? _FrostColors.textGold : _FrostColors.slotBorder,
                width: isEquipped ? 2 : 1,
              ),
            ),
            child: item != null
                ? Stack(
                    children: [
                      Center(child: _buildItemSprite(item)),
                      if (item.quantity > 1)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(150),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                color: _FrostColors.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildItemSprite(InventoryItem item, {double size = 32}) {
    final itemDef = GameItems.get(item.itemId);
    if (itemDef != null) {
      return ItemImage(item: itemDef, size: size);
    }
    return Icon(
      Icons.help_outline,
      color: _FrostColors.textMuted,
      size: size,
    );
  }

  Widget _buildQuestsTab() {
    final activeQuests = widget.playerQuests
        .where((pq) => pq.isActive)
        .toList();
    final completedQuests = widget.playerQuests
        .where((pq) => pq.isCompleted)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activeQuests.isNotEmpty) ...[
          const Text(
            'Active Quests',
            style: TextStyle(
              color: _FrostColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...activeQuests.map(_buildQuestCard),
          const SizedBox(height: 24),
        ],
        if (completedQuests.isNotEmpty) ...[
          const Text(
            'Completed',
            style: TextStyle(
              color: _FrostColors.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...completedQuests.map(_buildQuestCard),
        ],
        if (activeQuests.isEmpty && completedQuests.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    color: _FrostColors.textMuted,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No quests yet',
                    style: TextStyle(
                      color: _FrostColors.textMuted,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Talk to NPCs to find quests!',
                    style: TextStyle(
                      color: _FrostColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestCard(PlayerQuest playerQuest) {
    final quest = widget.quests.firstWhere(
      (q) => q.id == playerQuest.questId,
      orElse: () => Quest(
        id: playerQuest.questId,
        title: 'Unknown Quest',
        description: '',
        type: QuestType.side,
        objectives: [],
        rewards: const QuestRewards(),
      ),
    );
    final isComplete = playerQuest.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _FrostColors.slotBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete ? _FrostColors.textGold : _FrostColors.slotBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isComplete ? _FrostColors.textGold : _FrostColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quest.title,
                  style: TextStyle(
                    color: _FrostColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: isComplete ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          if (!isComplete && quest.objectives.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...quest.objectives.map((obj) => _buildObjectiveRow(obj, playerQuest)),
          ],
        ],
      ),
    );
  }

  Widget _buildObjectiveRow(QuestObjective objective, PlayerQuest playerQuest) {
    final progress = playerQuest.getObjectiveProgress(objective.id);
    final isObjectiveComplete = progress >= objective.targetAmount;

    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 4),
      child: Row(
        children: [
          Icon(
            isObjectiveComplete ? Icons.check : Icons.circle_outlined,
            color: isObjectiveComplete ? _FrostColors.textGold : _FrostColors.textMuted,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              objective.description,
              style: TextStyle(
                color: _FrostColors.textSecondary,
                fontSize: 12,
                decoration: isObjectiveComplete ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Text(
            '$progress / ${objective.targetAmount}',
            style: const TextStyle(
              color: _FrostColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              color: _FrostColors.textMuted,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Skills Coming Soon',
              style: TextStyle(
                color: _FrostColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Level up to unlock new abilities!',
              style: TextStyle(
                color: _FrostColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Player name
        _buildSettingsTile(
          icon: Icons.person_outline,
          title: 'Player Name',
          child: TextField(
            controller: _nameController,
            style: const TextStyle(color: _FrostColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter name',
              hintStyle: const TextStyle(color: _FrostColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _FrostColors.slotBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _FrostColors.slotBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _FrostColors.textPrimary),
              ),
              filled: true,
              fillColor: _FrostColors.slotBg,
            ),
            onSubmitted: widget.onUpdatePlayerName,
          ),
        ),
        const SizedBox(height: 16),
        // Debug mode toggle
        _buildSettingsTile(
          icon: Icons.bug_report_outlined,
          title: 'Debug Mode',
          trailing: Switch(
            value: widget.debugEnabled,
            onChanged: (_) => widget.onToggleDebug(),
            activeColor: _FrostColors.textGold,
          ),
        ),
        const SizedBox(height: 32),
        // Exit to menu
        GestureDetector(
          onTap: widget.onExitToMenu,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withAlpha(100)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Exit to Menu',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Widget? child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _FrostColors.slotBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _FrostColors.slotBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _FrostColors.textPrimary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _FrostColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }

  Widget _buildDebugTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDebugButton(
          icon: Icons.monetization_on_outlined,
          title: 'Reset Gold',
          subtitle: 'Set gold to 0',
          onTap: widget.onResetGold,
        ),
        const SizedBox(height: 12),
        _buildDebugButton(
          icon: Icons.location_on_outlined,
          title: 'Reset Position',
          subtitle: 'Return to spawn point',
          onTap: widget.onResetPosition,
        ),
        const SizedBox(height: 12),
        _buildDebugButton(
          icon: Icons.assignment_outlined,
          title: 'Reset Quests',
          subtitle: 'Clear all quest progress',
          onTap: widget.onResetQuests,
        ),
      ],
    );
  }

  Widget _buildDebugButton({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _FrostColors.slotBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _FrostColors.slotBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: _FrostColors.textPrimary, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _FrostColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _FrostColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: _FrostColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
