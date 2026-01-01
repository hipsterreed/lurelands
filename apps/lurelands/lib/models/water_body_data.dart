import 'dart:math';
import '../utils/constants.dart';

/// Base class for all water body data in the game world.
/// Designed for serialization to sync with SpacetimeDB.
abstract class WaterBodyData {
  final String id;
  final double x;
  final double y;
  final WaterType waterType;

  const WaterBodyData({
    required this.id,
    required this.x,
    required this.y,
    required this.waterType,
  });

  /// Check if a point is inside this water body
  bool containsPoint(double px, double py);

  /// Check if a point is within casting proximity of this water body
  bool isWithinCastingRange(double px, double py, double proximityRadius);
}

/// Circular pond data
class PondData extends WaterBodyData {
  final double radius;

  const PondData({
    required super.id,
    required super.x,
    required super.y,
    required this.radius,
  }) : super(waterType: WaterType.pond);

  @override
  bool containsPoint(double px, double py) {
    final dx = px - x;
    final dy = py - y;
    return dx * dx + dy * dy <= radius * radius;
  }

  @override
  bool isWithinCastingRange(double px, double py, double proximityRadius) {
    final dx = px - x;
    final dy = py - y;
    final distance = sqrt(dx * dx + dy * dy);
    return distance <= radius + proximityRadius && distance >= radius;
  }

  /// Get the closest point on the pond edge from a given position
  ({double x, double y}) getClosestEdgePoint(double px, double py) {
    final dx = px - x;
    final dy = py - y;
    final distance = sqrt(dx * dx + dy * dy);

    if (distance == 0) {
      return (x: x + radius, y: y);
    }

    final nx = dx / distance;
    final ny = dy / distance;

    return (x: x + nx * radius, y: y + ny * radius);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'radius': radius,
        'waterType': 'pond',
      };

  factory PondData.fromJson(Map<String, dynamic> json) => PondData(
        id: json['id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        radius: (json['radius'] as num).toDouble(),
      );
}

/// Rectangular river data (flows horizontally or vertically)
class RiverData extends WaterBodyData {
  final double width;
  final double length;
  final double rotation; // Radians, 0 = horizontal

  const RiverData({
    required super.id,
    required super.x,
    required super.y,
    required this.width,
    required this.length,
    this.rotation = 0,
  }) : super(waterType: WaterType.river);

  @override
  bool containsPoint(double px, double py) {
    // Transform point to river's local space
    final dx = px - x;
    final dy = py - y;
    
    // Rotate point to align with river
    final cosR = cos(-rotation);
    final sinR = sin(-rotation);
    final localX = dx * cosR - dy * sinR;
    final localY = dx * sinR + dy * cosR;

    // Check if inside rectangle
    return localX.abs() <= length / 2 && localY.abs() <= width / 2;
  }

  @override
  bool isWithinCastingRange(double px, double py, double proximityRadius) {
    // Transform point to river's local space
    final dx = px - x;
    final dy = py - y;
    
    final cosR = cos(-rotation);
    final sinR = sin(-rotation);
    final localX = dx * cosR - dy * sinR;
    final localY = dx * sinR + dy * cosR;

    // Check if within extended rectangle but outside the river
    final inExtended = localX.abs() <= length / 2 + proximityRadius && 
                       localY.abs() <= width / 2 + proximityRadius;
    final inRiver = localX.abs() <= length / 2 && localY.abs() <= width / 2;

    return inExtended && !inRiver;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'length': length,
        'rotation': rotation,
        'waterType': 'river',
      };

  factory RiverData.fromJson(Map<String, dynamic> json) => RiverData(
        id: json['id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        length: (json['length'] as num).toDouble(),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      );
}

/// Large ocean area data (typically on edge of map)
class OceanData extends WaterBodyData {
  final double width;
  final double height;

  const OceanData({
    required super.id,
    required super.x,
    required super.y,
    required this.width,
    required this.height,
  }) : super(waterType: WaterType.ocean);

  /// Left edge of the ocean
  double get left => x;
  
  /// Right edge of the ocean
  double get right => x + width;
  
  /// Top edge of the ocean
  double get top => y;
  
  /// Bottom edge of the ocean
  double get bottom => y + height;

  @override
  bool containsPoint(double px, double py) {
    return px >= left && px <= right && py >= top && py <= bottom;
  }

  @override
  bool isWithinCastingRange(double px, double py, double proximityRadius) {
    // Check if within extended rectangle but outside the ocean
    final inExtended = px >= left - proximityRadius && 
                       px <= right + proximityRadius && 
                       py >= top - proximityRadius && 
                       py <= bottom + proximityRadius;
    final inOcean = containsPoint(px, py);

    return inExtended && !inOcean;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'waterType': 'ocean',
      };

  factory OceanData.fromJson(Map<String, dynamic> json) => OceanData(
        id: json['id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );
}

