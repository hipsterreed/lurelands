import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../../utils/constants.dart';
import 'nature_tileset.dart';

/// A performant component that renders many decorative tiles using SpriteBatch.
/// 
/// SpriteBatch renders all tiles in a single draw call, making it ideal for
/// hundreds of static decorations like weeds, mushrooms, flowers, etc.
class WorldDecorations extends PositionComponent with HasGameReference {
  /// The loaded tileset
  final NatureTilesheet tilesheet;
  
  /// List of decoration placements to render
  final List<DecorationPlacement> placements;
  
  /// The sprite batch for efficient rendering
  SpriteBatch? _spriteBatch;

  WorldDecorations({
    required this.tilesheet,
    required this.placements,
  }) : super(
    position: Vector2.zero(),
    priority: 1, // Just above ground
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    if (placements.isEmpty) return;
    
    // Get any sprite to access the image reference
    final sampleSprite = tilesheet.getSprite(placements.first.tile);
    
    // Create sprite batch from the tileset image
    _spriteBatch = SpriteBatch(sampleSprite.image);
    
    // Add all decorations to the batch
    for (final placement in placements) {
      final sprite = tilesheet.getSprite(placement.tile);
      
      // Calculate the source rect from the sprite
      final srcRect = Rect.fromLTWH(
        sprite.srcPosition.x,
        sprite.srcPosition.y,
        sprite.srcSize.x,
        sprite.srcSize.y,
      );
      
      // Calculate render position (centered at bottom)
      final renderSize = NatureTilesheet.renderedSize;
      final renderPos = Offset(
        placement.position.x - renderSize.x / 2,
        placement.position.y - renderSize.y,
      );
      
      // Add to batch with scaling
      _spriteBatch!.addTransform(
        source: srcRect,
        transform: RSTransform.fromComponents(
          rotation: 0,
          scale: NatureTilesheet.renderScale,
          anchorX: 0,
          anchorY: 0,
          translateX: renderPos.dx,
          translateY: renderPos.dy,
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    _spriteBatch?.render(canvas);
  }
  
  /// Factory to create weeds sprinkled across the world.
  /// 
  /// [tilesheet] - The loaded tileset
  /// [count] - Number of weeds to spawn
  /// [seed] - Random seed for consistent placement
  /// [isValidPosition] - Callback to check if position is valid (not in water, etc.)
  static WorldDecorations generateWeeds({
    required NatureTilesheet tilesheet,
    int count = 150,
    int seed = 999,
    bool Function(double x, double y)? isValidPosition,
  }) {
    final random = Random(seed);
    final placements = <DecorationPlacement>[];
    
    int attempts = 0;
    while (placements.length < count && attempts < count * 3) {
      attempts++;
      
      // Random position (avoid ocean area on left)
      final x = 300 + random.nextDouble() * (GameConstants.worldWidth - 400);
      final y = 100 + random.nextDouble() * (GameConstants.worldHeight - 200);
      
      // Check if position is valid
      if (isValidPosition != null && !isValidPosition(x, y)) {
        continue;
      }
      
      placements.add(DecorationPlacement(
        tile: NatureTile.weed,
        position: Vector2(x, y),
      ));
    }
    
    return WorldDecorations(
      tilesheet: tilesheet,
      placements: placements,
    );
  }
  
  /// Factory to create random decorations across the world.
  /// 
  /// [tilesheet] - The loaded tileset
  /// [count] - Number of decorations to spawn
  /// [seed] - Random seed for consistent placement
  /// [tiles] - List of tiles with weights to randomly select from
  /// [isValidPosition] - Callback to check if position is valid (not in water, etc.)
  static WorldDecorations generateRandom({
    required NatureTilesheet tilesheet,
    required List<({NatureTile tile, int weight})> tiles,
    int count = 100,
    int seed = 999,
    bool Function(double x, double y)? isValidPosition,
  }) {
    final random = Random(seed);
    final placements = <DecorationPlacement>[];
    
    // Calculate total weight for weighted random selection
    final totalWeight = tiles.fold(0, (sum, opt) => sum + opt.weight);
    
    int attempts = 0;
    while (placements.length < count && attempts < count * 3) {
      attempts++;
      
      // Random position (avoid ocean area on left)
      final x = 300 + random.nextDouble() * (GameConstants.worldWidth - 400);
      final y = 100 + random.nextDouble() * (GameConstants.worldHeight - 200);
      
      // Check if position is valid
      if (isValidPosition != null && !isValidPosition(x, y)) {
        continue;
      }
      
      // Weighted random tile selection
      int roll = random.nextInt(totalWeight);
      NatureTile selectedTile = tiles.first.tile;
      for (final option in tiles) {
        roll -= option.weight;
        if (roll < 0) {
          selectedTile = option.tile;
          break;
        }
      }
      
      placements.add(DecorationPlacement(
        tile: selectedTile,
        position: Vector2(x, y),
      ));
    }
    
    return WorldDecorations(
      tilesheet: tilesheet,
      placements: placements,
    );
  }
}

