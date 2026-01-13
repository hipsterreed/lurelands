import 'package:flutter/material.dart';

import '../services/game_save_service.dart';
import '../utils/constants.dart';
import 'panel_frame.dart';

/// Full screen quest panel with list on left, details on right, footer at bottom
/// Uses the shared dark wood theme from PanelColors
class QuestPanel extends StatefulWidget {
  final List<Quest> quests;
  final List<PlayerQuest> playerQuests;
  final VoidCallback onClose;
  final void Function(String questId) onAcceptQuest;
  final void Function(String questId) onCompleteQuest;

  // Sign filtering parameters (optional) - when provided, filters to this sign's quests
  final String? signId;
  final String? signName;
  final List<String>? storylines;

  const QuestPanel({
    super.key,
    required this.quests,
    required this.playerQuests,
    required this.onClose,
    required this.onAcceptQuest,
    required this.onCompleteQuest,
    this.signId,
    this.signName,
    this.storylines,
  });

  /// Returns true if showing sign-filtered view (section-based, no tabs)
  bool get isSignMode => signId != null;

  @override
  State<QuestPanel> createState() => _QuestPanelState();
}

class _QuestPanelState extends State<QuestPanel> {
  String? _selectedQuestId;
  int _selectedTab = 0;

  Quest? get _selectedQuest =>
      widget.quests.where((q) => q.id == _selectedQuestId).firstOrNull;

  PlayerQuest? get _selectedPlayerQuest => _selectedQuestId == null
      ? null
      : widget.playerQuests.where((pq) => pq.questId == _selectedQuestId).firstOrNull;

  /// Filter quests to only those belonging to the current sign
  List<Quest> _filterQuestsForSign(List<Quest> quests) {
    if (widget.signId == null) return quests;
    return quests.where((q) {
      if (q.questGiverType == 'npc') return false;
      if (q.questGiverType == 'sign') return q.questGiverId == widget.signId;
      if (widget.storylines == null || widget.storylines!.isEmpty) return true;
      return q.storyline != null && widget.storylines!.contains(q.storyline);
    }).toList();
  }

  /// Get filtered quests based on mode
  List<Quest> get _filteredQuests =>
      widget.isSignMode ? _filterQuestsForSign(widget.quests) : widget.quests;

  /// Available quests (not started, prerequisites met)
  List<Quest> get _availableQuests {
    return _filteredQuests.where((q) {
      final pq = widget.playerQuests.where((p) => p.questId == q.id).firstOrNull;
      if (pq != null) return false;
      if (q.prerequisiteQuestId != null) {
        final prereqDone = widget.playerQuests.any(
          (p) => p.questId == q.prerequisiteQuestId && p.isCompleted,
        );
        if (!prereqDone) return false;
      }
      return true;
    }).toList();
  }

