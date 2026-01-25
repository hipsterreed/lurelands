import '../models/quest_models.dart';
import '../services/game_save_service.dart' show QuestProgress;

/// Registry of all quest definitions
class Quests {
  Quests._();

  // ============================================
  // ACT 1 - MAIN STORYLINE
  // ============================================

  /// Quest 1: The Lien Notice
  /// Establishes core motivation and stakes
  static const Quest lienNotice = Quest(
    id: 'act1_01_lien_notice',
    title: 'The Lien Notice',
    description:
        'A letter has arrived. The family property is at risk. Read the notice and talk to Ellie to understand what must be done.',
    type: QuestType.story,
    storyline: 'act1_main',
    storyOrder: 1,
    objectives: [
      QuestObjective(
        id: 'read_notice',
        type: QuestObjectiveType.visitLocation,
        description: 'Read the lien notice',
        targetId: 'location_mailbox',
      ),
      QuestObjective(
        id: 'talk_ellie',
        type: QuestObjectiveType.talkToNpc,
        description: 'Talk to Ellie',
        targetId: 'npc_ellie',
      ),
    ],
    rewards: QuestRewards(xp: 25),
    questGiver: QuestGiver(type: QuestGiverType.npc, id: 'npc_ellie'),
  );

  /// Quest 2: Old Waters
  /// Reconnects player to fishing
  static const Quest oldWaters = Quest(
    id: 'act1_02_old_waters',
    title: 'Old Waters',
    description:
        'Eli suggests you try fishing in the old river spot. Maybe the waters still remember you.',
    type: QuestType.story,
    storyline: 'act1_main',
    storyOrder: 2,
    prerequisiteQuestId: 'act1_01_lien_notice',
    objectives: [
      QuestObjective(
        id: 'catch_first_fish',
        type: QuestObjectiveType.catchAnyFish,
        description: 'Catch your first fish',
        targetAmount: 1,
      ),
    ],
    rewards: QuestRewards(gold: 10, xp: 50),
    questGiver: QuestGiver(type: QuestGiverType.npc, id: 'npc_eli'),
  );

  /// Quest 3: Tradition, Not Hope
  /// Introduces town nostalgia and fishing contest
  static const Quest traditionNotHope = Quest(
    id: 'act1_03_tradition_not_hope',
    title: 'Tradition, Not Hope',
    description:
        'Thomas tells you about the old fishing contest. Despite everything, the town still holds it each season. Maybe you should enter.',
    type: QuestType.story,
    storyline: 'act1_main',
    storyOrder: 3,
    prerequisiteQuestId: 'act1_02_old_waters',
    objectives: [
      QuestObjective(
        id: 'talk_thomas',
        type: QuestObjectiveType.talkToNpc,
        description: 'Talk to Thomas about the contest',
        targetId: 'npc_thomas',
      ),
      QuestObjective(
        id: 'enter_contest',
        type: QuestObjectiveType.attendEvent,
        description: 'Enter the fishing contest',
        targetId: 'event_fishing_contest',
      ),
    ],
    rewards: QuestRewards(xp: 35),
    questGiver: QuestGiver(type: QuestGiverType.npc, id: 'npc_thomas'),
  );

  /// Quest 4: A Modest Win
  /// First proof the waters still respond
  static const Quest aModestWin = Quest(
    id: 'act1_04_a_modest_win',
    title: 'A Modest Win',
    description:
        'Catch fish during the contest. Show the town—and yourself—that the waters still yield their bounty.',
    type: QuestType.story,
    storyline: 'act1_main',
    storyOrder: 4,
    prerequisiteQuestId: 'act1_03_tradition_not_hope',
    objectives: [
      QuestObjective(
        id: 'contest_catch',
        type: QuestObjectiveType.catchAnyFish,
        description: 'Catch fish during the contest',
        targetAmount: 3,
      ),
    ],
    rewards: QuestRewards(gold: 25, xp: 75),
    questGiver: QuestGiver(type: QuestGiverType.npc, id: 'npc_eli'),
  );

