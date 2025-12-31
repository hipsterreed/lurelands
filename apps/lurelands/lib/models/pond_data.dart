import 'dart:math';

/// Represents the data for a pond in the game world.
class PondData {
  final String id;
  final double x;
  final double y;
  final double radius;

  const PondData({
    required this.id,
    required this.x,
    required this.y,
    required this.radius,
  });

  /// Check if a point is inside this pond
  bool containsPoint(double px, double py) {
    final dx = px - x;
    final dy = py - y;
    return dx * dx + dy * dy <= radius * radius;
  }

  /// Check if a point is within casting proximity of this pond
  bool isWithinCastingRange(double px, double py, double proximityRadius) {
    final dx = px - x;
    final dy = py - y;
    final distance = sqrt(dx * dx + dy * dy);
    // Player is within casting range if they're outside the pond but close enough
    return distance <= radius + proximityRadius && distance >= radius;
  }

  /// Get the closest point on the pond edge from a given position
  ({double x, double y}) getClosestEdgePoint(double px, double py) {
    final dx = px - x;
    final dy = py - y;
    final distance = sqrt(dx * dx + dy * dy);

    if (distance == 0) {
      // Player is exactly at center, return point to the right
      return (x: x + radius, y: y);
    }

    // Normalize and scale to radius
    final nx = dx / distance;
    final ny = dy / distance;

    return (x: x + nx * radius, y: y + ny * radius);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'radius': radius,
      };

  factory PondData.fromJson(Map<String, dynamic> json) => PondData(
        id: json['id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        radius: (json['radius'] as num).toDouble(),
      );
}
