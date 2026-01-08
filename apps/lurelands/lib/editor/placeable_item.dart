import 'package:flame/components.dart';

import '../game/world/nature_tileset.dart';
import '../utils/constants.dart';
import 'map_editor_game.dart';

/// Types of items that can be placed in the map editor
enum PlaceableItemType {
  tile,        // Ground/water/decoration tiles from tileset
  tree,        // Tree component (round or pine)
  shop,        // Shop/fish house building
  questSign,   // Quest sign post
  sunflower,   // Sunflower decoration
  walkableZone, // Invisible walkable area (for docks, bridges)
}

/// A placed item in the map editor
class PlacedItem {
  /// Unique identifier
  final String id;
  
  /// Type of item
  final PlaceableItemType type;
  
  /// World position (center point for most items, top-left for tiles)
  Vector2 position;
  
  /// For tile type: which tile from the tileset
  final NatureTile? tile;
  
  /// For water tiles: the water type (pond, river, ocean)
  final WaterType? waterType;
  
  /// For tree type: round or pine
  final TreeType? treeType;
  
  /// For tree type: variant index (0-3)
  final int? treeVariant;
  
  /// For shop/questSign: unique ID
  final String? structureId;
  
  /// For shop/questSign: display name
  final String? structureName;
  
  /// For questSign: storylines
  final List<String>? storylines;
  
  /// For walkable zone: size of the zone
  final Vector2? zoneSize;

  PlacedItem({
    required this.id,
    required this.type,
    required this.position,
    this.tile,
    this.waterType,
    this.treeType,
    this.treeVariant,
    this.structureId,
    this.structureName,
    this.storylines,
    this.zoneSize,
  });

  /// Create a copy with updated position
  PlacedItem copyWith({Vector2? position}) {
    return PlacedItem(
      id: id,
      type: type,
      position: position ?? this.position.clone(),
      tile: tile,
      waterType: waterType,
      treeType: treeType,
      treeVariant: treeVariant,
      structureId: structureId,
      structureName: structureName,
      storylines: storylines,
      zoneSize: zoneSize,
    );
  }

  /// Convert to JSON for export
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'type': type.name,
      'x': position.x,
      'y': position.y,
    };

    if (tile != null) {
      json['tile'] = tile!.name;
    }
    if (waterType != null) {
      json['waterType'] = waterType!.name;
    }
    if (treeType != null) {
      json['treeType'] = treeType!.name;
    }
    if (treeVariant != null) {
      json['treeVariant'] = treeVariant;
    }
    if (structureId != null) {
      json['structureId'] = structureId;
    }
    if (structureName != null) {
      json['structureName'] = structureName;
    }
    if (storylines != null) {
      json['storylines'] = storylines;
    }
    if (zoneSize != null) {
      json['zoneWidth'] = zoneSize!.x;
      json['zoneHeight'] = zoneSize!.y;
    }

    return json;
  }

  /// Create from JSON
  factory PlacedItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = PlaceableItemType.values.firstWhere((t) => t.name == typeStr);
    
    NatureTile? tile;
    if (json['tile'] != null) {
      final tileStr = json['tile'] as String;
      tile = NatureTile.values.firstWhere((t) => t.name == tileStr);
    }
    
    WaterType? waterType;
    if (json['waterType'] != null) {
      final wtStr = json['waterType'] as String;
      waterType = WaterType.values.firstWhere((w) => w.name == wtStr);
    }
    
    TreeType? treeType;
    if (json['treeType'] != null) {
      final ttStr = json['treeType'] as String;
      treeType = TreeType.values.firstWhere((t) => t.name == ttStr);
    }
    
    Vector2? zoneSize;
    if (json['zoneWidth'] != null && json['zoneHeight'] != null) {
      zoneSize = Vector2(
        (json['zoneWidth'] as num).toDouble(),
        (json['zoneHeight'] as num).toDouble(),
      );
    }

    return PlacedItem(
      id: json['id'] as String,
      type: type,
      position: Vector2(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      tile: tile,
      waterType: waterType,
      treeType: treeType,
      treeVariant: json['treeVariant'] as int?,
      structureId: json['structureId'] as String?,
      structureName: json['structureName'] as String?,
      storylines: (json['storylines'] as List<dynamic>?)?.cast<String>(),
      zoneSize: zoneSize,
    );
  }
}

