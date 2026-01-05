import 'package:flutter/material.dart';

import '../services/spacetimedb/stdb_service.dart';
import '../utils/constants.dart';

/// WoW-style quest dialog colors
class _QuestDialogColors {
  static const Color woodDark = Color(0xFF5D3A1A);
  static const Color woodMedium = Color(0xFF8B5A2B);
  static const Color woodLight = Color(0xFFA0724B);
  static const Color panelBg = Color(0xFF2D1810);
  static const Color slotBg = Color(0xFF4A3728);
  static const Color slotBorder = Color(0xFF6B4423);
  static const Color textLight = Color(0xFFF5E6D3);
  static const Color textGold = Color(0xFFFFD700);
  static const Color textMuted = Color(0xFF8B7355);
  static const Color progressGreen = Color(0xFF4CAF50);
  static const Color acceptButton = Color(0xFF2E7D32);
  static const Color declineButton = Color(0xFF8B4513);
}

/// WoW-style quest offer dialog - shown when approaching a quest sign
/// Shows one quest at a time with Accept/Decline buttons
class QuestOfferDialog extends StatelessWidget {
  final Quest quest;
  final PlayerQuest? playerQuest; // If player already has this quest
  final String signName; // Name of the quest sign/giver
  final VoidCallback onClose;
  final VoidCallback onAccept;
  final VoidCallback? onComplete; // Only available if quest is completable

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
    final dialogWidth = (screenSize.width * 0.85).clamp(320.0, 450.0);

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withAlpha(180),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping dialog
            child: Container(
              width: dialogWidth,
              constraints: BoxConstraints(
                maxHeight: screenSize.height * 0.75,
              ),
              decoration: _buildDialogDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuestTitle(),
                          const SizedBox(height: 16),
                          _buildDescription(),
                          const SizedBox(height: 20),
                          if (_isActive) ...[
                            _buildObjectives(),
                            const SizedBox(height: 20),
                          ],
                          _buildRewards(),
                        ],
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

