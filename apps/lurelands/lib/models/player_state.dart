/// Represents the state of a player in the game world.
/// Designed for serialization to sync with SpacetimeDB.
class PlayerState {
  final String id;
  final String name; // Player display name
  final double x;
  final double y;
  final bool isCasting;
  final double? castTargetX;
  final double? castTargetY;
  final int color; // ARGB color value for customization
  final double facingAngle; // Radians, 0 = right, PI/2 = down
  final int equippedPoleTier; // Fishing pole tier (1-4)
  final int equippedLureTier; // Lure tier (1-4)
  final bool isOnline; // Whether the player is currently online and in the world

  const PlayerState({
    required this.id,
    required this.x,
    required this.y,
    this.name = 'Player', // Default name
    this.isCasting = false,
    this.castTargetX,
    this.castTargetY,
    this.color = 0xFFE74C3C, // Default red
    this.facingAngle = 0.0,
    this.equippedPoleTier = 1, // Default to tier 1
    this.equippedLureTier = 1, // Default to tier 1
    this.isOnline = true, // Default to online
  });

  PlayerState copyWith({
    String? id,
    String? name,
    double? x,
    double? y,
    bool? isCasting,
    double? castTargetX,
    double? castTargetY,
    int? color,
    double? facingAngle,
    int? equippedPoleTier,
    int? equippedLureTier,
    bool? isOnline,
  }) {
    return PlayerState(
      id: id ?? this.id,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      isCasting: isCasting ?? this.isCasting,
      castTargetX: castTargetX ?? this.castTargetX,
      castTargetY: castTargetY ?? this.castTargetY,
      color: color ?? this.color,
      facingAngle: facingAngle ?? this.facingAngle,
      equippedPoleTier: equippedPoleTier ?? this.equippedPoleTier,
      equippedLureTier: equippedLureTier ?? this.equippedLureTier,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'x': x,
        'y': y,
        'isCasting': isCasting,
        'castTargetX': castTargetX,
        'castTargetY': castTargetY,
        'color': color,
        'facingAngle': facingAngle,
        'equippedPoleTier': equippedPoleTier,
        'equippedLureTier': equippedLureTier,
        'isOnline': isOnline,
      };

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Player',
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        isCasting: json['isCasting'] as bool? ?? false,
        castTargetX: (json['castTargetX'] as num?)?.toDouble(),
        castTargetY: (json['castTargetY'] as num?)?.toDouble(),
        color: json['color'] as int? ?? 0xFFE74C3C,
        facingAngle: (json['facingAngle'] as num?)?.toDouble() ?? 0.0,
        equippedPoleTier: json['equippedPoleTier'] as int? ?? 1,
        equippedLureTier: json['equippedLureTier'] as int? ?? 1,
        isOnline: json['isOnline'] as bool? ?? true,
      );
}
