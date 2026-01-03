import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
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

/// Connection state for SpacetimeDB
enum StdbConnectionState {
  disconnected,
  connecting,
  connected,
  error,
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

  // Stream controllers
  final _playerUpdatesController = StreamController<List<PlayerState>>.broadcast();
  final _connectionStateController = StreamController<StdbConnectionState>.broadcast();
  final _worldStateController = StreamController<WorldState>.broadcast();
  final _inventoryController = StreamController<List<InventoryEntry>>.broadcast();

  // Throttle position updates to avoid flooding
  DateTime? _lastPositionUpdate;
  static const _positionUpdateInterval = Duration(milliseconds: 50); // 20 updates/sec max

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
      print('[Bridge] Connected successfully!');
      return true;
    } catch (e) {
      print('[Bridge] Connection error: $e');
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

  void _onMessage(dynamic message) {
    print('[Bridge] Received message: $message');
    try {
      final data = message is String ? jsonDecode(message) : message;
      _handleMessage(data as Map<String, dynamic>);
    } catch (e) {
      print('[Bridge] Error parsing message: $e');
    }
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    print('[Bridge] Handling message type: $type');

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
          _players.clear();
          for (final playerJson in playersData) {
            final player = _parsePlayer(playerJson as Map<String, dynamic>);
            _players[player.id] = player;
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
          _players[player.id] = player;
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
          // Update or add the item in our local list
          final index = _inventory.indexWhere((e) => e.stackKey == updatedItem.stackKey);
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
    }
  }

  PlayerState _parsePlayer(Map<String, dynamic> json) {
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
    );
  }

  void _onError(Object error) {
    _setState(StdbConnectionState.error);
    _scheduleReconnect();
  }

  void _onDone() {
    if (_state == StdbConnectionState.connected) {
      _setState(StdbConnectionState.error);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_serverUrl != null) {
      _reconnectTimer = Timer(const Duration(seconds: 5), () {
        connect(_serverUrl!);
      });
    }
  }

  void _sendMessage(Map<String, dynamic> message) {
    print('[Bridge] _sendMessage() - channel: ${_channel != null}, isConnected: $isConnected');
    if (_channel != null && isConnected) {
      try {
        final encoded = jsonEncode(message);
        print('[Bridge] Sending: $encoded');
        _channel!.sink.add(encoded);
      } catch (e) {
        print('[Bridge] Send error: $e');
        _setState(StdbConnectionState.error);
      }
    } else {
      print('[Bridge] Cannot send - not connected');
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
  void dispose() {
    _reconnectTimer?.cancel();
    disconnect();
    _playerUpdatesController.close();
    _connectionStateController.close();
    _worldStateController.close();
    _inventoryController.close();
  }
}

