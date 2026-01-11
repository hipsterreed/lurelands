import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';

import '../../utils/constants.dart';
import '../components/tiled_water.dart';
import '../lurelands_game.dart';

/// World component that loads and renders a Tiled map.
///
/// This component replaces the programmatic [LurelandsWorld] with a
/// Tiled-based map loaded from `map1.tmx`.
///
/// Responsibilities:
/// - Load and render the Tiled map at the correct scale
/// - Parse the water layer to detect water tiles for fishing
/// - Parse the game_logic layer for spawn points
/// - Provide collision/water query methods for the player and fishing system
class TiledMapWorld extends World with HasGameReference<LurelandsGame> {
  TiledMapWorld();

  /// The loaded Tiled map component
  late TiledComponent _tiledMap;

  /// Scale factor to match world size (800px map -> 2000px world)
  static const double mapScale = 2.5;

  /// Original tile size in the Tiled map
  static const double originalTileSize = 16.0;

  /// Rendered tile size after scaling
  static const double renderedTileSize = originalTileSize * mapScale;

  /// Map dimensions in tiles
  static const int mapWidthTiles = 50;
  static const int mapHeightTiles = 50;

  /// Water tile data extracted from the water layer
  final List<TiledWaterData> _waterData = [];

  /// Cache of water tile positions for fast lookup (x * 1000 + y -> waterType)
  final Map<int, WaterType> _waterTileCache = {};

  /// Spawn point extracted from game_logic layer
  Vector2? _playerSpawnPoint;

  /// All tiled water data for collision/proximity checks
  List<TiledWaterData> get allTiledWaterData => _waterData;

  /// Get player spawn point (or center of map if not found)
  Vector2 get playerSpawnPoint =>
      _playerSpawnPoint ?? Vector2(GameConstants.worldWidth / 2, GameConstants.worldHeight / 2);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    debugPrint('[TiledMapWorld] Starting to load map...');

