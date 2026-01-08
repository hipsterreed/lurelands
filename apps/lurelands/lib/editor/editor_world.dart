import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../game/world/nature_tileset.dart';
import '../utils/constants.dart';
import 'map_editor_game.dart';
import 'placeable_item.dart';

/// The editor world - renders ground, grid, and all placed items.
/// 
/// This is a simplified world for the map editor with no game logic.
class EditorWorld extends World with HasGameReference<MapEditorGame> {
  final MapEditorGame editor;
  
  EditorWorld({required this.editor});

  /// Nature tileset for rendering tiles
  late NatureTilesheet _tilesheet;
  
  /// Grid overlay component
  late GridOverlay _gridOverlay;
  
  /// Map of placed item IDs to their visual components
  final Map<String, Component> _itemComponents = {};

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load the nature tileset
    _tilesheet = NatureTilesheet();
    await _tilesheet.load(game.images);

    // Add tiled ground (same as main game)
    await add(EditorGround(tilesheet: _tilesheet));

    // Add grid overlay
    _gridOverlay = GridOverlay(editor: editor);
    await add(_gridOverlay);
  }

  /// Add a visual component for a placed item
  Future<void> addPlacedItem(PlacedItem item) async {
    Component? component;

    switch (item.type) {
      case PlaceableItemType.tile:
        if (item.tile != null) {
          component = EditorTileComponent(
            tilesheet: _tilesheet,
            tile: item.tile!,
            position: item.position.clone(),
          );
        }
        break;
        
      case PlaceableItemType.tree:
        component = EditorTreeComponent(
          position: item.position.clone(),
          treeType: item.treeType ?? TreeType.round,
          variant: item.treeVariant ?? 0,
        );
        break;
        
      case PlaceableItemType.shop:
        component = EditorShopComponent(
          position: item.position.clone(),
        );
        break;
        
      case PlaceableItemType.questSign:
        component = EditorQuestSignComponent(
          position: item.position.clone(),
        );
        break;
        
      case PlaceableItemType.sunflower:
        component = EditorSunflowerComponent(
          position: item.position.clone(),
        );
        break;
        
      case PlaceableItemType.walkableZone:
        component = EditorWalkableZoneComponent(
          position: item.position.clone(),
          zoneSize: item.zoneSize ?? Vector2.all(48),
        );
        break;
    }

    if (component != null) {
      _itemComponents[item.id] = component;
      await add(component);
    }
  }

  /// Remove the visual component for a placed item
  void removePlacedItem(PlacedItem item) {
    final component = _itemComponents.remove(item.id);
    if (component != null) {
      remove(component);
    }
  }

  /// Update grid visibility
  void updateGrid() {
    _gridOverlay.visible = editor.showGrid;
  }

  /// Get the tilesheet for palette preview rendering
  NatureTilesheet get tilesheet => _tilesheet;
}

/// Ground component - tiles grass across the entire world
class EditorGround extends PositionComponent {
  final NatureTilesheet tilesheet;
  
  EditorGround({required this.tilesheet})
      : super(
          position: Vector2.zero(),
          size: Vector2(GameConstants.worldWidth, GameConstants.worldHeight),
          priority: 0,
        );

  Image? _tiledImage;
  bool _textureGenerated = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _generateTiledTexture();
  }

  Future<void> _generateTiledTexture() async {
    final grassSprite = tilesheet.getSprite(NatureTile.grassPlain);
    final tileSize = NatureTilesheet.tileSize * NatureTilesheet.renderScale;
    
    final tilesX = (size.x / tileSize).ceil();
    final tilesY = (size.y / tileSize).ceil();
    
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    
    for (var y = 0; y < tilesY; y++) {
      for (var x = 0; x < tilesX; x++) {
        grassSprite.render(
          canvas,
          position: Vector2(x * tileSize, y * tileSize),
          size: Vector2.all(tileSize),
        );
      }
    }
    
    final picture = recorder.endRecording();
    _tiledImage = await picture.toImage(size.x.toInt(), size.y.toInt());
    _textureGenerated = true;
  }

  @override
  void render(Canvas canvas) {
    if (_textureGenerated && _tiledImage != null) {
      canvas.drawImage(_tiledImage!, Offset.zero, Paint());
    } else {
      final basePaint = Paint()..color = GameColors.grassGreen;
      canvas.drawRect(size.toRect(), basePaint);
    }
  }
}

