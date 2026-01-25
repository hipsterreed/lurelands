/// Quest objective types - supports multiple gameplay mechanics
enum QuestObjectiveType {
  /// Catch a specific fish species
  catchSpecificFish,

  /// Catch any fish (total count)
  catchAnyFish,

  /// Catch fish of minimum rarity
  catchRareFish,

  /// Talk to a specific NPC
  talkToNpc,

  /// Visit a specific location/area
  visitLocation,

  /// Sell fish for gold
  sellFish,

  /// Make a lien payment
  payLien,

  /// Collect specific items
  collectItem,

  /// Attend/participate in an event
  attendEvent,
}

/// Individual quest objective with progress tracking
class QuestObjective {
  final String id;
  final QuestObjectiveType type;
  final String description;
  final String? targetId; // Fish ID, NPC ID, location ID, item ID
  final int targetAmount;
  final int? minRarity; // For catchRareFish objectives

  const QuestObjective({
    required this.id,
    required this.type,
    required this.description,
    this.targetId,
    this.targetAmount = 1,
    this.minRarity,
  });

  /// Display name for the objective type
  String get typeDisplayName {
    switch (type) {
      case QuestObjectiveType.catchSpecificFish:
        return 'Catch';
      case QuestObjectiveType.catchAnyFish:
        return 'Catch fish';
      case QuestObjectiveType.catchRareFish:
        return 'Catch rare fish';
      case QuestObjectiveType.talkToNpc:
        return 'Talk to';
      case QuestObjectiveType.visitLocation:
        return 'Visit';
      case QuestObjectiveType.sellFish:
        return 'Sell fish';
      case QuestObjectiveType.payLien:
        return 'Pay lien';
      case QuestObjectiveType.collectItem:
        return 'Collect';
      case QuestObjectiveType.attendEvent:
        return 'Attend';
    }
  }
}

/// Item reward for quests
class ItemReward {
  final String itemId;
  final int quantity;
  final int rarity;

  const ItemReward({
    required this.itemId,
    this.quantity = 1,
    this.rarity = 0,
  });
}

/// Quest rewards bundle
class QuestRewards {
  final int gold;
  final int xp;
  final List<ItemReward> items;

  const QuestRewards({
    this.gold = 0,
    this.xp = 0,
    this.items = const [],
  });

  bool get hasRewards => gold > 0 || xp > 0 || items.isNotEmpty;
}

/// Quest giver type
enum QuestGiverType {
  sign,
  npc,
}

/// Quest giver information
class QuestGiver {
  final QuestGiverType type;
  final String id;

  const QuestGiver({
    required this.type,
    required this.id,
  });
}

/// Quest type classification
enum QuestType {
  /// Main storyline quest - required for progression
  story,

  /// Side quest - optional but may unlock content
  side,

  /// Optional quest - purely optional, often lore-based
  optional,

  /// Daily repeatable quest
  daily,
}

/// Quest definition - static quest data
class Quest {
  final String id;
  final String title;
  final String description;
  final QuestType type;
  final String? storyline;
  final int? storyOrder;
  final String? prerequisiteQuestId;
  final List<QuestObjective> objectives;
  final QuestRewards rewards;
  final QuestGiver? questGiver;
  final bool isRepeatable;

  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.storyline,
    this.storyOrder,
    this.prerequisiteQuestId,
    this.objectives = const [],
    this.rewards = const QuestRewards(),
    this.questGiver,
    this.isRepeatable = false,
  });

  bool get isStoryQuest => type == QuestType.story;
  bool get isSideQuest => type == QuestType.side;
  bool get isOptionalQuest => type == QuestType.optional;
  bool get isDailyQuest => type == QuestType.daily;

  /// Get quest type as string for backward compatibility
  String get questTypeString {
    switch (type) {
      case QuestType.story:
        return 'story';
      case QuestType.side:
        return 'side';
      case QuestType.optional:
        return 'optional';
      case QuestType.daily:
        return 'daily';
    }
  }

  /// Get quest giver type as string for backward compatibility
  String? get questGiverType {
    if (questGiver == null) return null;
    return questGiver!.type == QuestGiverType.sign ? 'sign' : 'npc';
  }

  /// Get quest giver ID for backward compatibility
  String? get questGiverId => questGiver?.id;

  /// Get gold reward for backward compatibility
  int get goldReward => rewards.gold;

  /// Get XP reward for backward compatibility
  int get xpReward => rewards.xp;

  /// Get item rewards for backward compatibility
  List<ItemReward> get itemRewards => rewards.items;

  /// Check if quest has any fish-catching objectives
  bool get hasFishObjectives {
    return objectives.any((o) =>
        o.type == QuestObjectiveType.catchSpecificFish ||
        o.type == QuestObjectiveType.catchAnyFish ||
        o.type == QuestObjectiveType.catchRareFish);
  }

  /// Get required fish map for backward compatibility with old UI
  Map<String, int> get requiredFish {
    final result = <String, int>{};
    for (final obj in objectives) {
      if (obj.type == QuestObjectiveType.catchSpecificFish &&
          obj.targetId != null) {
        result[obj.targetId!] = obj.targetAmount;
      }
    }
    return result;
  }

  /// Get total fish required for backward compatibility
  int? get totalFishRequired {
    for (final obj in objectives) {
      if (obj.type == QuestObjectiveType.catchAnyFish) {
        return obj.targetAmount;
      }
    }
    return null;
  }

  /// Get min rarity required for backward compatibility
  int? get minRarityRequired {
    for (final obj in objectives) {
      if (obj.type == QuestObjectiveType.catchRareFish) {
        return obj.minRarity;
      }
    }
    return null;
  }
}
