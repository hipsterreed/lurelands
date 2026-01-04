import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/water_body_data.dart';
import '../../services/spacetimedb/stdb_service.dart';
import '../../utils/constants.dart';
import '../components/ocean.dart';
import '../components/pond.dart';
import '../components/river.dart';
import '../components/shop.dart';
import '../components/sunflower.dart';
import '../components/tree.dart';
import '../lurelands_game.dart';
import 'nature_tileset.dart';
import 'world_decorations.dart';

/// Default fallback world state when server data is unavailable
const WorldState fallbackWorldState = WorldState(
  ponds: [
    PondData(id: 'pond_1', x: 600, y: 600, radius: 100),
    PondData(id: 'pond_2', x: 1400, y: 1200, radius: 80),
  ],
  rivers: [
    RiverData(id: 'river_1', x: 1000, y: 400, width: 80, length: 600, rotation: 0.3),
  ],
  ocean: OceanData(id: 'ocean_1', x: 0, y: 0, width: 250, height: 2000),
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
  final List<Pond> _pondComponents = [];
  final List<River> _riverComponents = [];
  Ocean? _oceanComponent;
  final List<Tree> _treeComponents = [];
  final List<Shop> _shopComponents = [];
  
  /// Nature tileset for decorations
  late NatureTilesheet _tilesheet;

  /// All pond components in the world
  List<Pond> get pondComponents => _pondComponents;

  /// All river components in the world
  List<River> get riverComponents => _riverComponents;

  /// The ocean component (if any)
  Ocean? get oceanComponent => _oceanComponent;

  /// All tree components in the world
  List<Tree> get treeComponents => _treeComponents;

  /// All shop components in the world
  List<Shop> get shopComponents => _shopComponents;

  /// All water body data for collision/proximity checks
  List<WaterBodyData> get allWaterBodies => [
    ...worldState.ponds,
    ...worldState.rivers,
    if (worldState.ocean != null) worldState.ocean!,
  ];

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
    // Add ocean (typically on left side of map)
    if (worldState.ocean != null) {
      _oceanComponent = Ocean(data: worldState.ocean!);
      await add(_oceanComponent!);
    }

    // Add rivers
    for (final riverData in worldState.rivers) {
      final river = River(data: riverData);
      _riverComponents.add(river);
      await add(river);
    }

    // Add ponds
    for (final pondData in worldState.ponds) {
      final pond = Pond(data: pondData);
      _pondComponents.add(pond);
      await add(pond);
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
    for (final waterBody in allWaterBodies) {
      if (waterBody.containsPoint(x, y)) {
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