/// Category grouping for the sidebar palette
enum PaletteCategory {
  water('Water', 'Water tiles for building ponds, rivers, ocean'),
  ground('Ground', 'Ground and grass tiles'),
  trees('Trees', 'Trees and large plants'),
  structures('Structures', 'Buildings and interactive objects'),
  decorations('Decorations', 'Small decorative elements'),
  special('Special', 'Walkable zones and special markers');

  final String label;
  final String description;
  
  const PaletteCategory(this.label, this.description);
}

/// An entry in the item palette
class PaletteEntry {
  final String name;
  final PaletteCategory category;
  
  /// For tile entries
  final NatureTile? tile;
  
  /// For component entries
  final PlaceableItemType? itemType;
  
  /// For trees
  final TreeType? treeType;
  final int? treeVariant;
  
  /// For water tiles
  final WaterType? waterType;
  
  /// Asset path for preview image
  final String? assetPath;

  const PaletteEntry({
    required this.name,
    required this.category,
    this.tile,
    this.itemType,
    this.treeType,
    this.treeVariant,
    this.waterType,
    this.assetPath,
  });
}

/// All available palette entries
class EditorPalette {
  EditorPalette._();

  static const List<PaletteEntry> entries = [
    // --- Water tiles ---
    PaletteEntry(
      name: 'Water Top-Left',
      category: PaletteCategory.water,
      tile: NatureTile.waterTopLeft,
      waterType: WaterType.pond,
    ),
    PaletteEntry(
      name: 'Water Top',
      category: PaletteCategory.water,
      tile: NatureTile.waterTop,
      waterType: WaterType.pond,
    ),
    PaletteEntry(
      name: 'Water Top-Right',
      category: PaletteCategory.water,
      tile: NatureTile.waterTopRight,
      waterType: WaterType.pond,
    ),
    PaletteEntry(
      name: 'Water Left',
      category: PaletteCategory.water,
      tile: NatureTile.waterLeft,
      waterType: WaterType.pond,
    ),
    PaletteEntry(
      name: 'Water Middle',
      category: PaletteCategory.water,
      tile: NatureTile.waterMiddle,
      waterType: WaterType.pond,
    ),
    PaletteEntry(
      name: 'Water Right',
      category: PaletteCategory.water,
      tile: NatureTile.waterRight,
      waterType: WaterType.pond,
    ),
    PaletteEntry(
      name: 'Water Bottom-Left',
      category: PaletteCategory.water,
      tile: NatureTile.waterBottomLeft,
      waterType: WaterType.pond,
    ),
    PaletteEntry(
      name: 'Water Bottom',
      category: PaletteCategory.water,
      tile: NatureTile.waterBottom,
      waterType: WaterType.pond,
    ),
    PaletteEntry(
      name: 'Water Bottom-Right',
      category: PaletteCategory.water,
      tile: NatureTile.waterBottomRight,
      waterType: WaterType.pond,
    ),
    PaletteEntry(
      name: 'Water Plain',
      category: PaletteCategory.water,
      tile: NatureTile.waterPlain,
      waterType: WaterType.pond,
    ),
    PaletteEntry(
      name: 'Reeds',
      category: PaletteCategory.water,
      tile: NatureTile.reeds,
    ),
    PaletteEntry(
      name: 'Rock in Water',
      category: PaletteCategory.water,
      tile: NatureTile.rockInWater,
    ),
    
    // --- Ground tiles ---
    PaletteEntry(
      name: 'Grass',
      category: PaletteCategory.ground,
      tile: NatureTile.grassPlain,
    ),
    
    // --- Dock tiles ---
    PaletteEntry(
      name: 'Dock Top-Left',
      category: PaletteCategory.ground,
      tile: NatureTile.dockTopLeft,
    ),
    PaletteEntry(
      name: 'Dock Top-Right',
      category: PaletteCategory.ground,
      tile: NatureTile.dockTopRight,
    ),
    PaletteEntry(
      name: 'Dock Middle1-Left',
      category: PaletteCategory.ground,
      tile: NatureTile.dockMiddle1Left,
    ),
    PaletteEntry(
      name: 'Dock Middle1-Right',
      category: PaletteCategory.ground,
      tile: NatureTile.dockMiddle1Right,
    ),
    PaletteEntry(
      name: 'Dock Middle2-Left',
      category: PaletteCategory.ground,
      tile: NatureTile.dockMiddle2Left,
    ),
    PaletteEntry(
      name: 'Dock Middle2-Right',
      category: PaletteCategory.ground,
      tile: NatureTile.dockMiddle2Right,
    ),
    PaletteEntry(
      name: 'Dock Bottom-Left',
      category: PaletteCategory.ground,
      tile: NatureTile.dockBottomLeft,
    ),
    PaletteEntry(
      name: 'Dock Bottom-Right',
      category: PaletteCategory.ground,
      tile: NatureTile.dockBottomRight,
    ),
    
    // --- Trees ---
    PaletteEntry(
      name: 'Round Tree 1',
      category: PaletteCategory.trees,
      itemType: PlaceableItemType.tree,
      treeType: TreeType.round,
      treeVariant: 0,
      assetPath: 'plants/tree_01_strip4.png',
    ),
    PaletteEntry(
      name: 'Round Tree 2',
      category: PaletteCategory.trees,
      itemType: PlaceableItemType.tree,
      treeType: TreeType.round,
      treeVariant: 1,
      assetPath: 'plants/tree_01_strip4.png',
    ),
    PaletteEntry(
      name: 'Round Tree 3',
      category: PaletteCategory.trees,
      itemType: PlaceableItemType.tree,
      treeType: TreeType.round,
      treeVariant: 2,
      assetPath: 'plants/tree_01_strip4.png',
    ),
    PaletteEntry(
      name: 'Round Tree 4',
      category: PaletteCategory.trees,
      itemType: PlaceableItemType.tree,
      treeType: TreeType.round,
      treeVariant: 3,
      assetPath: 'plants/tree_01_strip4.png',
    ),
    PaletteEntry(
      name: 'Pine Tree 1',
      category: PaletteCategory.trees,
      itemType: PlaceableItemType.tree,
      treeType: TreeType.pine,
      treeVariant: 0,
      assetPath: 'plants/tree_02_strip4.png',
    ),
    PaletteEntry(
      name: 'Pine Tree 2',
      category: PaletteCategory.trees,
      itemType: PlaceableItemType.tree,
      treeType: TreeType.pine,
      treeVariant: 1,
      assetPath: 'plants/tree_02_strip4.png',
    ),
    PaletteEntry(
      name: 'Pine Tree 3',
      category: PaletteCategory.trees,
      itemType: PlaceableItemType.tree,
      treeType: TreeType.pine,
      treeVariant: 2,
      assetPath: 'plants/tree_02_strip4.png',
    ),
    PaletteEntry(
      name: 'Pine Tree 4',
      category: PaletteCategory.trees,
      itemType: PlaceableItemType.tree,
      treeType: TreeType.pine,
      treeVariant: 3,
      assetPath: 'plants/tree_02_strip4.png',
    ),
    
    // --- Structures ---
    PaletteEntry(
      name: 'Shop / Fish House',
      category: PaletteCategory.structures,
      itemType: PlaceableItemType.shop,
      assetPath: 'structures/fish_house1.png',
    ),
    PaletteEntry(
      name: 'Quest Sign',
      category: PaletteCategory.structures,
      itemType: PlaceableItemType.questSign,
      assetPath: 'structures/sign.png',
    ),
    
    // --- Decorations ---
    PaletteEntry(
      name: 'Sunflower',
      category: PaletteCategory.decorations,
      itemType: PlaceableItemType.sunflower,
      assetPath: 'plants/sunflower.png',
    ),
    PaletteEntry(
      name: 'Weed',
      category: PaletteCategory.decorations,
      tile: NatureTile.weed,
    ),
    PaletteEntry(
      name: 'Flower 1',
      category: PaletteCategory.decorations,
      tile: NatureTile.flower1,
    ),
    PaletteEntry(
      name: 'Flower 2',
      category: PaletteCategory.decorations,
      tile: NatureTile.flower2,
    ),
    PaletteEntry(
      name: 'Brown Mushroom',
      category: PaletteCategory.decorations,
      tile: NatureTile.mushroomBrown,
    ),
    PaletteEntry(
      name: 'Red Mushroom',
      category: PaletteCategory.decorations,
      tile: NatureTile.mushroomRed,
    ),
    
    // --- Special ---
    PaletteEntry(
      name: 'Walkable Zone',
      category: PaletteCategory.special,
      itemType: PlaceableItemType.walkableZone,
    ),
  ];

  /// Get entries by category
  static List<PaletteEntry> getByCategory(PaletteCategory category) {
    return entries.where((e) => e.category == category).toList();
  }
}

