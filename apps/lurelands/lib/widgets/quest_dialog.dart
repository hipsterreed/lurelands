import 'package:flutter/material.dart';

import '../services/game_save_service.dart';
import '../utils/constants.dart';
import 'panel_frame.dart';

/// Stardew Valley style quest dialog - shown when approaching a quest sign
/// Uses the shared dark wood theme from PanelColors
class QuestOfferDialog extends StatelessWidget {
  final Quest quest;
  final PlayerQuest? playerQuest;
  final String signName;
  final VoidCallback onClose;
  final VoidCallback onAccept;
  final VoidCallback? onComplete;

  const QuestOfferDialog({
    super.key,
    required this.quest,
    this.playerQuest,
    this.signName = 'Quest Board',
    required this.onClose,
    required this.onAccept,
    this.onComplete,
  });

  bool get _isActive => playerQuest?.isActive ?? false;
  bool get _canComplete => _isActive && playerQuest!.areRequirementsMet(quest);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.95).clamp(500.0, 900.0);

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withAlpha(180),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: dialogWidth,
              constraints: BoxConstraints(
                maxHeight: screenSize.height * 0.85,
              ),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        color: PanelColors.woodDark.withAlpha(150),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDescription(),
                            const SizedBox(height: 16),
                            if (_isActive) ...[
                              _buildObjectives(),
                              const SizedBox(height: 16),
                            ],
                            _buildRewards(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildActionButtons(),
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
              quest.isStoryQuest ? Icons.auto_stories : Icons.wb_sunny_outlined,
              color: quest.isStoryQuest ? PanelColors.textGold : PanelColors.textLight,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              quest.title,
              style: const TextStyle(
                color: PanelColors.textLight,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          _buildCloseButton(),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: onClose,
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
    );
  }

  Widget _buildDescription() {
    return Container(
      width: double.infinity,
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
    );
  }

  Widget _buildObjectives() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.flag_outlined, color: PanelColors.textGold, size: 14),
            SizedBox(width: 6),
            Text(
              'OBJECTIVES',
              style: TextStyle(
                color: PanelColors.textGold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._buildObjectivesList(),
      ],
    );
  }

  List<Widget> _buildObjectivesList() {
    final objectives = <Widget>[];

    for (final entry in quest.requiredFish.entries) {
      final itemDef = GameItems.get(entry.key);
      final progress = playerQuest?.fishProgress[entry.key] ?? 0;
      final completed = progress >= entry.value;

      objectives.add(_buildObjectiveRow(
        itemDef?.name ?? entry.key,
        progress,
        entry.value,
        completed,
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

    return objectives;
  }

  Widget _buildObjectiveRow(String label, int progress, int target, bool completed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: completed
            ? PanelColors.progressGreen.withAlpha(30)
            : PanelColors.slotBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: completed ? PanelColors.progressGreen.withAlpha(150) : PanelColors.slotBorder,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: completed ? PanelColors.progressGreen : PanelColors.slotBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: completed ? PanelColors.progressGreen : PanelColors.slotBorder,
                width: 2,
              ),
            ),
            child: completed
                ? const Icon(Icons.check, color: Colors.white, size: 12)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: completed ? PanelColors.progressGreen : PanelColors.textLight,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                decoration: completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
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
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.card_giftcard_outlined, color: PanelColors.textGold, size: 14),
            SizedBox(width: 6),
            Text(
              'REWARDS',
              style: TextStyle(
                color: PanelColors.textGold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRewardTiles(),
      ],
    );
  }

  Widget _buildRewardTiles() {
    // Convert item rewards to the format expected by RewardTilesRow
    final itemRewards = quest.itemRewards
        .map((item) => (itemId: item.itemId, quantity: item.quantity))
        .toList();

    return RewardTilesRow(
      goldReward: quest.goldReward > 0 ? quest.goldReward : null,
      xpReward: quest.xpReward > 0 ? quest.xpReward : null,
      itemRewards: itemRewards,
      tileSize: 52,
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PanelColors.woodDark.withAlpha(200),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        border: const Border(
          top: BorderSide(color: PanelColors.divider, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Close/Decline button
          Expanded(
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: PanelColors.slotBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: PanelColors.slotBorder, width: 2),
                ),
                child: Center(
                  child: Text(
                    _isActive ? 'CLOSE' : 'DECLINE',
                    style: const TextStyle(
                      color: PanelColors.textLight,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Accept/Complete button
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _canComplete
                  ? onComplete
                  : (_isActive ? null : onAccept),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _canComplete
                      ? PanelColors.textGold
                      : _isActive
                          ? PanelColors.slotBg
                          : PanelColors.progressGreen,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _canComplete
                        ? PanelColors.textGold
                        : _isActive
                            ? PanelColors.slotBorder
                            : const Color(0xFF66BB6A),
                    width: 2,
                  ),
                  boxShadow: _isActive && !_canComplete
                      ? null
                      : [
                          BoxShadow(
                            color: (_canComplete ? PanelColors.textGold : PanelColors.progressGreen).withAlpha(100),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_canComplete) ...[
                      const Icon(Icons.check_circle, size: 16, color: Colors.black87),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _canComplete
                          ? 'COMPLETE'
                          : _isActive
                              ? 'IN PROGRESS...'
                              : 'ACCEPT QUEST',
                      style: TextStyle(
                        color: _canComplete
                            ? Colors.black87
                            : _isActive
                                ? PanelColors.textMuted
                                : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Determines which quest to show at a quest sign
class QuestSignHelper {
  static List<Quest> _filterForSign(
    List<Quest> quests,
    String? signId,
    List<String>? storylines,
  ) {
    return quests.where((q) {
      if (q.questGiverType == 'npc') return false;
      if (q.questGiverType == 'sign') {
        return q.questGiverId == signId;
      }
      if (storylines == null || storylines.isEmpty) return true;
      return q.storyline != null && storylines.contains(q.storyline);
    }).toList();
  }

  static Quest? getQuestToShow({
    required List<Quest> allQuests,
    required List<PlayerQuest> playerQuests,
    String? signId,
    List<String>? storylines,
  }) {
    final filteredQuests = _filterForSign(allQuests, signId, storylines);

    Quest? completableQuest;
    Quest? availableQuest;
    Quest? activeQuest;

    for (final quest in filteredQuests) {
      final pq = playerQuests.where((p) => p.questId == quest.id).firstOrNull;

      if (pq != null && pq.isActive && pq.areRequirementsMet(quest)) {
        completableQuest ??= quest;
        continue;
      }

      if (pq != null && pq.isActive) {
        activeQuest ??= quest;
        continue;
      }

      if (pq != null && pq.isCompleted) continue;

      if (pq == null) {
        if (quest.prerequisiteQuestId != null) {
          final prereqDone = playerQuests.any(
            (p) => p.questId == quest.prerequisiteQuestId && p.isCompleted,
          );
          if (!prereqDone) continue;
        }
        availableQuest ??= quest;
      }
    }

    return completableQuest ?? availableQuest ?? activeQuest;
  }

  static bool hasAvailableOrCompletableQuests({
    required List<Quest> allQuests,
    required List<PlayerQuest> playerQuests,
    String? signId,
    List<String>? storylines,
  }) {
    final filteredQuests = _filterForSign(allQuests, signId, storylines);

    for (final quest in filteredQuests) {
      final pq = playerQuests.where((p) => p.questId == quest.id).firstOrNull;

      if (pq != null && pq.isActive && pq.areRequirementsMet(quest)) {
        return true;
      }

      if (pq == null) {
        if (quest.prerequisiteQuestId != null) {
          final prereqDone = playerQuests.any(
            (p) => p.questId == quest.prerequisiteQuestId && p.isCompleted,
          );
          if (!prereqDone) continue;
        }
        return true;
      }
    }
    return false;
  }

  static bool hasCompletableQuest({
    required List<Quest> allQuests,
    required List<PlayerQuest> playerQuests,
    String? signId,
    List<String>? storylines,
  }) {
    final filteredQuests = _filterForSign(allQuests, signId, storylines);

    for (final quest in filteredQuests) {
      final pq = playerQuests.where((p) => p.questId == quest.id).firstOrNull;
      if (pq != null && pq.isActive && pq.areRequirementsMet(quest)) {
        return true;
      }
    }
    return false;
  }

  static bool hasActiveQuest({
    required List<Quest> allQuests,
    required List<PlayerQuest> playerQuests,
    String? signId,
    List<String>? storylines,
  }) {
    final filteredQuests = _filterForSign(allQuests, signId, storylines);

    for (final quest in filteredQuests) {
      final pq = playerQuests.where((p) => p.questId == quest.id).firstOrNull;
      if (pq != null && pq.isActive && !pq.areRequirementsMet(quest)) {
        return true;
      }
    }
    return false;
  }
}

/// Helper for NPC quest indicators
class NpcHelper {
  static List<Quest> _filterForNpc(List<Quest> quests, String npcId) {
    return quests.where((q) {
      return q.questGiverType == 'npc' && q.questGiverId == npcId;
    }).toList();
  }

  static Quest? getQuestToShow({
    required List<Quest> allQuests,
    required List<PlayerQuest> playerQuests,
    required String npcId,
  }) {
    final filteredQuests = _filterForNpc(allQuests, npcId);

    Quest? completableQuest;
    Quest? availableQuest;
    Quest? activeQuest;

    for (final quest in filteredQuests) {
      final pq = playerQuests.where((p) => p.questId == quest.id).firstOrNull;

      if (pq != null && pq.isActive && pq.areRequirementsMet(quest)) {
        completableQuest ??= quest;
        continue;
      }

      if (pq != null && pq.isActive) {
        activeQuest ??= quest;
        continue;
      }

      if (pq != null && pq.isCompleted) continue;

      if (pq == null) {
        if (quest.prerequisiteQuestId != null) {
          final prereqDone = playerQuests.any(
            (p) => p.questId == quest.prerequisiteQuestId && p.isCompleted,
          );
          if (!prereqDone) continue;
        }
        availableQuest ??= quest;
      }
    }

    return completableQuest ?? availableQuest ?? activeQuest;
  }

  static bool hasAvailableOrCompletableQuests({
    required List<Quest> allQuests,
    required List<PlayerQuest> playerQuests,
    required String npcId,
  }) {
    final filteredQuests = _filterForNpc(allQuests, npcId);

    for (final quest in filteredQuests) {
      final pq = playerQuests.where((p) => p.questId == quest.id).firstOrNull;

      if (pq != null && pq.isActive && pq.areRequirementsMet(quest)) {
        return true;
      }

      if (pq == null) {
        if (quest.prerequisiteQuestId != null) {
          final prereqDone = playerQuests.any(
            (p) => p.questId == quest.prerequisiteQuestId && p.isCompleted,
          );
          if (!prereqDone) continue;
        }
        return true;
      }
    }
    return false;
  }

  static bool hasCompletableQuest({
    required List<Quest> allQuests,
    required List<PlayerQuest> playerQuests,
    required String npcId,
  }) {
    final filteredQuests = _filterForNpc(allQuests, npcId);

    for (final quest in filteredQuests) {
      final pq = playerQuests.where((p) => p.questId == quest.id).firstOrNull;
      if (pq != null && pq.isActive && pq.areRequirementsMet(quest)) {
        return true;
      }
    }
    return false;
  }

  static bool hasActiveQuest({
    required List<Quest> allQuests,
    required List<PlayerQuest> playerQuests,
    required String npcId,
  }) {
    final filteredQuests = _filterForNpc(allQuests, npcId);

    for (final quest in filteredQuests) {
      final pq = playerQuests.where((p) => p.questId == quest.id).firstOrNull;
      if (pq != null && pq.isActive && !pq.areRequirementsMet(quest)) {
        return true;
      }
    }
    return false;
  }
}