  /// Quest 5: Worth Something Again
  /// Establishes economy loop
  static const Quest worthSomethingAgain = Quest(
    id: 'act1_05_worth_something_again',
    title: 'Worth Something Again',
    description:
        'Lena at the market will buy your fish. Sell enough to make your first payment on the lien.',
    type: QuestType.story,
    storyline: 'act1_main',
    storyOrder: 5,
    prerequisiteQuestId: 'act1_04_a_modest_win',
    objectives: [
      QuestObjective(
        id: 'sell_fish',
        type: QuestObjectiveType.sellFish,
        description: 'Sell fish at the market',
        targetAmount: 50, // Gold worth of fish
      ),
      QuestObjective(
        id: 'first_payment',
        type: QuestObjectiveType.payLien,
        description: 'Make first lien payment',
        targetAmount: 1,
      ),
    ],
    rewards: QuestRewards(xp: 100),
    questGiver: QuestGiver(type: QuestGiverType.npc, id: 'npc_lena'),
  );

  /// Quest 6: Things That Used to Work (Required Side Quest)
  /// Shows rebuilding is possible
  static const Quest thingsThatUsedToWork = Quest(
    id: 'act1_06_things_that_used_to_work',
    title: 'Things That Used to Work',
    description:
        'Mara needs help collecting materials for small repairs around town. Little fixes that add up.',
    type: QuestType.side,
    storyline: 'act1_side',
    storyOrder: 1,
    prerequisiteQuestId: 'act1_05_worth_something_again',
    objectives: [
      QuestObjective(
        id: 'collect_wood',
        type: QuestObjectiveType.collectItem,
        description: 'Collect driftwood',
        targetId: 'item_driftwood',
        targetAmount: 5,
      ),
      QuestObjective(
        id: 'talk_mara',
        type: QuestObjectiveType.talkToNpc,
        description: 'Bring materials to Mara',
        targetId: 'npc_mara',
      ),
    ],
    rewards: QuestRewards(gold: 30, xp: 60),
    questGiver: QuestGiver(type: QuestGiverType.npc, id: 'npc_mara'),
  );

  /// Quest 7: Voices at the Edge (Optional)
  /// Seeds mystery & unease, rune foreshadowing
  static const Quest voicesAtTheEdge = Quest(
    id: 'act1_07_voices_at_the_edge',
    title: 'Voices at the Edge',
    description:
        'Harlan speaks of strange things at the water\'s edge. Fish in an odd spot he mentions—something feels different there.',
    type: QuestType.optional,
    storyline: 'act1_optional',
    storyOrder: 1,
    prerequisiteQuestId: 'act1_04_a_modest_win',
    objectives: [
      QuestObjective(
        id: 'fish_odd_spot',
        type: QuestObjectiveType.catchAnyFish,
        description: 'Fish at the strange spot',
        targetAmount: 1,
      ),
      QuestObjective(
        id: 'talk_harlan',
        type: QuestObjectiveType.talkToNpc,
        description: 'Tell Harlan what you found',
        targetId: 'npc_harlan',
      ),
    ],
    rewards: QuestRewards(xp: 45),
    questGiver: QuestGiver(type: QuestGiverType.npc, id: 'npc_harlan'),
  );

  /// Quest 8: Keeping Records
  /// Reinforces visible progress
  static const Quest keepingRecords = Quest(
    id: 'act1_08_keeping_records',
    title: 'Keeping Records',
    description:
        'Ellie tracks all payments carefully. Make the second lien payment and see your progress recorded.',
    type: QuestType.story,
    storyline: 'act1_main',
    storyOrder: 6,
    prerequisiteQuestId: 'act1_05_worth_something_again',
    objectives: [
      QuestObjective(
        id: 'second_payment',
        type: QuestObjectiveType.payLien,
        description: 'Make second lien payment',
        targetAmount: 1,
      ),
      QuestObjective(
        id: 'talk_ellie_records',
        type: QuestObjectiveType.talkToNpc,
        description: 'Speak with Ellie',
        targetId: 'npc_ellie',
      ),
    ],
    rewards: QuestRewards(xp: 80),
    questGiver: QuestGiver(type: QuestGiverType.npc, id: 'npc_ellie'),
  );

