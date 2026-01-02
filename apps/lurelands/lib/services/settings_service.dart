/// Simple settings service for player preferences.
/// Name is stored in-memory and sent to the database when joining the world.
class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  // Default player name
  static const String _defaultPlayerName = 'Fisher';

  // In-memory storage
  String _playerName = _defaultPlayerName;

  /// Get the current player name
  String get playerName => _playerName;

  /// Set the player name
  set playerName(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && trimmed.length <= 16) {
      _playerName = trimmed;
      print('[SettingsService] Name set to: "$_playerName"');
    } else {
      print('[SettingsService] Invalid name: "$value" (trimmed: "$trimmed")');
    }
  }

  /// Initialize the settings service
  Future<void> init() async {
    // No-op for now, but kept for future use
  }

  /// Reset to default settings
  void reset() {
    _playerName = _defaultPlayerName;
  }
}
