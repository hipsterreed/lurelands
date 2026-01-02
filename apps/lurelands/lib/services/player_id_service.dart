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
      print('[PlayerIdService] Using cached player ID: $_cachedPlayerId');
      return _cachedPlayerId!;
    }

    // Retry logic for hot restart - SharedPreferences plugin might not be ready immediately
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        if (attempt > 0) {
          // Wait a bit before retrying (plugin might not be ready during hot restart)
          await Future.delayed(Duration(milliseconds: 100 * attempt));
        }

        final prefs = await SharedPreferences.getInstance();
        final storedId = prefs.getString(_playerIdKey);

        print('[PlayerIdService] Loaded from storage (attempt ${attempt + 1}): $storedId');

        if (storedId != null && storedId.isNotEmpty) {
          _cachedPlayerId = storedId;
          print('[PlayerIdService] Using stored player ID: $storedId');
          return storedId;
        }

        // Generate new player ID
        final newId = 'player_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
        await prefs.setString(_playerIdKey, newId);
        _cachedPlayerId = newId;
        print('[PlayerIdService] Generated new player ID: $newId');
        return newId;
      } catch (e) {
        print('[PlayerIdService] Error loading player ID (attempt ${attempt + 1}): $e');
        if (attempt == 2) {
          // Last attempt failed, use fallback
          // But try to use a consistent fallback based on a stable identifier
          // For now, generate a new one but log the issue
          final fallbackId = 'player_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
          _cachedPlayerId = fallbackId;
          print('[PlayerIdService] Using fallback player ID: $fallbackId (SharedPreferences unavailable)');
          return fallbackId;
        }
        // Continue to next attempt
      }
    }

    // Should never reach here, but just in case
    final fallbackId = 'player_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
    _cachedPlayerId = fallbackId;
    return fallbackId;
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

