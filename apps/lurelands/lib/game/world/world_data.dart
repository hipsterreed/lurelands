import '../../models/pond_data.dart';

/// Static world data configuration
class WorldData {
  // Prevent instantiation
  WorldData._();

  /// Default pond configuration for the game world
  static const List<PondData> defaultPonds = [
    PondData(id: 'pond_1', x: 400, y: 400, radius: 120),
    PondData(id: 'pond_2', x: 1500, y: 300, radius: 100),
    PondData(id: 'pond_3', x: 800, y: 1400, radius: 140),
    PondData(id: 'pond_4', x: 1600, y: 1500, radius: 90),
  ];

  /// World boundary
  static const double worldWidth = 2000.0;
  static const double worldHeight = 2000.0;

  /// Player spawn position
  static const double spawnX = 1000.0;
  static const double spawnY = 1000.0;
}

