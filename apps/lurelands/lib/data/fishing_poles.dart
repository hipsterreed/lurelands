import 'dart:ui';

/// Definition of a fishing pole with all properties
class FishingPoleDefinition {
  final String id;
  final String name;
  final String description;
  final int tileId; // Tiled tile ID (75-99)
  final int spriteColumn; // Column in spritesheet (0-24)
  final int spriteRow; // Always 3 for poles
  final int tier; // 1-4 (affects gameplay bonuses)
  final int price; // Purchase price (0 = starter)
  final double maxCastDistance; // Maximum cast range

  const FishingPoleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.tileId,
    required this.spriteColumn,
    required this.spriteRow,
    required this.tier,
    required this.price,
    required this.maxCastDistance,
  });

  /// Spritesheet configuration
  static const String spritesheetPath = 'assets/images/fish/fish_spritesheet.png';
  static const double spriteSize = 16.0;

  /// Get the source rect for this sprite in the spritesheet
  Rect get sourceRect => Rect.fromLTWH(
        spriteColumn * spriteSize,
        spriteRow * spriteSize,
        spriteSize,
        spriteSize,
      );
}

/// Registry of all fishing poles
class FishingPoles {
  FishingPoles._();

  // ============================================
  // Tier 1 - Common (tiles 75-80, columns 0-5)
  // ============================================
  static const FishingPoleDefinition pole1 = FishingPoleDefinition(
    id: 'pole_1',
    name: 'Wooden Rod',
    description: 'A basic fishing rod for beginners. Free!',
    tileId: 75,
    spriteColumn: 0,
    spriteRow: 3,
    tier: 1,
    price: 0,
    maxCastDistance: 100.0,
  );

  static const FishingPoleDefinition poleBamboo = FishingPoleDefinition(
    id: 'pole_bamboo',
    name: 'Bamboo Rod',
    description: 'A lightweight bamboo pole, flexible and easy to use.',
    tileId: 76,
    spriteColumn: 1,
    spriteRow: 3,
    tier: 1,
    price: 50,
    maxCastDistance: 105.0,
  );

  static const FishingPoleDefinition poleReed = FishingPoleDefinition(
    id: 'pole_reed',
    name: 'Reed Pole',
    description: 'Crafted from river reeds, surprisingly durable.',
    tileId: 77,
    spriteColumn: 2,
    spriteRow: 3,
    tier: 1,
    price: 75,
    maxCastDistance: 108.0,
  );

  static const FishingPoleDefinition poleWillow = FishingPoleDefinition(
    id: 'pole_willow',
    name: 'Willow Switch',
    description: 'A whippy willow branch, perfect for small catches.',
    tileId: 78,
    spriteColumn: 3,
    spriteRow: 3,
    tier: 1,
    price: 100,
    maxCastDistance: 112.0,
  );

  static const FishingPoleDefinition poleCane = FishingPoleDefinition(
    id: 'pole_cane',
    name: 'Cane Rod',
    description: 'A traditional cane pole used by generations of anglers.',
    tileId: 79,
    spriteColumn: 4,
    spriteRow: 3,
    tier: 1,
    price: 125,
    maxCastDistance: 115.0,
  );

  static const FishingPoleDefinition poleHickory = FishingPoleDefinition(
    id: 'pole_hickory',
    name: 'Hickory Rod',
    description: 'Strong hickory wood provides excellent durability.',
    tileId: 80,
    spriteColumn: 5,
    spriteRow: 3,
    tier: 1,
    price: 150,
    maxCastDistance: 118.0,
  );

  // ============================================
  // Tier 2 - Uncommon (tiles 81-87, columns 6-12)
  // ============================================
  static const FishingPoleDefinition pole2 = FishingPoleDefinition(
    id: 'pole_2',
    name: 'Steel Rod',
    description: 'A sturdy rod with better casting distance.',
    tileId: 81,
    spriteColumn: 6,
    spriteRow: 3,
    tier: 2,
    price: 200,
    maxCastDistance: 140.0,
  );

  static const FishingPoleDefinition poleBronze = FishingPoleDefinition(
    id: 'pole_bronze',
    name: 'Bronze Rod',
    description: 'Bronze-reinforced for extra strength and reach.',
    tileId: 82,
    spriteColumn: 7,
    spriteRow: 3,
    tier: 2,
    price: 250,
    maxCastDistance: 145.0,
  );

  static const FishingPoleDefinition poleCopper = FishingPoleDefinition(
    id: 'pole_copper',
    name: 'Copper Rod',
    description: 'Polished copper guides ensure smooth casting.',
    tileId: 83,
    spriteColumn: 8,
    spriteRow: 3,
    tier: 2,
    price: 280,
    maxCastDistance: 148.0,
  );