  /// Active quests (in progress)
  List<Quest> get _activeQuests {
    final activeIds = widget.playerQuests
        .where((pq) => pq.isActive)
        .map((pq) => pq.questId)
        .toSet();
    return _filteredQuests.where((q) => activeIds.contains(q.id)).toList();
  }

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
            onTap: () {},
            child: Container(
              width: panelWidth,
              height: panelHeight,
              decoration: BoxDecoration(
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
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  // Only show tabs in non-sign mode (backpack access)
                  if (!widget.isSignMode) _buildTabs(),
                  Expanded(
                    child: _selectedQuestId == null
                        ? (widget.isSignMode ? _buildSignSectionsView() : _buildQuestList())
                        : _buildQuestDetails(),
                  ),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Determine title and icon based on mode
    final title = widget.isSignMode
        ? (widget.signName?.toUpperCase() ?? 'QUEST BOARD')
        : 'QUEST JOURNAL';
    final icon = widget.isSignMode
        ? Icons.assignment_outlined
        : Icons.menu_book_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: PanelColors.slotBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: PanelColors.slotBorder, width: 2),
            ),
            child: Icon(
              icon,
              color: PanelColors.textGold,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: PanelColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: PanelColors.slotBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: PanelColors.slotBorder, width: 2),
              ),
              child: const Icon(
                Icons.close,
                color: PanelColors.textLight,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['Available', 'In Progress', 'Completed'];
    final counts = [
      _getQuestsForCategory(0).length,
      _getQuestsForCategory(1).length,
      _getQuestsForCategory(2).length,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PanelColors.woodDark.withAlpha(150),
        border: const Border(
          bottom: BorderSide(color: PanelColors.divider, width: 2),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedTab = index;
                _selectedQuestId = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? PanelColors.slotBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? PanelColors.textGold : PanelColors.slotBorder,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: PanelColors.textGold.withAlpha(60),
                            blurRadius: 6,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Text(
                      tabs[index],
                      style: TextStyle(
                        color: isSelected ? PanelColors.textGold : PanelColors.textMuted,
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (counts[index] > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? PanelColors.textGold : PanelColors.slotBorder,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${counts[index]}',
                          style: TextStyle(
                            color: isSelected ? Colors.black87 : PanelColors.textLight,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Quest> _getQuestsForCategory(int category) {
    switch (category) {
      case 0:
        return widget.quests.where((q) {
          final pq = widget.playerQuests.where((p) => p.questId == q.id).firstOrNull;
          if (pq != null) return false;
          if (q.prerequisiteQuestId != null) {
            final prereqDone = widget.playerQuests.any(
              (p) => p.questId == q.prerequisiteQuestId && p.isCompleted,
            );
            if (!prereqDone) return false;
          }
          return true;
        }).toList();
      case 1:
        final activeIds = widget.playerQuests
            .where((pq) => pq.isActive)
            .map((pq) => pq.questId)
            .toSet();
        return widget.quests.where((q) => activeIds.contains(q.id)).toList();
      case 2:
        final completedIds = widget.playerQuests
            .where((pq) => pq.isCompleted)
            .map((pq) => pq.questId)
            .toSet();
        return widget.quests.where((q) => completedIds.contains(q.id)).toList();
      default:
        return [];
    }
  }

  /// Section-based view for sign mode (Available + Active sections, no tabs)
  Widget _buildSignSectionsView() {
    final available = _availableQuests;
    final active = _activeQuests;

    // Empty state if no quests at this sign
    if (available.isEmpty && active.isEmpty) {
      return Container(
        color: PanelColors.woodDark.withAlpha(150),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                color: PanelColors.textMuted.withAlpha(120),
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'No quests at this sign',
                style: TextStyle(
                  color: PanelColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: PanelColors.woodDark.withAlpha(150),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Available Quests Section
            if (available.isNotEmpty) ...[
              _buildSignSectionHeader('AVAILABLE QUESTS', available.length),
              const SizedBox(height: 10),
              ...available.map((q) => _buildQuestListItem(q)),
              const SizedBox(height: 20),
            ],

            // Active Quests Section
            if (active.isNotEmpty) ...[
              _buildSignSectionHeader('ACTIVE QUESTS', active.length),
              const SizedBox(height: 10),
              ...active.map((q) => _buildQuestListItem(q)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: PanelColors.textGold,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: PanelColors.slotBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: PanelColors.textLight,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestListItem(Quest quest) {
    final playerQuest = widget.playerQuests
        .where((pq) => pq.questId == quest.id)
        .firstOrNull;
    final canComplete = playerQuest != null &&
        playerQuest.isActive &&
        playerQuest.areRequirementsMet(quest);
    final isActive = playerQuest?.isActive == true;
    final isCompleted = playerQuest?.isCompleted == true;

    // Determine icon and color
    IconData icon;
    Color iconColor;
    if (isCompleted) {
      icon = Icons.check_circle;
      iconColor = PanelColors.textMuted;
    } else if (canComplete) {
      icon = Icons.help_outline;
      iconColor = PanelColors.textGold;
    } else if (isActive) {
      icon = Icons.priority_high;
      iconColor = PanelColors.textGold;
    } else {
      icon = Icons.priority_high;
      iconColor = PanelColors.textGold;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedQuestId = quest.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PanelColors.slotBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: PanelColors.slotBorder,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                quest.title,
                style: const TextStyle(
                  color: PanelColors.textLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestList() {
    final quests = _getQuestsForCategory(_selectedTab);

    if (quests.isEmpty) {
      return Container(
        color: PanelColors.woodDark.withAlpha(150),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                color: PanelColors.textMuted.withAlpha(120),
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _selectedTab == 0
                    ? 'No quests available'
                    : _selectedTab == 1
                        ? 'No active quests'
                        : 'No completed quests',
                style: const TextStyle(
                  color: PanelColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: PanelColors.woodDark.withAlpha(150),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: quests.length,
        itemBuilder: (context, index) {
        final quest = quests[index];
        final playerQuest = widget.playerQuests
            .where((pq) => pq.questId == quest.id)
            .firstOrNull;
        final canComplete = playerQuest != null &&
            playerQuest.isActive &&
            playerQuest.areRequirementsMet(quest);
        final isActive = playerQuest?.isActive == true;
        final isCompleted = playerQuest?.isCompleted == true;

        // Determine icon and color
        IconData icon;
        Color iconColor;
        if (isCompleted) {
          icon = Icons.check_circle;
          iconColor = PanelColors.textMuted;
        } else if (canComplete) {
          icon = Icons.help_outline;
          iconColor = PanelColors.textGold;
        } else if (isActive) {
          icon = Icons.priority_high;
          iconColor = PanelColors.textGold;
        } else {
          icon = Icons.priority_high;
          iconColor = PanelColors.textGold;
        }

        return GestureDetector(
          onTap: () => setState(() => _selectedQuestId = quest.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PanelColors.slotBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: PanelColors.slotBorder,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Exclamation icon
                Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                // Quest title
                Expanded(
                  child: Text(
                    quest.title,
                    style: const TextStyle(
                      color: PanelColors.textLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildQuestDetails() {
    final quest = _selectedQuest;

    if (quest == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back,
              color: PanelColors.textMuted.withAlpha(120),
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'Select a quest to view details',
              style: TextStyle(
                color: PanelColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final playerQuest = _selectedPlayerQuest;

    return Column(
      children: [
        // Description at top
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PanelColors.slotBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PanelColors.slotBorder, width: 2),
            ),
            child: Text(
              quest.description,
              style: const TextStyle(
                color: PanelColors.textLight,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ),
        // Objectives and Rewards side by side
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Objectives on left half
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('OBJECTIVES', Icons.flag_outlined),
                      const SizedBox(height: 10),
                      _buildObjectives(quest, playerQuest),
                    ],
                  ),
                ),
              ),
              // Divider
              Container(
                width: 2,
                color: PanelColors.divider,
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),
              // Rewards on right half
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('REWARDS', Icons.card_giftcard_outlined),
                      const SizedBox(height: 10),
                      _buildRewardsSection(quest),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: PanelColors.textGold, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: PanelColors.textGold,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildObjectives(Quest quest, PlayerQuest? playerQuest) {
    final objectives = <Widget>[];

    for (final entry in quest.requiredFish.entries) {
      final itemDef = GameItems.get(entry.key);
      final progress = playerQuest?.fishProgress[entry.key] ?? 0;
      final target = entry.value;
      objectives.add(_buildObjectiveRow(
        itemDef?.name ?? entry.key,
        progress,
        target,
        progress >= target,
        itemDef?.assetPath,
      ));
    }

    if (quest.totalFishRequired != null) {
      final progress = playerQuest?.totalFishCaught ?? 0;
      final target = quest.totalFishRequired!;
      objectives.add(_buildObjectiveRow(
        'Catch any fish',
        progress,
        target,
        progress >= target,
        null, // No specific fish icon for "any fish"
      ));
    }

    if (quest.minRarityRequired != null) {
      final progress = playerQuest?.maxRarityCaught ?? 0;
      final target = quest.minRarityRequired!;
      objectives.add(_buildObjectiveRow(
        'Catch a $target-star fish',
        progress >= target ? 1 : 0,
        1,
        progress >= target,
        null, // No specific fish icon for rarity requirement
      ));
    }

    if (objectives.isEmpty) {
      return const Text(
        'Complete the quest objectives',
        style: TextStyle(color: PanelColors.textMuted, fontSize: 11),
      );
    }

    // Display objectives in a wrap layout (2 per row, but can span if content is long)
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8) / 2; // 2 columns with spacing
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: objectives.map((objective) {
            return SizedBox(
              width: itemWidth,
              child: objective,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildObjectiveRow(String label, int progress, int target, bool completed, String? assetPath) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: completed ? PanelColors.progressGreen.withAlpha(30) : PanelColors.slotBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: completed ? PanelColors.progressGreen.withAlpha(150) : PanelColors.slotBorder,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Fish sprite (always show if available, even when completed) or check icon
          if (assetPath != null)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PanelColors.panelBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: PanelColors.slotBorder,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.asset(
                  assetPath,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to check icon if image fails
                    return Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: completed ? PanelColors.progressGreen : PanelColors.panelBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: completed ? PanelColors.progressGreen : PanelColors.slotBorder,
                          width: 2,
                        ),
                      ),
                      child: completed
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    );
                  },
                ),
              ),
            )
          else
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: completed ? PanelColors.progressGreen : PanelColors.panelBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: completed ? PanelColors.progressGreen : PanelColors.slotBorder,
                  width: 2,
                ),
              ),
              child: completed
                  ? const Icon(Icons.check, color: Colors.white, size: 10)
                  : null,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: completed ? PanelColors.progressGreen : PanelColors.textLight,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                decoration: completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: completed ? PanelColors.progressGreen : PanelColors.woodDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$progress / $target',
              style: TextStyle(
                color: completed ? Colors.white : PanelColors.textLight,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsSection(Quest quest) {
    if (quest.goldReward == 0 &&
        quest.xpReward == 0 &&
        quest.itemRewards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PanelColors.slotBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PanelColors.slotBorder, width: 2),
        ),
        child: const Text(
          'No rewards',
          style: TextStyle(
            color: PanelColors.textMuted,
            fontSize: 11,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (quest.goldReward > 0)
          _buildRewardTile(
            Icons.monetization_on,
            PanelColors.textGold,
            '${quest.goldReward}',
            null,
          ),
        if (quest.xpReward > 0)
          _buildRewardTile(
            Icons.star_rounded,
            const Color(0xFF9C27B0),
            '${quest.xpReward} XP',
            null,
          ),
        for (final item in quest.itemRewards)
          _buildItemRewardTile(item.itemId, item.quantity),
      ],
    );
  }

  Widget _buildFooter() {
    final quest = _selectedQuest;
    final playerQuest = _selectedPlayerQuest;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PanelColors.woodDark.withAlpha(200),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        border: const Border(
          top: BorderSide(color: PanelColors.divider, width: 2),
        ),
      ),
      child: quest == null
          ? const SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  'Select a quest',
                  style: TextStyle(color: PanelColors.textMuted, fontSize: 12),
                ),
              ),
            )
          : Row(
              children: [
                // Close button
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedQuestId = null),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: PanelColors.slotBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PanelColors.slotBorder, width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: PanelColors.textLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Action button
                SizedBox(
                  width: 180,
                  height: 44,
                  child: _buildActionButton(quest, playerQuest),
                ),
              ],
            ),
    );
  }

  Widget _buildRewardTile(IconData icon, Color color, String label, String? imagePath) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: PanelColors.slotBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(100), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: imagePath != null
                  ? Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: PanelColors.panelBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: PanelColors.slotBorder, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Image.asset(
                          imagePath,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(icon, color: color, size: 40);
                          },
                        ),
                      ),
                    )
                  : Icon(icon, color: color, size: 40),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            width: double.infinity,
            decoration: BoxDecoration(
              color: PanelColors.woodDark.withAlpha(200),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRewardTile(String itemId, int quantity) {
    final itemDef = GameItems.get(itemId);
    final itemName = itemDef?.name ?? itemId;
    final assetPath = itemDef?.assetPath;
    final displayText = quantity > 1 ? 'x$quantity' : itemName;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: PanelColors.slotBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PanelColors.textLight.withAlpha(100), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: assetPath != null
                  ? Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: PanelColors.panelBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: PanelColors.slotBorder, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Image.asset(
                          assetPath,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.inventory_2,
                              color: PanelColors.textLight,
                              size: 40,
                            );
                          },
                        ),
                      ),
                    )
                  : Icon(Icons.inventory_2, color: PanelColors.textLight, size: 40),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            width: double.infinity,
            decoration: BoxDecoration(
              color: PanelColors.woodDark.withAlpha(200),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
            ),
            child: Text(
              displayText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PanelColors.textLight,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(Quest quest, PlayerQuest? playerQuest) {
    final bool isAvailable = playerQuest == null;
    final bool isActive = playerQuest?.isActive == true;
    final bool canComplete = isActive && playerQuest!.areRequirementsMet(quest);
    final bool isCompleted = playerQuest?.isCompleted == true;

    if (isCompleted) {
      return Container(
        decoration: BoxDecoration(
          color: PanelColors.progressGreen.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PanelColors.progressGreen, width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: PanelColors.progressGreen, size: 18),
            SizedBox(width: 8),
            Text(
              'Completed',
              style: TextStyle(
                color: PanelColors.progressGreen,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (canComplete) {
      return GestureDetector(
        onTap: () => widget.onCompleteQuest(quest.id),
        child: Container(
          decoration: BoxDecoration(
            color: PanelColors.textGold,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PanelColors.textGold, width: 2),
            boxShadow: [
              BoxShadow(
                color: PanelColors.textGold.withAlpha(100),
                blurRadius: 6,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 18, color: Colors.black87),
              SizedBox(width: 6),
              Text(
                'Complete',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isActive) {
      return Container(
        decoration: BoxDecoration(
          color: PanelColors.slotBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PanelColors.slotBorder, width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, color: PanelColors.textMuted, size: 18),
            SizedBox(width: 6),
            Text(
              'In Progress',
              style: TextStyle(
                color: PanelColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (isAvailable) {
      return GestureDetector(
        onTap: () => widget.onAcceptQuest(quest.id),
        child: Container(
          decoration: BoxDecoration(
            color: PanelColors.progressGreen,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF66BB6A), width: 2),
            boxShadow: [
              BoxShadow(
                color: PanelColors.progressGreen.withAlpha(100),
                blurRadius: 6,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_task, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Accept',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox();
  }
}
