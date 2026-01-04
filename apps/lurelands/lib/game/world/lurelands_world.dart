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
    // Define tiled ponds and rivers
    final tiledWaterConfigs = [
      // Pond 1: 5x4 tiles at position (500, 500)
      const TiledWaterData(
        id: 'tiled_pond_1',
        x: 500,
        y: 500,
        widthInTiles: 5,
        heightInTiles: 4,
        waterType: WaterType.pond,
      ),
      // Pond 2: 4x3 tiles at position (1300, 1000)
      const TiledWaterData(
        id: 'tiled_pond_2',
        x: 1300,
        y: 1000,
        widthInTiles: 4,
        heightInTiles: 3,
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

