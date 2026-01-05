import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../../services/spacetimedb/stdb_service.dart';
import '../../utils/constants.dart';
import '../components/quest_sign.dart';
import '../components/shop.dart';
import '../components/sunflower.dart';
import '../components/tiled_water.dart';
import '../components/tree.dart';
import '../lurelands_game.dart';
import 'nature_tileset.dart';
import 'world_decorations.dart';

/// Default fallback world state when server data is unavailable
/// Note: Ponds and rivers are now defined as tiled water bodies in _addTiledWaterBodies()
const WorldState fallbackWorldState = WorldState(
  ponds: [],
  rivers: [],
  ocean: null,
);

/// The game world containing terrain, water bodies, and vegetation.
/// 
/// This component is responsible for:
/// - Ground/terrain rendering
/// - Water bodies (ponds, rivers, ocean)
/// - Vegetation spawning (trees, sunflowers)
/// - Decorations (weeds, mushrooms) from tileset
/// 
/// The player is added separately by [LurelandsGame] after spawn position is determined.
class LurelandsWorld extends World with HasGameReference<LurelandsGame> {
  /// Water body configuration for this world
  final WorldState worldState;

  LurelandsWorld({required this.worldState});

  // Component references for external access
  final List<TiledWaterBody> _tiledWaterComponents = [];
  final List<Tree> _treeComponents = [];
  final List<Shop> _shopComponents = [];
  final List<QuestSign> _questSignComponents = [];

  /// Dock walkable areas (rectangles where players can walk over water)
  final List<Rect> _dockAreas = [];

  /// Nature tileset for decorations and water
  late NatureTilesheet _tilesheet;

  /// Tiled water body configurations (ponds/rivers built from tiles)
  final List<TiledWaterData> _tiledWaterData = [];

  /// All tree components in the world
  List<Tree> get treeComponents => _treeComponents;

  /// All shop components in the world
  List<Shop> get shopComponents => _shopComponents;

  /// All quest sign components in the world
  List<QuestSign> get questSignComponents => _questSignComponents;

  /// All tiled water body components
  List<TiledWaterBody> get tiledWaterComponents => _tiledWaterComponents;
  
  /// All tiled water data for collision/proximity checks
  List<TiledWaterData> get allTiledWaterData => _tiledWaterData;
  
  /// All dock walkable areas
  List<Rect> get dockAreas => _dockAreas;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load the nature tileset
    _tilesheet = NatureTilesheet();
    await _tilesheet.load(game.images);

    // Add ground terrain (tiled grass from tileset)
    await add(TiledGround(tilesheet: _tilesheet));

    // Add water bodies
    await _addWaterBodies();

    // Add vegetation
    await _spawnVegetation();
    
    // Add tileset decorations (weeds, mushrooms)
    await _spawnDecorations();
    
    // Add shops
    await _spawnShops();
    
