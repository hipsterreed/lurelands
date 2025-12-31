/// Represents the state of a player in the game world.
/// Designed for serialization to sync with SpacetimeDB.
class PlayerState {
  final String id;
  final double x;
  final double y;
  final bool isCasting;
  final double? castTargetX;
  final double? castTargetY;
  final int color; // ARGB color value for customization
  final double facingAngle; // Radians, 0 = right, PI/2 = down

  const PlayerState({
    required this.id,
    required this.x,
    required this.y,
    this.isCasting = false,
    this.castTargetX,
    this.castTargetY,
    this.color = 0xFFE74C3C, // Default red
    this.facingAngle = 0.0,
  });

  PlayerState copyWith({
    String? id,
    double? x,
    double? y,
    bool? isCasting,
    double? castTargetX,
    double? castTargetY,
    int? color,
    double? facingAngle,
  }) {
    return PlayerState(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      isCasting: isCasting ?? this.isCasting,
      castTargetX: castTargetX ?? this.castTargetX,
      castTargetY: castTargetY ?? this.castTargetY,
      color: color ?? this.color,
      facingAngle: facingAngle ?? this.facingAngle,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'isCasting': isCasting,
        'castTargetX': castTargetX,
        'castTargetY': castTargetY,
        'color': color,
        'facingAngle': facingAngle,
      };

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
        id: json['id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        isCasting: json['isCasting'] as bool? ?? false,
        castTargetX: (json['castTargetX'] as num?)?.toDouble(),
        castTargetY: (json['castTargetY'] as num?)?.toDouble(),
        color: json['color'] as int? ?? 0xFFE74C3C,
        facingAngle: (json['facingAngle'] as num?)?.toDouble() ?? 0.0,
      );
}
