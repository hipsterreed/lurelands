import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../components/quest_sign.dart';
import '../components/shop.dart';
import '../components/sunflower.dart';
import '../components/tiled_water.dart';
import '../components/tree.dart';
import '../../utils/constants.dart';
import 'nature_tileset.dart';

/// Tree type for world loading (matches editor)
enum WorldTreeType { round, pine }

/// Configuration for a placed tile
class TileConfig {
  final String id;
  final double x;
  final double y;
  final NatureTile tile;
  final WaterType? waterType;

  const TileConfig({
    required this.id,
    required this.x,
    required this.y,
    required this.tile,
    this.waterType,
  });

  factory TileConfig.fromJson(Map<String, dynamic> json) {
    final tileStr = json['tile'] as String;
    final tile = NatureTile.values.firstWhere((t) => t.name == tileStr);
    
    WaterType? waterType;
    if (json['waterType'] != null) {
      final wtStr = json['waterType'] as String;
      waterType = WaterType.values.firstWhere((w) => w.name == wtStr);
    }

    return TileConfig(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      tile: tile,
      waterType: waterType,
    );
  }
}

/// Configuration for a placed tree
class TreeConfig {
  final String id;
  final double x;
  final double y;
  final WorldTreeType treeType;
  final int variant;

  const TreeConfig({
    required this.id,
    required this.x,
    required this.y,
    required this.treeType,
    required this.variant,
  });

  factory TreeConfig.fromJson(Map<String, dynamic> json) {
    final typeStr = json['treeType'] as String? ?? 'round';
    final treeType = WorldTreeType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => WorldTreeType.round,
    );

    return TreeConfig(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      treeType: treeType,
      variant: json['treeVariant'] as int? ?? 0,
    );
  }

  /// Convert to game TreeType
  TreeType get gameTreeType {
    switch (treeType) {
      case WorldTreeType.round:
        return TreeType.round;
      case WorldTreeType.pine:
        return TreeType.pine;
    }
  }
}

/// Configuration for a placed structure (shop, quest sign)
class StructureConfig {
  final String id;
  final String type; // 'shop' or 'questSign'
  final double x;
  final double y;
  final String? structureId;
  final String? structureName;
  final List<String>? storylines;

  const StructureConfig({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.structureId,
    this.structureName,
    this.storylines,
  });