    // Add quest signs
    await _spawnQuestSigns();
  }

  /// Add all water body components to the world
  Future<void> _addWaterBodies() async {
    // Add tiled water bodies (ponds and rivers from tileset)
    await _addTiledWaterBodies();
  }

  /// Add tiled water bodies built from the tileset
  Future<void> _addTiledWaterBodies() async {
    // Calculate ocean height in tiles to span full map height
    // Tile size = 16 * 3 = 48px, map height = 2000px
    final tileSize = NatureTilesheet.tileSize * NatureTilesheet.renderScale;
    final oceanHeightInTiles = (GameConstants.worldHeight / tileSize).ceil();
    
    // Define tiled ponds, rivers, and ocean
    final tiledWaterConfigs = [
      // Ocean: spans the left edge of the map, extended 6 tiles further into the world
      TiledWaterData(
        id: 'ocean_1',
        x: -tileSize,  // Start 1 tile off-screen to hide left edge
        y: 0,
        widthInTiles: 12,  // Extended 6 more tiles into the world (was 6)
        heightInTiles: oceanHeightInTiles,
        waterType: WaterType.ocean,
      ),
      // Pond 1: 10x8 tiles - larger lake by the merchant
      const TiledWaterData(
        id: 'tiled_pond_1',
        x: 980,
        y: 450,  // Moved up slightly to accommodate larger size
        widthInTiles: 10,
        heightInTiles: 8,
        waterType: WaterType.pond,
      ),
      // Pond 2: 7x5 tiles - moved 10 tiles right
      const TiledWaterData(
        id: 'tiled_pond_2',
        x: 1780,  // Was 1300, moved 10 tiles (480px) right
        y: 900,
        widthInTiles: 7,
        heightInTiles: 5,
        waterType: WaterType.pond,
      ),
      // River: 10x3 tiles - moved 10 tiles right and up 1 tile
      const TiledWaterData(
        id: 'tiled_river_1',
        x: 1280,  // Was 800, moved 10 tiles (480px) right
        y: 252,   // Moved up 1 tile (was 300)
        widthInTiles: 10,
        heightInTiles: 3,
        waterType: WaterType.river,
      ),
    ];

    for (final data in tiledWaterConfigs) {
      _tiledWaterData.add(data);
      
      final waterBody = TiledWaterBody(
        id: data.id,
        tilesheet: _tilesheet,
        position: Vector2(data.x, data.y),
        widthInTiles: data.widthInTiles,
        heightInTiles: data.heightInTiles,
        waterType: data.waterType,
      );
      _tiledWaterComponents.add(waterBody);
      await add(waterBody);
    }
    
    // Add decorations (reeds and rocks) to ponds and rivers
    await _spawnWaterDecorations();
    
    // Add docks to ocean and ponds
    await _spawnDocks();
  }
  
  /// Spawn docks next to water bodies
  Future<void> _spawnDocks() async {
    final tileSize = NatureTilesheet.tileSize * NatureTilesheet.renderScale;
    
    // Ocean dock - rotated 90° clockwise to extend horizontally from shore into ocean
    // Ocean: x=-48, width=12 tiles, so right edge is at -48 + 12*48 = 528
    await _spawnOceanDock(
      oceanEdgeX: -tileSize + 12 * tileSize,  // Right edge of the ocean (528px)
      y: 500.0,
      tileSize: tileSize,
    );
    
    // Pond 1 dock - extends from bottom shore into pond (moved up 6 tiles from bottom edge)
    // Pond 1 is at (980, 450) with size 10x8 tiles, bottom edge at 450 + 8*48 = 834
    // Moving dock up 6 tiles: 834 - 6*48 = 546
    await _spawnPondDock(
      pondX: 980.0,
      pondBottomY: 450.0 + 8 * tileSize - 6 * tileSize,  // Moved up 6 tiles (was 4)
      pondWidth: 10 * tileSize,
      tileSize: tileSize,
    );
    
    // Pond 2 dock - extends from bottom shore into pond (moved up 3 tiles)
    // Pond 2 is at (1780, 900) with size 7x5 tiles, bottom edge at 900 + 5*48 = 1140
    await _spawnPondDock(
      pondX: 1780.0,  // Updated to match new pond position
      pondBottomY: 900.0 + 5 * tileSize - 3 * tileSize,  // Moved up 3 tiles
      pondWidth: 7 * tileSize,
      tileSize: tileSize,
    );
  }
  
  /// Spawn ocean dock - rotated 90° clockwise to go horizontally
  Future<void> _spawnOceanDock({required double oceanEdgeX, required double y, required double tileSize}) async {
    // Dock rotated 90° clockwise: what was vertical is now horizontal
    // Left 2 columns on grass, right 2 columns over water
    // We'll place tiles manually with rotation
    
    final dockTiles = [
      // First column (far left, on grass) - use bottom tiles (end of dock on land)
      (tile: NatureTile.dockBottomLeft, col: 0, row: 0),
      (tile: NatureTile.dockBottomRight, col: 0, row: 1),
      // Second column - on grass
      (tile: NatureTile.dockMiddle2Left, col: 1, row: 0),
      (tile: NatureTile.dockMiddle2Right, col: 1, row: 1),
      // Third column - over water
      (tile: NatureTile.dockMiddle1Left, col: 2, row: 0),
      (tile: NatureTile.dockMiddle1Right, col: 2, row: 1),
      // Fourth column (far right, over water) - use top tiles (end of dock in water)
      (tile: NatureTile.dockTopLeft, col: 3, row: 0),
      (tile: NatureTile.dockTopRight, col: 3, row: 1),
    ];
    
    // Position so 2 columns on grass (right of ocean edge), 2 columns over water
    final startX = oceanEdgeX - tileSize * 2;  // Start 2 tiles left of ocean edge
    final startY = y;
    
    for (final dt in dockTiles) {
      final sprite = _tilesheet.getSprite(dt.tile);
      final dockTile = SpriteComponent(
        sprite: sprite,
        position: Vector2(startX + dt.col * tileSize, startY + dt.row * tileSize),
        size: NatureTilesheet.renderedSize,
        anchor: Anchor.topLeft,
        angle: 1.5708,  // 90 degrees clockwise in radians (pi/2)
        priority: GameLayers.pond.toInt() + 2,
      );
      await add(dockTile);
    }
    
    // Register dock walkable area (3 columns wide, 2 rows tall - exclude rightmost column which is the end)
    _dockAreas.add(Rect.fromLTWH(startX, startY, tileSize * 3, tileSize * 2));
  }
  
  /// Spawn pond dock - vertical, extending from bottom shore into pond
  Future<void> _spawnPondDock({required double pondX, required double pondBottomY, required double pondWidth, required double tileSize}) async {
    // Position dock centered on pond, with top 2 rows on grass (below pond), bottom 2 in water
    final dockX = pondX + (pondWidth - DockTiles.width) / 2;  // Centered
    final dockY = pondBottomY - tileSize * 2;  // Top 2 rows inside pond, bottom 2 outside
    
    final placements = DockTiles.generate(
      startX: dockX,
      startY: dockY,
    );
    
    for (final placement in placements) {
      final sprite = _tilesheet.getSprite(placement.tile);
      final dockTile = SpriteComponent(
        sprite: sprite,
        position: Vector2(placement.x, placement.y),
        size: NatureTilesheet.renderedSize,
        anchor: Anchor.topLeft,
        priority: GameLayers.pond.toInt() + 2,
      );
      await add(dockTile);
    }
    
    // Register dock walkable area (2 tiles wide, 3 tiles tall - exclude bottom tile which is the end)
    _dockAreas.add(Rect.fromLTWH(dockX, dockY, DockTiles.width, DockTiles.height - tileSize));
  }
  
  /// Spawn reeds and rocks inside/around ponds and rivers
  Future<void> _spawnWaterDecorations() async {
    final random = Random(999); // Changed seed for better distribution
    final tileSize = NatureTilesheet.tileSize * NatureTilesheet.renderScale;
    final minDistance = tileSize * 1.5; // Minimum distance between decorations
    
    for (final waterData in _tiledWaterData) {
      // Skip ocean - too big and doesn't need decorations
      if (waterData.waterType == WaterType.ocean) continue;
      
      // Calculate number of decorations based on water body size
      final area = waterData.widthInTiles * waterData.heightInTiles;
      final decorationCount = (area * 0.25).ceil().clamp(2, 6); // Reduced for better spread
      
      // Track placed positions to ensure spread and no overlaps
      final placedPositions = <Vector2>[];
      
      for (var i = 0; i < decorationCount; i++) {
        // Try to find a good position that's spread out
        Vector2? bestPosition;
        for (var attempt = 0; attempt < 20; attempt++) {
          // Random position within the water body (avoiding edges)
          final margin = tileSize * 0.8;
          final x = waterData.x + margin + random.nextDouble() * (waterData.width - margin * 2);
          final y = waterData.y + margin + random.nextDouble() * (waterData.height - margin * 2);
          final candidatePos = Vector2(x, y);
          
          // Check if this position is far enough from all placed decorations
          bool tooClose = false;
          for (final placed in placedPositions) {
            if (candidatePos.distanceTo(placed) < minDistance) {
              tooClose = true;
              break;
            }
          }
          
          if (!tooClose) {
            bestPosition = candidatePos;
            break;
          }
        }
        
        // If we found a valid position, place the decoration
        if (bestPosition != null) {
          placedPositions.add(bestPosition);
          
          // Alternate between reeds and rocks for variety
          final tile = i.isEven ? NatureTile.reeds : NatureTile.rockInWater;
          
          // Create a sprite component for the decoration
          final sprite = _tilesheet.getSprite(tile);
          final decoration = SpriteComponent(
            sprite: sprite,
            position: bestPosition,
            size: NatureTilesheet.renderedSize,
            anchor: Anchor.center,
            priority: GameLayers.pond.toInt() + 1, // Just above water
          );
          await add(decoration);
        }
      }
    }
  }

  /// Spawn decorative vegetation (trees and sunflowers)
  Future<void> _spawnVegetation() async {
    await _spawnSunflowers();
    await _spawnTrees();
  }

  /// Spawn sunflowers randomly around the map
  Future<void> _spawnSunflowers() async {
    final random = Random(123); // Seeded for consistent placement
    const count = 30;

    for (var i = 0; i < count; i++) {
      // Start after ocean area (ocean right edge is at ~528px)
      final x = 580 + random.nextDouble() * (GameConstants.worldWidth - 680);
      final y = 100 + random.nextDouble() * (GameConstants.worldHeight - 200);

      // Don't place sunflowers inside water or on docks
      if (_isValidPlacement(x, y)) {
        await add(Sunflower(position: Vector2(x, y)));
      }
    }
  }

  /// Spawn trees randomly around the map
  Future<void> _spawnTrees() async {
    final random = Random(1234); // Changed seed to avoid trees in ponds/rivers
    const count = 20;

    for (var i = 0; i < count; i++) {
      // Start after ocean area (ocean right edge is at ~528px)
      final x = 580 + random.nextDouble() * (GameConstants.worldWidth - 680);
      final y = 150 + random.nextDouble() * (GameConstants.worldHeight - 300);

      // Don't place trees inside water or on docks
      if (_isValidPlacement(x, y)) {
        final tree = Tree.random(Vector2(x, y), random);
        _treeComponents.add(tree);
        await add(tree);
      }
    }
  }

  /// Spawn weeds and flowers across the map using SpriteBatch for performance
  Future<void> _spawnDecorations() async {
    final decorations = WorldDecorations.generateRandom(
      tilesheet: _tilesheet,
      tiles: [
        (tile: NatureTile.weed, weight: 10),    // Most common
        (tile: NatureTile.flower1, weight: 2),  // Light sprinkle
        (tile: NatureTile.flower2, weight: 2),  // Light sprinkle
      ],
      count: 150,
      seed: 777,
      isValidPosition: (x, y) => _isValidPlacement(x, y),
    );
    await add(decorations);
  }

  /// Check if a point is inside any water body
  bool _isInsideWater(double x, double y) {
    for (final tiledWater in _tiledWaterData) {
      if (tiledWater.containsPoint(x, y)) {
        return true;
      }
    }
    return false;
  }
  
  /// Check if a point is on a dock
  bool _isOnDock(double x, double y) {
    for (final dockRect in _dockAreas) {
      if (dockRect.contains(Offset(x, y))) {
        return true;
      }
    }
    return false;
  }
  
  /// Check if a position is valid for placing objects (not in water or on dock)
  bool _isValidPlacement(double x, double y) {
    return !_isInsideWater(x, y) && !_isOnDock(x, y);
  }

  /// Check if a point is inside any water body (public for external use)
  bool isInsideWater(double x, double y) => _isInsideWater(x, y);

  /// Spawn shops at fixed locations on the map
  Future<void> _spawnShops() async {
    // Place a shop at a nice location - near center but not in water
    // Position it away from the ocean (which is on the left side)
    final shopPositions = [
      (x: 800.0, y: 800.0, id: 'main_shop', name: 'Fish Market'),
    ];

    for (final shopData in shopPositions) {
      // Make sure shop is not inside water or on a dock
      if (_isValidPlacement(shopData.x, shopData.y)) {
        final shop = Shop(
          position: Vector2(shopData.x, shopData.y),
          id: shopData.id,
          name: shopData.name,
        );
        _shopComponents.add(shop);
        await add(shop);
      }
    }
  }

  /// Spawn quest signs at fixed locations on the map
  Future<void> _spawnQuestSigns() async {
    final tileSize = NatureTilesheet.tileSize * NatureTilesheet.renderScale;
    
    // Ocean dock is at: startX = 528 - 96 = 432, y = 500
    // Place sign just to the right of the dock on the grass
    final oceanDockSignX = 432.0 + tileSize * 4;  // Right of dock
    final oceanDockSignY = 500.0 + tileSize;      // Centered on dock y
    
    // Pond 1 dock: centered on pond at (980, 450) with width 10*48
    // Dock y is around 546 (450 + 8*48 - 6*48), extends down 4 tiles
    // Place sign to the right of the dock, on the shore
    final pond1DockX = 980.0 + (10 * tileSize) / 2 + tileSize * 2; // Right of dock
    final pond1DockY = 450.0 + 8 * tileSize - 6 * tileSize + tileSize * 5; // Below dock, on shore
    
    // Quest signs with their associated storylines
    final questSignPositions = [
      (
        x: oceanDockSignX, 
        y: oceanDockSignY, 
        id: 'ocean_quest_board', 
        name: "Sailor's Board",
        storylines: ['ocean_mysteries'],
      ),
      (
        x: pond1DockX, 
        y: pond1DockY, 
        id: 'guild_quest_board', 
        name: "Fisher's Guild",
        storylines: ['fishermans_guild'],
      ),
    ];

    for (final signData in questSignPositions) {
      debugPrint('[World] QuestSign ${signData.id} at (${signData.x}, ${signData.y})');
      
      final questSign = QuestSign(
        position: Vector2(signData.x, signData.y),
        id: signData.id,
        name: signData.name,
        storylines: signData.storylines,
      );
      _questSignComponents.add(questSign);
      await add(questSign);
      debugPrint('[World] Added quest sign: ${signData.id} for storylines: ${signData.storylines}');
    }
    debugPrint('[World] Total quest signs added: ${_questSignComponents.length}');
  }
}