  /// Quest 9: What the Water Remembers (Side)
  /// Introduces legendary fisherman lore
  static const Quest whatTheWaterRemembers = Quest(
    id: 'act1_09_what_the_water_remembers',
    title: 'What the Water Remembers',
    description:
        'Thomas knows old stories about these waters and the fishermen who came before. Ask around town about the past.',
    type: QuestType.side,
    storyline: 'act1_side',
    storyOrder: 2,
    prerequisiteQuestId: 'act1_04_a_modest_win',
    objectives: [
      QuestObjective(
        id: 'talk_thomas_lore',
        type: QuestObjectiveType.talkToNpc,
        description: 'Ask Thomas about the old days',
        targetId: 'npc_thomas',
      ),
      QuestObjective(
        id: 'talk_eli_lore',
        type: QuestObjectiveType.talkToNpc,
        description: 'Ask Eli about the legendary fisherman',
        targetId: 'npc_eli',
      ),
    ],
    rewards: QuestRewards(xp: 50),
    questGiver: QuestGiver(type: QuestGiverType.npc, id: 'npc_thomas'),
  );

  /// Quest 10: The Broken Span
  /// Physical world progression - bridge repair begins
  static const Quest theBrokenSpan = Quest(
    id: 'act1_10_the_broken_span',
    title: 'The Broken Span',
    description:
        'The old bridge has been broken for years. Mara thinks it could be fixed—if someone helped gather what\'s needed.',
    type: QuestType.story,
    storyline: 'act1_main',
    storyOrder: 7,
    prerequisiteQuestId: 'act1_06_things_that_used_to_work',
    objectives: [
      QuestObjective(
        id: 'inspect_bridge',
        type: QuestObjectiveType.visitLocation,
        description: 'Inspect the broken bridge',
        targetId: 'location_broken_bridge',
      ),
      QuestObjective(
        id: 'talk_mara_bridge',
        type: QuestObjectiveType.talkToNpc,
        description: 'Discuss repairs with Mara',
        targetId: 'npc_mara',
      ),
    ],
    rewards: QuestRewards(xp: 65),
    questGiver: QuestGiver(type: QuestGiverType.npc, id: 'npc_mara'),
  );

  /// Quest 11: One More Payment
  /// Ties economy to world change
  static const Quest oneMorePayment = Quest(
    id: 'act1_11_one_more_payment',
    title: 'One More Payment',
    description:
        'The bridge repairs need funding. Earn enough through fishing and selling to cover the materials.',
    type: QuestType.story,
    storyline: 'act1_main',
    storyOrder: 8,
    prerequisiteQuestId: 'act1_10_the_broken_span',
    objectives: [
      QuestObjective(
        id: 'earn_for_bridge',
        type: QuestObjectiveType.sellFish,
        description: 'Earn gold for bridge materials',
        targetAmount: 100,
      ),
      QuestObjective(
        id: 'deliver_funds',
        type: QuestObjectiveType.talkToNpc,
        description: 'Deliver funds to Lena',
        targetId: 'npc_lena',
      ),
    ],
    rewards: QuestRewards(gold: 20, xp: 90),
    questGiver: QuestGiver(type: QuestGiverType.npc, id: 'npc_lena'),
  );

  /// Quest 12: Across the River
  /// Marks end of starter biome - ocean access unlocked
  static const Quest acrossTheRiver = Quest(
    id: 'act1_12_across_the_river',
    title: 'Across the River',
    description:
        'The bridge is ready. Cross to the other side and discover what waters await beyond.',
    type: QuestType.story,
    storyline: 'act1_main',
    storyOrder: 9,
    prerequisiteQuestId: 'act1_11_one_more_payment',
    objectives: [
      QuestObjective(
        id: 'witness_opening',
        type: QuestObjectiveType.attendEvent,
        description: 'Attend the bridge opening',
        targetId: 'event_bridge_opening',
      ),
      QuestObjective(
        id: 'cross_bridge',
        type: QuestObjectiveType.visitLocation,
        description: 'Cross to the other side',
        targetId: 'location_ocean_shore',
      ),
      QuestObjective(
        id: 'talk_eli_ocean',
        type: QuestObjectiveType.talkToNpc,
        description: 'Talk to Eli about the ocean',
        targetId: 'npc_eli',
      ),
    ],
    rewards: QuestRewards(gold: 50, xp: 150),
    questGiver: QuestGiver(type: QuestGiverType.npc, id: 'npc_eli'),
  );

