import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../../utils/constants.dart';
import '../world/nature_tileset.dart';

/// A rectangular water body rendered using 9-slice tiles from the tileset.
/// 
/// This component uses SpriteBatch for efficient rendering of tile-based
/// ponds and rivers.
class TiledWaterBody extends PositionComponent with CollisionCallbacks {
  /// Unique identifier for this water body
  final String id;
  
  /// The tileset to render from
  final NatureTilesheet tilesheet;
  
  /// Width of the water body in tiles
  final int widthInTiles;
  
  /// Height of the water body in tiles
  final int heightInTiles;
  
  /// Water type for fishing purposes
  final WaterType waterType;
  
  /// Sprite batch for efficient rendering
  SpriteBatch? _spriteBatch;

  TiledWaterBody({
    required this.id,
    required this.tilesheet,
    required Vector2 position,
    required this.widthInTiles,
    required this.heightInTiles,
    this.waterType = WaterType.pond,
  }) : super(
    position: position,
    size: Vector2(
      widthInTiles * NatureTilesheet.tileSize * NatureTilesheet.renderScale,
      heightInTiles * NatureTilesheet.tileSize * NatureTilesheet.renderScale,
    ),
    anchor: Anchor.topLeft,
    priority: GameLayers.pond.toInt(),
  );

  /// Get the rendered tile size
  double get _tileSize => NatureTilesheet.tileSize * NatureTilesheet.renderScale;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Build the sprite batch
    await _buildSpriteBatch();
    
    // Add rectangular hitbox for collision/fishing detection
    await add(RectangleHitbox());
  }

  Future<void> _buildSpriteBatch() async {
    // Get any water sprite to access the image
    final sampleSprite = tilesheet.getSprite(NatureTile.waterPlain);
    _spriteBatch = SpriteBatch(sampleSprite.image);
    
    // Generate tiles for each position
    for (int y = 0; y < heightInTiles; y++) {
      for (int x = 0; x < widthInTiles; x++) {
        final tile = WaterTiles.getTileAt(x, y, widthInTiles, heightInTiles);
        final sprite = tilesheet.getSprite(tile);
        
        // Calculate source rect from sprite
        final srcRect = Rect.fromLTWH(
          sprite.srcPosition.x,
          sprite.srcPosition.y,
          sprite.srcSize.x,
          sprite.srcSize.y,
        );
        
        // Add to batch
        _spriteBatch!.addTransform(
          source: srcRect,
          transform: RSTransform.fromComponents(
            rotation: 0,
            scale: NatureTilesheet.renderScale,
            anchorX: 0,
            anchorY: 0,
            translateX: x * _tileSize,
            translateY: y * _tileSize,
          ),
        );
      }
    }
  }

  @override
  void render(Canvas canvas) {
    _spriteBatch?.render(canvas);
  }

  /// Check if a point is inside this water body
  @override
  bool containsPoint(Vector2 point) {
    return point.x >= position.x && 
           point.x <= position.x + size.x &&
           point.y >= position.y && 
           point.y <= position.y + size.y;
  }

  /// Check if a player position is within casting range
  bool isPlayerInCastingRange(Vector2 playerPos, double proximityRadius) {
    // Expand the rectangle by proximity radius
    final expandedLeft = position.x - proximityRadius;
    final expandedRight = position.x + size.x + proximityRadius;
    final expandedTop = position.y - proximityRadius;
    final expandedBottom = position.y + size.y + proximityRadius;
    
    final inExtended = playerPos.x >= expandedLeft && 
                       playerPos.x <= expandedRight &&
                       playerPos.y >= expandedTop && 
                       playerPos.y <= expandedBottom;
    
    final inWater = containsPoint(playerPos);
    
    return inExtended && !inWater;
  }

  /// Get center position of this water body
  Vector2 get center => Vector2(
    position.x + size.x / 2,
    position.y + size.y / 2,
  );
}

/// Data class for tiled water body configuration.
/// Can be used for serialization/sync with server.
class TiledWaterData {
  final String id;
  final double x;
  final double y;
  final int widthInTiles;
  final int heightInTiles;
  final WaterType waterType;

  const TiledWaterData({
    required this.id,
    required this.x,
    required this.y,
    required this.widthInTiles,
    required this.heightInTiles,
    this.waterType = WaterType.pond,
  });

  /// Get the rendered width in world units
  double get width => widthInTiles * NatureTilesheet.tileSize * NatureTilesheet.renderScale;
  
  /// Get the rendered height in world units
  double get height => heightInTiles * NatureTilesheet.tileSize * NatureTilesheet.renderScale;

  /// Check if a point is inside this water body
  bool containsPoint(double px, double py) {
    return px >= x && px <= x + width && py >= y && py <= y + height;
  }

  /// Check if within casting range
  bool isWithinCastingRange(double px, double py, double proximityRadius) {
    final inExtended = px >= x - proximityRadius && 
                       px <= x + width + proximityRadius &&
                       py >= y - proximityRadius && 
                       py <= y + height + proximityRadius;
    return inExtended && !containsPoint(px, py);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'widthInTiles': widthInTiles,
    'heightInTiles': heightInTiles,
    'waterType': waterType.name,
  };

  factory TiledWaterData.fromJson(Map<String, dynamic> json) => TiledWaterData(
    id: json['id'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    widthInTiles: json['widthInTiles'] as int,
    heightInTiles: json['heightInTiles'] as int,
    waterType: WaterType.values.firstWhere(
      (t) => t.name == json['waterType'],
      orElse: () => WaterType.pond,
    ),
  );
}

