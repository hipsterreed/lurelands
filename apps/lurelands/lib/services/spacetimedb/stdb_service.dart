import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/player_state.dart';
import '../../models/water_body_data.dart';

/// Represents an inventory entry from the server
class InventoryEntry {
  final int id;
  final String playerId;
  final String itemId;
  final int rarity; // 1-3 stars for fish, 0 for non-fish
  final int quantity;

  const InventoryEntry({
    required this.id,
    required this.playerId,
    required this.itemId,
    required this.rarity,
    required this.quantity,
  });

  factory InventoryEntry.fromJson(Map<String, dynamic> json) => InventoryEntry(
        id: json['id'] as int,
        playerId: json['playerId'] as String,
        itemId: json['itemId'] as String,
        rarity: json['rarity'] as int,
        quantity: json['quantity'] as int,
      );

  /// Unique key for this stack (itemId + rarity)
  String get stackKey => '$itemId:$rarity';
}

/// Represents a quest definition from the server
class Quest {
  final String id;
  final String title;
  final String description;
  final String questType; // 'story' or 'daily'
  final String? storyline;
  final int? storyOrder;
  final String? prerequisiteQuestId;
  final String requirements; // JSON string
  final String rewards; // JSON string
  // Quest giver system
  final String? questGiverType; // 'npc', 'sign', or null (any sign with matching storyline)
  final String? questGiverId; // NPC ID or Sign ID

  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.questType,
    this.storyline,
    this.storyOrder,
    this.prerequisiteQuestId,
    required this.requirements,
    required this.rewards,
    this.questGiverType,
    this.questGiverId,
  });

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        questType: json['questType'] as String,
        storyline: json['storyline'] as String?,
        storyOrder: json['storyOrder'] as int?,
        prerequisiteQuestId: json['prerequisiteQuestId'] as String?,
        requirements: json['requirements'] as String,
        rewards: json['rewards'] as String,
        questGiverType: json['questGiverType'] as String?,
        questGiverId: json['questGiverId'] as String?,
      );

  /// Parse requirements JSON to get required fish counts
  Map<String, int> get requiredFish {
    try {
      final req = jsonDecode(requirements) as Map<String, dynamic>;
      final fish = req['fish'] as Map<String, dynamic>?;
      if (fish == null) return {};
      return fish.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  /// Get total fish requirement if specified
  int? get totalFishRequired {
    try {
      final req = jsonDecode(requirements) as Map<String, dynamic>;
      return req['total_fish'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Get minimum rarity requirement if specified
  int? get minRarityRequired {
    try {
      final req = jsonDecode(requirements) as Map<String, dynamic>;
      return req['min_rarity'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Parse rewards JSON to get gold amount
  int get goldReward {
    try {
      final rew = jsonDecode(rewards) as Map<String, dynamic>;
      return rew['gold'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Parse rewards JSON to get XP amount
  int get xpReward {
    try {
      final rew = jsonDecode(rewards) as Map<String, dynamic>;
      return rew['xp'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Parse rewards JSON to get item rewards
  List<({String itemId, int quantity})> get itemRewards {
    try {
      final rew = jsonDecode(rewards) as Map<String, dynamic>;
      final items = rew['items'] as List?;
      if (items == null) return [];
      return items.map((item) {
        final m = item as Map<String, dynamic>;
        return (
          itemId: m['item_id'] as String,
          quantity: m['quantity'] as int? ?? 1,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  bool get isStoryQuest => questType == 'story';
  bool get isDailyQuest => questType == 'daily';
}

/// Represents a player's progress on a quest
class PlayerQuest {
  final int id;
  final String playerId;
  final String questId;
  final String status; // 'available', 'active', 'completed'
  final String progress; // JSON string
  final int? acceptedAt; // Unix timestamp (microseconds)
  final int? completedAt; // Unix timestamp (microseconds)

  const PlayerQuest({
    required this.id,
    required this.playerId,
    required this.questId,
    required this.status,
    required this.progress,
    this.acceptedAt,
    this.completedAt,
  });

  factory PlayerQuest.fromJson(Map<String, dynamic> json) => PlayerQuest(
        id: json['id'] as int,
        playerId: json['playerId'] as String,
        questId: json['questId'] as String,
        status: json['status'] as String,
        progress: json['progress'] as String,
        acceptedAt: json['acceptedAt'] as int?,
        completedAt: json['completedAt'] as int?,
      );

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  /// Parse progress JSON to get fish counts
  Map<String, int> get fishProgress {
    try {
      final prog = jsonDecode(progress) as Map<String, dynamic>;
      return prog.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  /// Get total fish caught
  int get totalFishCaught => fishProgress['total'] ?? 0;

  /// Get max rarity caught
  int get maxRarityCaught => fishProgress['max_rarity'] ?? 0;

  /// Check if quest requirements are met
  bool areRequirementsMet(Quest quest) {
    // Check specific fish requirements
    for (final entry in quest.requiredFish.entries) {
      final caught = fishProgress[entry.key] ?? 0;
      if (caught < entry.value) return false;
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
}

/// Player stats including level and XP
class PlayerStats {
  final String playerId;
  final int totalPlaytimeSeconds;
  final int totalSessions;
  final int totalFishCaught;
  final int totalGoldEarned;
  final int totalGoldSpent;
  final int firstSeenAt; // Unix timestamp (microseconds)
  final int lastSeenAt; // Unix timestamp (microseconds)
  final int level;
  final int xp;
  final int xpToNextLevel;

  const PlayerStats({
    required this.playerId,
    required this.totalPlaytimeSeconds,
    required this.totalSessions,
    required this.totalFishCaught,
    required this.totalGoldEarned,
    required this.totalGoldSpent,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.level,
    required this.xp,
    required this.xpToNextLevel,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
        playerId: json['playerId'] as String,
        totalPlaytimeSeconds: json['totalPlaytimeSeconds'] as int? ?? 0,
        totalSessions: json['totalSessions'] as int? ?? 0,
        totalFishCaught: json['totalFishCaught'] as int? ?? 0,
        totalGoldEarned: json['totalGoldEarned'] as int? ?? 0,
        totalGoldSpent: json['totalGoldSpent'] as int? ?? 0,
        firstSeenAt: json['firstSeenAt'] as int? ?? 0,
        lastSeenAt: json['lastSeenAt'] as int? ?? 0,
        level: json['level'] as int? ?? 1,
        xp: json['xp'] as int? ?? 0,
        xpToNextLevel: json['xpToNextLevel'] as int? ?? 100,
      );

  /// Get XP progress as a percentage (0.0 to 1.0)
  double get xpProgress => xpToNextLevel > 0 ? xp / xpToNextLevel : 0.0;
}

/// Level up event data
class LevelUpEvent {
  final String playerId;
  final int newLevel;
  final int xp;
  final int xpToNextLevel;

  const LevelUpEvent({
    required this.playerId,
    required this.newLevel,
    required this.xp,
    required this.xpToNextLevel,
  });

  factory LevelUpEvent.fromJson(Map<String, dynamic> json) => LevelUpEvent(
        playerId: json['playerId'] as String,
        newLevel: json['newLevel'] as int,
        xp: json['xp'] as int,
        xpToNextLevel: json['xpToNextLevel'] as int,
      );
}

/// NPC definition from the server
class Npc {
  final String id;
  final String name;
  final String? title;
  final String? description;
  final double? locationX;
  final double? locationY;
  final String? spriteId;
  final bool canGiveQuests;
  final bool canTrade;
  final bool isActive;

  const Npc({
    required this.id,
    required this.name,
    this.title,
    this.description,
    this.locationX,
    this.locationY,
    this.spriteId,
    required this.canGiveQuests,
    required this.canTrade,
    required this.isActive,
  });

  factory Npc.fromJson(Map<String, dynamic> json) => Npc(
        id: json['id'] as String,
        name: json['name'] as String,
        title: json['title'] as String?,
        description: json['description'] as String?,
        locationX: (json['locationX'] as num?)?.toDouble(),
        locationY: (json['locationY'] as num?)?.toDouble(),
        spriteId: json['spriteId'] as String?,
        canGiveQuests: json['canGiveQuests'] as bool? ?? false,
        canTrade: json['canTrade'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
      );

  /// Check if NPC has a valid world position
  bool get hasPosition => locationX != null && locationY != null;
}

/// Player's interaction history with an NPC
class PlayerNpcInteraction {
  final int id;
  final String playerId;
  final String npcId;
  final bool hasTalked;
  final bool hasTraded;
  final int talkCount;
  final int reputation;
  final int firstInteractionAt;
  final int lastInteractionAt;

  const PlayerNpcInteraction({
    required this.id,
    required this.playerId,
    required this.npcId,
    required this.hasTalked,
    required this.hasTraded,
    required this.talkCount,
    required this.reputation,
    required this.firstInteractionAt,
    required this.lastInteractionAt,
  });

  factory PlayerNpcInteraction.fromJson(Map<String, dynamic> json) =>
      PlayerNpcInteraction(
        id: json['id'] as int,
        playerId: json['playerId'] as String,
        npcId: json['npcId'] as String,
        hasTalked: json['hasTalked'] as bool? ?? false,
        hasTraded: json['hasTraded'] as bool? ?? false,
        talkCount: json['talkCount'] as int? ?? 0,
        reputation: json['reputation'] as int? ?? 0,
        firstInteractionAt: json['firstInteractionAt'] as int? ?? 0,
        lastInteractionAt: json['lastInteractionAt'] as int? ?? 0,
      );
}

/// Connection state for SpacetimeDB
enum StdbConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Connection quality based on latency
enum ConnectionQuality {
  excellent, // < 100ms
  good,      // 100-200ms
  fair,      // 200-500ms
  poor,      // 500-1000ms
  critical,  // > 1000ms or packet loss
}

/// Data received from SpacetimeDB containing world state
class WorldState {
  final List<PondData> ponds;
  final List<RiverData> rivers;
  final OceanData? ocean;
  final List<SpawnPointData> spawnPoints;

  const WorldState({
    this.ponds = const [],
    this.rivers = const [],
    this.ocean,
    this.spawnPoints = const [],
  });

  factory WorldState.fromJson(Map<String, dynamic> json) {
    final pondsJson = json['ponds'] as List? ?? [];
    final riversJson = json['rivers'] as List? ?? [];
    final oceanJson = json['ocean'] as Map<String, dynamic>?;
    final spawnPointsJson = json['spawnPoints'] as List? ?? [];

    return WorldState(
      ponds: pondsJson.map((e) => PondData.fromJson(e as Map<String, dynamic>)).toList(),
      rivers: riversJson.map((e) => RiverData.fromJson(e as Map<String, dynamic>)).toList(),
      ocean: oceanJson != null ? OceanData.fromJson(oceanJson) : null,
      spawnPoints: spawnPointsJson.map((e) => SpawnPointData.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Spawn point data from the server
class SpawnPointData {
  final String id;
  final double x;
  final double y;
  final String name;

  const SpawnPointData({
    required this.id,
    required this.x,
    required this.y,
    required this.name,
  });

  factory SpawnPointData.fromJson(Map<String, dynamic> json) => SpawnPointData(
        id: json['id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        name: json['name'] as String? ?? 'Spawn Point',
      );
}

/// Abstract interface for SpacetimeDB communication.
abstract class SpacetimeDBService {
  /// Connect to the SpacetimeDB server
  Future<bool> connect(String serverUrl);

  /// Disconnect from the server
  Future<void> disconnect();

  /// Check bridge health and SpacetimeDB connection status
  /// Returns a record with status info, or null if health check failed
  Future<({String status, String spacetimedb, bool healthy})> checkHealth(String bridgeUrl);

  /// Check if currently connected
  bool get isConnected;

  /// Current connection state
  StdbConnectionState get state;

  /// Join the game world with a player ID
  /// Returns the spawn position assigned by the server
  Future<({double x, double y})?> joinWorld(String playerId, String name, int color);

  /// Leave the game world
  Future<void> leaveWorld();

  /// Update the local player's position
  void updatePlayerPosition(double x, double y, double facingAngle);

  /// Log when player stops moving (for debugging without flooding logs)
  void logMovementStopped(double x, double y);

  /// Notify that player started casting
  void startCasting(double targetX, double targetY);

  /// Notify that player stopped casting / reeled in
  void stopCasting();

  /// Update the player's display name
  void updatePlayerName(String name);

  /// Fetch player data from the database by player ID
  /// Returns null if player doesn't exist
  Future<PlayerState?> fetchPlayerData(String playerId);

  /// Get the world state (water bodies, spawn points)
  WorldState get worldState;

  /// Stream of all player states (including local player)
  Stream<List<PlayerState>> get playerUpdates;

  /// Stream of connection state changes
  Stream<StdbConnectionState> get connectionStateStream;

  /// Stream of world state updates
  Stream<WorldState> get worldStateUpdates;

  /// Stream of inventory updates
  Stream<List<InventoryEntry>> get inventoryUpdates;

  /// Current inventory items
  List<InventoryEntry> get inventory;

  /// Notify that player caught a fish
  void catchFish(String itemId, int rarity, String waterBodyId);

  /// Request inventory refresh
  void requestInventory();

  /// Sell an item from inventory
  void sellItem(String itemId, int rarity, int quantity);

  /// Buy an item from the shop
  void buyItem(String itemId, int price);

  /// Equip a fishing pole from inventory
  void equipPole(String poleItemId);

  /// Unequip the currently equipped fishing pole
  void unequipPole();

  /// Set player's gold to a specific amount (debug function)
  void setGold(int amount);

  // Quest methods
  
  /// Stream of quest updates
  Stream<({List<Quest> quests, List<PlayerQuest> playerQuests})> get questUpdates;

  /// Current list of all quests
  List<Quest> get quests;

  /// Current list of player's quest progress
  List<PlayerQuest> get playerQuests;

  /// Accept a quest
  void acceptQuest(String questId);

  /// Complete a quest
  void completeQuest(String questId);

  /// Request quest refresh
  void requestQuests();

  /// Reset all quests for the player (debug feature)
  void resetAllQuests();

  // Player stats methods

  /// Current player stats (null if not yet received)
  PlayerStats? get playerStats;

  /// Stream of player stats updates
  Stream<PlayerStats> get playerStatsStream;

  /// Stream of level up events
  Stream<LevelUpEvent> get levelUpStream;

  // NPC methods

  /// Current list of all NPCs
  List<Npc> get npcs;

  /// Current list of player's NPC interactions
  List<PlayerNpcInteraction> get npcInteractions;

  /// Stream of NPC updates
  Stream<({List<Npc> npcs, List<PlayerNpcInteraction> interactions})> get npcUpdates;

  /// Request NPC data refresh
  void requestNpcs();

  /// Record talking to an NPC
  void talkToNpc(String npcId);

  // Connection health methods

  /// Current connection quality based on latency
  ConnectionQuality get connectionQuality;

  /// Stream of connection quality changes
  Stream<ConnectionQuality> get connectionQualityStream;

  /// Current latency in milliseconds
  int get latencyMs;

  /// Request a full state resync from server
  void requestResync();

  /// Dispose resources
  void dispose();
}

/// Bridge-based SpacetimeDB service implementation.
/// Connects to the Bun/Elysia bridge which handles SpacetimeDB communication.
class BridgeSpacetimeDBService implements SpacetimeDBService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  StdbConnectionState _state = StdbConnectionState.disconnected;
  String? _playerId;
  Timer? _reconnectTimer;
  String? _serverUrl;
  Completer<({double x, double y})?>? _spawnCompleter;

  // Local state
  PlayerState? _localPlayer;
  final Map<String, PlayerState> _players = {};
  WorldState _worldState = const WorldState();
  List<InventoryEntry> _inventory = [];
  List<Quest> _quests = [];
  List<PlayerQuest> _playerQuests = [];
  PlayerStats? _playerStats;
  List<Npc> _npcs = [];
  List<PlayerNpcInteraction> _npcInteractions = [];

  // Stream controllers
  final _playerUpdatesController = StreamController<List<PlayerState>>.broadcast();
  final _connectionStateController = StreamController<StdbConnectionState>.broadcast();
  final _worldStateController = StreamController<WorldState>.broadcast();
  final _inventoryController = StreamController<List<InventoryEntry>>.broadcast();
  final _questController = StreamController<({List<Quest> quests, List<PlayerQuest> playerQuests})>.broadcast();
  final _playerStatsController = StreamController<PlayerStats>.broadcast();
  final _levelUpController = StreamController<LevelUpEvent>.broadcast();
  final _npcController = StreamController<({List<Npc> npcs, List<PlayerNpcInteraction> interactions})>.broadcast();

  // Throttle position updates to avoid flooding
  DateTime? _lastPositionUpdate;
  static const _positionUpdateInterval = Duration(milliseconds: 50); // 20 updates/sec max

  // Heartbeat for connection health
  Timer? _heartbeatTimer;
  DateTime? _lastPong;
  int _missedPongs = 0;
  static const _heartbeatInterval = Duration(seconds: 15);
  static const _maxMissedPongs = 2;

  // Reconnection with exponential backoff
  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = Duration(seconds: 60);
  static const _baseReconnectDelay = Duration(seconds: 1);

  // Connection quality tracking
  ConnectionQuality _connectionQuality = ConnectionQuality.excellent;
  int _latencyMs = 0;
  final List<int> _recentLatencies = [];
  final _connectionQualityController = StreamController<ConnectionQuality>.broadcast();

  @override
  StdbConnectionState get state => _state;

  @override
  bool get isConnected => _state == StdbConnectionState.connected;

  @override
  WorldState get worldState => _worldState;

  @override
  Stream<List<PlayerState>> get playerUpdates => _playerUpdatesController.stream;

  @override
  Stream<StdbConnectionState> get connectionStateStream => _connectionStateController.stream;

  @override
  Stream<WorldState> get worldStateUpdates => _worldStateController.stream;

  @override
  Stream<List<InventoryEntry>> get inventoryUpdates => _inventoryController.stream;

  @override
  List<InventoryEntry> get inventory => _inventory;

  @override
  Stream<({List<Quest> quests, List<PlayerQuest> playerQuests})> get questUpdates => _questController.stream;

  @override
  List<Quest> get quests => _quests;

  @override
  List<PlayerQuest> get playerQuests => _playerQuests;

  @override
  PlayerStats? get playerStats => _playerStats;

  @override
  Stream<PlayerStats> get playerStatsStream => _playerStatsController.stream;

  @override
  Stream<LevelUpEvent> get levelUpStream => _levelUpController.stream;

  @override
  List<Npc> get npcs => _npcs;

  @override
  List<PlayerNpcInteraction> get npcInteractions => _npcInteractions;

  @override
  Stream<({List<Npc> npcs, List<PlayerNpcInteraction> interactions})> get npcUpdates => _npcController.stream;

  @override
  ConnectionQuality get connectionQuality => _connectionQuality;

  @override
  Stream<ConnectionQuality> get connectionQualityStream => _connectionQualityController.stream;

  @override
  int get latencyMs => _latencyMs;

  void _setState(StdbConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _connectionStateController.add(newState);
    }
  }

  @override
  Future<bool> connect(String serverUrl) async {
    print('[Bridge] connect() called with: $serverUrl');
    
    if (_state == StdbConnectionState.connecting || _state == StdbConnectionState.connected) {
      print('[Bridge] Already connecting/connected, returning ${_state == StdbConnectionState.connected}');
      return _state == StdbConnectionState.connected;
    }

    _serverUrl = serverUrl;
    _setState(StdbConnectionState.connecting);

    try {
      // Connect to bridge WebSocket endpoint
      print('[Bridge] Parsing URI and connecting...');
      final uri = Uri.parse(serverUrl);
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection with timeout
      print('[Bridge] Waiting for WebSocket ready...');
      await _channel!.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('[Bridge] Connection TIMED OUT');
          throw TimeoutException('Connection timed out');
        },
      );

      print('[Bridge] WebSocket ready! Setting up listener...');
      
      // Set up message listener
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _setState(StdbConnectionState.connected);
      _reconnectAttempts = 0; // Reset on successful connection
      _startHeartbeat();
      debugPrint('[Bridge] Connected successfully!');
      return true;
    } catch (e) {
      debugPrint('[Bridge] Connection error: $e');
      _setState(StdbConnectionState.error);
      await _cleanup();
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    await _cleanup();
    _setState(StdbConnectionState.disconnected);
  }

  Future<void> _cleanup() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  Future<({String status, String spacetimedb, bool healthy})> checkHealth(String bridgeUrl) async {
    try {
      // Convert ws:// to http:// for health check
      final httpUrl = bridgeUrl
          .replaceFirst('wss://', 'https://')
          .replaceFirst('ws://', 'http://')
          .replaceFirst('/ws', '/health');

      debugPrint('[Bridge] Health check: $httpUrl');

      final response = await http.get(Uri.parse(httpUrl)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Health check timed out'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'unknown';
        final spacetimedb = data['spacetimedb'] as String? ?? 'unknown';
        final healthy = status == 'ok' && spacetimedb == 'connected';

        debugPrint('[Bridge] Health check result: status=$status, spacetimedb=$spacetimedb, healthy=$healthy');

        return (status: status, spacetimedb: spacetimedb, healthy: healthy);
      } else {
        debugPrint('[Bridge] Health check failed: ${response.statusCode}');
        return (status: 'error', spacetimedb: 'unknown', healthy: false);
      }
    } catch (e) {
      debugPrint('[Bridge] Health check error: $e');
      return (status: 'error', spacetimedb: 'unreachable', healthy: false);
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = message is String ? jsonDecode(message) : message;
      final type = (data as Map<String, dynamic>)['type'] as String?;
      // Skip logging for frequent player position updates
      if (type != 'players') {
        print('[Bridge] Received message: $message');
      }
      _handleMessage(data);
    } catch (e) {
      print('[Bridge] Error parsing message: $e');
    }
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    // Skip logging for frequent player position updates
    if (type != 'players') {
      print('[Bridge] Handling message type: $type');
    }

    switch (type) {
      case 'connected':
        print('[Bridge] Server confirmed connection');
        break;

      case 'world_state':
        final worldData = data['data'] as Map<String, dynamic>?;
        if (worldData != null) {
          _worldState = WorldState.fromJson(worldData);
          _worldStateController.add(_worldState);
        }
        break;

      case 'spawn':
        final x = (data['x'] as num?)?.toDouble();
        final y = (data['y'] as num?)?.toDouble();
        if (x != null && y != null) {
          _spawnCompleter?.complete((x: x, y: y));
          _spawnCompleter = null;
          
          // Update local player position
          if (_localPlayer != null) {
            _localPlayer = _localPlayer!.copyWith(x: x, y: y);
            _players[_localPlayer!.id] = _localPlayer!;
            _emitPlayerUpdate();
          }
        }
        break;

      case 'players':
        final playersData = data['players'] as List?;
        if (playersData != null) {
          // Preserve local player's equipped pole state before clearing
          final preservedPoleId = _localPlayer?.equippedPoleId;
          final preservedPoleTier = _localPlayer?.equippedPoleTier ?? 1;
          
          _players.clear();
          for (final playerJson in playersData) {
            final player = _parsePlayer(playerJson as Map<String, dynamic>);
            // For local player, preserve our equipped pole state to avoid flicker
            if (player.id == _playerId && preservedPoleId != null) {
              final updatedLocal = player.copyWith(
                equippedPoleId: preservedPoleId,
                equippedPoleTier: preservedPoleTier,
              );
              _localPlayer = updatedLocal;
              _players[player.id] = updatedLocal;
            } else {
              _players[player.id] = player;
              // Update _localPlayer reference if this is the local player
              if (player.id == _playerId) {
                _localPlayer = player;
              }
            }
          }
          _emitPlayerUpdate();
        }
        break;

      case 'player_joined':
        final playerData = data['player'] as Map<String, dynamic>?;
        if (playerData != null) {
          final player = _parsePlayer(playerData);
          _players[player.id] = player;
          _emitPlayerUpdate();
        }
        break;

      case 'player_left':
        final playerId = data['playerId'] as String?;
        if (playerId != null) {
          _players.remove(playerId);
          _emitPlayerUpdate();
        }
        break;

      case 'player_updated':
        final playerData = data['player'] as Map<String, dynamic>?;
        if (playerData != null) {
          final player = _parsePlayer(playerData);
          // For local player, preserve our equipped pole state to avoid flicker
          // from server broadcasts that may have stale data
          if (player.id == _playerId && _localPlayer != null) {
            final updatedLocal = player.copyWith(
              equippedPoleId: _localPlayer!.equippedPoleId,
              equippedPoleTier: _localPlayer!.equippedPoleTier,
            );
            _localPlayer = updatedLocal;
            _players[player.id] = updatedLocal;
          } else {
            _players[player.id] = player;
          }
          _emitPlayerUpdate();
        }
        break;

      case 'player_data':
        final playerData = data['player'] as Map<String, dynamic>?;
        if (_fetchPlayerCompleter != null) {
          if (playerData != null) {
            final player = _parsePlayer(playerData);
            _fetchPlayerCompleter!.complete(player);
          } else {
            _fetchPlayerCompleter!.complete(null);
          }
        }
        break;

      case 'fish_caught':
        // Handle fish caught notification (for future UI)
        debugPrint('[Bridge] Fish caught notification received');
        break;

      case 'inventory':
        final itemsData = data['items'] as List?;
        if (itemsData != null) {
          _inventory = itemsData
              .map((e) => InventoryEntry.fromJson(e as Map<String, dynamic>))
              .toList();
          _inventoryController.add(_inventory);
          debugPrint('[Bridge] Inventory updated: ${_inventory.length} stacks');
        }
        break;

      case 'inventory_updated':
        final itemData = data['item'] as Map<String, dynamic>?;
        if (itemData != null) {
          final updatedItem = InventoryEntry.fromJson(itemData);
          // Update or add the item in our local list (use id for uniqueness since items may not stack)
          final index = _inventory.indexWhere((e) => e.id == updatedItem.id);
          if (index >= 0) {
            _inventory[index] = updatedItem;
          } else {
            _inventory.add(updatedItem);
          }
          _inventoryController.add(_inventory);
          debugPrint('[Bridge] Inventory item updated: ${updatedItem.itemId} x${updatedItem.quantity}');
        }
        break;

      case 'error':
        final errorMessage = data['message'] as String?;
        if (errorMessage != null) {
          print('[Bridge] Error: $errorMessage');
        }
        break;

      case 'quests':
        final questsData = data['quests'] as List?;
        final playerQuestsData = data['playerQuests'] as List?;
        if (questsData != null) {
          _quests = questsData
              .map((e) => Quest.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        if (playerQuestsData != null) {
          _playerQuests = playerQuestsData
              .map((e) => PlayerQuest.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        _questController.add((quests: _quests, playerQuests: _playerQuests));
        debugPrint('[Bridge] Quests updated: ${_quests.length} quests, ${_playerQuests.length} player quests');
        break;

      case 'quest_updated':
        final pqData = data['playerQuest'] as Map<String, dynamic>?;
        if (pqData != null) {
          final updatedPq = PlayerQuest.fromJson(pqData);
          // Update or add the player quest
          final index = _playerQuests.indexWhere((pq) => pq.questId == updatedPq.questId);
          if (index >= 0) {
            _playerQuests[index] = updatedPq;
          } else {
            _playerQuests.add(updatedPq);
          }
          _questController.add((quests: _quests, playerQuests: _playerQuests));
          debugPrint('[Bridge] Player quest updated: ${updatedPq.questId} -> ${updatedPq.status}');
        }
        break;

      case 'player_stats':
        final statsData = data['stats'] as Map<String, dynamic>?;
        if (statsData != null) {
          _playerStats = PlayerStats.fromJson(statsData);
          _playerStatsController.add(_playerStats!);
          debugPrint('[Bridge] Player stats updated: Level ${_playerStats!.level}, XP ${_playerStats!.xp}/${_playerStats!.xpToNextLevel}');
        }
        break;

      case 'level_up':
        final levelUpData = LevelUpEvent.fromJson(data);
        // Also update local stats cache
        if (_playerStats != null && levelUpData.playerId == _playerStats!.playerId) {
          _playerStats = PlayerStats(
            playerId: _playerStats!.playerId,
            totalPlaytimeSeconds: _playerStats!.totalPlaytimeSeconds,
            totalSessions: _playerStats!.totalSessions,
            totalFishCaught: _playerStats!.totalFishCaught,
            totalGoldEarned: _playerStats!.totalGoldEarned,
            totalGoldSpent: _playerStats!.totalGoldSpent,
            firstSeenAt: _playerStats!.firstSeenAt,
            lastSeenAt: _playerStats!.lastSeenAt,
            level: levelUpData.newLevel,
            xp: levelUpData.xp,
            xpToNextLevel: levelUpData.xpToNextLevel,
          );
          _playerStatsController.add(_playerStats!);
        }
        _levelUpController.add(levelUpData);
        debugPrint('[Bridge] Level up! New level: ${levelUpData.newLevel}');
        break;

      case 'npcs':
        final npcsData = data['npcs'] as List?;
        final interactionsData = data['playerNpcInteractions'] as List?;
        if (npcsData != null) {
          _npcs = npcsData
              .map((e) => Npc.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        if (interactionsData != null) {
          _npcInteractions = interactionsData
              .map((e) => PlayerNpcInteraction.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        _npcController.add((npcs: _npcs, interactions: _npcInteractions));
        debugPrint('[Bridge] NPCs updated: ${_npcs.length} npcs, ${_npcInteractions.length} interactions');
        break;

      case 'npc_interaction_updated':
        final interactionData = data['interaction'] as Map<String, dynamic>?;
        if (interactionData != null) {
          final updatedInteraction = PlayerNpcInteraction.fromJson(interactionData);
          // Update or add the interaction
          final index = _npcInteractions.indexWhere(
            (i) => i.npcId == updatedInteraction.npcId && i.playerId == updatedInteraction.playerId,
          );
          if (index >= 0) {
            _npcInteractions[index] = updatedInteraction;
          } else {
            _npcInteractions.add(updatedInteraction);
          }
          _npcController.add((npcs: _npcs, interactions: _npcInteractions));
          debugPrint('[Bridge] NPC interaction updated: ${updatedInteraction.npcId}');
        }
        break;

      case 'pong':
        _lastPong = DateTime.now();
        _missedPongs = 0;
        // Calculate round-trip latency
        final sentAt = data['timestamp'] as int?;
        if (sentAt != null) {
          final latency = DateTime.now().millisecondsSinceEpoch - sentAt;
          _updateConnectionQuality(latency);
        }
        break;
    }
  }

  PlayerState _parsePlayer(Map<String, dynamic> json) {
    final equippedPoleId = json['equippedPoleId'] as String?;
    // Derive equippedPoleTier from equippedPoleId if present
    int poleTier = 1;
    if (equippedPoleId != null && equippedPoleId.startsWith('pole_')) {
      poleTier = int.tryParse(equippedPoleId.split('_').last) ?? 1;
    }
    
    return PlayerState(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Player',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      facingAngle: (json['facingAngle'] as num?)?.toDouble() ?? 0.0,
      isCasting: json['isCasting'] as bool? ?? false,
      castTargetX: (json['castTargetX'] as num?)?.toDouble(),
      castTargetY: (json['castTargetY'] as num?)?.toDouble(),
      color: json['color'] as int? ?? 0xFFE74C3C,
      isOnline: json['isOnline'] as bool? ?? true,
      gold: json['gold'] as int? ?? 0,
      equippedPoleTier: poleTier,
      equippedPoleId: equippedPoleId,
    );
  }

  void _onError(Object error, StackTrace? stackTrace) {
    debugPrint('[Bridge] WebSocket ERROR: $error');
    if (stackTrace != null) {
      debugPrint('[Bridge] Stack trace: $stackTrace');
    }
    _stopHeartbeat();
    _setState(StdbConnectionState.error);
    _scheduleReconnect();
  }

  void _onDone() {
    final closeCode = _channel?.closeCode;
    final closeReason = _channel?.closeReason;
    debugPrint('[Bridge] WebSocket CLOSED - code: $closeCode, reason: $closeReason, wasConnected: ${_state == StdbConnectionState.connected}');
    _stopHeartbeat();
    if (_state == StdbConnectionState.connected) {
      _setState(StdbConnectionState.error);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_serverUrl == null) return;

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s, 60s (max)
    final exponentialDelay = _baseReconnectDelay * (1 << _reconnectAttempts.clamp(0, 6));
    final delay = exponentialDelay > _maxReconnectDelay ? _maxReconnectDelay : exponentialDelay;

    // Add jitter (0-25% of delay) to prevent thundering herd
    final jitterMs = (delay.inMilliseconds * 0.25 * (DateTime.now().millisecond / 1000)).toInt();
    final finalDelay = delay + Duration(milliseconds: jitterMs);

    debugPrint('[Bridge] Scheduling reconnect in ${finalDelay.inSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(finalDelay, () async {
      _reconnectAttempts++;
      await connect(_serverUrl!);
    });
  }

  // --- Heartbeat Methods ---

  void _startHeartbeat() {
    _stopHeartbeat();
    _lastPong = DateTime.now();
    _missedPongs = 0;

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!isConnected) return;

      // Check if we missed too many pongs
      if (_lastPong != null) {
        final timeSincePong = DateTime.now().difference(_lastPong!);
        if (timeSincePong > _heartbeatInterval * 2) {
          _missedPongs++;
          debugPrint('[Bridge] Missed pong #$_missedPongs (${timeSincePong.inSeconds}s since last)');

          if (_missedPongs >= _maxMissedPongs) {
            debugPrint('[Bridge] Too many missed pongs, reconnecting...');
            _handleDeadConnection();
            return;
          }
        }
      }

      // Send ping
      _sendMessage({
        'type': 'ping',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _handleDeadConnection() {
    _stopHeartbeat();
    _setState(StdbConnectionState.error);
    _cleanup();
    _scheduleReconnect();
  }

  void _updateConnectionQuality(int latency) {
    _recentLatencies.add(latency);
    if (_recentLatencies.length > 5) {
      _recentLatencies.removeAt(0);
    }

    // Use average of recent latencies
    final avgLatency = _recentLatencies.reduce((a, b) => a + b) ~/ _recentLatencies.length;
    _latencyMs = avgLatency;

    ConnectionQuality quality;
    if (avgLatency < 100) {
      quality = ConnectionQuality.excellent;
    } else if (avgLatency < 200) {
      quality = ConnectionQuality.good;
    } else if (avgLatency < 500) {
      quality = ConnectionQuality.fair;
    } else if (avgLatency < 1000) {
      quality = ConnectionQuality.poor;
    } else {
      quality = ConnectionQuality.critical;
    }

    if (quality != _connectionQuality) {
      _connectionQuality = quality;
      _connectionQualityController.add(quality);
    }
  }

  @override
  void requestResync() {
    if (!isConnected) {
      debugPrint('[Bridge] Cannot resync - not connected');
      return;
    }

    debugPrint('[Bridge] Requesting full state resync');
    _sendMessage({'type': 'request_resync'});
  }

  bool _wasMoving = false;

  void _sendMessage(Map<String, dynamic> message) {
    final isMove = message['type'] == 'move';
    if (!isMove) {
      print('[Bridge] _sendMessage() - channel: ${_channel != null}, isConnected: $isConnected');
    }
    if (_channel != null && isConnected) {
      try {
        final encoded = jsonEncode(message);
        if (!isMove) {
          print('[Bridge] Sending: $encoded');
        }
        _channel!.sink.add(encoded);
        if (isMove) {
          _wasMoving = true;
        }
      } catch (e) {
        print('[Bridge] Send error: $e');
        _setState(StdbConnectionState.error);
      }
    } else {
      if (!isMove) {
        print('[Bridge] Cannot send - not connected');
      }
    }
  }

  @override
  void logMovementStopped(double x, double y) {
    if (_wasMoving) {
      print('[Bridge] Player stopped moving at ($x, $y)');
      _wasMoving = false;
    }
  }

  @override
  Future<({double x, double y})?> joinWorld(String playerId, String name, int color) async {
    print('[Bridge] joinWorld() called - playerId: $playerId, isConnected: $isConnected');
    
    if (!isConnected) {
      print('[Bridge] Not connected, returning null');
      return null;
    }

    _playerId = playerId;
    _spawnCompleter = Completer<({double x, double y})?>();

    // Create local player with temporary position
    _localPlayer = PlayerState(
      id: playerId,
      name: name,
      x: 1000.0,
      y: 1000.0,
      color: color,
      isOnline: true,
    );
    _players[playerId] = _localPlayer!;

    // Send join message to bridge
    print('[Bridge] Sending join message with name: "$name"');
    _sendMessage({
      'type': 'join',
      'playerId': playerId,
      'name': name,
      'color': color,
    });

    // Wait for spawn position from server (with timeout)
    print('[Bridge] Waiting for spawn response...');
    try {
      final result = await _spawnCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('[Bridge] Spawn response TIMED OUT, using fallback');
          // Fallback to random spawn point if server doesn't respond
          if (_worldState.spawnPoints.isNotEmpty) {
            final random = Random();
            final spawn = _worldState.spawnPoints[random.nextInt(_worldState.spawnPoints.length)];
            return (x: spawn.x, y: spawn.y);
          }
          return (x: 1000.0, y: 1000.0);
        },
      );
      print('[Bridge] Got spawn position: $result');
      return result;
    } catch (e) {
      print('[Bridge] joinWorld error: $e');
      return (x: 1000.0, y: 1000.0);
    }
  }

  @override
  Future<void> leaveWorld() async {
    if (_playerId != null && isConnected) {
      _sendMessage({'type': 'leave'});
    }
    _players.remove(_playerId);
    _localPlayer = null;
    _playerId = null;
    _emitPlayerUpdate();
  }

  @override
  void updatePlayerPosition(double x, double y, double facingAngle) {
    if (_playerId == null || !isConnected) return;

    // Throttle updates
    final now = DateTime.now();
    if (_lastPositionUpdate != null &&
        now.difference(_lastPositionUpdate!) < _positionUpdateInterval) {
      return;
    }
    _lastPositionUpdate = now;

    _sendMessage({
      'type': 'move',
      'x': x,
      'y': y,
      'angle': facingAngle,
    });

    // Update local state immediately for responsiveness
    if (_localPlayer != null) {
      _localPlayer = _localPlayer!.copyWith(x: x, y: y, facingAngle: facingAngle);
      _players[_playerId!] = _localPlayer!;
      _emitPlayerUpdate();
    }
  }

  @override
  void startCasting(double targetX, double targetY) {
    if (_playerId == null || !isConnected) return;

    _sendMessage({
      'type': 'cast',
      'targetX': targetX,
      'targetY': targetY,
    });

    if (_localPlayer != null) {
      _localPlayer = _localPlayer!.copyWith(
        isCasting: true,
        castTargetX: targetX,
        castTargetY: targetY,
      );
      _players[_playerId!] = _localPlayer!;
      _emitPlayerUpdate();
    }
  }

  @override
  void stopCasting() {
    if (_playerId == null || !isConnected) return;

    _sendMessage({'type': 'reel'});

    if (_localPlayer != null) {
      _localPlayer = _localPlayer!.copyWith(
        isCasting: false,
        castTargetX: null,
        castTargetY: null,
      );
      _players[_playerId!] = _localPlayer!;
      _emitPlayerUpdate();
    }
  }

  @override
  void updatePlayerName(String name) {
    if (_playerId == null || !isConnected) {
      print('[Bridge] Cannot update name - playerId: $_playerId, isConnected: $isConnected');
      return;
    }

    print('[Bridge] Updating player name - playerId: $_playerId, newName: "$name"');
    _sendMessage({
      'type': 'update_name',
      'playerId': _playerId!,
      'name': name,
    });

    // Update local state immediately
    if (_localPlayer != null) {
      _localPlayer = _localPlayer!.copyWith(name: name);
      _players[_playerId!] = _localPlayer!;
      _emitPlayerUpdate();
    }
  }

  @override
  void catchFish(String itemId, int rarity, String waterBodyId) {
    if (_playerId == null || !isConnected) {
      debugPrint('[Bridge] Cannot catch fish - not connected');
      return;
    }

    debugPrint('[Bridge] Catching fish: $itemId, rarity: $rarity, waterBody: $waterBodyId');
    _sendMessage({
      'type': 'catch_fish',
      'itemId': itemId,
      'rarity': rarity,
      'waterBodyId': waterBodyId,
    });
  }

  @override
  void requestInventory() {
    if (!isConnected) {
      debugPrint('[Bridge] Cannot request inventory - not connected');
      return;
    }

    _sendMessage({'type': 'get_inventory'});
  }

  @override
  void sellItem(String itemId, int rarity, int quantity) {
    if (_playerId == null || !isConnected) {
      debugPrint('[Bridge] Cannot sell item - not connected');
      return;
    }

    debugPrint('[Bridge] Selling item: $itemId x$quantity (rarity: $rarity)');
    _sendMessage({
      'type': 'sell_item',
      'itemId': itemId,
      'rarity': rarity,
      'quantity': quantity,
    });
  }

  @override
  void buyItem(String itemId, int price) {
    if (_playerId == null || !isConnected) {
      debugPrint('[Bridge] Cannot buy item - not connected');
      return;
    }

    debugPrint('[Bridge] Buying item: $itemId for ${price}g');
    _sendMessage({
      'type': 'buy_item',
      'itemId': itemId,
      'price': price,
    });
  }

  @override
  void equipPole(String poleItemId) {
    if (_playerId == null || !isConnected) {
      debugPrint('[Bridge] Cannot equip pole - not connected');
      return;
    }

    debugPrint('[Bridge] Equipping pole: $poleItemId');
    _sendMessage({
      'type': 'equip_pole',
      'poleItemId': poleItemId,
    });

    // Update local state immediately for responsiveness
    if (_localPlayer != null) {
      int poleTier = 1;
      if (poleItemId.startsWith('pole_')) {
        poleTier = int.tryParse(poleItemId.split('_').last) ?? 1;
      }
      _localPlayer = _localPlayer!.copyWith(
        equippedPoleId: poleItemId,
        equippedPoleTier: poleTier,
      );
      _players[_playerId!] = _localPlayer!;
      _emitPlayerUpdate();
    }
  }

  @override
  void unequipPole() {
    if (_playerId == null || !isConnected) {
      debugPrint('[Bridge] Cannot unequip pole - not connected');
      return;
    }

    debugPrint('[Bridge] Unequipping pole');
    _sendMessage({
      'type': 'unequip_pole',
    });

    // Update local state immediately for responsiveness
    if (_localPlayer != null) {
      _localPlayer = _localPlayer!.copyWith(
        clearEquippedPoleId: true,
        equippedPoleTier: 1,
      );
      _players[_playerId!] = _localPlayer!;
      _emitPlayerUpdate();
    }
  }

  @override
  void setGold(int amount) {
    if (_playerId == null || !isConnected) {
      debugPrint('[Bridge] Cannot set gold - not connected');
      return;
    }

    debugPrint('[Bridge] Setting gold to: $amount');
    _sendMessage({
      'type': 'set_gold',
      'amount': amount,
    });

    // Update local state immediately for responsiveness
    if (_localPlayer != null) {
      _localPlayer = _localPlayer!.copyWith(gold: amount);
      _players[_playerId!] = _localPlayer!;
      _emitPlayerUpdate();
    }
  }

  Completer<PlayerState?>? _fetchPlayerCompleter;

  @override
  Future<PlayerState?> fetchPlayerData(String playerId) async {
    if (!isConnected) {
      print('[Bridge] Cannot fetch player - not connected');
      return null;
    }

    print('[Bridge] Fetching player data for: $playerId');
    _fetchPlayerCompleter = Completer<PlayerState?>();

    _sendMessage({
      'type': 'fetch_player',
      'playerId': playerId,
    });

    try {
      final result = await _fetchPlayerCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('[Bridge] Fetch player data TIMED OUT');
          return null;
        },
      );
      print('[Bridge] Got player data: ${result != null ? result.name : "null"}');
      return result;
    } catch (e) {
      print('[Bridge] fetchPlayerData error: $e');
      return null;
    } finally {
      _fetchPlayerCompleter = null;
    }
  }

  void _emitPlayerUpdate() {
    _playerUpdatesController.add(_players.values.toList());
  }

  @override
  void acceptQuest(String questId) {
    if (_playerId == null || !isConnected) {
      debugPrint('[Bridge] Cannot accept quest - not connected');
      return;
    }

    debugPrint('[Bridge] Accepting quest: $questId');
    _sendMessage({
      'type': 'accept_quest',
      'questId': questId,
    });

    // Optimistic update
    final quest = _quests.where((q) => q.id == questId).firstOrNull;
    if (quest != null) {
      _playerQuests.add(PlayerQuest(
        id: DateTime.now().millisecondsSinceEpoch,
        playerId: _playerId!,
        questId: questId,
        status: 'active',
        progress: '{}',
        acceptedAt: DateTime.now().microsecondsSinceEpoch,
        completedAt: null,
      ));
      _questController.add((quests: _quests, playerQuests: _playerQuests));
    }
  }

  @override
  void completeQuest(String questId) {
    if (_playerId == null || !isConnected) {
      debugPrint('[Bridge] Cannot complete quest - not connected');
      return;
    }

    debugPrint('[Bridge] Completing quest: $questId');
    _sendMessage({
      'type': 'complete_quest',
      'questId': questId,
    });

    // Optimistic update
    final index = _playerQuests.indexWhere((pq) => pq.questId == questId);
    if (index >= 0) {
      final pq = _playerQuests[index];
      _playerQuests[index] = PlayerQuest(
        id: pq.id,
        playerId: pq.playerId,
        questId: pq.questId,
        status: 'completed',
        progress: pq.progress,
        acceptedAt: pq.acceptedAt,
        completedAt: DateTime.now().microsecondsSinceEpoch,
      );
      _questController.add((quests: _quests, playerQuests: _playerQuests));
    }
  }

  @override
  void requestQuests() {
    if (!isConnected) {
      debugPrint('[Bridge] Cannot request quests - not connected');
      return;
    }

    _sendMessage({'type': 'get_quests'});
  }

  @override
  void resetAllQuests() {
    if (!isConnected) {
      debugPrint('[Bridge] Cannot reset quests - not connected');
      return;
    }

    debugPrint('[Bridge] Resetting all quests');
    _sendMessage({'type': 'reset_quests'});

    // Optimistic update: clear local quest state
    _playerQuests.clear();
    _questController.add((quests: _quests, playerQuests: _playerQuests));
  }

  @override
  void requestNpcs() {
    if (!isConnected) {
      debugPrint('[Bridge] Cannot request NPCs - not connected');
      return;
    }

    _sendMessage({'type': 'get_npcs'});
  }

  @override
  void talkToNpc(String npcId) {
    if (!isConnected) {
      debugPrint('[Bridge] Cannot talk to NPC - not connected');
      return;
    }

    _sendMessage({'type': 'npc_talk', 'npcId': npcId});
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    disconnect();
    _playerUpdatesController.close();
    _connectionStateController.close();
    _worldStateController.close();
    _inventoryController.close();
    _questController.close();
    _playerStatsController.close();
    _levelUpController.close();
    _npcController.close();
    _connectionQualityController.close();
  }
}