  // ============================================
  // ALL QUESTS MAP
  // ============================================

  /// All quests indexed by ID
  static const Map<String, Quest> all = {
    // Act 1 - Main
    'act1_01_lien_notice': lienNotice,
    'act1_02_old_waters': oldWaters,
    'act1_03_tradition_not_hope': traditionNotHope,
    'act1_04_a_modest_win': aModestWin,
    'act1_05_worth_something_again': worthSomethingAgain,
    'act1_08_keeping_records': keepingRecords,
    'act1_10_the_broken_span': theBrokenSpan,
    'act1_11_one_more_payment': oneMorePayment,
    'act1_12_across_the_river': acrossTheRiver,
    // Act 1 - Side
    'act1_06_things_that_used_to_work': thingsThatUsedToWork,
    'act1_09_what_the_water_remembers': whatTheWaterRemembers,
    // Act 1 - Optional
    'act1_07_voices_at_the_edge': voicesAtTheEdge,
  };

  /// Get quest by ID
  static Quest? get(String id) => all[id];

  /// Get quests by storyline (sorted by story order)
  static List<Quest> getByStoryline(String storyline) {
    final quests =
        all.values.where((q) => q.storyline == storyline).toList();
    quests.sort(
        (a, b) => (a.storyOrder ?? 999).compareTo(b.storyOrder ?? 999));
    return quests;
  }

  /// Get quests for a specific quest giver
  static List<Quest> getByQuestGiver(QuestGiverType type, String id) {
    return all.values
        .where((q) => q.questGiver?.type == type && q.questGiver?.id == id)
        .toList();
  }

  /// Get quests for a sign by sign ID
  static List<Quest> getBySign(String signId) {
    return getByQuestGiver(QuestGiverType.sign, signId);
  }

  /// Get quests for an NPC by NPC ID
  static List<Quest> getByNpc(String npcId) {
    return getByQuestGiver(QuestGiverType.npc, npcId);
  }

  /// Get all main story quests (sorted)
  static List<Quest> get mainStoryQuests {
    return getByStoryline('act1_main');
  }

  /// Get all side quests
  static List<Quest> get sideQuests {
    return all.values.where((q) => q.type == QuestType.side).toList();
  }

  /// Get all optional quests
  static List<Quest> get optionalQuests {
    return all.values.where((q) => q.type == QuestType.optional).toList();
  }

  /// Check if prerequisites are met for a quest
  static bool arePrerequisitesMet(Quest quest, List<QuestProgress> progress) {
    if (quest.prerequisiteQuestId == null) return true;
    return progress.any((p) =>
        p.questId == quest.prerequisiteQuestId && p.isCompleted);
  }

  /// Get available quests (prerequisites met, not started or completed)
  static List<Quest> getAvailable(List<QuestProgress> progress) {
    final startedOrCompletedIds =
        progress.map((p) => p.questId).toSet();

    return all.values.where((quest) {
      // Skip if already started or completed
      if (startedOrCompletedIds.contains(quest.id)) return false;
      // Check prerequisites
      return arePrerequisitesMet(quest, progress);
    }).toList();
  }

  /// Get active quests
  static List<Quest> getActive(List<QuestProgress> progress) {
    final activeIds = progress
        .where((p) => p.isActive)
        .map((p) => p.questId)
        .toSet();

    return all.values.where((q) => activeIds.contains(q.id)).toList();
  }

  /// Get completed quests
  static List<Quest> getCompleted(List<QuestProgress> progress) {
    final completedIds = progress
        .where((p) => p.isCompleted)
        .map((p) => p.questId)
        .toSet();

    return all.values.where((q) => completedIds.contains(q.id)).toList();
  }
}