  BoxDecoration _buildDialogDecoration() {
    return BoxDecoration(
      color: _QuestDialogColors.panelBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _QuestDialogColors.woodMedium, width: 5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(200),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    // Quest giver header with scroll/parchment look
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _QuestDialogColors.woodDark,
            _QuestDialogColors.woodMedium,
            _QuestDialogColors.woodDark,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        border: Border(
          bottom: BorderSide(color: _QuestDialogColors.woodLight, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Quest icon - exclamation for new, question for turn-in
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _canComplete 
                  ? _QuestDialogColors.progressGreen.withAlpha(80)
                  : _QuestDialogColors.textGold.withAlpha(80),
              shape: BoxShape.circle,
              border: Border.all(
                color: _canComplete 
                    ? _QuestDialogColors.progressGreen
                    : _QuestDialogColors.textGold,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                _canComplete ? '?' : '!',
                style: TextStyle(
                  color: _canComplete 
                      ? _QuestDialogColors.progressGreen
                      : _QuestDialogColors.textGold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signName,
                  style: TextStyle(
                    color: _QuestDialogColors.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                if (quest.storyline != null)
                  Text(
                    quest.storyline!.replaceAll('_', ' '),
                    style: TextStyle(
                      color: _QuestDialogColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _QuestDialogColors.slotBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _QuestDialogColors.slotBorder, width: 2),
              ),
              child: Icon(
                Icons.close,
                color: _QuestDialogColors.textLight,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestTitle() {
    return Row(
      children: [
        Icon(
          quest.isStoryQuest ? Icons.auto_stories : Icons.today,
          color: _QuestDialogColors.textGold,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            quest.title,
            style: TextStyle(
              color: _QuestDialogColors.textGold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _QuestDialogColors.slotBg.withAlpha(150),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _QuestDialogColors.slotBorder.withAlpha(100),
          width: 1,
        ),
      ),
      child: Text(
        quest.description,
        style: TextStyle(
          color: _QuestDialogColors.textLight,
          fontSize: 14,
          height: 1.5,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildObjectives() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OBJECTIVES',
          style: TextStyle(
            color: _QuestDialogColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        ..._buildObjectivesList(),
      ],
    );
  }

  List<Widget> _buildObjectivesList() {
    final objectives = <Widget>[];

    // Specific fish requirements
    for (final entry in quest.requiredFish.entries) {
      final itemDef = GameItems.get(entry.key);
      final progress = playerQuest?.fishProgress[entry.key] ?? 0;
      final met = progress >= entry.value;

      objectives.add(_buildObjectiveRow(
        itemDef?.name ?? entry.key,
        progress,
        entry.value,
        met,
      ));
    }

    // Total fish requirement
    if (quest.totalFishRequired != null) {
      final progress = playerQuest?.totalFishCaught ?? 0;
      final met = progress >= quest.totalFishRequired!;

      objectives.add(_buildObjectiveRow(
        'Catch any fish',
        progress,
        quest.totalFishRequired!,
        met,
      ));
    }

    // Min rarity requirement
    if (quest.minRarityRequired != null) {
      final progress = playerQuest?.maxRarityCaught ?? 0;
      final met = progress >= quest.minRarityRequired!;

      objectives.add(_buildObjectiveRow(
        'Catch a ${quest.minRarityRequired}-star fish',
        met ? 1 : 0,
        1,
        met,
      ));
    }

    return objectives;
  }

  Widget _buildObjectiveRow(String label, int current, int required, bool met) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: met 
            ? _QuestDialogColors.progressGreen.withAlpha(30)
            : _QuestDialogColors.slotBg.withAlpha(100),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: met 
              ? _QuestDialogColors.progressGreen.withAlpha(100)
              : _QuestDialogColors.slotBorder.withAlpha(80),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            color: met ? _QuestDialogColors.progressGreen : _QuestDialogColors.textMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: met 
                    ? _QuestDialogColors.progressGreen
                    : _QuestDialogColors.textLight,
                fontSize: 13,
                decoration: met ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _QuestDialogColors.woodDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$current/$required',
              style: TextStyle(
                color: met 
                    ? _QuestDialogColors.progressGreen
                    : _QuestDialogColors.textLight,
                fontSize: 11,
                fontWeight: FontWeight.bold,
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
        Text(
          'REWARDS',
          style: TextStyle(
            color: _QuestDialogColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _QuestDialogColors.slotBg.withAlpha(150),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _QuestDialogColors.textGold.withAlpha(60),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Gold reward
              if (quest.goldReward > 0) ...[
                Icon(
                  Icons.monetization_on,
                  color: _QuestDialogColors.textGold,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Text(
                  '${quest.goldReward}',
                  style: TextStyle(
                    color: _QuestDialogColors.textGold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              // Item rewards
              for (final item in quest.itemRewards) ...[
                Icon(
                  Icons.card_giftcard,
                  color: _QuestDialogColors.textLight,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${GameItems.get(item.itemId)?.name ?? item.itemId} x${item.quantity}',
                  style: TextStyle(
                    color: _QuestDialogColors.textLight,
                    fontSize: 13,
                  ),
                ),
              ],
              if (quest.goldReward == 0 && quest.itemRewards.isEmpty)
                Text(
                  'Experience',
                  style: TextStyle(
                    color: _QuestDialogColors.textMuted,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _QuestDialogColors.woodDark.withAlpha(150),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
        border: Border(
          top: BorderSide(color: _QuestDialogColors.slotBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Decline/Close button
          Expanded(
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _QuestDialogColors.declineButton,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _QuestDialogColors.woodLight,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _isActive ? 'CLOSE' : 'DECLINE',
                    style: TextStyle(
                      color: _QuestDialogColors.textLight,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Accept/Complete button
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _canComplete 
                  ? onComplete 
                  : (_isActive ? null : onAccept),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _canComplete
                        ? [
                            _QuestDialogColors.progressGreen,
                            _QuestDialogColors.progressGreen.withAlpha(200),
                          ]
                        : _isActive
                            ? [
                                _QuestDialogColors.slotBg,
                                _QuestDialogColors.slotBg,
                              ]
                            : [
                                _QuestDialogColors.acceptButton,
                                _QuestDialogColors.acceptButton.withAlpha(200),
                              ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _canComplete
                        ? Colors.white.withAlpha(150)
                        : _isActive
                            ? _QuestDialogColors.slotBorder
                            : _QuestDialogColors.textGold,
                    width: 2,
                  ),
                  boxShadow: (_canComplete || !_isActive)
                      ? [
                          BoxShadow(
                            color: (_canComplete
                                    ? _QuestDialogColors.progressGreen
                                    : _QuestDialogColors.textGold)
                                .withAlpha(60),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_canComplete) ...[
                        Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _canComplete 
                            ? 'COMPLETE QUEST'
                            : _isActive 
                                ? 'IN PROGRESS...'
                                : 'ACCEPT QUEST',
                        style: TextStyle(
                          color: _isActive && !_canComplete
                              ? _QuestDialogColors.textMuted
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
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
  /// Filter quests by storyline if specified
  static List<Quest> _filterByStoryline(List<Quest> quests, List<String>? storylines) {
    if (storylines == null || storylines.isEmpty) return quests;
    return quests.where((q) => 
      q.storyline != null && storylines.contains(q.storyline)
    ).toList();
  }

  /// Gets the next quest to show at a quest sign
  /// Priority: 1) Completable quests, 2) Available quests, 3) Active quests
  /// If storylines is provided, only shows quests matching those storylines
  static Quest? getQuestToShow({
    required List<Quest> allQuests,
    required List<PlayerQuest> playerQuests,
    List<String>? storylines,
  }) {
    final filteredQuests = _filterByStoryline(allQuests, storylines);
    
    Quest? completableQuest;
    Quest? availableQuest;
    Quest? activeQuest;

    for (final quest in filteredQuests) {
      final pq = playerQuests.where((p) => p.questId == quest.id).firstOrNull;

      // Check if this quest is completable (priority 1)
      if (pq != null && pq.isActive && pq.areRequirementsMet(quest)) {
        completableQuest ??= quest;
        continue;
      }

      // Check if this quest is active but not complete (priority 3)
      if (pq != null && pq.isActive) {
        activeQuest ??= quest;
        continue;
      }

      // Skip completed quests
      if (pq != null && pq.isCompleted) continue;

      // Check if quest is available (no playerQuest entry)
      if (pq == null) {
        // Check prerequisites
        if (quest.prerequisiteQuestId != null) {
          final prereqDone = playerQuests.any(
            (p) => p.questId == quest.prerequisiteQuestId && p.isCompleted,
          );
          if (!prereqDone) continue;
        }
        availableQuest ??= quest;
      }
    }

    // Return in priority order
    return completableQuest ?? availableQuest ?? activeQuest;
  }

  /// Check if there are any available or completable quests (for showing ! indicator)
  /// If storylines is provided, only checks quests matching those storylines
  static bool hasAvailableOrCompletableQuests({
    required List<Quest> allQuests,
    required List<PlayerQuest> playerQuests,
    List<String>? storylines,
  }) {
    final filteredQuests = _filterByStoryline(allQuests, storylines);
    
    for (final quest in filteredQuests) {
      final pq = playerQuests.where((p) => p.questId == quest.id).firstOrNull;

      // Completable quest
      if (pq != null && pq.isActive && pq.areRequirementsMet(quest)) {
        return true;
      }

      // Available quest (not started, prerequisites met)
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

  /// Check if there's a quest ready to turn in (for showing ? indicator instead of !)
  /// If storylines is provided, only checks quests matching those storylines
  static bool hasCompletableQuest({
    required List<Quest> allQuests,
    required List<PlayerQuest> playerQuests,
    List<String>? storylines,
  }) {
    final filteredQuests = _filterByStoryline(allQuests, storylines);
    
    for (final quest in filteredQuests) {
      final pq = playerQuests.where((p) => p.questId == quest.id).firstOrNull;
      if (pq != null && pq.isActive && pq.areRequirementsMet(quest)) {
        return true;
      }
    }
    return false;
  }

  /// Check if there's an active quest in progress (not complete)
  /// If storylines is provided, only checks quests matching those storylines
  static bool hasActiveQuest({
    required List<Quest> allQuests,
    required List<PlayerQuest> playerQuests,
    List<String>? storylines,
  }) {
    final filteredQuests = _filterByStoryline(allQuests, storylines);
    
    for (final quest in filteredQuests) {
      final pq = playerQuests.where((p) => p.questId == quest.id).firstOrNull;
      // Active but not complete
      if (pq != null && pq.isActive && !pq.areRequirementsMet(quest)) {
        return true;
      }
    }
    return false;
  }
}

