import 'package:flutter/material.dart';

import '../services/spacetimedb/stdb_service.dart';
import '../utils/constants.dart';

/// Quest panel colors (matching backpack theme)
class _QuestColors {
  static const Color woodDark = Color(0xFF5D3A1A);
  static const Color woodMedium = Color(0xFF8B5A2B);
  static const Color woodLight = Color(0xFFA0724B);
  static const Color panelBg = Color(0xFF2D1810);
  static const Color slotBg = Color(0xFF4A3728);
  static const Color slotBorder = Color(0xFF6B4423);
  static const Color slotHighlight = Color(0xFF8B6914);
  static const Color textLight = Color(0xFFF5E6D3);
  static const Color textGold = Color(0xFFFFD700);
  static const Color textMuted = Color(0xFF8B7355);
  static const Color progressGreen = Color(0xFF4CAF50);
}

/// Panel for viewing quests at a quest sign
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
  String _selectedCategory = 'available'; // 'available', 'active', 'completed'

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
                  _buildCategoryTabs(),
                  Expanded(
                    child: Row(
                      children: [
                        // Quest list (left side)
                        Expanded(
                          flex: 2,
                          child: _buildQuestList(),
                        ),
                        // Divider
                        Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: _QuestColors.slotBorder,
                        ),
                        // Quest details (right side)
                        Expanded(
                          flex: 3,
                          child: _buildQuestDetails(),
                        ),
                      ],
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

  BoxDecoration _buildFrameDecoration() {
    return BoxDecoration(
      color: _QuestColors.panelBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _QuestColors.woodMedium, width: 6),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(200),
          blurRadius: 32,
          offset: const Offset(0, 16),
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
            _QuestColors.woodDark,
            _QuestColors.woodMedium,
            _QuestColors.woodDark,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: Border(
          bottom: BorderSide(color: _QuestColors.woodLight, width: 2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _QuestColors.slotBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _QuestColors.slotBorder, width: 2),
            ),
            child: Icon(
              Icons.assignment,
              color: _QuestColors.textGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'QUEST BOARD',
            style: TextStyle(
              color: _QuestColors.textLight,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _QuestColors.slotBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _QuestColors.slotBorder, width: 2),
              ),
              child: Icon(
                Icons.close,
                color: _QuestColors.textLight,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _QuestColors.woodDark.withAlpha(180),
        border: Border(
          bottom: BorderSide(color: _QuestColors.slotBorder, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCategoryTab('available', 'Available'),
          const SizedBox(width: 8),
          _buildCategoryTab('active', 'Active'),
          const SizedBox(width: 8),
          _buildCategoryTab('completed', 'Completed'),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String category, String label) {
    final isSelected = _selectedCategory == category;
    final count = _getQuestsForCategory(category).length;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedCategory = category;
        _selectedQuestId = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _QuestColors.slotHighlight : _QuestColors.slotBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? _QuestColors.textGold : _QuestColors.slotBorder,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _QuestColors.textGold : _QuestColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _QuestColors.woodDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: _QuestColors.textLight,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Quest> _getQuestsForCategory(String category) {
    switch (category) {
      case 'available':
        return widget.quests.where((q) {
          final pq = widget.playerQuests.where((p) => p.questId == q.id).firstOrNull;
          if (pq != null) return false; // Already have this quest
          // Check prerequisites
          if (q.prerequisiteQuestId != null) {
            final prereqDone = widget.playerQuests.any(
              (p) => p.questId == q.prerequisiteQuestId && p.isCompleted,
            );
            if (!prereqDone) return false;
          }
          return true;
        }).toList();
      case 'active':
        final activeQuestIds = widget.playerQuests
            .where((pq) => pq.isActive)
            .map((pq) => pq.questId)
            .toSet();
        return widget.quests.where((q) => activeQuestIds.contains(q.id)).toList();
      case 'completed':
        final completedQuestIds = widget.playerQuests
            .where((pq) => pq.isCompleted)
            .map((pq) => pq.questId)
            .toSet();
        return widget.quests.where((q) => completedQuestIds.contains(q.id)).toList();
      default:
        return [];
    }
  }

  Widget _buildQuestList() {
    final quests = _getQuestsForCategory(_selectedCategory);

    if (quests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              color: _QuestColors.textMuted.withAlpha(100),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'No ${_selectedCategory} quests',
              style: TextStyle(
                color: _QuestColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: quests.length,
      itemBuilder: (context, index) {
        final quest = quests[index];
        final isSelected = _selectedQuestId == quest.id;

        return GestureDetector(
          onTap: () => setState(() => _selectedQuestId = quest.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? _QuestColors.slotHighlight : _QuestColors.slotBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? _QuestColors.textGold : _QuestColors.slotBorder,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      quest.isStoryQuest ? Icons.auto_stories : Icons.today,
                      color: quest.isStoryQuest
                          ? _QuestColors.textGold
                          : _QuestColors.textMuted,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        quest.title,
                        style: TextStyle(
                          color: _QuestColors.textLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (quest.storyline != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    quest.storyline!.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: _QuestColors.textMuted,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestDetails() {
    final quest = widget.quests.where((q) => q.id == _selectedQuestId).firstOrNull;

    if (quest == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app,
              color: _QuestColors.textMuted.withAlpha(100),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Select a quest to view details',
              style: TextStyle(
                color: _QuestColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final playerQuest = widget.playerQuests.where((pq) => pq.questId == quest.id).firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quest title
          Row(
            children: [
              Icon(
                quest.isStoryQuest ? Icons.auto_stories : Icons.today,
                color: _QuestColors.textGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quest.title,
                  style: TextStyle(
                    color: _QuestColors.textGold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (quest.storyline != null) ...[
            const SizedBox(height: 4),
            Text(
              quest.storyline!.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                color: _QuestColors.textMuted,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Description
          Text(
            quest.description,
            style: TextStyle(
              color: _QuestColors.textLight,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Requirements
          _buildSectionHeader('Requirements'),
          const SizedBox(height: 8),
          _buildRequirements(quest, playerQuest),
          const SizedBox(height: 16),

          // Rewards
          _buildSectionHeader('Rewards'),
          const SizedBox(height: 8),
          _buildRewards(quest),
          const SizedBox(height: 20),

          // Action button
          _buildActionButton(quest, playerQuest),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: _QuestColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildRequirements(Quest quest, PlayerQuest? playerQuest) {
    final reqs = <Widget>[];

    // Specific fish requirements
    for (final entry in quest.requiredFish.entries) {
      final itemDef = GameItems.get(entry.key);
      final progress = playerQuest?.fishProgress[entry.key] ?? 0;
      final met = progress >= entry.value;

      reqs.add(_buildRequirementRow(
        itemDef?.name ?? entry.key,
        '$progress / ${entry.value}',
        met,
      ));
    }

    // Total fish requirement
    if (quest.totalFishRequired != null) {
      final progress = playerQuest?.totalFishCaught ?? 0;
      final met = progress >= quest.totalFishRequired!;

      reqs.add(_buildRequirementRow(
        'Total Fish',
        '$progress / ${quest.totalFishRequired}',
        met,
      ));
    }

    // Min rarity requirement
    if (quest.minRarityRequired != null) {
      final progress = playerQuest?.maxRarityCaught ?? 0;
      final met = progress >= quest.minRarityRequired!;

      reqs.add(_buildRequirementRow(
        'Catch ${quest.minRarityRequired}-star fish',
        met ? 'Done' : 'Not yet',
        met,
      ));
    }

    if (reqs.isEmpty) {
      reqs.add(Text(
        'Complete the objectives',
        style: TextStyle(color: _QuestColors.textMuted, fontSize: 12),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: reqs);
  }

  Widget _buildRequirementRow(String label, String progress, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            color: met ? _QuestColors.progressGreen : _QuestColors.textMuted,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _QuestColors.textLight,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            progress,
            style: TextStyle(
              color: met ? _QuestColors.progressGreen : _QuestColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewards(Quest quest) {
    final rewards = <Widget>[];

    // Gold reward
    if (quest.goldReward > 0) {
      rewards.add(_buildRewardRow(Icons.monetization_on, '${quest.goldReward} Gold'));
    }

    // Item rewards
    for (final item in quest.itemRewards) {
      final itemDef = GameItems.get(item.itemId);
      rewards.add(_buildRewardRow(
        Icons.card_giftcard,
        '${itemDef?.name ?? item.itemId} x${item.quantity}',
      ));
    }

    if (rewards.isEmpty) {
      rewards.add(Text(
        'No rewards',
        style: TextStyle(color: _QuestColors.textMuted, fontSize: 12),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rewards);
  }

  Widget _buildRewardRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: _QuestColors.textGold, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: _QuestColors.textLight,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(Quest quest, PlayerQuest? playerQuest) {
    if (playerQuest == null) {
      // Available quest - show Accept button
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => widget.onAcceptQuest(quest.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: _QuestColors.slotHighlight,
            foregroundColor: _QuestColors.textGold,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: _QuestColors.textGold, width: 2),
            ),
          ),
          child: const Text(
            'ACCEPT QUEST',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ),
      );
    }

    if (playerQuest.isActive) {
      final canComplete = playerQuest.areRequirementsMet(quest);

      if (canComplete) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => widget.onCompleteQuest(quest.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: _QuestColors.progressGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'COMPLETE QUEST',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        );
      } else {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _QuestColors.slotBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _QuestColors.slotBorder, width: 2),
          ),
          child: Center(
            child: Text(
              'IN PROGRESS',
              style: TextStyle(
                color: _QuestColors.textMuted,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        );
      }
    }

    // Completed quest
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _QuestColors.progressGreen.withAlpha(50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _QuestColors.progressGreen, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: _QuestColors.progressGreen, size: 20),
          const SizedBox(width: 8),
          Text(
            'COMPLETED',
            style: TextStyle(
              color: _QuestColors.progressGreen,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

