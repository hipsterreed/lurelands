import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/water_body_data.dart';
import '../../services/spacetimedb/stdb_service.dart';
import '../../utils/constants.dart';
import '../components/ocean.dart';
import '../components/pond.dart';
import '../components/river.dart';
import '../components/sunflower.dart';
import '../components/tree.dart';

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
/// 
/// The player is added separately by [LurelandsGame] after spawn position is determined.
class LurelandsWorld extends World {
  /// Water body configuration for this world
  final WorldState worldState;

  LurelandsWorld({required this.worldState});

  // Component references for external access
  final List<Pond> _pondComponents = [];
  final List<River> _riverComponents = [];
  Ocean? _oceanComponent;
  final List<Tree> _treeComponents = [];

  /// All pond components in the world
  List<Pond> get pondComponents => _pondComponents;

  /// All river components in the world
  List<River> get riverComponents => _riverComponents;

  /// The ocean component (if any)
  Ocean? get oceanComponent => _oceanComponent;

  /// All tree components in the world
  List<Tree> get treeComponents => _treeComponents;

  /// All water body data for collision/proximity checks
  List<WaterBodyData> get allWaterBodies => [
    ...worldState.ponds,
    ...worldState.rivers,
    if (worldState.ocean != null) worldState.ocean!,
  ];

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Add ground terrain
    await add(Ground());

    // Add water bodies
    await _addWaterBodies();

    // Add vegetation
    await _spawnVegetation();
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
}

/// Ground component - solid green with scattered pixel shade spots
class Ground extends PositionComponent {
  Ground()
      : super(
          position: Vector2.zero(),
          size: Vector2(GameConstants.worldWidth, GameConstants.worldHeight),
          priority: 0,
        );

  // Size of shade pixels
  static const double pixelSize = 6.0;
  
  // Cached texture image
  Image? _textureImage;
  bool _textureGenerated = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _generateTexture();
  }

  /// Generate the ground texture with sparse pixel spots
  Future<void> _generateTexture() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Draw solid base color
    final basePaint = Paint()..color = GameColors.grassGreen;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), basePaint);
    
    // Seeded random for consistent spots
    final random = Random(789);
    
    // Shade colors
    final darkPaint = Paint()..color = GameColors.grassGreenDark;
    final lightPaint = Paint()..color = GameColors.grassGreenLight;
    
    // Scatter sparse pixel spots across the map
    final spotCount = 800; // Adjust for density
    
    for (var i = 0; i < spotCount; i++) {
      final x = (random.nextDouble() * size.x / pixelSize).floor() * pixelSize;
      final y = (random.nextDouble() * size.y / pixelSize).floor() * pixelSize;
      final isLight = random.nextBool();
      
      canvas.drawRect(
        Rect.fromLTWH(x, y, pixelSize, pixelSize),
        isLight ? lightPaint : darkPaint,
      );
    }
    
    // Convert to image
    final picture = recorder.endRecording();
    _textureImage = await picture.toImage(size.x.toInt(), size.y.toInt());
    _textureGenerated = true;
  }

  @override
  void render(Canvas canvas) {
    if (_textureGenerated && _textureImage != null) {
      canvas.drawImage(_textureImage!, Offset.zero, Paint());
    } else {
      // Fallback while texture generates
      final basePaint = Paint()..color = GameColors.grassGreen;
      canvas.drawRect(size.toRect(), basePaint);
    }
  }
}

