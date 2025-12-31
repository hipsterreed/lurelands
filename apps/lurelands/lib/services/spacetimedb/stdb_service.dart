import 'dart:async';

import '../../models/player_state.dart';

/// Abstract interface for SpacetimeDB communication.
/// This will be implemented with actual WebSocket logic in Phase 2.
abstract class SpacetimeDBService {
  /// Connect to the SpacetimeDB server
  Future<void> connect(String serverUrl);

  /// Disconnect from the server
  Future<void> disconnect();

  /// Check if currently connected
  bool get isConnected;

  /// Join the game world with a player ID
  Future<void> joinWorld(String playerId);

  /// Leave the game world
  Future<void> leaveWorld();

  /// Update the local player's position
  void updatePlayerPosition(double x, double y, double facingAngle);

  /// Notify that player started casting
  void startCasting(double targetX, double targetY);

  /// Notify that player stopped casting / reeled in
  void stopCasting();

  /// Stream of all player states (including local player)
  Stream<List<PlayerState>> get playerUpdates;

  /// Stream of connection state changes
  Stream<bool> get connectionState;
}

/// Stub implementation for Phase 1 (single-player mode).
/// Returns only the local player's state.
class StubSpacetimeDBService implements SpacetimeDBService {
  bool _isConnected = false;
  PlayerState? _localPlayer;

  final _playerUpdatesController =
      StreamController<List<PlayerState>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  @override
  Future<void> connect(String serverUrl) async {
    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 100));
    _isConnected = true;
    _connectionStateController.add(true);
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _localPlayer = null;
    _connectionStateController.add(false);
  }

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> joinWorld(String playerId) async {
    _localPlayer = PlayerState(
      id: playerId,
      x: 1000.0, // Start at center of world
      y: 1000.0,
    );
    _emitPlayerUpdate();
  }

  @override
  Future<void> leaveWorld() async {
    _localPlayer = null;
    _playerUpdatesController.add([]);
  }

  @override
  void updatePlayerPosition(double x, double y, double facingAngle) {
    if (_localPlayer != null) {
      _localPlayer = _localPlayer!.copyWith(
        x: x,
        y: y,
        facingAngle: facingAngle,
      );
      _emitPlayerUpdate();
    }
  }

  @override
  void startCasting(double targetX, double targetY) {
    if (_localPlayer != null) {
      _localPlayer = _localPlayer!.copyWith(
        isCasting: true,
        castTargetX: targetX,
        castTargetY: targetY,
      );
      _emitPlayerUpdate();
    }
  }

  @override
  void stopCasting() {
    if (_localPlayer != null) {
      _localPlayer = _localPlayer!.copyWith(
        isCasting: false,
        castTargetX: null,
        castTargetY: null,
      );
      _emitPlayerUpdate();
    }
  }

  @override
  Stream<List<PlayerState>> get playerUpdates => _playerUpdatesController.stream;

  @override
  Stream<bool> get connectionState => _connectionStateController.stream;

  void _emitPlayerUpdate() {
    if (_localPlayer != null) {
      _playerUpdatesController.add([_localPlayer!]);
    }
  }

  void dispose() {
    _playerUpdatesController.close();
    _connectionStateController.close();
  }
}

