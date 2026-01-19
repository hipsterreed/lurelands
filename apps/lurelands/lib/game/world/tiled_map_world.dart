import 'dart:ui' as ui;
import 'dart:ui' show Rect, Offset;

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';

import '../../utils/constants.dart';
import '../components/fountain.dart';
import '../components/shop.dart';
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

  /// The loaded Tiled map component (used for parsing, not rendering)
  late TiledComponent _tiledMap;

  /// Pre-rendered map image (eliminates tile seams)
  ui.Image? _bakedMapImage;

  /// Scale factor to match world size
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

  /// Shops created from building objects
  final List<Shop> _shops = [];

  /// Fountains created from props layer
  final List<Fountain> _fountains = [];

  /// All tiled water data for fishing proximity checks
  List<TiledWaterData> get allTiledWaterData => _waterData;

  /// Expose fishable tile cache for debug rendering
  Map<int, WaterType> get fishableTileCache => _fishableTileCache;

  /// Expose tile collision cache for debug rendering
  Map<int, List<Rect>> get tileCollisionCache => _tileCollisionCache;

  /// Get the water layer for debug access
  TileLayer? get waterLayer => _tiledMap.tileMap.getLayer<TileLayer>('Water');

  /// All shops in the world
  List<Shop> get shops => _shops;

  /// Get player spawn point (or center of map if not found)
  Vector2 get playerSpawnPoint => _playerSpawnPoint ?? Vector2(worldWidth / 2, worldHeight / 2);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    debugPrint('[TiledMapWorld] Starting to load map...');

    try {
      // Load the Tiled map with scaling
      // flame_tiled needs the path relative to project root (including 'assets/')
      _tiledMap = await TiledComponent.load('map2.tmx', Vector2.all(renderedTileSize), prefix: 'assets/maps/');

      debugPrint('[TiledMapWorld] TiledComponent loaded successfully');

      // Bake the entire map to a single image to eliminate tile seams
      await _bakeMapToImage();

      debugPrint('[TiledMapWorld] Map baked to single image');

      // Parse tilesets for collision objects and properties
      _parseTilesetCollisions();

      // Parse the collision object layer
      _parseCollisionObjectLayer();

      // Parse the water layer for fishing regions
      _parseWaterLayer();

      // Parse game logic layer for spawn points
      _parseGameLogicLayer();

      // Render tile objects from object layers (buildings, trees, etc.)
      await _renderObjectLayerTiles('Buildings');

      // Process props layer (fountains, etc.)
      await _processPropsLayer();

      debugPrint('[TiledMapWorld] Loaded map with ${_waterData.length} water regions');
      debugPrint('[TiledMapWorld] Tile collision cache: ${_tileCollisionCache.length} tiles with collision');
      debugPrint('[TiledMapWorld] Collision layer rects: ${_collisionLayerRects.length}');
      debugPrint('[TiledMapWorld] Player spawn: $_playerSpawnPoint');
    } catch (e, stackTrace) {
      debugPrint('[TiledMapWorld] ERROR loading map: $e');
      debugPrint('[TiledMapWorld] Stack trace: $stackTrace');
    }
  }

  /// Bake specific tile layers to a single image to eliminate tile seams
  /// Only bakes ground/path layers - other layers render normally
  Future<void> _bakeMapToImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Layers to bake (static ground layers that cause seams)
    const layersToBake = ['Ground', 'Paths'];

    // Render only the specified layers
    for (final layer in _tiledMap.tileMap.renderableLayers) {
      if (layersToBake.contains(layer.layer.name)) {
        layer.render(canvas, CameraComponent());
      }
    }

    // Convert to image
    final picture = recorder.endRecording();
    _bakedMapImage = await picture.toImage(worldWidth.toInt(), worldHeight.toInt());

    // Create a sprite from the baked image and add it
    final sprite = Sprite(_bakedMapImage!);
    await add(SpriteComponent(sprite: sprite, position: Vector2.zero(), size: Vector2(worldWidth, worldHeight), priority: 0));

    // Hide the baked layers in TiledComponent so they don't double-render
    for (final layer in _tiledMap.tileMap.renderableLayers) {
      if (layersToBake.contains(layer.layer.name)) {
        layer.layer.visible = false;
      }
    }

    // Add TiledComponent for remaining layers (water, decorations, etc.)
    await add(_tiledMap);
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
            collisionRects.add(Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height));
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
      _collisionLayerRects.add(Rect.fromLTWH(obj.x * mapScale, obj.y * mapScale, obj.width * mapScale, obj.height * mapScale));
    }

    debugPrint('[TiledMapWorld] Parsed ${_collisionLayerRects.length} collision objects from layer');
  }

  /// Render tile objects from an object layer (for buildings, trees, etc.)
  Future<void> _renderObjectLayerTiles(String layerName) async {
    final objectLayer = _tiledMap.tileMap.getLayer<ObjectGroup>(layerName);
    if (objectLayer == null) {
      debugPrint('[TiledMapWorld] No object layer "$layerName" found');
      return;
    }

    final tileMap = _tiledMap.tileMap.map;
    int count = 0;
    int shopCount = 0;

    for (final obj in objectLayer.objects) {
      // Only process tile objects (those with a gid)
      final gid = obj.gid;
      if (gid == null || gid == 0) continue;

      // Find the tileset and local tile ID for this gid
      Tileset? tileset;
      int localId = 0;
      for (final ts in tileMap.tilesets) {
        final firstGid = ts.firstGid ?? 0;
        final tileCount = ts.tileCount ?? 0;
        if (gid >= firstGid && gid < firstGid + tileCount) {
          tileset = ts;
          localId = gid - firstGid;
          break;
        }
      }

      if (tileset == null) {
        debugPrint('[TiledMapWorld] Could not find tileset for gid $gid');
        continue;
      }

      // Get the image source for this tile
      String? imageSource;
      double imageWidth = obj.width;
      double imageHeight = obj.height;

      // Check if this is an image collection tileset (individual tile images)
      final tile = tileset.tiles.where((t) => t.localId == localId).firstOrNull;
      if (tile?.image != null) {
        // Image collection tileset - each tile has its own image
        imageSource = tile!.image!.source;
        imageWidth = tile.image!.width?.toDouble() ?? obj.width;
        imageHeight = tile.image!.height?.toDouble() ?? obj.height;
      } else if (tileset.image != null) {
        // Spritesheet tileset - we'd need to extract from the sheet
        // For now, skip these as they're more complex
        debugPrint('[TiledMapWorld] Spritesheet tileset objects not yet supported');
        continue;
      } else {
        continue;
      }

      if (imageSource == null) continue;

      // Load the image - path is relative to the tileset, need to resolve
      // The tsx files are in assets/tilesets/v2/, images referenced as ../../images/...
      // Flame's image loader expects paths relative to assets/images/
      // So ../../images/structures/X.png -> structures/X.png
      var resolvedPath = imageSource;
      // Remove relative path prefixes
      while (resolvedPath.startsWith('../')) {
        resolvedPath = resolvedPath.substring(3);
      }
      // Remove 'images/' prefix since Flame loads from assets/images/
      if (resolvedPath.startsWith('images/')) {
        resolvedPath = resolvedPath.substring(7);
      }

      // Check if this building should be a shop via is_shop property
      final isShop = obj.properties.getValue<bool>('is_shop') ?? tile.properties.getValue<bool>('is_shop') ?? false;

      // In Tiled, tile objects are positioned at bottom-left
      // Calculate position - for shops we use bottomCenter anchor
      final scaledX = obj.x * mapScale;
      final scaledY = obj.y * mapScale; // Bottom position for shop
      final scaledWidth = imageWidth * mapScale;
      final scaledHeight = imageHeight * mapScale;

      if (isShop) {
        // Create a Shop component for interactive buildings
        // Shop uses bottomCenter anchor, so position at center-bottom
        final shopX = scaledX + scaledWidth / 2;
        final shopY = scaledY;

        try {
          final image = await game.images.load(resolvedPath);
          final shopSprite = Sprite(image);

          // Get collision rectangles from the tile (if any)
          final tileCollisions = _tileCollisionCache[gid];
          List<Rect>? scaledCollisions;
          if (tileCollisions != null && tileCollisions.isNotEmpty) {
            // Scale collision rects from tile coordinates to world coordinates
            scaledCollisions = tileCollisions
                .map((rect) => Rect.fromLTWH(rect.left * mapScale, rect.top * mapScale, rect.width * mapScale, rect.height * mapScale))
                .toList();
            debugPrint('[TiledMapWorld] Shop has ${scaledCollisions.length} collision rects from Tiled');
          }

          final shop = Shop(
            position: Vector2(shopX, shopY),
            id: obj.name.isNotEmpty ? obj.name : 'shop_$shopCount',
            name: obj.name.isNotEmpty ? obj.name : 'Shop',
            sprite: shopSprite,
            spriteSize: Vector2(scaledWidth, scaledHeight),
            collisionRects: scaledCollisions,
          );
          await add(shop);
          _shops.add(shop);
          shopCount++;

          // Add shop collision to world collision layer for player movement
          if (tileCollisions != null && tileCollisions.isNotEmpty) {
            final topLeftY = (obj.y - imageHeight) * mapScale;
            for (final rect in tileCollisions) {
              _collisionLayerRects.add(
                Rect.fromLTWH(
                  scaledX + rect.left * mapScale,
                  topLeftY + rect.top * mapScale,
                  rect.width * mapScale,
                  rect.height * mapScale,
                ),
              );
            }
          }

          debugPrint('[TiledMapWorld] Created shop "${shop.id}" at ($shopX, $shopY)');
        } catch (e) {
          debugPrint('[TiledMapWorld] Failed to load shop image $resolvedPath: $e');
        }
      } else {
        // Regular building - render as sprite and add collision
        try {
          final image = await game.images.load(resolvedPath);
          final sprite = Sprite(image);

          // Adjust y position since Flame uses top-left anchor
          final topLeftY = (obj.y - imageHeight) * mapScale;

          final spriteComponent = SpriteComponent(
            sprite: sprite,
            position: Vector2(scaledX, topLeftY),
            size: Vector2(scaledWidth, scaledHeight),
          );

          await add(spriteComponent);
          count++;

          // Add collision rectangles from the tile (if any)
          final tileCollisions = _tileCollisionCache[gid];
          if (tileCollisions != null && tileCollisions.isNotEmpty) {
            for (final rect in tileCollisions) {
              // Scale and position collision rect in world coordinates
              // rect is relative to tile's top-left, sprite is at (scaledX, topLeftY)
              _collisionLayerRects.add(
                Rect.fromLTWH(
                  scaledX + rect.left * mapScale,
                  topLeftY + rect.top * mapScale,
                  rect.width * mapScale,
                  rect.height * mapScale,
                ),
              );
            }
            debugPrint('[TiledMapWorld] Building has ${tileCollisions.length} collision rects');
          }
        } catch (e) {
          debugPrint('[TiledMapWorld] Failed to load image $resolvedPath: $e');
        }
      }
    }

    debugPrint('[TiledMapWorld] Rendered $count tile objects from "$layerName" layer');
    debugPrint('[TiledMapWorld] Created $shopCount shops');
  }

  /// Process the Props / World Objects layer for animated objects like fountains
  Future<void> _processPropsLayer() async {
    final objectLayer = _tiledMap.tileMap.getLayer<ObjectGroup>('Props / World Objects');
    if (objectLayer == null) {
      debugPrint('[TiledMapWorld] No Props / World Objects layer found');
      return;
    }

    int fountainCount = 0;

    for (final obj in objectLayer.objects) {
      // Only process tile objects (those with a gid)
      final gid = obj.gid;
      if (gid == null || gid == 0) continue;

      // Get the kind property to determine what type of prop this is
      final kind = obj.properties.getValue<String>('kind') ?? '';

      // Calculate position - Tiled uses bottom-left for tile objects
      final scaledX = obj.x * mapScale;
      final scaledY = obj.y * mapScale;
      final scaledWidth = obj.width * mapScale;
      final scaledHeight = obj.height * mapScale;

      switch (kind) {
        case 'fountain':
          // Create animated fountain
          // Position at center-bottom since Fountain uses bottomCenter anchor
          final fountainX = scaledX + scaledWidth / 2;
          final fountainY = scaledY;

          final fountain = Fountain(
            position: Vector2(fountainX, fountainY),
            size: Vector2(scaledWidth, scaledHeight),
          );
          await add(fountain);
          _fountains.add(fountain);
          fountainCount++;

          // Add collision from tileset (if any)
          final tileCollisions = _tileCollisionCache[gid];
          if (tileCollisions != null && tileCollisions.isNotEmpty) {
            // Calculate top-left position (Tiled positions tile objects at bottom-left)
            final topLeftY = (obj.y - obj.height) * mapScale;
            for (final rect in tileCollisions) {
              _collisionLayerRects.add(
                Rect.fromLTWH(
                  scaledX + rect.left * mapScale,
                  topLeftY + rect.top * mapScale,
                  rect.width * mapScale,
                  rect.height * mapScale,
                ),
              );
            }
            debugPrint('[TiledMapWorld] Fountain has ${tileCollisions.length} collision rects');
          }

          debugPrint('[TiledMapWorld] Created fountain at ($fountainX, $fountainY)');
          break;

        default:
          debugPrint('[TiledMapWorld] Unknown prop kind: $kind');
          break;
      }
    }

    debugPrint('[TiledMapWorld] Created $fountainCount fountains from Props layer');
  }

  /// Parse the water layer to find fishable tiles and build water regions
  void _parseWaterLayer() {
    final waterLayer = _tiledMap.tileMap.getLayer<TileLayer>('Water');
    if (waterLayer == null) {
      debugPrint('[TiledMapWorld] WARNING: No "Water" layer found (case-sensitive)');
      // List all available layers for debugging
      debugPrint('[TiledMapWorld] Available layers:');
      for (final layer in _tiledMap.tileMap.map.layers) {
        debugPrint('  - "${layer.name}" (${layer.runtimeType})');
      }
      return;
    }

    debugPrint('[TiledMapWorld] Found "Water" layer, scanning for fishable tiles...');

    final tileMap = _tiledMap.tileMap.map;
    int totalWaterTiles = 0;
    int fishableTiles = 0;
    final Set<int> uniqueGids = {};

    // Scan for fishable tiles
    for (int y = 0; y < mapHeightTiles; y++) {
      for (int x = 0; x < mapWidthTiles; x++) {
        final gid = waterLayer.tileData?[y][x].tile;
        if (gid == null || gid == 0) continue;

        totalWaterTiles++;
        uniqueGids.add(gid);

        // Check if this tile has is_fishable property
        final tile = tileMap.tileByGid(gid);
        final isFishable = tile?.properties.getValue<bool>('is_fishable') ?? false;

        if (isFishable) {
          fishableTiles++;
          final waterType = _determineWaterType(x, y, gid);
          _fishableTileCache[_tileKey(x, y)] = waterType;
        }
      }
    }

    debugPrint('[TiledMapWorld] Water layer scan complete:');
    debugPrint('  - Total water tiles found: $totalWaterTiles');
    debugPrint('  - Unique tile GIDs: ${uniqueGids.length}');
    debugPrint('  - Tiles with is_fishable=true: $fishableTiles');

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
          _playerSpawnPoint = Vector2((x + 0.5) * renderedTileSize, (y + 0.5) * renderedTileSize);
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
          final scaledRect = Rect.fromLTWH(rect.left * mapScale, rect.top * mapScale, rect.width * mapScale, rect.height * mapScale);

          if (scaledRect.contains(Offset(tileLocalX, tileLocalY))) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Check if a world position is inside the water (collision area) of a fishable tile.
  /// This checks if the point is on a fishable tile AND within that tile's collision area.
  bool isInsideWater(double x, double y) {
    final tileX = (x / renderedTileSize).floor();
    final tileY = (y / renderedTileSize).floor();

    if (tileX < 0 || tileX >= mapWidthTiles || tileY < 0 || tileY >= mapHeightTiles) {
      return false;
    }

    // First check if this tile is fishable
    if (!_fishableTileCache.containsKey(_tileKey(tileX, tileY))) {
      return false;
    }

    // Now check if the point is within the collision area of this fishable tile
    // The collision area defines the actual water portion of the tile
    return _isInFishableTileCollision(x, y, tileX, tileY);
  }

  /// Check if a point is within the collision area of a fishable tile at the given tile position.
  /// Returns true if the point hits a collision object on the water layer tile.
  bool _isInFishableTileCollision(double worldX, double worldY, int tileX, int tileY) {
    final waterLayer = _tiledMap.tileMap.getLayer<TileLayer>('Water');
    if (waterLayer == null) return false;

    final gid = waterLayer.tileData?[tileY][tileX].tile;
    if (gid == null || gid == 0) return false;

    final collisionRects = _tileCollisionCache[gid];
    if (collisionRects == null || collisionRects.isEmpty) {
      // No collision defined - treat entire tile as water (fallback)
      return true;
    }

    // Calculate position within the tile
    final tileLocalX = worldX - (tileX * renderedTileSize);
    final tileLocalY = worldY - (tileY * renderedTileSize);

    // Check each collision rect (scale from tile coords to world coords)
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

    return false;
  }

  /// Check if a world position is on a fishable tile (for casting proximity detection)
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

  /// Check if a player position is near any fishable water (for fishing).
  /// Optimized to only check tiles within a certain radius of the player.
  bool isPlayerNearWater(Vector2 playerPos, double castingBuffer) {
    // Calculate tile range to check (in tiles, not world coords)
    final checkRadiusTiles = ((castingBuffer + renderedTileSize) / renderedTileSize).ceil();
    final centerTileX = (playerPos.x / renderedTileSize).floor();
    final centerTileY = (playerPos.y / renderedTileSize).floor();

    final minTileX = (centerTileX - checkRadiusTiles).clamp(0, mapWidthTiles - 1);
    final maxTileX = (centerTileX + checkRadiusTiles).clamp(0, mapWidthTiles - 1);
    final minTileY = (centerTileY - checkRadiusTiles).clamp(0, mapHeightTiles - 1);
    final maxTileY = (centerTileY + checkRadiusTiles).clamp(0, mapHeightTiles - 1);

    // Check only tiles within range
    for (int ty = minTileY; ty <= maxTileY; ty++) {
      for (int tx = minTileX; tx <= maxTileX; tx++) {
        if (!_fishableTileCache.containsKey(_tileKey(tx, ty))) continue;

        // Check if player is within casting range of this tile's water area
        if (_isTileWaterInRange(tx, ty, playerPos.x, playerPos.y, castingBuffer)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if a tile's water (collision area) is within casting range of player.
  bool _isTileWaterInRange(int tileX, int tileY, double playerX, double playerY, double buffer) {
    final waterLayer = _tiledMap.tileMap.getLayer<TileLayer>('Water');
    if (waterLayer == null) return false;

    final gid = waterLayer.tileData?[tileY][tileX].tile;
    if (gid == null || gid == 0) return false;

    final tileWorldX = tileX * renderedTileSize;
    final tileWorldY = tileY * renderedTileSize;

    final collisionRects = _tileCollisionCache[gid];
    if (collisionRects == null || collisionRects.isEmpty) {
      // No collision - check distance to tile bounds
      final tileRect = Rect.fromLTWH(tileWorldX, tileWorldY, renderedTileSize, renderedTileSize);
      return _isPointNearRect(playerX, playerY, tileRect, buffer);
    }

    // Check if player is near any collision rect (the water area)
    for (final rect in collisionRects) {
      final worldRect = Rect.fromLTWH(
        tileWorldX + rect.left * mapScale,
        tileWorldY + rect.top * mapScale,
        rect.width * mapScale,
        rect.height * mapScale,
      );
      if (_isPointNearRect(playerX, playerY, worldRect, buffer)) {
        return true;
      }
    }
    return false;
  }

  /// Check if a point is within buffer distance of a rectangle (but not inside).
  bool _isPointNearRect(double px, double py, Rect rect, double buffer) {
    // Expand rect by buffer
    final expanded = Rect.fromLTRB(
      rect.left - buffer,
      rect.top - buffer,
      rect.right + buffer,
      rect.bottom + buffer,
    );
    // Check if in expanded but not in original
    final inExpanded = expanded.contains(Offset(px, py));
    final inOriginal = rect.contains(Offset(px, py));
    return inExpanded && !inOriginal;
  }

  /// Get info about nearby water the player can cast into.
  /// Optimized to only check tiles within a certain radius.
  ({WaterType waterType, String id})? getNearbyWaterInfo(Vector2 playerPos, double castingBuffer) {
    final checkRadiusTiles = ((castingBuffer + renderedTileSize) / renderedTileSize).ceil();
    final centerTileX = (playerPos.x / renderedTileSize).floor();
    final centerTileY = (playerPos.y / renderedTileSize).floor();

    final minTileX = (centerTileX - checkRadiusTiles).clamp(0, mapWidthTiles - 1);
    final maxTileX = (centerTileX + checkRadiusTiles).clamp(0, mapWidthTiles - 1);
    final minTileY = (centerTileY - checkRadiusTiles).clamp(0, mapHeightTiles - 1);
    final maxTileY = (centerTileY + checkRadiusTiles).clamp(0, mapHeightTiles - 1);

    for (int ty = minTileY; ty <= maxTileY; ty++) {
      for (int tx = minTileX; tx <= maxTileX; tx++) {
        final waterType = _fishableTileCache[_tileKey(tx, ty)];
        if (waterType == null) continue;

        if (_isTileWaterInRange(tx, ty, playerPos.x, playerPos.y, castingBuffer)) {
          return (waterType: waterType, id: 'tile_${tx}_$ty');
        }
      }
    }
    return null;
  }

  /// Get fishable tiles near a position for debug rendering.
  /// Returns list of (tileX, tileY, waterType, collisionRects in world coords).
  List<({int tileX, int tileY, WaterType waterType, List<Rect> collisionRects})>
      getFishableTilesNear(Vector2 pos, double radius) {
    final result = <({int tileX, int tileY, WaterType waterType, List<Rect> collisionRects})>[];

    final checkRadiusTiles = ((radius + renderedTileSize) / renderedTileSize).ceil();
    final centerTileX = (pos.x / renderedTileSize).floor();
    final centerTileY = (pos.y / renderedTileSize).floor();

    final minTileX = (centerTileX - checkRadiusTiles).clamp(0, mapWidthTiles - 1);
    final maxTileX = (centerTileX + checkRadiusTiles).clamp(0, mapWidthTiles - 1);
    final minTileY = (centerTileY - checkRadiusTiles).clamp(0, mapHeightTiles - 1);
    final maxTileY = (centerTileY + checkRadiusTiles).clamp(0, mapHeightTiles - 1);

    final waterLayer = _tiledMap.tileMap.getLayer<TileLayer>('Water');

    for (int ty = minTileY; ty <= maxTileY; ty++) {
      for (int tx = minTileX; tx <= maxTileX; tx++) {
        final waterType = _fishableTileCache[_tileKey(tx, ty)];
        if (waterType == null) continue;

        final tileWorldX = tx * renderedTileSize;
        final tileWorldY = ty * renderedTileSize;

        List<Rect> worldRects = [];

        if (waterLayer != null) {
          final gid = waterLayer.tileData?[ty][tx].tile;
          if (gid != null && gid != 0) {
            final collisionRects = _tileCollisionCache[gid];
            if (collisionRects != null && collisionRects.isNotEmpty) {
              worldRects = collisionRects.map((rect) => Rect.fromLTWH(
                tileWorldX + rect.left * mapScale,
                tileWorldY + rect.top * mapScale,
                rect.width * mapScale,
                rect.height * mapScale,
              )).toList();
            }
          }
        }

        // If no collision rects, use the full tile
        if (worldRects.isEmpty) {
          worldRects = [Rect.fromLTWH(tileWorldX, tileWorldY, renderedTileSize, renderedTileSize)];
        }

        result.add((tileX: tx, tileY: ty, waterType: waterType, collisionRects: worldRects));
      }
    }
    return result;
  }

  /// Dock areas - for now, empty since we're transitioning from old system
  /// These will be detected from an objects layer later
  List<Rect> get dockAreas => [];
}
