import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../game/world/nature_tileset.dart';
import '../utils/constants.dart';
import 'editor_world.dart';
import 'placeable_item.dart';

/// Map editor game - a standalone Flame game for visual map editing.
/// 
/// This is completely separate from LurelandsGame and has:
/// - No player, no fishing mechanics, no SpacetimeDB connection
/// - Pan/zoom camera controlled by mouse/touch
/// - Click-to-place items from the sidebar palette
/// - Grid overlay for precise placement
class MapEditorGame extends FlameGame
    with
        ScrollDetector,
        ScaleDetector,
        TapCallbacks,
        SecondaryTapDetector,
        KeyboardEvents {
  
  /// Currently selected item type from sidebar
  PlaceableItemType? selectedItemType;
  
  /// Currently selected tile (for tile placement mode)
  NatureTile? selectedTile;
  
  /// Water type for water tiles
  WaterType selectedWaterType = WaterType.pond;
  
  /// Tree variant (0-3)
  int selectedTreeVariant = 0;
  
  /// Tree type
  TreeType selectedTreeType = TreeType.round;
  
  /// All placed items in the world
  final List<PlacedItem> placedItems = [];
  
  /// Currently selected/hovered item for editing
  PlacedItem? selectedItem;
  
  /// Grid visibility toggle
  bool showGrid = true;
  
  /// Snap to grid toggle
  bool snapToGrid = true;
  
  /// Grid size in pixels (matches tile size)
  double get gridSize => NatureTilesheet.tileSize * NatureTilesheet.renderScale;
  
  /// Callback when placed items change (for UI updates)
  void Function()? onItemsChanged;
  
  /// The editor world component
  late EditorWorld _editorWorld;
  
  // Camera control state
  Vector2 _lastPanPosition = Vector2.zero();
  double _currentZoom = 1.0;
  static const double _minZoom = 0.25;
  static const double _maxZoom = 3.0;

  @override
  Color backgroundColor() => GameColors.grassGreen;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Create the editor world
    _editorWorld = EditorWorld(editor: this);
    world = _editorWorld;

    // Set up camera
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = _currentZoom;
    
    // Start camera at center of world
    camera.viewfinder.position = Vector2(
      GameConstants.worldWidth / 2,
      GameConstants.worldHeight / 2,
    );
  }

  /// Snap a position to the grid cell's top-left corner
  /// Always snaps for tiles, optionally for other items
  Vector2 snapPositionToCell(Vector2 pos) {
    // Use floor to always get the cell the click is inside
    return Vector2(
      (pos.x / gridSize).floor() * gridSize,
      (pos.y / gridSize).floor() * gridSize,
    );
  }

  /// Snap a position to the nearest grid intersection (for non-tile items)
  Vector2 snapPositionToGrid(Vector2 pos) {
    if (!snapToGrid) return pos;
    return Vector2(
      (pos.x / gridSize).round() * gridSize,
      (pos.y / gridSize).round() * gridSize,
    );
  }

  /// Convert screen position to world position
  Vector2 screenToWorld(Vector2 screenPos) {
    return camera.viewfinder.globalToLocal(screenPos);
  }

  /// Place an item at the given world position
  void placeItemAt(Vector2 worldPos) {
    if (selectedItemType == null && selectedTile == null) return;

    PlacedItem item;
    
    if (selectedTile != null) {
      // Tiles always snap to grid cell (top-left corner of clicked cell)
      final snappedPos = snapPositionToCell(worldPos);
      item = PlacedItem(
        id: _generateId(),
        type: PlaceableItemType.tile,
        position: snappedPos,
        tile: selectedTile,
        waterType: _isWaterTile(selectedTile!) ? selectedWaterType : null,
      );
    } else {
      // Components snap to grid intersection if snap is enabled
      final snappedPos = snapPositionToGrid(worldPos);
      item = PlacedItem(
        id: _generateId(),
        type: selectedItemType!,
        position: snappedPos,
        treeType: selectedItemType == PlaceableItemType.tree ? selectedTreeType : null,
        treeVariant: selectedItemType == PlaceableItemType.tree ? selectedTreeVariant : null,
      );
    }
    
    placedItems.add(item);
    _editorWorld.addPlacedItem(item);
    onItemsChanged?.call();
  }

  /// Remove an item at the given world position
  void removeItemAt(Vector2 worldPos) {
    // Find item at position (check in reverse order for top-most)
    for (int i = placedItems.length - 1; i >= 0; i--) {
      final item = placedItems[i];
      if (_isPositionOnItem(worldPos, item)) {
        placedItems.removeAt(i);
        _editorWorld.removePlacedItem(item);
        if (selectedItem == item) {
          selectedItem = null;
        }
        onItemsChanged?.call();
        return;
      }
    }
  }

  /// Select an item at the given world position
  PlacedItem? selectItemAt(Vector2 worldPos) {
    // Find item at position (check in reverse order for top-most)
    for (int i = placedItems.length - 1; i >= 0; i--) {
      final item = placedItems[i];
      if (_isPositionOnItem(worldPos, item)) {
        selectedItem = item;
        onItemsChanged?.call();
        return item;
      }
    }
    selectedItem = null;
    onItemsChanged?.call();
    return null;
  }

  /// Check if a position is within an item's bounds
  bool _isPositionOnItem(Vector2 pos, PlacedItem item) {
    final itemSize = _getItemSize(item);
    final halfSize = itemSize / 2;
    return pos.x >= item.position.x - halfSize.x &&
           pos.x <= item.position.x + halfSize.x &&
           pos.y >= item.position.y - halfSize.y &&
           pos.y <= item.position.y + halfSize.y;
  }

  /// Get the visual size of an item for hit testing
  Vector2 _getItemSize(PlacedItem item) {
    switch (item.type) {
      case PlaceableItemType.tile:
        return Vector2.all(gridSize);
      case PlaceableItemType.tree:
        return Vector2(96, 102); // Tree size at 3x scale
      case PlaceableItemType.shop:
        return Vector2(64, 64); // Shop size
      case PlaceableItemType.questSign:
        return Vector2(48, 48); // Sign size
      case PlaceableItemType.sunflower:
        return Vector2(48, 48);
      case PlaceableItemType.walkableZone:
        return item.zoneSize ?? Vector2.all(gridSize);
    }
  }

  /// Check if a tile is a water tile
  bool _isWaterTile(NatureTile tile) {
    return tile == NatureTile.waterTopLeft ||
           tile == NatureTile.waterTop ||
           tile == NatureTile.waterTopRight ||
           tile == NatureTile.waterLeft ||
           tile == NatureTile.waterMiddle ||
           tile == NatureTile.waterRight ||
           tile == NatureTile.waterBottomLeft ||
           tile == NatureTile.waterBottom ||
           tile == NatureTile.waterBottomRight ||
           tile == NatureTile.waterPlain;
  }

  /// Generate a unique ID for placed items
  String _generateId() {
    return 'item_${DateTime.now().millisecondsSinceEpoch}_${placedItems.length}';
  }

  /// Clear all placed items
  void clearAll() {
    for (final item in placedItems) {
      _editorWorld.removePlacedItem(item);
    }
    placedItems.clear();
    selectedItem = null;
    onItemsChanged?.call();
  }

  /// Toggle grid visibility
  void toggleGrid() {
    showGrid = !showGrid;
    _editorWorld.updateGrid();
  }

  /// Toggle snap to grid
  void toggleSnap() {
    snapToGrid = !snapToGrid;
  }

  // --- Input Handling ---

  @override
  void onTapUp(TapUpEvent event) {
    final worldPos = screenToWorld(event.canvasPosition);
    
    // If we have something selected to place, place it
    if (selectedItemType != null || selectedTile != null) {
      placeItemAt(worldPos);
    } else {
      // Otherwise try to select an existing item
      selectItemAt(worldPos);
    }
  }

  @override
  void onSecondaryTapUp(TapUpInfo info) {
    // Right-click to delete
    final worldPos = screenToWorld(info.eventPosition.global);
    removeItemAt(worldPos);
  }

  @override
  void onScroll(PointerScrollInfo info) {
    // Zoom with scroll wheel
    final scrollDelta = info.scrollDelta.global.y;
    final zoomDelta = scrollDelta > 0 ? 0.9 : 1.1;
    
    _currentZoom = (_currentZoom * zoomDelta).clamp(_minZoom, _maxZoom);
    camera.viewfinder.zoom = _currentZoom;
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    _lastPanPosition = info.eventPosition.global;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    // Handle pinch zoom
    if (info.scale.global != Vector2.all(1.0)) {
      final scaleDelta = info.scale.global.x;
      if (scaleDelta != 1.0) {
        _currentZoom = (_currentZoom * scaleDelta).clamp(_minZoom, _maxZoom);
        camera.viewfinder.zoom = _currentZoom;
      }
    }
    
    // Handle pan (two-finger drag or middle mouse)
    final delta = info.eventPosition.global - _lastPanPosition;
    _lastPanPosition = info.eventPosition.global;
    
    // Only pan if not zooming (single touch/click drag)
    if (info.pointerCount == 1 || info.scale.global == Vector2.all(1.0)) {
      // Invert delta and scale by zoom for natural panning
      camera.viewfinder.position -= delta / _currentZoom;
      
      // Clamp to world bounds
      _clampCameraPosition();
    }
  }

  void _clampCameraPosition() {
    final pos = camera.viewfinder.position;
    camera.viewfinder.position = Vector2(
      pos.x.clamp(0, GameConstants.worldWidth),
      pos.y.clamp(0, GameConstants.worldHeight),
    );
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Keyboard shortcuts
    if (event is KeyDownEvent) {
      // G = Toggle grid
      if (event.logicalKey == LogicalKeyboardKey.keyG) {
        toggleGrid();
        return KeyEventResult.handled;
      }
      // S = Toggle snap
      if (event.logicalKey == LogicalKeyboardKey.keyS) {
        toggleSnap();
        return KeyEventResult.handled;
      }
      // Delete/Backspace = Delete selected item
      if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        if (selectedItem != null) {
          placedItems.remove(selectedItem);
          _editorWorld.removePlacedItem(selectedItem!);
          selectedItem = null;
          onItemsChanged?.call();
        }
        return KeyEventResult.handled;
      }
      // Escape = Deselect
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        selectedItem = null;
        selectedItemType = null;
        selectedTile = null;
        onItemsChanged?.call();
        return KeyEventResult.handled;
      }
    }
    
    return KeyEventResult.ignored;
  }

  /// Export all placed items to JSON
  Map<String, dynamic> exportToJson() {
    final tiles = <Map<String, dynamic>>[];
    final trees = <Map<String, dynamic>>[];
    final structures = <Map<String, dynamic>>[];
    final decorations = <Map<String, dynamic>>[];
    final walkableZones = <Map<String, dynamic>>[];

    for (final item in placedItems) {
      final json = item.toJson();
      
      switch (item.type) {
        case PlaceableItemType.tile:
          tiles.add(json);
          break;
        case PlaceableItemType.tree:
          trees.add(json);
          break;
        case PlaceableItemType.shop:
        case PlaceableItemType.questSign:
          structures.add(json);
          break;
        case PlaceableItemType.sunflower:
          decorations.add(json);
          break;
        case PlaceableItemType.walkableZone:
          walkableZones.add(json);
          break;
      }
    }

    return {
      'version': 1,
      'worldWidth': GameConstants.worldWidth,
      'worldHeight': GameConstants.worldHeight,
      'tiles': tiles,
      'trees': trees,
      'structures': structures,
      'decorations': decorations,
      'walkableZones': walkableZones,
    };
  }

  /// Import placed items from JSON
  void importFromJson(Map<String, dynamic> json) {
    clearAll();
    
    // Import tiles
    final tiles = json['tiles'] as List<dynamic>? ?? [];
    for (final tileJson in tiles) {
      final item = PlacedItem.fromJson(tileJson as Map<String, dynamic>);
      placedItems.add(item);
      _editorWorld.addPlacedItem(item);
    }
    
    // Import trees
    final trees = json['trees'] as List<dynamic>? ?? [];
    for (final treeJson in trees) {
      final item = PlacedItem.fromJson(treeJson as Map<String, dynamic>);
      placedItems.add(item);
      _editorWorld.addPlacedItem(item);
    }
    
    // Import structures
    final structures = json['structures'] as List<dynamic>? ?? [];
    for (final structJson in structures) {
      final item = PlacedItem.fromJson(structJson as Map<String, dynamic>);
      placedItems.add(item);
      _editorWorld.addPlacedItem(item);
    }
    
    // Import decorations
    final decorations = json['decorations'] as List<dynamic>? ?? [];
    for (final decoJson in decorations) {
      final item = PlacedItem.fromJson(decoJson as Map<String, dynamic>);
      placedItems.add(item);
      _editorWorld.addPlacedItem(item);
    }
    
    // Import walkable zones
    final walkableZones = json['walkableZones'] as List<dynamic>? ?? [];
    for (final zoneJson in walkableZones) {
      final item = PlacedItem.fromJson(zoneJson as Map<String, dynamic>);
      placedItems.add(item);
      _editorWorld.addPlacedItem(item);
    }
    
    onItemsChanged?.call();
  }
}

/// Tree type for editor
enum TreeType { round, pine }