/// Grid overlay for precise placement
class GridOverlay extends PositionComponent {
  final MapEditorGame editor;
  
  GridOverlay({required this.editor})
      : super(
          position: Vector2.zero(),
          size: Vector2(GameConstants.worldWidth, GameConstants.worldHeight),
          priority: 1000, // Render on top
        );

  bool visible = true;

  @override
  void render(Canvas canvas) {
    if (!visible) return;

    final gridSize = editor.gridSize;
    final paint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw vertical lines
    for (double x = 0; x <= size.x; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.y),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.y; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.x, y),
        paint,
      );
    }
  }
}

/// A placed tile from the tileset
class EditorTileComponent extends SpriteComponent {
  final NatureTilesheet tilesheet;
  final NatureTile tile;

  EditorTileComponent({
    required this.tilesheet,
    required this.tile,
    required Vector2 position,
  }) : super(
         position: position,
         size: NatureTilesheet.renderedSize,
         anchor: Anchor.topLeft,
         priority: 10,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = tilesheet.getSprite(tile);
  }
}

/// A placed tree component
class EditorTreeComponent extends SpriteComponent with HasGameReference<MapEditorGame> {
  final TreeType treeType;
  final int variant;

  EditorTreeComponent({
    required Vector2 position,
    required this.treeType,
    required this.variant,
  }) : super(
         position: position,
         anchor: Anchor.bottomCenter,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    if (treeType == TreeType.round) {
      final sheet = SpriteSheet(
        image: await game.images.load('plants/tree_01_strip4.png'),
        srcSize: Vector2(32, 34),
      );
      sprite = sheet.getSprite(0, variant);
      size = Vector2(32 * 3, 34 * 3);
    } else {
      final sheet = SpriteSheet(
        image: await game.images.load('plants/tree_02_strip4.png'),
        srcSize: Vector2(28, 43),
      );
      sprite = sheet.getSprite(0, variant);
      size = Vector2(28 * 3, 43 * 3);
    }

    priority = position.y.toInt();
  }
}

/// A placed shop component
class EditorShopComponent extends SpriteComponent with HasGameReference<MapEditorGame> {
  EditorShopComponent({required Vector2 position})
      : super(
          position: position,
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite('structures/fish_house1.png');
    if (sprite != null) {
      size = Vector2(sprite!.srcSize.x * 2, sprite!.srcSize.y * 2);
    }
    priority = position.y.toInt();
  }
}

/// A placed quest sign component
class EditorQuestSignComponent extends SpriteComponent with HasGameReference<MapEditorGame> {
  EditorQuestSignComponent({required Vector2 position})
      : super(
          position: position,
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite('structures/sign.png');
    if (sprite != null) {
      size = Vector2(sprite!.srcSize.x * 2, sprite!.srcSize.y * 2);
    }
    priority = position.y.toInt();
  }
}

/// A placed sunflower component
class EditorSunflowerComponent extends SpriteComponent with HasGameReference<MapEditorGame> {
  EditorSunflowerComponent({required Vector2 position})
      : super(
          position: position,
          anchor: Anchor.bottomCenter,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite('plants/sunflower.png');
    if (sprite != null) {
      size = Vector2(sprite!.srcSize.x * 2, sprite!.srcSize.y * 2);
    }
    priority = position.y.toInt();
  }
}

/// A walkable zone (visible in editor, invisible in game)
class EditorWalkableZoneComponent extends PositionComponent {
  final Vector2 zoneSize;

  EditorWalkableZoneComponent({
    required Vector2 position,
    required this.zoneSize,
  }) : super(
         position: position,
         size: zoneSize,
         anchor: Anchor.topLeft,
         priority: 5,
       );

  @override
  void render(Canvas canvas) {
    // Draw semi-transparent green rectangle
    final paint = Paint()
      ..color = const Color(0x4000FF00)
      ..style = PaintingStyle.fill;
    canvas.drawRect(size.toRect(), paint);

    // Draw border
    final borderPaint = Paint()
      ..color = const Color(0xFF00FF00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(size.toRect(), borderPaint);
  }
}

