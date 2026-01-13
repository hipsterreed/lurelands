import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/constants.dart';

/// Local game save data model - like Stardew Valley's save file
/// All game progress is stored in a single JSON file
class GameSaveData {
  // Player info
  final String playerId;
  final String playerName;
  final int playerColor;
  final double playerX;
  final double playerY;
  final double facingAngle;
  final int gold;
  final String? equippedPoleId;

  // Player stats
  final int level;
  final int xp;
  final int totalFishCaught;
  final int totalGoldEarned;
  final int totalGoldSpent;
  final int totalPlaytimeSeconds;
  final int totalSessions;

  // Inventory (list of item stacks)
  final List<InventoryItem> inventory;

  // Quest progress
  final List<QuestProgress> questProgress;

  // NPC relationships
  final List<NpcRelationship> npcRelationships;

  // Timestamps
  final DateTime createdAt;
  final DateTime lastPlayedAt;

  const GameSaveData({
    required this.playerId,
    required this.playerName,
    required this.playerColor,
    required this.playerX,
    required this.playerY,
    this.facingAngle = 0.0,
    this.gold = 0,
    this.equippedPoleId,
    this.level = 1,
    this.xp = 0,
    this.totalFishCaught = 0,
    this.totalGoldEarned = 0,
    this.totalGoldSpent = 0,
    this.totalPlaytimeSeconds = 0,
    this.totalSessions = 0,
    this.inventory = const [],
    this.questProgress = const [],
    this.npcRelationships = const [],
    required this.createdAt,
    required this.lastPlayedAt,
  });

  /// Create a new save with default values
  factory GameSaveData.newGame({
    required String playerId,
    required String playerName,
    required int playerColor,
    double spawnX = 800.0,
    double spawnY = 800.0,
  }) {
    final now = DateTime.now();
    return GameSaveData(
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
      playerX: spawnX,
      playerY: spawnY,
      gold: 0,
      equippedPoleId: 'pole_1', // Start with basic pole equipped
      level: 1,
      xp: 0,
      inventory: [
        // Start with a basic fishing pole
        const InventoryItem(itemId: 'pole_1', quantity: 1, rarity: 0),
      ],
      questProgress: [],
      npcRelationships: [],
      createdAt: now,
      lastPlayedAt: now,
    );
  }