  static const FishingPoleDefinition poleIron = FishingPoleDefinition(
    id: 'pole_iron',
    name: 'Iron Rod',
    description: 'Heavy-duty iron construction for bigger fish.',
    tileId: 84,
    spriteColumn: 9,
    spriteRow: 3,
    tier: 2,
    price: 320,
    maxCastDistance: 152.0,
  );

  static const FishingPoleDefinition poleAlloy = FishingPoleDefinition(
    id: 'pole_alloy',
    name: 'Alloy Rod',
    description: 'A modern alloy blend for optimal performance.',
    tileId: 85,
    spriteColumn: 10,
    spriteRow: 3,
    tier: 2,
    price: 360,
    maxCastDistance: 156.0,
  );

  static const FishingPoleDefinition poleSpring = FishingPoleDefinition(
    id: 'pole_spring',
    name: 'Spring Rod',
    description: 'Built-in spring action absorbs shock from big catches.',
    tileId: 86,
    spriteColumn: 11,
    spriteRow: 3,
    tier: 2,
    price: 400,
    maxCastDistance: 160.0,
  );

  static const FishingPoleDefinition poleComposite = FishingPoleDefinition(
    id: 'pole_composite',
    name: 'Composite Rod',
    description: 'Multi-material composite for balanced performance.',
    tileId: 87,
    spriteColumn: 12,
    spriteRow: 3,
    tier: 2,
    price: 450,
    maxCastDistance: 165.0,
  );

  // ============================================
  // Tier 3 - Rare (tiles 88-93, columns 13-18)
  // ============================================
  static const FishingPoleDefinition pole3 = FishingPoleDefinition(
    id: 'pole_3',
    name: 'Carbon Fiber Rod',
    description: 'A lightweight rod for serious anglers.',
    tileId: 88,
    spriteColumn: 13,
    spriteRow: 3,
    tier: 3,
    price: 500,
    maxCastDistance: 180.0,
  );

  static const FishingPoleDefinition poleGraphite = FishingPoleDefinition(
    id: 'pole_graphite',
    name: 'Graphite Rod',
    description: 'High-modulus graphite for incredible sensitivity.',
    tileId: 89,
    spriteColumn: 14,
    spriteRow: 3,
    tier: 3,
    price: 600,
    maxCastDistance: 185.0,
  );

  static const FishingPoleDefinition poleTitanium = FishingPoleDefinition(
    id: 'pole_titanium',
    name: 'Titanium Rod',
    description: 'Aerospace-grade titanium, incredibly light and strong.',
    tileId: 90,
    spriteColumn: 15,
    spriteRow: 3,
    tier: 3,
    price: 750,
    maxCastDistance: 190.0,
  );

  static const FishingPoleDefinition poleUltralight = FishingPoleDefinition(
    id: 'pole_ultralight',
    name: 'Ultralight Rod',
    description: 'Featherweight design for maximum casting finesse.',
    tileId: 91,
    spriteColumn: 16,
    spriteRow: 3,
    tier: 3,
    price: 900,
    maxCastDistance: 195.0,
  );

  static const FishingPoleDefinition polePrecision = FishingPoleDefinition(
    id: 'pole_precision',
    name: 'Precision Rod',
    description: 'Engineered for pinpoint accuracy in every cast.',
    tileId: 92,
    spriteColumn: 17,
    spriteRow: 3,
    tier: 3,
    price: 1100,
    maxCastDistance: 200.0,
  );

  static const FishingPoleDefinition poleExpert = FishingPoleDefinition(
    id: 'pole_expert',
    name: "Expert's Rod",
    description: 'Crafted for professional anglers who demand the best.',
    tileId: 93,
    spriteColumn: 18,
    spriteRow: 3,
    tier: 3,
    price: 1300,
    maxCastDistance: 205.0,
  );

  // ============================================
  // Tier 4 - Legendary (tiles 94-99, columns 19-24)
  // ============================================
  static const FishingPoleDefinition pole4 = FishingPoleDefinition(
    id: 'pole_4',
    name: "Legendary Angler's Rod",
    description: 'The ultimate fishing rod, crafted by masters.',
    tileId: 94,
    spriteColumn: 19,
    spriteRow: 3,
    tier: 4,
    price: 1500,
    maxCastDistance: 220.0,
  );

  static const FishingPoleDefinition poleMythic = FishingPoleDefinition(
    id: 'pole_mythic',
    name: 'Mythic Rod',
    description: 'Forged from materials of legend and lore.',
    tileId: 95,
    spriteColumn: 20,
    spriteRow: 3,
    tier: 4,
    price: 2000,
    maxCastDistance: 225.0,
  );