/// Ground component - tiles the grassPlain sprite across the entire world
class TiledGround extends PositionComponent {
  final NatureTilesheet tilesheet;
  
  TiledGround({required this.tilesheet})
      : super(
          position: Vector2.zero(),
          size: Vector2(GameConstants.worldWidth, GameConstants.worldHeight),
          priority: 0,
        );

  // Cached tiled texture
  Image? _tiledImage;
  bool _textureGenerated = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _generateTiledTexture();
  }

  /// Generate the ground by tiling the grass sprite
  Future<void> _generateTiledTexture() async {
    final grassSprite = tilesheet.getSprite(NatureTile.grassPlain);
    
    // Tile size after scaling
    final tileSize = NatureTilesheet.tileSize * NatureTilesheet.renderScale;
    
    // Calculate how many tiles we need
    final tilesX = (size.x / tileSize).ceil();
    final tilesY = (size.y / tileSize).ceil();
    
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Tile the grass sprite across the entire world
    for (var y = 0; y < tilesY; y++) {
      for (var x = 0; x < tilesX; x++) {
        grassSprite.render(
          canvas,
          position: Vector2(x * tileSize, y * tileSize),
          size: Vector2.all(tileSize),
        );
      }
    }
    
    // Convert to image for efficient rendering
    final picture = recorder.endRecording();
    _tiledImage = await picture.toImage(size.x.toInt(), size.y.toInt());
    _textureGenerated = true;
  }

  @override
  void render(Canvas canvas) {
    if (_textureGenerated && _tiledImage != null) {
      canvas.drawImage(_tiledImage!, Offset.zero, Paint());
    } else {
      // Fallback while texture generates
      final basePaint = Paint()..color = GameColors.grassGreen;
      canvas.drawRect(size.toRect(), basePaint);
    }
  }
}

