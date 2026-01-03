import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service for managing game settings.
/// 
/// Handles persistent storage for:
/// - Player identity (ID, name, color)
/// - Audio settings
/// - Graphics settings
/// 
/// Uses singleton pattern with lazy initialization.
class GameSettings {
  GameSettings._();

  static final GameSettings instance = GameSettings._();

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Cached values for quick access
  String? _cachedPlayerId;
  String? _cachedPlayerName;
  int? _cachedPlayerColor;

  // Storage keys
  static const String _playerIdKey = 'player_id';
  static const String _playerNameKey = 'player_name';
  static const String _playerColorKey = 'player_color';
  static const String _musicVolumeKey = 'music_volume';
  static const String _sfxVolumeKey = 'sfx_volume';
  static const String _showFpsKey = 'show_fps';

  // Default values
  static const String defaultPlayerNamePrefix = 'Fisher';
  static const int defaultPlayerColor = 0xFFE74C3C; // Red
  static const double defaultMusicVolume = 0.7;
  static const double defaultSfxVolume = 1.0;

  /// Initialize the settings service. Must be called before accessing settings.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      debugPrint('[GameSettings] Initialized successfully');
    } catch (e) {
      debugPrint('[GameSettings] Failed to initialize: $e');
      // Continue without persistent storage
    }
  }

  /// Ensure settings are initialized before use
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  // ============= Player Identity =============

  /// Get the persistent player ID, creating a new one if needed.
  Future<String> getPlayerId() async {
    if (_cachedPlayerId != null) {
      return _cachedPlayerId!;
    }

    await _ensureInitialized();

    final storedId = _prefs?.getString(_playerIdKey);
    if (storedId != null && storedId.isNotEmpty) {
      _cachedPlayerId = storedId;
      debugPrint('[GameSettings] Loaded player ID: $storedId');
      return storedId;
    }

    // Generate new player ID
    final newId = 'player_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
    await setPlayerId(newId);
    debugPrint('[GameSettings] Generated new player ID: $newId');
    return newId;
  }

  /// Set the player ID
  Future<void> setPlayerId(String playerId) async {
    await _ensureInitialized();
    _cachedPlayerId = playerId;
    await _prefs?.setString(_playerIdKey, playerId);
  }

  /// Get the player name
  Future<String> getPlayerName() async {
    if (_cachedPlayerName != null) {
      return _cachedPlayerName!;
    }

    await _ensureInitialized();

    final storedName = _prefs?.getString(_playerNameKey);
    if (storedName != null && storedName.isNotEmpty) {
      _cachedPlayerName = storedName;
      return storedName;
    }

    // Generate default name with random suffix
    final randomSuffix = DateTime.now().millisecondsSinceEpoch % 10000;
    final defaultName = '$defaultPlayerNamePrefix$randomSuffix';
    _cachedPlayerName = defaultName;
    return defaultName;
  }

  /// Set the player name
  Future<void> setPlayerName(String name) async {
    await _ensureInitialized();
    _cachedPlayerName = name;
    await _prefs?.setString(_playerNameKey, name);
    debugPrint('[GameSettings] Saved player name: $name');
  }

  /// Get the player color (ARGB format)
  Future<int> getPlayerColor() async {
    if (_cachedPlayerColor != null) {
      return _cachedPlayerColor!;
    }

    await _ensureInitialized();

    final storedColor = _prefs?.getInt(_playerColorKey);
    if (storedColor != null) {
      _cachedPlayerColor = storedColor;
      return storedColor;
    }

    _cachedPlayerColor = defaultPlayerColor;
    return defaultPlayerColor;
  }

  /// Set the player color
  Future<void> setPlayerColor(int color) async {
    await _ensureInitialized();
    _cachedPlayerColor = color;
    await _prefs?.setInt(_playerColorKey, color);
  }

  // ============= Audio Settings =============

  /// Get music volume (0.0 to 1.0)
  Future<double> getMusicVolume() async {
    await _ensureInitialized();
    return _prefs?.getDouble(_musicVolumeKey) ?? defaultMusicVolume;
  }

  /// Set music volume
  Future<void> setMusicVolume(double volume) async {
    await _ensureInitialized();
    await _prefs?.setDouble(_musicVolumeKey, volume.clamp(0.0, 1.0));
  }

  /// Get sound effects volume (0.0 to 1.0)
  Future<double> getSfxVolume() async {
    await _ensureInitialized();
    return _prefs?.getDouble(_sfxVolumeKey) ?? defaultSfxVolume;
  }

  /// Set sound effects volume
  Future<void> setSfxVolume(double volume) async {
    await _ensureInitialized();
    await _prefs?.setDouble(_sfxVolumeKey, volume.clamp(0.0, 1.0));
  }

  // ============= Graphics Settings =============

  /// Get whether to show FPS counter
  Future<bool> getShowFps() async {
    await _ensureInitialized();
    return _prefs?.getBool(_showFpsKey) ?? false;
  }

  /// Set whether to show FPS counter
  Future<void> setShowFps(bool show) async {
    await _ensureInitialized();
    await _prefs?.setBool(_showFpsKey, show);
  }

  // ============= Utility Methods =============

  /// Clear all player data (for testing/reset)
  Future<void> clearPlayerData() async {
    await _ensureInitialized();
    _cachedPlayerId = null;
    _cachedPlayerName = null;
    _cachedPlayerColor = null;
    await _prefs?.remove(_playerIdKey);
    await _prefs?.remove(_playerNameKey);
    await _prefs?.remove(_playerColorKey);
    debugPrint('[GameSettings] Cleared player data');
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
}

