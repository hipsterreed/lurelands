import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../services/spacetimedb/stdb_service.dart';
import '../../utils/constants.dart';
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
  
  /// Nature tileset for decorations and water
  late NatureTilesheet _tilesheet;
  
  /// Tiled water body configurations (ponds/rivers built from tiles)
  final List<TiledWaterData> _tiledWaterData = [];

  /// All tree components in the world
  List<Tree> get treeComponents => _treeComponents;

  /// All shop components in the world
  List<Shop> get shopComponents => _shopComponents;
  
  /// All tiled water body components
  List<TiledWaterBody> get tiledWaterComponents => _tiledWaterComponents;
  
  /// All tiled water data for collision/proximity checks
  List<TiledWaterData> get allTiledWaterData => _tiledWaterData;

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
      // Ocean: spans the left edge of the map, shifted 1 tile left to hide the edge
      TiledWaterData(
        id: 'ocean_1',
        x: -tileSize,  // Start 1 tile off-screen to hide left edge
        y: 0,
        widthInTiles: 6,  // One extra tile to compensate for offset
        heightInTiles: oceanHeightInTiles,
        waterType: WaterType.ocean,
      ),
      // Pond 1: 8x6 tiles - bigger to accommodate dock
      const TiledWaterData(
        id: 'tiled_pond_1',
        x: 500,
        y: 500,
        widthInTiles: 8,
        heightInTiles: 6,
        waterType: WaterType.pond,
      ),
      // Pond 2: 7x5 tiles - bigger to accommodate dock
      const TiledWaterData(
        id: 'tiled_pond_2',
        x: 1300,
        y: 900,
        widthInTiles: 7,
        heightInTiles: 5,
        waterType: WaterType.pond,
      ),
      // River: 10x3 tiles (long horizontal river)
      const TiledWaterData(
        id: 'tiled_river_1',
        x: 800,
        y: 300,
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
    // Ocean right edge is at 5 * tileSize - tileSize = ~192px
    await _spawnOceanDock(
      oceanEdgeX: 5 * tileSize - tileSize,
      y: 500.0,
      tileSize: tileSize,
    );
    
    // Pond 1 dock - extends from bottom shore into pond (moved up 4 tiles from bottom edge)
    // Pond 1 is at (500, 500) with size 8x6 tiles, bottom edge at 500 + 6*48 = 788
    // Moving dock up 4 tiles: 788 - 4*48 = 596
    await _spawnPondDock(
      pondX: 500.0,
      pondBottomY: 500.0 + 6 * tileSize - 4 * tileSize,  // Moved up 4 tiles
      pondWidth: 8 * tileSize,
      tileSize: tileSize,
    );
    
    // Pond 2 dock - extends from bottom shore into pond
    // Pond 2 is at (1300, 900) with size 7x5 tiles, bottom edge at 900 + 5*48 = 1140
    await _spawnPondDock(
      pondX: 1300.0,
      pondBottomY: 900.0 + 5 * tileSize,
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
  }
  
  /// Spawn reeds and rocks inside/around ponds and rivers
  Future<void> _spawnWaterDecorations() async {
    final random = Random(888); // Seeded for consistent placement
    final tileSize = NatureTilesheet.tileSize * NatureTilesheet.renderScale;
    
    for (final waterData in _tiledWaterData) {
      // Skip ocean - too big and doesn't need decorations
      if (waterData.waterType == WaterType.ocean) continue;
      
      // Calculate number of decorations based on water body size
      final area = waterData.widthInTiles * waterData.heightInTiles;
      final decorationCount = (area * 0.3).ceil().clamp(2, 8); // ~30% coverage, min 2, max 8
      
      for (var i = 0; i < decorationCount; i++) {
        // Random position within the water body (avoiding edges)
        final margin = tileSize * 0.5;
        final x = waterData.x + margin + random.nextDouble() * (waterData.width - margin * 2);
        final y = waterData.y + margin + random.nextDouble() * (waterData.height - margin * 2);
        
        // Randomly choose reed or rock
        final tile = random.nextBool() ? NatureTile.reeds : NatureTile.rockInWater;
        
        // Create a sprite component for the decoration
        final sprite = _tilesheet.getSprite(tile);
        final decoration = SpriteComponent(
          sprite: sprite,
          position: Vector2(x, y),
          size: NatureTilesheet.renderedSize,
          anchor: Anchor.center,
          priority: GameLayers.pond.toInt() + 1, // Just above water
        );
        await add(decoration);
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
      // Start after ocean area
      final x = 300 + random.nextDouble() * (GameConstants.worldWidth - 400);
      final y = 100 + random.nextDouble() * (GameConstants.worldHeight - 200);

      // Don't place sunflowers inside any water body
      if (!_isInsideWater(x, y)) {
        await add(Sunflower(position: Vector2(x, y)));
      }
    }
  }

  /// Spawn trees randomly around the map
  Future<void> _spawnTrees() async {
    final random = Random(456); // Different seed for variety
    const count = 20;

    for (var i = 0; i < count; i++) {
      // Start after ocean area
      final x = 350 + random.nextDouble() * (GameConstants.worldWidth - 450);
      final y = 150 + random.nextDouble() * (GameConstants.worldHeight - 300);

      // Don't place trees inside any water body
      if (!_isInsideWater(x, y)) {
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
      isValidPosition: (x, y) => !_isInsideWater(x, y),
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
      // Make sure shop is not inside water
      if (!_isInsideWater(shopData.x, shopData.y)) {
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

