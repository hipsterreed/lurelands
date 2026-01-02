import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing persistent player ID
class PlayerIdService {
  PlayerIdService._();

  static final PlayerIdService instance = PlayerIdService._();

  static const String _playerIdKey = 'player_id';
  String? _cachedPlayerId;

  /// Get the player ID, creating a new one if it doesn't exist
  Future<String> getPlayerId() async {
    if (_cachedPlayerId != null) {
      return _cachedPlayerId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getString(_playerIdKey);

      if (storedId != null && storedId.isNotEmpty) {
        _cachedPlayerId = storedId;
        return storedId;
      }

      // Generate new player ID
      final newId = 'player_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
      await prefs.setString(_playerIdKey, newId);
      _cachedPlayerId = newId;
      return newId;
    } catch (e) {
      // Fallback if SharedPreferences fails
      final fallbackId = 'player_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
      _cachedPlayerId = fallbackId;
      return fallbackId;
    }
  }

  /// Generate a random string for uniqueness
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[(random + i) % chars.length]);
    }
    return buffer.toString();
  }

  /// Clear the stored player ID (for testing/reset)
  Future<void> clearPlayerId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_playerIdKey);
      _cachedPlayerId = null;
    } catch (e) {
      // Ignore errors
    }
  }
}

