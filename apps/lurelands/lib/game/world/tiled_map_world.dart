import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';

import '../../utils/constants.dart';
import '../components/tiled_water.dart';
import '../lurelands_game.dart';

/// World component that loads and renders a Tiled map.
///
/// Collision detection uses:
/// 1. Tile collision objects from tilesets (precise shapes on individual tiles)
/// 2. Collision object layer from the map (for larger blocking areas)
///
/// Fishing detection uses:
/// - `is_fishable` tile property from tilesets
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
  static const int mapWidthTiles = 128;
  static const int mapHeightTiles = 128;

  /// Calculated world dimensions based on map size and scale
  static const double worldWidth = mapWidthTiles * renderedTileSize;
  static const double worldHeight = mapHeightTiles * renderedTileSize;

  /// Water tile data extracted from the water layer (for fishing regions)
  final List<TiledWaterData> _waterData = [];

  /// Cache of fishable tile positions (x * 1000 + y -> waterType)
  final Map<int, WaterType> _fishableTileCache = {};

  /// Cache of tile collision objects: GID -> list of collision rectangles (in tile-local coordinates)
  final Map<int, List<Rect>> _tileCollisionCache = {};

  /// Collision rectangles from the collision object layer (in world coordinates)
  final List<Rect> _collisionLayerRects = [];

  /// Spawn point extracted from game_logic layer
  Vector2? _playerSpawnPoint;

  /// All tiled water data for fishing proximity checks
  List<TiledWaterData> get allTiledWaterData => _waterData;

  /// Get player spawn point (or center of map if not found)
  Vector2 get playerSpawnPoint =>
      _playerSpawnPoint ?? Vector2(worldWidth / 2, worldHeight / 2);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    debugPrint('[TiledMapWorld] Starting to load map...');

    try {
      // Load the Tiled map with scaling
      // flame_tiled needs the path relative to project root (including 'assets/')
      _tiledMap = await TiledComponent.load(
        'map2.tmx',
        Vector2.all(renderedTileSize),
        prefix: 'assets/maps/',
      );

      debugPrint('[TiledMapWorld] TiledComponent loaded successfully');

      await add(_tiledMap);

      debugPrint('[TiledMapWorld] TiledComponent added to world');

      // Parse tilesets for collision objects and properties
      _parseTilesetCollisions();

      // Parse the collision object layer
      _parseCollisionObjectLayer();

      // Parse the water layer for fishing regions
      _parseWaterLayer();

      // Parse game logic layer for spawn points
      _parseGameLogicLayer();

      debugPrint('[TiledMapWorld] Loaded map with ${_waterData.length} water regions');
      debugPrint('[TiledMapWorld] Tile collision cache: ${_tileCollisionCache.length} tiles with collision');
      debugPrint('[TiledMapWorld] Collision layer rects: ${_collisionLayerRects.length}');
      debugPrint('[TiledMapWorld] Player spawn: $_playerSpawnPoint');
    } catch (e, stackTrace) {
      debugPrint('[TiledMapWorld] ERROR loading map: $e');
      debugPrint('[TiledMapWorld] Stack trace: $stackTrace');
    }
  }

  /// Parse all tilesets for tile collision objects and properties
  void _parseTilesetCollisions() {
    final tileMap = _tiledMap.tileMap.map;

    for (final tileset in tileMap.tilesets) {
      final firstGid = tileset.firstGid ?? 0;

      for (final tile in tileset.tiles) {
        final gid = firstGid + tile.localId;

        // Check for collision objects on this tile
        final objectGroup = tile.objectGroup;
        if (objectGroup != null && objectGroup is ObjectGroup) {
          final collisionRects = <Rect>[];

          for (final obj in objectGroup.objects) {
            // Convert to Rect (tile-local coordinates, unscaled)
            collisionRects.add(Rect.fromLTWH(
              obj.x,
              obj.y,
              obj.width,
              obj.height,
            ));
          }

          if (collisionRects.isNotEmpty) {
            _tileCollisionCache[gid] = collisionRects;
          }
        }
      }
    }

    debugPrint('[TiledMapWorld] Parsed ${_tileCollisionCache.length} tiles with collision objects');
  }

  /// Parse the collision object layer for blocking areas
  void _parseCollisionObjectLayer() {
    // Try common names for collision layer
    ObjectGroup? collisionLayer;
    for (final name in ['collision', 'collisions', 'obstacles', 'blocking']) {
      collisionLayer = _tiledMap.tileMap.getLayer<ObjectGroup>(name);
      if (collisionLayer != null) break;
    }

    if (collisionLayer == null) {
      debugPrint('[TiledMapWorld] No collision object layer found');
      return;
    }

    for (final obj in collisionLayer.objects) {
      // Convert to world coordinates with scaling
      _collisionLayerRects.add(Rect.fromLTWH(
        obj.x * mapScale,
        obj.y * mapScale,
        obj.width * mapScale,
        obj.height * mapScale,
      ));
    }

    debugPrint('[TiledMapWorld] Parsed ${_collisionLayerRects.length} collision objects from layer');
  }

  /// Parse the water layer to find fishable tiles and build water regions
  void _parseWaterLayer() {
    final waterLayer = _tiledMap.tileMap.getLayer<TileLayer>('water');
    if (waterLayer == null) {
      debugPrint('[TiledMapWorld] WARNING: No water layer found');
      return;
    }

    final tileMap = _tiledMap.tileMap.map;

    // Scan for fishable tiles
    for (int y = 0; y < mapHeightTiles; y++) {
      for (int x = 0; x < mapWidthTiles; x++) {
        final gid = waterLayer.tileData?[y][x].tile;
        if (gid == null || gid == 0) continue;

        // Check if this tile has is_fishable property
        final tile = tileMap.tileByGid(gid);
        final isFishable = tile?.properties.getValue<bool>('is_fishable') ?? false;

        if (isFishable) {
          final waterType = _determineWaterType(x, y, gid);
          _fishableTileCache[_tileKey(x, y)] = waterType;
        }
      }
    }

    // Build water regions for fishing proximity detection
    _buildWaterRegions();
  }

  /// Create a unique key for tile position
  int _tileKey(int x, int y) => x * 1000 + y;

  /// Determine water type based on tile position and GID
  WaterType _determineWaterType(int x, int y, int gid) {
    // Bottom rows are ocean (roughly bottom 10 rows)
    if (y >= 40) {
      return WaterType.ocean;
    }

    // GIDs 333-416 are from beach_tiles.tsx (contains ocean water)
    if (gid >= 333 && gid <= 416) {
      return WaterType.ocean;
    }

    return WaterType.pond;
  }

  /// Build water regions from fishable tiles using flood fill
  void _buildWaterRegions() {
    final visited = <int>{};
    int regionId = 0;

    for (final entry in _fishableTileCache.entries) {
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

  /// Flood fill to find connected fishable tiles of the same type
  Set<int> _floodFill(int startKey, WaterType waterType, Set<int> visited) {
    final region = <int>{};
    final queue = <int>[startKey];

    while (queue.isNotEmpty) {
      final key = queue.removeLast();
      if (visited.contains(key)) continue;

      final tileType = _fishableTileCache[key];
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

    final tileMap = _tiledMap.tileMap.map;

    // Look for spawn point marker (tile with is_spawn property)
    for (int y = 0; y < mapHeightTiles; y++) {
      for (int x = 0; x < mapWidthTiles; x++) {
        final gid = logicLayer.tileData?[y][x].tile;
        if (gid == null || gid == 0) continue;

        final tile = tileMap.tileByGid(gid);
        final isSpawn = tile?.properties.getValue<bool>('is_spawn') ?? false;

        if (isSpawn) {
          // Found spawn point - convert tile position to world position
          _playerSpawnPoint = Vector2(
            (x + 0.5) * renderedTileSize,
            (y + 0.5) * renderedTileSize,
          );
          debugPrint('[TiledMapWorld] Found spawn point at tile ($x, $y) -> world $_playerSpawnPoint');
        }
      }
    }
  }

  /// Check if a world position collides with any tile collision object or collision layer rect
  bool isCollisionAt(double x, double y) {
    // Check collision object layer first (larger areas)
    for (final rect in _collisionLayerRects) {
      if (rect.contains(Offset(x, y))) {
        return true;
      }
    }

    // Check tile collision objects
    return _checkTileCollision(x, y);
  }

  /// Check collision against tile collision objects at a world position
  bool _checkTileCollision(double worldX, double worldY) {
    // Convert world position to tile position
    final tileX = (worldX / renderedTileSize).floor();
    final tileY = (worldY / renderedTileSize).floor();

    // Check bounds
    if (tileX < 0 || tileX >= mapWidthTiles || tileY < 0 || tileY >= mapHeightTiles) {
      return false;
    }

    // Check all layers for tiles with collision objects at this position
    for (final layer in _tiledMap.tileMap.map.layers) {
      if (layer is TileLayer) {
        final gid = layer.tileData?[tileY][tileX].tile;
        if (gid == null || gid == 0) continue;

        final collisionRects = _tileCollisionCache[gid];
        if (collisionRects == null) continue;

        // Calculate position within the tile (0-16 range, then scaled)
        final tileLocalX = worldX - (tileX * renderedTileSize);
        final tileLocalY = worldY - (tileY * renderedTileSize);

        // Check each collision rect (need to scale from tile coords to world coords)
        for (final rect in collisionRects) {
          final scaledRect = Rect.fromLTWH(
            rect.left * mapScale,
            rect.top * mapScale,
            rect.width * mapScale,
            rect.height * mapScale,
          );

          if (scaledRect.contains(Offset(tileLocalX, tileLocalY))) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Check if a world position is inside a fishable water tile
  bool isInsideWater(double x, double y) {
    // First check tile collision (for precise water edge detection)
    if (_checkTileCollision(x, y)) {
      return true;
    }

    // Fallback: check if the tile is fishable (for tiles without collision objects yet)
    final tileX = (x / renderedTileSize).floor();
    final tileY = (y / renderedTileSize).floor();

    if (tileX < 0 || tileX >= mapWidthTiles || tileY < 0 || tileY >= mapHeightTiles) {
      return false;
    }

    return _fishableTileCache.containsKey(_tileKey(tileX, tileY));
  }

  /// Check if a world position is fishable (for casting detection)
  bool isFishableAt(double x, double y) {
    final tileX = (x / renderedTileSize).floor();
    final tileY = (y / renderedTileSize).floor();

    if (tileX < 0 || tileX >= mapWidthTiles || tileY < 0 || tileY >= mapHeightTiles) {
      return false;
    }

    return _fishableTileCache.containsKey(_tileKey(tileX, tileY));
  }

  /// Get water type at a world position (or null if not fishable)
  WaterType? getWaterTypeAt(double x, double y) {
    final tileX = (x / renderedTileSize).floor();
    final tileY = (y / renderedTileSize).floor();

    if (tileX < 0 || tileX >= mapWidthTiles || tileY < 0 || tileY >= mapHeightTiles) {
      return null;
    }

    return _fishableTileCache[_tileKey(tileX, tileY)];
  }

  /// Check if a player position is near any fishable water (for fishing)
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