  /// Create from JSON
  factory GameSaveData.fromJson(Map<String, dynamic> json) {
    return GameSaveData(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      playerColor: json['playerColor'] as int,
      playerX: (json['playerX'] as num).toDouble(),
      playerY: (json['playerY'] as num).toDouble(),
      facingAngle: (json['facingAngle'] as num?)?.toDouble() ?? 0.0,
      gold: json['gold'] as int? ?? 0,
      equippedPoleId: json['equippedPoleId'] as String?,
      level: json['level'] as int? ?? 1,
      xp: json['xp'] as int? ?? 0,
      totalFishCaught: json['totalFishCaught'] as int? ?? 0,
      totalGoldEarned: json['totalGoldEarned'] as int? ?? 0,
      totalGoldSpent: json['totalGoldSpent'] as int? ?? 0,
      totalPlaytimeSeconds: json['totalPlaytimeSeconds'] as int? ?? 0,
      totalSessions: json['totalSessions'] as int? ?? 0,
      inventory: (json['inventory'] as List?)
              ?.map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      questProgress: (json['questProgress'] as List?)
              ?.map((e) => QuestProgress.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      npcRelationships: (json['npcRelationships'] as List?)
              ?.map((e) => NpcRelationship.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastPlayedAt: DateTime.parse(json['lastPlayedAt'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'playerColor': playerColor,
      'playerX': playerX,
      'playerY': playerY,
      'facingAngle': facingAngle,
      'gold': gold,
      'equippedPoleId': equippedPoleId,
      'level': level,
      'xp': xp,
      'totalFishCaught': totalFishCaught,
      'totalGoldEarned': totalGoldEarned,
      'totalGoldSpent': totalGoldSpent,
      'totalPlaytimeSeconds': totalPlaytimeSeconds,
      'totalSessions': totalSessions,
      'inventory': inventory.map((e) => e.toJson()).toList(),
      'questProgress': questProgress.map((e) => e.toJson()).toList(),
      'npcRelationships': npcRelationships.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated values
  GameSaveData copyWith({
    String? playerId,
    String? playerName,
    int? playerColor,
    double? playerX,
    double? playerY,
    double? facingAngle,
    int? gold,
    String? equippedPoleId,
    bool clearEquippedPoleId = false,
    int? level,
    int? xp,
    int? totalFishCaught,
    int? totalGoldEarned,
    int? totalGoldSpent,
    int? totalPlaytimeSeconds,
    int? totalSessions,
    List<InventoryItem>? inventory,
    List<QuestProgress>? questProgress,
    List<NpcRelationship>? npcRelationships,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
  }) {
    return GameSaveData(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      playerColor: playerColor ?? this.playerColor,
      playerX: playerX ?? this.playerX,
      playerY: playerY ?? this.playerY,
      facingAngle: facingAngle ?? this.facingAngle,
      gold: gold ?? this.gold,
      equippedPoleId:
          clearEquippedPoleId ? null : (equippedPoleId ?? this.equippedPoleId),
      level: level ?? this.level,
      xp: xp ?? this.xp,
      totalFishCaught: totalFishCaught ?? this.totalFishCaught,
      totalGoldEarned: totalGoldEarned ?? this.totalGoldEarned,
      totalGoldSpent: totalGoldSpent ?? this.totalGoldSpent,
      totalPlaytimeSeconds: totalPlaytimeSeconds ?? this.totalPlaytimeSeconds,
      totalSessions: totalSessions ?? this.totalSessions,
      inventory: inventory ?? this.inventory,
      questProgress: questProgress ?? this.questProgress,
      npcRelationships: npcRelationships ?? this.npcRelationships,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  /// Get XP required for next level
  int get xpToNextLevel {
    // Simple formula: 100 * level^1.5
    return (100 * (level * 1.5)).round();
  }

  /// Get XP progress as a percentage (0.0 to 1.0)
  double get xpProgress => xpToNextLevel > 0 ? xp / xpToNextLevel : 0.0;
}

/// Inventory item model - compatible with UI panels
class InventoryItem {
  final String itemId;
  final int quantity;
  final int rarity; // 0 for non-fish, 1-3 stars for fish

  const InventoryItem({
    required this.itemId,
    required this.quantity,
    this.rarity = 0,
  });

  /// Unique ID for this item stack (derived from stackKey)
  int get id => stackKey.hashCode;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      itemId: json['itemId'] as String,
      quantity: json['quantity'] as int,
      rarity: json['rarity'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'quantity': quantity,
      'rarity': rarity,
    };
  }

  /// Unique key for this stack (itemId + rarity)
  String get stackKey => '$itemId:$rarity';

  InventoryItem copyWith({
    String? itemId,
    int? quantity,
    int? rarity,
  }) {
    return InventoryItem(
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      rarity: rarity ?? this.rarity,
    );
  }
}

/// Quest progress model
class QuestProgress {
  final String questId;
  final String status; // 'available', 'active', 'completed'
  final Map<String, int> progress; // Fish counts, etc.
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  const QuestProgress({
    required this.questId,
    required this.status,
    this.progress = const {},
    this.acceptedAt,
    this.completedAt,
  });

  factory QuestProgress.fromJson(Map<String, dynamic> json) {
    return QuestProgress(
      questId: json['questId'] as String,
      status: json['status'] as String,
      progress: (json['progress'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.parse(json['acceptedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questId': questId,
      'status': status,
      'progress': progress,
      'acceptedAt': acceptedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  /// Get total fish caught
  int get totalFishCaught => progress['total'] ?? 0;

  /// Get max rarity caught
  int get maxRarityCaught => progress['max_rarity'] ?? 0;

  /// Get specific fish count
  int getFishCount(String fishId) => progress[fishId] ?? 0;

  QuestProgress copyWith({
    String? questId,
    String? status,
    Map<String, int>? progress,
    DateTime? acceptedAt,
    DateTime? completedAt,
  }) {
    return QuestProgress(
      questId: questId ?? this.questId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Check if requirements are met for a quest
  bool areRequirementsMet(Quest quest) {
    // Check specific fish requirements
    for (final entry in quest.requiredFish.entries) {
      if (getFishCount(entry.key) < entry.value) return false;
    }
    // Check total fish requirement
    if (quest.totalFishRequired != null && totalFishCaught < quest.totalFishRequired!) {
      return false;
    }
    // Check min rarity requirement
    if (quest.minRarityRequired != null && maxRarityCaught < quest.minRarityRequired!) {
      return false;
    }
    return true;
  }

  /// Get fish progress map for UI
  Map<String, int> get fishProgress => progress;
}

/// Type alias for backward compatibility with old panel code
typedef PlayerQuest = QuestProgress;

/// Quest definition model - local quest data
class Quest {
  final String id;
  final String title;
  final String description;
  final String questType; // 'story' or 'daily'
  final String? storyline;
  final int? storyOrder;
  final String? prerequisiteQuestId;
  final int goldReward;
  final int xpReward;
  final List<ItemReward> itemRewards;
  final Map<String, int> requiredFish;
  final int? totalFishRequired;
  final int? minRarityRequired;
  final String? questGiverType;
  final String? questGiverId;

  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.questType,
    this.storyline,
    this.storyOrder,
    this.prerequisiteQuestId,
    this.goldReward = 0,
    this.xpReward = 0,
    this.itemRewards = const [],
    this.requiredFish = const {},
    this.totalFishRequired,
    this.minRarityRequired,
    this.questGiverType,
    this.questGiverId,
  });

  bool get isStoryQuest => questType == 'story';
  bool get isDailyQuest => questType == 'daily';
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

/// NPC relationship model
class NpcRelationship {
  final String npcId;
  final bool hasTalked;
  final bool hasTraded;
  final int talkCount;
  final int reputation;
  final DateTime? firstInteractionAt;
  final DateTime? lastInteractionAt;

  const NpcRelationship({
    required this.npcId,
    this.hasTalked = false,
    this.hasTraded = false,
    this.talkCount = 0,
    this.reputation = 0,
    this.firstInteractionAt,
    this.lastInteractionAt,
  });

  factory NpcRelationship.fromJson(Map<String, dynamic> json) {
    return NpcRelationship(
      npcId: json['npcId'] as String,
      hasTalked: json['hasTalked'] as bool? ?? false,
      hasTraded: json['hasTraded'] as bool? ?? false,
      talkCount: json['talkCount'] as int? ?? 0,
      reputation: json['reputation'] as int? ?? 0,
      firstInteractionAt: json['firstInteractionAt'] != null
          ? DateTime.parse(json['firstInteractionAt'] as String)
          : null,
      lastInteractionAt: json['lastInteractionAt'] != null
          ? DateTime.parse(json['lastInteractionAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'npcId': npcId,
      'hasTalked': hasTalked,
      'hasTraded': hasTraded,
      'talkCount': talkCount,
      'reputation': reputation,
      'firstInteractionAt': firstInteractionAt?.toIso8601String(),
      'lastInteractionAt': lastInteractionAt?.toIso8601String(),
    };
  }

  NpcRelationship copyWith({
    String? npcId,
    bool? hasTalked,
    bool? hasTraded,
    int? talkCount,
    int? reputation,
    DateTime? firstInteractionAt,
    DateTime? lastInteractionAt,
  }) {
    return NpcRelationship(
      npcId: npcId ?? this.npcId,
      hasTalked: hasTalked ?? this.hasTalked,
      hasTraded: hasTraded ?? this.hasTraded,
      talkCount: talkCount ?? this.talkCount,
      reputation: reputation ?? this.reputation,
      firstInteractionAt: firstInteractionAt ?? this.firstInteractionAt,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
    );
  }
}

/// Service to manage local game saves
/// Singleton pattern like GameSettings
class GameSaveService {
  GameSaveService._();

  static final GameSaveService instance = GameSaveService._();

  static const String _saveFileName = 'lurelands_save.json';
  static const Duration _autoSaveInterval = Duration(seconds: 30);

  GameSaveData? _currentSave;
  Timer? _autoSaveTimer;
  bool _isDirty = false;
  DateTime? _sessionStartTime;

  // Stream controllers for UI updates
  final _inventoryController = StreamController<List<InventoryItem>>.broadcast();
  final _questProgressController = StreamController<List<QuestProgress>>.broadcast();
  final _statsController = StreamController<GameSaveData>.broadcast();
  final _levelUpController = StreamController<int>.broadcast();

  /// Current save data
  GameSaveData? get currentSave => _currentSave;

  /// Streams for UI
  Stream<List<InventoryItem>> get inventoryUpdates => _inventoryController.stream;
  Stream<List<QuestProgress>> get questProgressUpdates => _questProgressController.stream;
  Stream<GameSaveData> get statsUpdates => _statsController.stream;
  Stream<int> get levelUpStream => _levelUpController.stream;

  /// Current inventory
  List<InventoryItem> get inventory => _currentSave?.inventory ?? [];

  /// Current gold
  int get gold => _currentSave?.gold ?? 0;

  /// Current level
  int get level => _currentSave?.level ?? 1;

  /// Current XP
  int get xp => _currentSave?.xp ?? 0;

  /// XP to next level
  int get xpToNextLevel => _currentSave?.xpToNextLevel ?? 100;

  /// Equipped pole ID
  String? get equippedPoleId => _currentSave?.equippedPoleId;

  /// Quest progress list
  List<QuestProgress> get questProgress => _currentSave?.questProgress ?? [];

  /// NPC relationships
  List<NpcRelationship> get npcRelationships =>
      _currentSave?.npcRelationships ?? [];

  /// Get the save file path
  Future<File> _getSaveFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_saveFileName');
  }

  /// Load save from file or create new
  Future<GameSaveData> loadOrCreateSave({
    required String playerId,
    required String playerName,
    required int playerColor,
    double? spawnX,
    double? spawnY,
  }) async {
    try {
      final file = await _getSaveFile();

      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        _currentSave = GameSaveData.fromJson(json);
        debugPrint('[GameSaveService] Loaded save file');

        // Update session count and last played
        _currentSave = _currentSave!.copyWith(
          totalSessions: _currentSave!.totalSessions + 1,
          lastPlayedAt: DateTime.now(),
          // Update player info in case it changed
          playerName: playerName,
          playerColor: playerColor,
        );
      } else {
        // Create new save
        _currentSave = GameSaveData.newGame(
          playerId: playerId,
          playerName: playerName,
          playerColor: playerColor,
          spawnX: spawnX ?? 800.0,
          spawnY: spawnY ?? 800.0,
        );
        debugPrint('[GameSaveService] Created new save file');
      }

      // Start auto-save timer
      _sessionStartTime = DateTime.now();
      _startAutoSave();

      // Emit initial state
      _emitAllUpdates();

      return _currentSave!;
    } catch (e) {
      debugPrint('[GameSaveService] Error loading save: $e');
      // Create new save on error
      _currentSave = GameSaveData.newGame(
        playerId: playerId,
        playerName: playerName,
        playerColor: playerColor,
        spawnX: spawnX ?? 800.0,
        spawnY: spawnY ?? 800.0,
      );
      _startAutoSave();
      return _currentSave!;
    }
  }

  /// Save to file
  Future<void> save() async {
    if (_currentSave == null) return;

    try {
      // Update playtime before saving
      if (_sessionStartTime != null) {
        final sessionTime = DateTime.now().difference(_sessionStartTime!).inSeconds;
        _currentSave = _currentSave!.copyWith(
          totalPlaytimeSeconds: _currentSave!.totalPlaytimeSeconds + sessionTime,
          lastPlayedAt: DateTime.now(),
        );
        _sessionStartTime = DateTime.now(); // Reset for next interval
      }

      final file = await _getSaveFile();
      final json = jsonEncode(_currentSave!.toJson());
      await file.writeAsString(json);
      _isDirty = false;
      debugPrint('[GameSaveService] Game saved');
    } catch (e) {
      debugPrint('[GameSaveService] Error saving: $e');
    }
  }

  /// Start auto-save timer
  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (_) {
      if (_isDirty) {
        save();
      }
    });
  }

  /// Mark save as dirty (needs saving)
  void _markDirty() {
    _isDirty = true;
  }

  /// Emit all updates to streams
  void _emitAllUpdates() {
    if (_currentSave == null) return;
    _inventoryController.add(_currentSave!.inventory);
    _questProgressController.add(_currentSave!.questProgress);
    _statsController.add(_currentSave!);
  }

  // ================== Player Actions ==================

  /// Update player position
  void updatePlayerPosition(double x, double y, double facingAngle) {
    if (_currentSave == null) return;
    _currentSave = _currentSave!.copyWith(
      playerX: x,
      playerY: y,
      facingAngle: facingAngle,
    );
    _markDirty();
  }

  /// Update player name
  void updatePlayerName(String name) {
    if (_currentSave == null) return;
    _currentSave = _currentSave!.copyWith(playerName: name);
    _markDirty();
    _statsController.add(_currentSave!);
  }

  // ================== Inventory Management ==================

  /// Add item to inventory
  void addItem(String itemId, int quantity, {int rarity = 0}) {
    if (_currentSave == null) return;

    final inventory = List<InventoryItem>.from(_currentSave!.inventory);
    final stackKey = '$itemId:$rarity';
    final existingIndex = inventory.indexWhere((e) => e.stackKey == stackKey);

    if (existingIndex >= 0) {
      // Stack exists - increase quantity
      inventory[existingIndex] = inventory[existingIndex].copyWith(
        quantity: inventory[existingIndex].quantity + quantity,
      );
    } else {
      // New stack
      inventory.add(InventoryItem(
        itemId: itemId,
        quantity: quantity,
        rarity: rarity,
      ));
    }

    _currentSave = _currentSave!.copyWith(inventory: inventory);
    _markDirty();
    _inventoryController.add(inventory);
  }

  /// Remove item from inventory
  bool removeItem(String itemId, int quantity, {int rarity = 0}) {
    if (_currentSave == null) return false;

    final inventory = List<InventoryItem>.from(_currentSave!.inventory);
    final stackKey = '$itemId:$rarity';
    final existingIndex = inventory.indexWhere((e) => e.stackKey == stackKey);

    if (existingIndex < 0) return false;

    final existing = inventory[existingIndex];
    if (existing.quantity < quantity) return false;

    if (existing.quantity == quantity) {
      inventory.removeAt(existingIndex);
    } else {
      inventory[existingIndex] = existing.copyWith(
        quantity: existing.quantity - quantity,
      );
    }

    _currentSave = _currentSave!.copyWith(inventory: inventory);
    _markDirty();
    _inventoryController.add(inventory);
    return true;
  }

  /// Catch a fish (add to inventory and update stats)
  void catchFish(String itemId, int rarity) {
    if (_currentSave == null) return;

    // Add fish to inventory
    addItem(itemId, 1, rarity: rarity);

    // Update stats
    _currentSave = _currentSave!.copyWith(
      totalFishCaught: _currentSave!.totalFishCaught + 1,
    );

    // Add XP for catching fish (more XP for rarer fish)
    final xpGain = 10 * rarity;
    addXp(xpGain);

    // Update active quest progress
    _updateQuestProgressForFish(itemId, rarity);

    _markDirty();
    _statsController.add(_currentSave!);
  }

  /// Update quest progress when catching fish
  void _updateQuestProgressForFish(String fishId, int rarity) {
    if (_currentSave == null) return;

    final questProgressList = List<QuestProgress>.from(_currentSave!.questProgress);
    bool changed = false;

    for (int i = 0; i < questProgressList.length; i++) {
      final qp = questProgressList[i];
      if (qp.isActive) {
        final newProgress = Map<String, int>.from(qp.progress);

        // Update specific fish count
        newProgress[fishId] = (newProgress[fishId] ?? 0) + 1;

        // Update total count
        newProgress['total'] = (newProgress['total'] ?? 0) + 1;

        // Update max rarity if this fish is rarer
        if (rarity > (newProgress['max_rarity'] ?? 0)) {
          newProgress['max_rarity'] = rarity;
        }

        questProgressList[i] = qp.copyWith(progress: newProgress);
        changed = true;
      }
    }

    if (changed) {
      _currentSave = _currentSave!.copyWith(questProgress: questProgressList);
      _questProgressController.add(questProgressList);
    }
  }

  // ================== Gold Management ==================

  /// Add gold
  void addGold(int amount) {
    if (_currentSave == null) return;
    _currentSave = _currentSave!.copyWith(
      gold: _currentSave!.gold + amount,
      totalGoldEarned: _currentSave!.totalGoldEarned + amount,
    );
    _markDirty();
    _statsController.add(_currentSave!);
  }

  /// Spend gold (returns false if not enough)
  bool spendGold(int amount) {
    if (_currentSave == null) return false;
    if (_currentSave!.gold < amount) return false;

    _currentSave = _currentSave!.copyWith(
      gold: _currentSave!.gold - amount,
      totalGoldSpent: _currentSave!.totalGoldSpent + amount,
    );
    _markDirty();
    _statsController.add(_currentSave!);
    return true;
  }

  /// Set gold to specific amount (debug)
  void setGold(int amount) {
    if (_currentSave == null) return;
    _currentSave = _currentSave!.copyWith(gold: amount);
    _markDirty();
    _statsController.add(_currentSave!);
  }

  // ================== Shop Actions ==================

  /// Sell item
  void sellItem(String itemId, int rarity, int quantity) {
    if (_currentSave == null) return;

    final itemDef = GameItems.get(itemId);
    if (itemDef == null) return;

    final sellPrice = itemDef.getSellPrice(rarity);
    final totalGold = sellPrice * quantity;

    if (removeItem(itemId, quantity, rarity: rarity)) {
      addGold(totalGold);
      debugPrint('[GameSaveService] Sold $itemId x$quantity for ${totalGold}g');
    }
  }

  /// Buy item
  bool buyItem(String itemId, int price) {
    if (_currentSave == null) return false;

    if (!spendGold(price)) {
      debugPrint('[GameSaveService] Not enough gold to buy $itemId');
      return false;
    }

    addItem(itemId, 1);
    debugPrint('[GameSaveService] Bought $itemId for ${price}g');
    return true;
  }

  // ================== Equipment ==================

  /// Equip a pole
  void equipPole(String poleItemId) {
    if (_currentSave == null) return;

    // Verify player owns this pole
    final hasItem = _currentSave!.inventory.any((e) => e.itemId == poleItemId);
    if (!hasItem) {
      debugPrint('[GameSaveService] Cannot equip - player does not own $poleItemId');
      return;
    }

    _currentSave = _currentSave!.copyWith(equippedPoleId: poleItemId);
    _markDirty();
    _statsController.add(_currentSave!);
    debugPrint('[GameSaveService] Equipped pole: $poleItemId');
  }

  /// Unequip pole
  void unequipPole() {
    if (_currentSave == null) return;
    _currentSave = _currentSave!.copyWith(clearEquippedPoleId: true);
    _markDirty();
    _statsController.add(_currentSave!);
    debugPrint('[GameSaveService] Unequipped pole');
  }

  // ================== XP & Leveling ==================

  /// Add XP and handle level ups
  void addXp(int amount) {
    if (_currentSave == null) return;

    int newXp = _currentSave!.xp + amount;
    int newLevel = _currentSave!.level;

    // Check for level up
    while (newXp >= _currentSave!.xpToNextLevel) {
      newXp -= _currentSave!.xpToNextLevel;
      newLevel++;
      debugPrint('[GameSaveService] Level up! Now level $newLevel');
      _levelUpController.add(newLevel);
    }

    _currentSave = _currentSave!.copyWith(
      xp: newXp,
      level: newLevel,
    );
    _markDirty();
    _statsController.add(_currentSave!);
  }

  // ================== Quest Management ==================

  /// Accept a quest
  void acceptQuest(String questId) {
    if (_currentSave == null) return;

    // Check if already accepted
    if (_currentSave!.questProgress.any((q) => q.questId == questId)) {
      return;
    }

    final questProgressList = List<QuestProgress>.from(_currentSave!.questProgress);
    questProgressList.add(QuestProgress(
      questId: questId,
      status: 'active',
      progress: {},
      acceptedAt: DateTime.now(),
    ));

    _currentSave = _currentSave!.copyWith(questProgress: questProgressList);
    _markDirty();
    _questProgressController.add(questProgressList);
    debugPrint('[GameSaveService] Accepted quest: $questId');
  }

  /// Complete a quest
  void completeQuest(String questId, {int goldReward = 0, int xpReward = 0}) {
    if (_currentSave == null) return;

    final questProgressList = List<QuestProgress>.from(_currentSave!.questProgress);
    final index = questProgressList.indexWhere((q) => q.questId == questId);

    if (index < 0) return;

    questProgressList[index] = questProgressList[index].copyWith(
      status: 'completed',
      completedAt: DateTime.now(),
    );

    _currentSave = _currentSave!.copyWith(questProgress: questProgressList);

    // Grant rewards
    if (goldReward > 0) addGold(goldReward);
    if (xpReward > 0) addXp(xpReward);

    _markDirty();
    _questProgressController.add(questProgressList);
    debugPrint('[GameSaveService] Completed quest: $questId');
  }

  /// Reset all quests (debug)
  void resetAllQuests() {
    if (_currentSave == null) return;
    _currentSave = _currentSave!.copyWith(questProgress: []);
    _markDirty();
    _questProgressController.add([]);
    debugPrint('[GameSaveService] Reset all quests');
  }

  // ================== NPC Interactions ==================

  /// Record talking to an NPC
  void talkToNpc(String npcId) {
    if (_currentSave == null) return;

    final relationships = List<NpcRelationship>.from(_currentSave!.npcRelationships);
    final index = relationships.indexWhere((r) => r.npcId == npcId);

    final now = DateTime.now();

    if (index >= 0) {
      relationships[index] = relationships[index].copyWith(
        hasTalked: true,
        talkCount: relationships[index].talkCount + 1,
        reputation: relationships[index].reputation + 1,
        lastInteractionAt: now,
      );
    } else {
      relationships.add(NpcRelationship(
        npcId: npcId,
        hasTalked: true,
        talkCount: 1,
        reputation: 1,
        firstInteractionAt: now,
        lastInteractionAt: now,
      ));
    }

    _currentSave = _currentSave!.copyWith(npcRelationships: relationships);
    _markDirty();
  }

  // ================== Delete Save ==================

  /// Delete save file (for starting fresh)
  Future<void> deleteSave() async {
    try {
      final file = await _getSaveFile();
      if (await file.exists()) {
        await file.delete();
        debugPrint('[GameSaveService] Save file deleted');
      }
      _currentSave = null;
    } catch (e) {
      debugPrint('[GameSaveService] Error deleting save: $e');
    }
  }

  /// Check if save exists
  Future<bool> hasSave() async {
    final file = await _getSaveFile();
    return file.exists();
  }

  // ================== Cleanup ==================

  /// Dispose resources
  void dispose() {
    // Save before disposing
    if (_isDirty) {
      save();
    }
    _autoSaveTimer?.cancel();
    _inventoryController.close();
    _questProgressController.close();
    _statsController.close();
    _levelUpController.close();
  }
}
