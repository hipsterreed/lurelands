import 'package:flutter/material.dart';

import '../services/spacetimedb/stdb_service.dart';
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

  const QuestPanel({
    super.key,
    required this.quests,
    required this.playerQuests,
    required this.onClose,
    required this.onAcceptQuest,
    required this.onCompleteQuest,
  });

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
                  _buildTabs(),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 280,
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: PanelColors.divider, width: 2),
                              ),
                            ),
                            child: _buildQuestList(),
                          ),
                        ),
                        Expanded(
                          child: _buildQuestDetails(),
                        ),
                      ],
                    ),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PanelColors.slotBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: PanelColors.slotBorder, width: 2),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: PanelColors.textGold,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'QUEST JOURNAL',
            style: TextStyle(
              color: PanelColors.textLight,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onClose,
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
                size: 22,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedTab = index;
                _selectedQuestId = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                            blurRadius: 8,
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
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (counts[index] > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? PanelColors.textGold : PanelColors.slotBorder,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${counts[index]}',
                          style: TextStyle(
                            color: isSelected ? Colors.black87 : PanelColors.textLight,
                            fontSize: 10,
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

  Widget _buildQuestList() {
    final quests = _getQuestsForCategory(_selectedTab);

    if (quests.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: quests.length,
      itemBuilder: (context, index) {
        final quest = quests[index];
        final isSelected = _selectedQuestId == quest.id;
        final playerQuest = widget.playerQuests
            .where((pq) => pq.questId == quest.id)
            .firstOrNull;
        final canComplete = playerQuest != null &&
            playerQuest.isActive &&
            playerQuest.areRequirementsMet(quest);

        return GestureDetector(
          onTap: () => setState(() => _selectedQuestId = quest.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected
                  ? PanelColors.slotHover
                  : PanelColors.slotBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? PanelColors.textGold : PanelColors.slotBorder,
                width: isSelected ? 2 : 2,
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
                // Quest type icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: quest.isStoryQuest
                        ? PanelColors.textGold.withAlpha(30)
                        : PanelColors.panelBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: quest.isStoryQuest
                          ? PanelColors.textGold.withAlpha(100)
                          : PanelColors.slotBorder,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    quest.isStoryQuest ? Icons.auto_stories : Icons.wb_sunny_outlined,
                    color: quest.isStoryQuest ? PanelColors.textGold : PanelColors.textLight,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                // Quest info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: TextStyle(
                          color: PanelColors.textLight,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (quest.storyline != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          quest.storyline!.replaceAll('_', ' '),
                          style: const TextStyle(
                            color: PanelColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Status badge
                if (canComplete)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PanelColors.progressGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Ready!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (playerQuest?.isActive == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PanelColors.textGold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a quest to view details',
              style: TextStyle(
                color: PanelColors.textMuted,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final playerQuest = _selectedPlayerQuest;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: quest.isStoryQuest
                      ? PanelColors.textGold.withAlpha(30)
                      : PanelColors.slotBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: quest.isStoryQuest
                        ? PanelColors.textGold.withAlpha(100)
                        : PanelColors.slotBorder,
                    width: 2,
                  ),
                ),
                child: Icon(
                  quest.isStoryQuest ? Icons.auto_stories : Icons.wb_sunny_outlined,
                  color: quest.isStoryQuest ? PanelColors.textGold : PanelColors.textLight,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: const TextStyle(
                        color: PanelColors.textLight,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (quest.storyline != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: PanelColors.slotBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: PanelColors.slotBorder, width: 1),
                        ),
                        child: Text(
                          quest.storyline!.replaceAll('_', ' '),
                          style: const TextStyle(
                            color: PanelColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PanelColors.slotBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PanelColors.slotBorder, width: 2),
            ),
            child: Text(
              quest.description,
              style: const TextStyle(
                color: PanelColors.textLight,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Objectives
          _buildSectionHeader('OBJECTIVES', Icons.flag_outlined),
          const SizedBox(height: 14),
          _buildObjectives(quest, playerQuest),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: PanelColors.textGold, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: PanelColors.textGold,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
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
      ));
    }

    if (objectives.isEmpty) {
      return const Text(
        'Complete the quest objectives',
        style: TextStyle(color: PanelColors.textMuted, fontSize: 14),
      );
    }

    return Column(children: objectives);
  }

  Widget _buildObjectiveRow(String label, int progress, int target, bool completed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: completed ? PanelColors.progressGreen.withAlpha(30) : PanelColors.slotBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: completed ? PanelColors.progressGreen.withAlpha(150) : PanelColors.slotBorder,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: completed ? PanelColors.progressGreen : PanelColors.panelBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: completed ? PanelColors.progressGreen : PanelColors.slotBorder,
                width: 2,
              ),
            ),
            child: completed
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: completed ? PanelColors.progressGreen : PanelColors.textLight,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: completed ? PanelColors.progressGreen : PanelColors.woodDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$progress / $target',
              style: TextStyle(
                color: completed ? Colors.white : PanelColors.textLight,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final quest = _selectedQuest;
    final playerQuest = _selectedPlayerQuest;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PanelColors.woodDark.withAlpha(200),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        border: const Border(
          top: BorderSide(color: PanelColors.divider, width: 2),
        ),
      ),
      child: quest == null
          ? const SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  'Select a quest to see rewards',
                  style: TextStyle(color: PanelColors.textMuted, fontSize: 15),
                ),
              ),
            )
          : Row(
              children: [
                // Rewards section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'REWARDS',
                        style: TextStyle(
                          color: PanelColors.textGold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (quest.goldReward > 0)
                            _buildRewardChip(
                              Icons.monetization_on,
                              PanelColors.textGold,
                              '${quest.goldReward}',
                            ),
                          if (quest.xpReward > 0)
                            _buildRewardChip(
                              Icons.star_rounded,
                              const Color(0xFF9C27B0),
                              '${quest.xpReward} XP',
                            ),
                          for (final item in quest.itemRewards)
                            _buildRewardChip(
                              Icons.inventory_2,
                              PanelColors.textLight,
                              'x${item.quantity}',
                            ),
                          if (quest.goldReward == 0 &&
                              quest.xpReward == 0 &&
                              quest.itemRewards.isEmpty)
                            const Text(
                              'No rewards',
                              style: TextStyle(
                                color: PanelColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Action button
                SizedBox(
                  width: 180,
                  height: 56,
                  child: _buildActionButton(quest, playerQuest),
                ),
              ],
            ),
    );
  }

  Widget _buildRewardChip(IconData icon, Color color, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: PanelColors.slotBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PanelColors.progressGreen, width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: PanelColors.progressGreen, size: 24),
            SizedBox(width: 10),
            Text(
              'Completed',
              style: TextStyle(
                color: PanelColors.progressGreen,
                fontSize: 16,
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PanelColors.textGold, width: 2),
            boxShadow: [
              BoxShadow(
                color: PanelColors.textGold.withAlpha(100),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 22, color: Colors.black87),
              SizedBox(width: 8),
              Text(
                'Complete',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PanelColors.slotBorder, width: 2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, color: PanelColors.textMuted, size: 22),
            SizedBox(width: 8),
            Text(
              'In Progress',
              style: TextStyle(
                color: PanelColors.textMuted,
                fontSize: 16,
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF66BB6A), width: 2),
            boxShadow: [
              BoxShadow(
                color: PanelColors.progressGreen.withAlpha(100),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_task, size: 22, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Accept',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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