    try {
      // Load the Tiled map with scaling
      // flame_tiled needs the path relative to project root (including 'assets/')
      _tiledMap = await TiledComponent.load(
        'map1.tmx',
        Vector2.all(renderedTileSize),
        prefix: 'assets/maps/',
      );

      debugPrint('[TiledMapWorld] TiledComponent loaded successfully');

      await add(_tiledMap);

      debugPrint('[TiledMapWorld] TiledComponent added to world');

      // Parse the map layers
      _parseWaterLayer();
      _parseGameLogicLayer();

      debugPrint('[TiledMapWorld] Loaded map with ${_waterData.length} water regions');
      debugPrint('[TiledMapWorld] Player spawn: $_playerSpawnPoint');
    } catch (e, stackTrace) {
      debugPrint('[TiledMapWorld] ERROR loading map: $e');
      debugPrint('[TiledMapWorld] Stack trace: $stackTrace');
    }
  }

  /// Parse the water layer to find water tiles and build water data
  void _parseWaterLayer() {
    final waterLayer = _tiledMap.tileMap.getLayer<TileLayer>('water');
    if (waterLayer == null) {
      debugPrint('[TiledMapWorld] WARNING: No water layer found');
      return;
    }

    // First pass: identify all water tiles and cache their positions
    for (int y = 0; y < mapHeightTiles; y++) {
      for (int x = 0; x < mapWidthTiles; x++) {
        final gid = waterLayer.tileData?[y][x].tile;
        if (gid != null && gid > 0) {
          // Non-zero GID means there's a water tile here
          // For now, determine water type based on position
          // (Future: use tile properties in .tsx files)
          final waterType = _determineWaterType(x, y, gid);
          _waterTileCache[_tileKey(x, y)] = waterType;
        }
      }
    }

    // Second pass: build water regions by flood-filling connected tiles
    _buildWaterRegions();
  }

  /// Create a unique key for tile position
  int _tileKey(int x, int y) => x * 1000 + y;

  /// Determine water type based on tile position and GID
  /// This is a heuristic until we add tile properties to the tilesets
  WaterType _determineWaterType(int x, int y, int gid) {
    // Bottom rows are ocean (roughly bottom 10 rows)
    if (y >= 40) {
      return WaterType.ocean;
    }

    // Look at GID ranges to differentiate water types
    // GIDs 181-332 are from nature_tiles.tsx (contains pond water)
    // GIDs 333-416 are from beach_tiles.tsx (contains ocean water)
    if (gid >= 333 && gid <= 416) {
      return WaterType.ocean;
    }

    // Check if it's a river (long horizontal body) vs pond
    // For now, use pond as default - can be refined later
    return WaterType.pond;
  }

  /// Build water regions from cached water tiles using flood fill
  void _buildWaterRegions() {
    final visited = <int>{};
    int regionId = 0;

    for (final entry in _waterTileCache.entries) {
      if (visited.contains(entry.key)) continue;

      // Start a new region with flood fill
      final region = _floodFill(entry.key, entry.value, visited);
      if (region.isNotEmpty) {
        // Find bounding box of this region
        int minX = mapWidthTiles, maxX = 0;
        int minY = mapHeightTiles, maxY = 0;

        for (final key in region) {
          final x = key ~/ 1000;
          final y = key % 1000;
          minX = minX < x ? minX : x;
          maxX = maxX > x ? maxX : x;
          minY = minY < y ? minY : y;
          maxY = maxY > y ? maxY : y;
        }

        // Create water data for this region
        final waterData = TiledWaterData(
          id: 'water_region_$regionId',
          x: minX * renderedTileSize,
          y: minY * renderedTileSize,
          widthInTiles: maxX - minX + 1,
          heightInTiles: maxY - minY + 1,
          waterType: entry.value,
        );
        _waterData.add(waterData);
        regionId++;
      }
    }
  }

  /// Flood fill to find connected water tiles of the same type
  Set<int> _floodFill(int startKey, WaterType waterType, Set<int> visited) {
    final region = <int>{};
    final queue = <int>[startKey];

    while (queue.isNotEmpty) {
      final key = queue.removeLast();
      if (visited.contains(key)) continue;

      final tileType = _waterTileCache[key];
      if (tileType == null || tileType != waterType) continue;

      visited.add(key);
      region.add(key);

      final x = key ~/ 1000;
      final y = key % 1000;

      // Check 4 neighbors
      if (x > 0) queue.add(_tileKey(x - 1, y));
      if (x < mapWidthTiles - 1) queue.add(_tileKey(x + 1, y));
      if (y > 0) queue.add(_tileKey(x, y - 1));
      if (y < mapHeightTiles - 1) queue.add(_tileKey(x, y + 1));
    }

    return region;
  }

  /// Parse the game_logic layer to find spawn points and other markers
  void _parseGameLogicLayer() {
    final logicLayer = _tiledMap.tileMap.getLayer<TileLayer>('game_logic');
    if (logicLayer == null) {
      debugPrint('[TiledMapWorld] WARNING: No game_logic layer found');
      return;
    }

    // Look for spawn point marker (tile ID 1198 in color_pallette_tiles)
    // firstgid for color_pallette_tiles is 417, so 1198 - 417 = 781 (local ID)
    // But actually the GID stored is the global ID
    for (int y = 0; y < mapHeightTiles; y++) {
      for (int x = 0; x < mapWidthTiles; x++) {
        final gid = logicLayer.tileData?[y][x].tile;
        if (gid == 1198) {
          // Found spawn point - convert tile position to world position
          // Center the spawn on the tile
          _playerSpawnPoint = Vector2(
            (x + 0.5) * renderedTileSize,
            (y + 0.5) * renderedTileSize,
          );
          debugPrint('[TiledMapWorld] Found spawn point at tile ($x, $y) -> world $_playerSpawnPoint');
        }
      }
    }
  }

  /// Check if a world position is inside any water body
  bool isInsideWater(double x, double y) {
    // Convert world position to tile position
    final tileX = (x / renderedTileSize).floor();
    final tileY = (y / renderedTileSize).floor();

    // Check bounds
    if (tileX < 0 || tileX >= mapWidthTiles || tileY < 0 || tileY >= mapHeightTiles) {
      return false;
    }

    return _waterTileCache.containsKey(_tileKey(tileX, tileY));
  }

  /// Check if a world position would collide with water
  /// Uses tile-based check for accurate collision detection
  bool isCollisionAt(double x, double y) {
    // Use the actual tile cache for precise collision detection
    return isInsideWater(x, y);
  }

  /// Get water type at a world position (or null if not water)
  WaterType? getWaterTypeAt(double x, double y) {
    final tileX = (x / renderedTileSize).floor();
    final tileY = (y / renderedTileSize).floor();

    if (tileX < 0 || tileX >= mapWidthTiles || tileY < 0 || tileY >= mapHeightTiles) {
      return null;
    }

    return _waterTileCache[_tileKey(tileX, tileY)];
  }

  /// Check if a player position is near any water body (for fishing)
  bool isPlayerNearWater(Vector2 playerPos, double castingBuffer) {
    for (final water in _waterData) {
      if (water.isWithinCastingRange(playerPos.x, playerPos.y, castingBuffer)) {
        return true;
      }
    }
    return false;
  }

  /// Get info about nearby water the player can cast into
  ({WaterType waterType, String id})? getNearbyWaterInfo(Vector2 playerPos, double castingBuffer) {
    for (final water in _waterData) {
      if (water.isWithinCastingRange(playerPos.x, playerPos.y, castingBuffer)) {
        return (waterType: water.waterType, id: water.id);
      }
    }
    return null;
  }

  /// Dock areas - for now, empty since we're transitioning from old system
  /// These will be detected from an objects layer later
  List<Rect> get dockAreas => [];
}