  factory StructureConfig.fromJson(Map<String, dynamic> json) {
    return StructureConfig(
      id: json['id'] as String,
      type: json['type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      structureId: json['structureId'] as String?,
      structureName: json['structureName'] as String?,
      storylines: (json['storylines'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

/// Configuration for a decoration (sunflower, etc.)
class DecorationConfig {
  final String id;
  final String type;
  final double x;
  final double y;
  final NatureTile? tile;

  const DecorationConfig({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.tile,
  });

  factory DecorationConfig.fromJson(Map<String, dynamic> json) {
    NatureTile? tile;
    if (json['tile'] != null) {
      final tileStr = json['tile'] as String;
      tile = NatureTile.values.firstWhere((t) => t.name == tileStr);
    }

    return DecorationConfig(
      id: json['id'] as String,
      type: json['type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      tile: tile,
    );
  }
}

/// Configuration for a walkable zone (overrides water blocking)
class WalkableZoneConfig {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;

  const WalkableZoneConfig({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory WalkableZoneConfig.fromJson(Map<String, dynamic> json) {
    return WalkableZoneConfig(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['zoneWidth'] as num?)?.toDouble() ?? 48,
      height: (json['zoneHeight'] as num?)?.toDouble() ?? 48,
    );
  }
}

/// Configuration for a water body (pond, river, ocean)
class WaterBodyConfig {
  final String id;
  final String type; // 'pond', 'river', 'ocean'
  final double x;
  final double y;
  final int widthInTiles;
  final int heightInTiles;

  const WaterBodyConfig({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.widthInTiles,
    required this.heightInTiles,
  });

  factory WaterBodyConfig.fromJson(Map<String, dynamic> json) {
    return WaterBodyConfig(
      id: json['id'] as String,
      type: json['type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      widthInTiles: json['widthInTiles'] as int,
      heightInTiles: json['heightInTiles'] as int,
    );
  }

  /// Convert type string to WaterType enum
  WaterType get waterType {
    switch (type) {
      case 'pond':
        return WaterType.pond;
      case 'river':
        return WaterType.river;
      case 'ocean':
        return WaterType.ocean;
      default:
        return WaterType.pond;
    }
  }

  /// Convert to TiledWaterData for game use
  TiledWaterData toTiledWaterData() {
    return TiledWaterData(
      id: id,
      x: x,
      y: y,
      widthInTiles: widthInTiles,
      heightInTiles: heightInTiles,
      waterType: waterType,
    );
  }
}

/// Complete world configuration loaded from JSON
class WorldConfig {
  final int version;
  final double worldWidth;
  final double worldHeight;
  final List<TileConfig> tiles;
  final List<WaterBodyConfig> waterBodies;
  final List<TreeConfig> trees;
  final List<StructureConfig> structures;
  final List<DecorationConfig> decorations;
  final List<WalkableZoneConfig> walkableZones;

  const WorldConfig({
    required this.version,
    required this.worldWidth,
    required this.worldHeight,
    required this.tiles,
    required this.waterBodies,
    required this.trees,
    required this.structures,
    required this.decorations,
    required this.walkableZones,
  });

  /// Load world config from JSON string
  factory WorldConfig.fromJson(Map<String, dynamic> json) {
    return WorldConfig(
      version: json['version'] as int? ?? 1,
      worldWidth: (json['worldWidth'] as num?)?.toDouble() ?? GameConstants.worldWidth,
      worldHeight: (json['worldHeight'] as num?)?.toDouble() ?? GameConstants.worldHeight,
      tiles: (json['tiles'] as List<dynamic>?)
              ?.map((t) => TileConfig.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      waterBodies: (json['waterBodies'] as List<dynamic>?)
              ?.map((w) => WaterBodyConfig.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
      trees: (json['trees'] as List<dynamic>?)
              ?.map((t) => TreeConfig.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      structures: (json['structures'] as List<dynamic>?)
              ?.map((s) => StructureConfig.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      decorations: (json['decorations'] as List<dynamic>?)
              ?.map((d) => DecorationConfig.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      walkableZones: (json['walkableZones'] as List<dynamic>?)
              ?.map((w) => WalkableZoneConfig.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Load world config from asset file
  static Future<WorldConfig?> loadFromAsset(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return WorldConfig.fromJson(json);
    } catch (e) {
      // Asset doesn't exist or is invalid - return null to use fallback
      return null;
    }
  }

  /// Get all water tiles grouped by water type for building TiledWaterData
  Map<WaterType, List<TileConfig>> get waterTilesByType {
    final result = <WaterType, List<TileConfig>>{};
    
    for (final tile in tiles) {
      if (tile.waterType != null) {
        result.putIfAbsent(tile.waterType!, () => []).add(tile);
      }
    }
    
    return result;
  }

  /// Check if a position is inside any water tile
  bool isInWater(double x, double y) {
    final tileSize = NatureTilesheet.tileSize * NatureTilesheet.renderScale;
    
    for (final tile in tiles) {
      if (tile.waterType != null) {
        if (x >= tile.x && x < tile.x + tileSize &&
            y >= tile.y && y < tile.y + tileSize) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if a position is in a walkable zone
  bool isInWalkableZone(double x, double y) {
    for (final zone in walkableZones) {
      if (x >= zone.x && x < zone.x + zone.width &&
          y >= zone.y && y < zone.y + zone.height) {
        return true;
      }
    }
    return false;
  }

  /// Get the water type at a position (or null if not water)
  WaterType? getWaterTypeAt(double x, double y) {
    final tileSize = NatureTilesheet.tileSize * NatureTilesheet.renderScale;
    
    for (final tile in tiles) {
      if (tile.waterType != null) {
        if (x >= tile.x && x < tile.x + tileSize &&
            y >= tile.y && y < tile.y + tileSize) {
          return tile.waterType;
        }
      }
    }
    return null;
  }
}

/// Helper to spawn components from WorldConfig
class WorldConfigLoader {
  final WorldConfig config;
  final NatureTilesheet tilesheet;

  WorldConfigLoader({
    required this.config,
    required this.tilesheet,
  });

  /// Create tree components from config
  List<Tree> createTrees() {
    return config.trees.map((treeConfig) {
      return Tree(
        position: Vector2(treeConfig.x, treeConfig.y),
        type: treeConfig.gameTreeType,
        variant: treeConfig.variant,
      );
    }).toList();
  }

  /// Create shop components from config
  List<Shop> createShops() {
    return config.structures
        .where((s) => s.type == 'shop')
        .map((shopConfig) {
      return Shop(
        position: Vector2(shopConfig.x, shopConfig.y),
        id: shopConfig.structureId ?? shopConfig.id,
        name: shopConfig.structureName ?? 'Shop',
      );
    }).toList();
  }

  /// Create quest sign components from config
  List<QuestSign> createQuestSigns() {
    return config.structures
        .where((s) => s.type == 'questSign')
        .map((signConfig) {
      return QuestSign(
        position: Vector2(signConfig.x, signConfig.y),
        id: signConfig.structureId ?? signConfig.id,
        name: signConfig.structureName ?? 'Quest Board',
        storylines: signConfig.storylines ?? [],
      );
    }).toList();
  }

  /// Create sunflower components from config
  List<Sunflower> createSunflowers() {
    return config.decorations
        .where((d) => d.type == 'sunflower')
        .map((sunflowerConfig) {
      return Sunflower(
        position: Vector2(sunflowerConfig.x, sunflowerConfig.y),
      );
    }).toList();
  }

  /// Get walkable zone rectangles
  List<Rect> getWalkableZones() {
    return config.walkableZones.map((zone) {
      return Rect.fromLTWH(zone.x, zone.y, zone.width, zone.height);
    }).toList();
  }

  /// Build TiledWaterData from water body configs (preferred)
  /// Returns pre-defined rectangular water bodies
  List<TiledWaterData> buildWaterBodiesFromConfig() {
    return config.waterBodies.map((wb) => wb.toTiledWaterData()).toList();
  }

  /// Build TiledWaterData from water tiles (legacy/custom shapes)
  /// Groups adjacent water tiles into rectangular regions
  List<TiledWaterData> buildWaterBodiesFromTiles() {
    final waterBodies = <TiledWaterData>[];
    final tileSize = NatureTilesheet.tileSize * NatureTilesheet.renderScale;
    
    // Group water tiles by water type and find bounding boxes
    final waterByType = config.waterTilesByType;
    
    for (final entry in waterByType.entries) {
      final waterType = entry.key;
      final tiles = entry.value;
      
      if (tiles.isEmpty) continue;
      
      // Find bounding box of all tiles of this type
      // This is a simple approach - for complex shapes you'd want flood fill
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = double.negativeInfinity;
      double maxY = double.negativeInfinity;
      
      for (final tile in tiles) {
        if (tile.x < minX) minX = tile.x;
        if (tile.y < minY) minY = tile.y;
        if (tile.x + tileSize > maxX) maxX = tile.x + tileSize;
        if (tile.y + tileSize > maxY) maxY = tile.y + tileSize;
      }
      
      final widthInTiles = ((maxX - minX) / tileSize).round();
      final heightInTiles = ((maxY - minY) / tileSize).round();
      
      waterBodies.add(TiledWaterData(
        id: '${waterType.name}_${waterBodies.length}',
        x: minX,
        y: minY,
        widthInTiles: widthInTiles,
        heightInTiles: heightInTiles,
        waterType: waterType,
      ));
    }
    
    return waterBodies;
  }

  /// Build all water bodies - uses waterBodies config if available, 
  /// falls back to building from tiles
  List<TiledWaterData> buildWaterBodies() {
    if (config.waterBodies.isNotEmpty) {
      return buildWaterBodiesFromConfig();
    }
    return buildWaterBodiesFromTiles();
  }
}


