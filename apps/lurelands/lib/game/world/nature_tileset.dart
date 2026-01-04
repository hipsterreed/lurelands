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
  
  // Add more tiles here as you identify them in the tileset
  // Format: tileName(col, row),  // description
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