  static const FishingPoleDefinition poleAncient = FishingPoleDefinition(
    id: 'pole_ancient',
    name: 'Ancient Rod',
    description: 'An artifact from a forgotten age of master fishers.',
    tileId: 96,
    spriteColumn: 21,
    spriteRow: 3,
    tier: 4,
    price: 2500,
    maxCastDistance: 230.0,
  );

  static const FishingPoleDefinition poleCelestial = FishingPoleDefinition(
    id: 'pole_celestial',
    name: 'Celestial Rod',
    description: 'Blessed by the stars, it glows with cosmic energy.',
    tileId: 97,
    spriteColumn: 22,
    spriteRow: 3,
    tier: 4,
    price: 3500,
    maxCastDistance: 240.0,
  );

  static const FishingPoleDefinition poleVoid = FishingPoleDefinition(
    id: 'pole_void',
    name: 'Void Fisher',
    description: 'Said to pull fish from between dimensions.',
    tileId: 98,
    spriteColumn: 23,
    spriteRow: 3,
    tier: 4,
    price: 4500,
    maxCastDistance: 248.0,
  );

  static const FishingPoleDefinition poleMaster = FishingPoleDefinition(
    id: 'pole_master',
    name: "Master's Rod",
    description: 'The pinnacle of fishing technology and craftsmanship.',
    tileId: 99,
    spriteColumn: 24,
    spriteRow: 3,
    tier: 4,
    price: 6000,
    maxCastDistance: 260.0,
  );

  /// All poles indexed by ID
  static const Map<String, FishingPoleDefinition> all = {
    // Tier 1 - Common
    'pole_1': pole1,
    'pole_bamboo': poleBamboo,
    'pole_reed': poleReed,
    'pole_willow': poleWillow,
    'pole_cane': poleCane,
    'pole_hickory': poleHickory,
    // Tier 2 - Uncommon
    'pole_2': pole2,
    'pole_bronze': poleBronze,
    'pole_copper': poleCopper,
    'pole_iron': poleIron,
    'pole_alloy': poleAlloy,
    'pole_spring': poleSpring,
    'pole_composite': poleComposite,
    // Tier 3 - Rare
    'pole_3': pole3,
    'pole_graphite': poleGraphite,
    'pole_titanium': poleTitanium,
    'pole_ultralight': poleUltralight,
    'pole_precision': polePrecision,
    'pole_expert': poleExpert,
    // Tier 4 - Legendary
    'pole_4': pole4,
    'pole_mythic': poleMythic,
    'pole_ancient': poleAncient,
    'pole_celestial': poleCelestial,
    'pole_void': poleVoid,
    'pole_master': poleMaster,
  };

  /// All poles indexed by tile ID (for Tiled integration)
  static const Map<int, FishingPoleDefinition> byTileId = {
    75: pole1,
    76: poleBamboo,
    77: poleReed,
    78: poleWillow,
    79: poleCane,
    80: poleHickory,
    81: pole2,
    82: poleBronze,
    83: poleCopper,
    84: poleIron,
    85: poleAlloy,
    86: poleSpring,
    87: poleComposite,
    88: pole3,
    89: poleGraphite,
    90: poleTitanium,
    91: poleUltralight,
    92: polePrecision,
    93: poleExpert,
    94: pole4,
    95: poleMythic,
    96: poleAncient,
    97: poleCelestial,
    98: poleVoid,
    99: poleMaster,
  };

  /// Get pole by ID
  static FishingPoleDefinition? get(String id) => all[id];

  /// Get pole by tile ID
  static FishingPoleDefinition? getByTileId(int tileId) => byTileId[tileId];

  /// Get all poles for shop display (sorted by price, excluding free starter pole)
  static List<FishingPoleDefinition> get shopPoles {
    final poles = all.values.where((p) => p.price > 0).toList();
    poles.sort((a, b) => a.price.compareTo(b.price));
    return poles;
  }

  /// Get all poles sorted by tier then price
  static List<FishingPoleDefinition> get allSorted {
    final poles = all.values.toList();
    poles.sort((a, b) {
      final tierCompare = a.tier.compareTo(b.tier);
      if (tierCompare != 0) return tierCompare;
      return a.price.compareTo(b.price);
    });
    return poles;
  }

  /// Get poles by tier
  static List<FishingPoleDefinition> getByTier(int tier) {
    return all.values.where((p) => p.tier == tier).toList();
  }

  /// Default pole (starter)
  static FishingPoleDefinition get defaultPole => pole1;
}
