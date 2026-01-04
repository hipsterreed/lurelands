import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

/// Tile definitions for nature.png (16x16 grid, each tile 16px)
/// 
/// Coordinates are 0-indexed, so col 9 in the tileset = index 8.
/// Format: TileName(column, row)
enum NatureTile {
  // Vegetation
  grassPlain(1, 3),
  weed(8, 4),
  mushroomBrown(8, 5),
  mushroomRed(8, 7),
  reeds(3, 3),
  rockInWater(2, 3),
  flower1(8, 6),
  flower2(9, 5),
  
  // Water tiles (9-slice pattern for building water bodies)
  // Top row: grass on top, bank, water on bottom
  waterTopLeft(3, 0),      // Corner: grass top-left
  waterTop(4, 0),          // Edge: grass on top
  waterTopRight(5, 0),     // Corner: grass top-right
  // Middle row: grass on sides, water with texture
  waterLeft(3, 1),         // Edge: grass on left
  waterMiddle(4, 1),       // Center: water with top texture
  waterRight(5, 1),        // Edge: grass on right
  // Bottom row: grass on bottom, water on top
  waterBottomLeft(3, 2),   // Corner: grass bottom-left
  waterBottom(4, 2),       // Edge: grass on bottom
  waterBottomRight(5, 2),  // Corner: grass bottom-right
  // Plain water (solid color, for large bodies)
  waterPlain(4, 3),
  ;

  /// Column index (0-based) in the tileset
  final int col;
  
  /// Row index (0-based) in the tileset
  final int row;
  
  const NatureTile(this.col, this.row);
}

/// Loader and accessor for the nature tileset spritesheet.
/// 
/// Usage:
/// ```dart
/// final tilesheet = NatureTilesheet();
/// await tilesheet.load(game.images);
/// final sprite = tilesheet.getSprite(NatureTile.weed);
/// ```
class NatureTilesheet {
  /// Size of each tile in pixels
  static const int tileSize = 16;
  
  /// Number of columns in the tileset (adjust if your sheet differs)
  static const int columns = 16;
  
  /// Number of rows in the tileset (adjust if your sheet differs)
  static const int rows = 16;
  
  /// Scale factor for rendering (matches tree scaling)
  static const double renderScale = 3.0;
  
  /// The loaded sprite sheet
  late SpriteSheet _sheet;
  
  /// Whether the tileset has been loaded
  bool _loaded = false;
  
  /// Check if tileset is loaded
  bool get isLoaded => _loaded;
  
  /// Load the tileset from the images cache
  Future<void> load(Images images) async {
    final image = await images.load('tiles/nature.png');
    _sheet = SpriteSheet(
      image: image,
      srcSize: Vector2.all(tileSize.toDouble()),
    );
    _loaded = true;
  }
  
  /// Get a sprite for a named tile
  Sprite getSprite(NatureTile tile) {
    assert(_loaded, 'NatureTilesheet must be loaded before use');
    // SpriteSheet.getSprite takes (row, column)
    return _sheet.getSprite(tile.row, tile.col);
  }
  
  /// Get a sprite by raw grid coordinates (0-indexed)
  Sprite getSpriteAt(int col, int row) {
    assert(_loaded, 'NatureTilesheet must be loaded before use');
    return _sheet.getSprite(row, col);
  }
  
  /// Get the rendered size of a tile (with scale applied)
  static Vector2 get renderedSize => Vector2.all(tileSize * renderScale);
}

/// Represents a decoration placement in the world
class DecorationPlacement {
  /// The tile type to render
  final NatureTile tile;
  
  /// World position (bottom-center anchor)
  final Vector2 position;
  
  const DecorationPlacement({
    required this.tile,
    required this.position,
  });
}

/// Helper class for working with the 9-slice water tileset.
/// 
/// The water tiles form a 3x3 grid pattern:
/// ```
/// [TopLeft]    [Top]    [TopRight]
/// [Left]       [Middle] [Right]
/// [BottomLeft] [Bottom] [BottomRight]
/// ```
/// 
/// Use [waterPlain] for interior tiles in large water bodies.
class WaterTiles {
  WaterTiles._();
  
  // Corners
  static const NatureTile topLeft = NatureTile.waterTopLeft;
  static const NatureTile topRight = NatureTile.waterTopRight;
  static const NatureTile bottomLeft = NatureTile.waterBottomLeft;
  static const NatureTile bottomRight = NatureTile.waterBottomRight;
  
  // Edges
  static const NatureTile top = NatureTile.waterTop;
  static const NatureTile bottom = NatureTile.waterBottom;
  static const NatureTile left = NatureTile.waterLeft;
  static const NatureTile right = NatureTile.waterRight;
  
  // Center/interior
  static const NatureTile middle = NatureTile.waterMiddle;
  static const NatureTile plain = NatureTile.waterPlain;
  
  /// Get the appropriate tile for a position in a rectangular water body.
  /// 
  /// [x] - column index within the water body (0 = left edge)
  /// [y] - row index within the water body (0 = top edge)
  /// [width] - total width in tiles
  /// [height] - total height in tiles
  /// [useTexturedMiddle] - if true, uses waterMiddle (with texture) for top row interior
  static NatureTile getTileAt(int x, int y, int width, int height, {bool useTexturedMiddle = true}) {
    final isLeft = x == 0;
    final isRight = x == width - 1;
    final isTop = y == 0;
    final isBottom = y == height - 1;
    
    // Corners
    if (isTop && isLeft) return topLeft;
    if (isTop && isRight) return topRight;
    if (isBottom && isLeft) return bottomLeft;
    if (isBottom && isRight) return bottomRight;
    
    // Edges
    if (isTop) return top;
    if (isBottom) return bottom;
    if (isLeft) return left;
    if (isRight) return right;
    
    // Interior - use textured middle for row just below top edge
    if (useTexturedMiddle && y == 1) return middle;
    
    // Deep interior - plain water
    return plain;
  }
  
  /// Generate a list of tile placements for a rectangular water body.
  /// 
  /// [startX] - world X position of top-left corner
  /// [startY] - world Y position of top-left corner
  /// [widthInTiles] - width of water body in tiles
  /// [heightInTiles] - height of water body in tiles
  /// [tileSize] - rendered size of each tile (default: 48 = 16 * 3)
  static List<({NatureTile tile, double x, double y})> generateRectangle({
    required double startX,
    required double startY,
    required int widthInTiles,
    required int heightInTiles,
    double tileSize = 48.0,
  }) {
    final placements = <({NatureTile tile, double x, double y})>[];
    
    for (int y = 0; y < heightInTiles; y++) {
      for (int x = 0; x < widthInTiles; x++) {
        final tile = getTileAt(x, y, widthInTiles, heightInTiles);
        placements.add((
          tile: tile,
          x: startX + x * tileSize,
          y: startY + y * tileSize,
        ));
      }
    }
    
    return placements;
  }
}

