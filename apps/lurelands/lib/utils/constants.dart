import 'dart:ui';

import '../services/item_service.dart';

/// Game-wide constants for Lurelands
class GameConstants {
  // Prevent instantiation
  GameConstants._();

  // World dimensions
  static const double worldWidth = 2000.0;
  static const double worldHeight = 2000.0;

  // Player settings
  static const double playerSize = 32.0;
  static const double playerSpeed = 200.0; // pixels per second

  // Fishing settings
  static const double castProximityRadius = 150.0; // Distance to pond to allow casting
  static const double minCastDistance = 40.0; // Min distance fishing line can extend
  static const double maxCastDistance = 120.0; // Max distance fishing line can extend
  static const double castChargeRate = 1.0; // Power fills per second (1.0 = full in 1s)
  static const double castAnimationDuration = 0.5; // seconds
  static const double reelAnimationDuration = 0.3; // seconds
  static const double lureSitDuration = 15.0; // seconds before auto-reel (extended for bite)

  // Fish bite settings
  static const double minBiteWait = 2.0; // Min seconds before fish bites
  static const double maxBiteWait = 6.0; // Max seconds before fish bites
  static const double biteReactionWindow = 1.5; // Seconds to tap after bite
  static const double bobberShakeIntensity = 4.0; // Pixels of shake

  // Fishing minigame settings
  static const double minigameBarGravity = 280.0; // Pixels per second fall
  static const double minigameBarBoost = 160.0; // Pixels per tap
  static const double minigameBarMaxSpeed = 400.0; // Max velocity
  static const double minigameProgressFillRate = 0.15; // % per second when on fish
  static const double minigameProgressDrainRate = 0.10; // % per second when off fish
  static const double minigameStartProgress = 0.25; // Starting progress (25%)
  
  // Fish difficulty by tier (movement speed multiplier)
  static const List<double> fishSpeedByTier = [0.6, 1.0, 1.4, 2.0];
  // Control bar size by tier (as % of meter height)
  static const List<double> barSizeByTier = [0.25, 0.20, 0.15, 0.12];
  // Minigame timeout by tier (seconds) - harder fish get more time
  static const List<double> minigameTimeoutByTier = [10.0, 14.0, 18.0, 24.0];
  
  // Pole tier bonuses (indexed by pole tier - 1, so tier 1 = index 0)
  // Gravity multiplier: higher = faster fall = more control
  static const List<double> poleGravityMultiplier = [1.0, 1.15, 1.3, 1.5];
  // Bar size bonus: adds to base bar size (helps with harder fish)
  static const List<double> poleBarSizeBonus = [0.0, 0.02, 0.04, 0.07];

  // Pond settings
  static const double minPondRadius = 80.0;
  static const double maxPondRadius = 150.0;

  // Camera settings
  static const double cameraZoom = 1.0;
}

/// Color palette for the game
class GameColors {
  // Prevent instantiation
  GameColors._();

  // World colors
  static const Color grassGreen = Color(0xFF4A7C23);
  static const Color grassGreenLight = Color(0xFF5C9A2D);
  static const Color grassGreenDark = Color(0xFF3A6018);

  // Water colors
  static const Color pondBlue = Color(0xFF2E86AB);
  static const Color pondBlueDark = Color(0xFF1A5276);
  static const Color pondBlueLight = Color(0xFF5DADE2);
  static const Color pondShore = Color(0xFF8B7355);

  // Player colors (default, can be customized later)
  static const Color playerDefault = Color(0xFFE74C3C);
  static const Color playerOutline = Color(0xFF922B21);

  // Fishing pole/line colors
  static const Color fishingPole = Color(0xFF6B4423);
  static const Color fishingLine = Color(0xFFD4D4D4);
  static const Color fishingLineCast = Color(0xFFFFFFFF);

  // UI colors
  static const Color menuBackground = Color(0xFF1A1A2E);
  static const Color menuAccent = Color(0xFF16213E);
  static const Color buttonPrimary = Color(0xFF0F3460);
  static const Color buttonHover = Color(0xFF1A5276);
  static const Color textPrimary = Color(0xFFE8E8E8);
  static const Color textSecondary = Color(0xFFB0B0B0);

  // Fishing minigame colors
  static const Color woodFrame = Color(0xFF8B5A2B);
  static const Color woodFrameDark = Color(0xFF5D3A1A);
  static const Color woodFrameLight = Color(0xFFA0724B);
  static const Color minigameWaterTop = Color(0xFF87CEEB);
  static const Color minigameWaterBottom = Color(0xFF1E90FF);
  static const Color catchBarGreen = Color(0xFF7CFC00);
  static const Color catchBarGreenLight = Color(0xFF98FB98);
  static const Color progressGreen = Color(0xFF32CD32);
  static const Color progressOrange = Color(0xFFFF8C00);
  static const Color progressRed = Color(0xFFFF4500);
}

/// Z-index ordering for game components
class GameLayers {
  // Prevent instantiation
  GameLayers._();

  static const double ground = 0;
  static const double pond = 1;
  static const double castLine = 5;
  static const double player = 10;
  static const double fishingPole = 11;
  static const double ui = 100;
}

/// Base asset paths
class AssetPaths {
  AssetPaths._();

  static const String items = 'assets/items';
  static const String images = 'assets/images';
  static const String characters = 'assets/images/characters';
  static const String fish = 'assets/images/fish';
  static const String plants = 'assets/images/plants';
}

/// Fishing pole asset with normal and casted variants
class FishingPoleAsset {
  final String normal;
  final String casted;
  final int tier;
  final double maxCastDistance; // Max distance this pole can cast

  const FishingPoleAsset({
    required this.normal,
    required this.casted,
    required this.tier,
    required this.maxCastDistance,
  });
}

/// Lure asset
class LureAsset {
  final String path;
  final int tier;

  const LureAsset({
    required this.path,
    required this.tier,
  });
}

/// Item assets (fishing poles, lures, etc.)
class ItemAssets {
  ItemAssets._();

  // Fishing Poles (tier 1-4, each with normal and casted/alt variant)
  // Each tier has progressively longer max cast distance
  static const FishingPoleAsset fishingPole1 = FishingPoleAsset(
    normal: '${AssetPaths.items}/fishing_pole_1.png',
    casted: '${AssetPaths.items}/fishing_pole_alt_1.png',
    tier: 1,
    maxCastDistance: 100.0, // Starter pole
  );

  static const FishingPoleAsset fishingPole2 = FishingPoleAsset(
    normal: '${AssetPaths.items}/fishing_pole_2.png',
    casted: '${AssetPaths.items}/fishing_pole_alt_2.png',
    tier: 2,
    maxCastDistance: 140.0, // Better range
  );

  static const FishingPoleAsset fishingPole3 = FishingPoleAsset(
    normal: '${AssetPaths.items}/fishing_pole_3.png',
    casted: '${AssetPaths.items}/fishing_pole_alt_3.png',
    tier: 3,
    maxCastDistance: 180.0, // Great range
  );

  static const FishingPoleAsset fishingPole4 = FishingPoleAsset(
    normal: '${AssetPaths.items}/fishing_pole_4.png',
    casted: '${AssetPaths.items}/fishing_pole_alt_4.png',
    tier: 4,
    maxCastDistance: 220.0, // Maximum range
  );

  /// All fishing poles indexed by tier (1-4)
  static const List<FishingPoleAsset> fishingPoles = [
    fishingPole1,
    fishingPole2,
    fishingPole3,
    fishingPole4,
  ];

  /// Get fishing pole by tier (1-4)
  static FishingPoleAsset getFishingPole(int tier) {
    assert(tier >= 1 && tier <= 4, 'Fishing pole tier must be between 1 and 4');
    return fishingPoles[tier - 1];
  }

  // Lures (tier 1-4)
  static const LureAsset lure1 = LureAsset(
    path: '${AssetPaths.items}/lure_1.png',
    tier: 1,
  );

  static const LureAsset lure2 = LureAsset(
    path: '${AssetPaths.items}/lure_2.png',
    tier: 2,
  );

  static const LureAsset lure3 = LureAsset(
    path: '${AssetPaths.items}/lure_3.png',
    tier: 3,
  );

  static const LureAsset lure4 = LureAsset(
    path: '${AssetPaths.items}/lure_4.png',
    tier: 4,
  );

  /// All lures indexed by tier (1-4)
  static const List<LureAsset> lures = [
    lure1,
    lure2,
    lure3,
    lure4,
  ];

  /// Get lure by tier (1-4)
  static LureAsset getLure(int tier) {
    assert(tier >= 1 && tier <= 4, 'Lure tier must be between 1 and 4');
    return lures[tier - 1];
  }
}

/// Water type enum for fish categorization
enum WaterType {
  pond,
  river,
  ocean,
  night, // Special night-time fish
}

/// Item type enum for inventory categorization
enum ItemType {
  fish,
  pole,
  lure,
  bait,
}

/// Definition of an item in the game (for client-side lookup)
class ItemDefinition {
  final String id;
  final String name;
  final String description;
  final ItemType type;
  final int basePrice;
  final String assetPath;
  final WaterType? waterType; // For fish only
  final int? tier; // For equipment tiers
  final Map<int, double>? rarityMultipliers; // From database

  const ItemDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.basePrice,
    required this.assetPath,
    this.waterType,
    this.tier,
    this.rarityMultipliers,
  });

  /// Get the sell price based on rarity (stars)
  int getSellPrice(int rarity) {
    // Use database multipliers if available
    if (rarityMultipliers != null && rarityMultipliers!.containsKey(rarity)) {
      return (basePrice * rarityMultipliers![rarity]!).round();
    }
    // Fallback to hardcoded logic
    final multiplier = rarity <= 1 ? 1.0 : (rarity == 2 ? 2.0 : 4.0);
    return (basePrice * multiplier).round();
  }
}

/// Centralized catalog of all game items
class GameItems {
  GameItems._();

  // --- Fish ---
  // Pond fish
  static const ItemDefinition fishPond1 = ItemDefinition(
    id: 'fish_pond_1',
    name: 'Pond Minnow',
    description: 'A common small fish found in ponds.',
    type: ItemType.fish,
    basePrice: 10,
    assetPath: '${AssetPaths.fish}/fish_pond_1.png',
    waterType: WaterType.pond,
    tier: 1,
  );
  static const ItemDefinition fishPond2 = ItemDefinition(
    id: 'fish_pond_2',
    name: 'Golden Koi',
    description: 'A beautiful golden fish prized by collectors.',
    type: ItemType.fish,
    basePrice: 25,
    assetPath: '${AssetPaths.fish}/fish_pond_2.png',
    waterType: WaterType.pond,
    tier: 2,
  );
  static const ItemDefinition fishPond3 = ItemDefinition(
    id: 'fish_pond_3',
    name: 'Mystic Carp',
    description: 'A rare carp with an ethereal glow.',
    type: ItemType.fish,
    basePrice: 50,
    assetPath: '${AssetPaths.fish}/fish_pond_3.png',
    waterType: WaterType.pond,
    tier: 3,
  );
  static const ItemDefinition fishPond4 = ItemDefinition(
    id: 'fish_pond_4',
    name: 'Ancient Pond Dragon',
    description: 'A legendary creature of pond folklore.',
    type: ItemType.fish,
    basePrice: 150,
    assetPath: '${AssetPaths.fish}/fish_pond_4.png',
    waterType: WaterType.pond,
    tier: 4,
  );

  // River fish
  static const ItemDefinition fishRiver1 = ItemDefinition(
    id: 'fish_river_1',
    name: 'Brook Trout',
    description: 'A common river fish, easy to catch.',
    type: ItemType.fish,
    basePrice: 12,
    assetPath: '${AssetPaths.fish}/fish_river_1.png',
    waterType: WaterType.river,
    tier: 1,
  );
  static const ItemDefinition fishRiver2 = ItemDefinition(
    id: 'fish_river_2',
    name: 'Silver Salmon',
    description: 'A sleek salmon with silver scales.',
    type: ItemType.fish,
    basePrice: 30,
    assetPath: '${AssetPaths.fish}/fish_river_2.png',
    waterType: WaterType.river,
    tier: 2,
  );
  static const ItemDefinition fishRiver3 = ItemDefinition(
    id: 'fish_river_3',
    name: 'Giant Catfish',
    description: 'A massive catfish lurking in deep waters.',
    type: ItemType.fish,
    basePrice: 60,
    assetPath: '${AssetPaths.fish}/fish_river_3.png',
    waterType: WaterType.river,
    tier: 3,
  );
  static const ItemDefinition fishRiver4 = ItemDefinition(
    id: 'fish_river_4',
    name: 'Legendary Sturgeon',
    description: 'An ancient fish from a bygone era.',
    type: ItemType.fish,
    basePrice: 180,
    assetPath: '${AssetPaths.fish}/fish_river_4.png',
    waterType: WaterType.river,
    tier: 4,
  );

  // Ocean fish
  static const ItemDefinition fishOcean1 = ItemDefinition(
    id: 'fish_ocean_1',
    name: 'Sea Perch',
    description: 'A common ocean fish found near shores.',
    type: ItemType.fish,
    basePrice: 15,
    assetPath: '${AssetPaths.fish}/fish_ocean_1.png',
    waterType: WaterType.ocean,
    tier: 1,
  );
  static const ItemDefinition fishOcean2 = ItemDefinition(
    id: 'fish_ocean_2',
    name: 'Bluefin Tuna',
    description: 'A fast and powerful ocean predator.',
    type: ItemType.fish,
    basePrice: 40,
    assetPath: '${AssetPaths.fish}/fish_ocean_2.png',
    waterType: WaterType.ocean,
    tier: 2,
  );
  static const ItemDefinition fishOcean3 = ItemDefinition(
    id: 'fish_ocean_3',
    name: 'Giant Marlin',
    description: 'A trophy fish sought by expert anglers.',
    type: ItemType.fish,
    basePrice: 80,
    assetPath: '${AssetPaths.fish}/fish_ocean_3.png',
    waterType: WaterType.ocean,
    tier: 3,
  );
  static const ItemDefinition fishOcean4 = ItemDefinition(
    id: 'fish_ocean_4',
    name: 'Kraken\'s Catch',
    description: 'A mythical deep-sea creature.',
    type: ItemType.fish,
    basePrice: 250,
    assetPath: '${AssetPaths.fish}/fish_ocean_4.png',
    waterType: WaterType.ocean,
    tier: 4,
  );

  // Night fish
  static const ItemDefinition fishNight1 = ItemDefinition(
    id: 'fish_night_1',
    name: 'Glowing Minnow',
    description: 'A small fish that glows in the dark.',
    type: ItemType.fish,
    basePrice: 20,
    assetPath: '${AssetPaths.fish}/fish_night_1.png',
    waterType: WaterType.night,
    tier: 1,
  );
  static const ItemDefinition fishNight2 = ItemDefinition(
    id: 'fish_night_2',
    name: 'Moonfish',
    description: 'A silvery fish that appears under moonlight.',
    type: ItemType.fish,
    basePrice: 45,
    assetPath: '${AssetPaths.fish}/fish_night_2.png',
    waterType: WaterType.night,
    tier: 2,
  );
  static const ItemDefinition fishNight3 = ItemDefinition(
    id: 'fish_night_3',
    name: 'Shadow Lurker',
    description: 'A mysterious fish that dwells in darkness.',
    type: ItemType.fish,
    basePrice: 90,
    assetPath: '${AssetPaths.fish}/fish_night_3.png',
    waterType: WaterType.night,
    tier: 3,
  );
  static const ItemDefinition fishNight4 = ItemDefinition(
    id: 'fish_night_4',
    name: 'Void Leviathan',
    description: 'A legendary creature from the abyss.',
    type: ItemType.fish,
    basePrice: 300,
    assetPath: '${AssetPaths.fish}/fish_night_4.png',
    waterType: WaterType.night,
    tier: 4,
  );

  // --- Poles ---
  static const ItemDefinition pole1 = ItemDefinition(
    id: 'pole_1',
    name: 'Wooden Rod',
    description: 'A basic fishing rod for beginners. Free!',
    type: ItemType.pole,
    basePrice: 0,
    assetPath: '${AssetPaths.items}/fishing_pole_1.png',
    tier: 1,
  );
  static const ItemDefinition pole2 = ItemDefinition(
    id: 'pole_2',
    name: 'Steel Rod',
    description: 'A sturdy rod with better casting distance.',
    type: ItemType.pole,
    basePrice: 200,
    assetPath: '${AssetPaths.items}/fishing_pole_2.png',
    tier: 2,
  );
  static const ItemDefinition pole3 = ItemDefinition(
    id: 'pole_3',
    name: 'Carbon Fiber Rod',
    description: 'A lightweight rod for serious anglers.',
    type: ItemType.pole,
    basePrice: 500,
    assetPath: '${AssetPaths.items}/fishing_pole_3.png',
    tier: 3,
  );
  static const ItemDefinition pole4 = ItemDefinition(
    id: 'pole_4',
    name: 'Legendary Angler\'s Rod',
    description: 'The ultimate fishing rod, crafted by masters.',
    type: ItemType.pole,
    basePrice: 1500,
    assetPath: '${AssetPaths.items}/fishing_pole_4.png',
    tier: 4,
  );

  // --- Lures ---
  static const ItemDefinition lure1 = ItemDefinition(
    id: 'lure_1',
    name: 'Basic Lure',
    description: 'A simple lure for common fish.',
    type: ItemType.lure,
    basePrice: 10,
    assetPath: '${AssetPaths.items}/lure_1.png',
    tier: 1,
  );
  static const ItemDefinition lure2 = ItemDefinition(
    id: 'lure_2',
    name: 'Spinner Lure',
    description: 'A flashy lure that attracts more fish.',
    type: ItemType.lure,
    basePrice: 30,
    assetPath: '${AssetPaths.items}/lure_2.png',
    tier: 2,
  );
  static const ItemDefinition lure3 = ItemDefinition(
    id: 'lure_3',
    name: 'Golden Lure',
    description: 'A premium lure for rare catches.',
    type: ItemType.lure,
    basePrice: 80,
    assetPath: '${AssetPaths.items}/lure_3.png',
    tier: 3,
  );
  static const ItemDefinition lure4 = ItemDefinition(
    id: 'lure_4',
    name: 'Enchanted Lure',
    description: 'A magical lure that calls legendary fish.',
    type: ItemType.lure,
    basePrice: 250,
    assetPath: '${AssetPaths.items}/lure_4.png',
    tier: 4,
  );

  /// All items indexed by ID
  static const Map<String, ItemDefinition> all = {
    // Fish - Pond
    'fish_pond_1': fishPond1,
    'fish_pond_2': fishPond2,
    'fish_pond_3': fishPond3,
    'fish_pond_4': fishPond4,
    // Fish - River
    'fish_river_1': fishRiver1,
    'fish_river_2': fishRiver2,
    'fish_river_3': fishRiver3,
    'fish_river_4': fishRiver4,
    // Fish - Ocean
    'fish_ocean_1': fishOcean1,
    'fish_ocean_2': fishOcean2,
    'fish_ocean_3': fishOcean3,
    'fish_ocean_4': fishOcean4,
    // Fish - Night
    'fish_night_1': fishNight1,
    'fish_night_2': fishNight2,
    'fish_night_3': fishNight3,
    'fish_night_4': fishNight4,
    // Poles
    'pole_1': pole1,
    'pole_2': pole2,
    'pole_3': pole3,
    'pole_4': pole4,
    // Lures
    'lure_1': lure1,
    'lure_2': lure2,
    'lure_3': lure3,
    'lure_4': lure4,
  };

  /// Get item definition by ID (from service if loaded, fallback otherwise)
  static ItemDefinition? get(String id) {
    if (ItemService.instance.isLoaded) {
      return ItemService.instance.get(id);
    }
    return all[id];
  }

  /// Get all fish items
  static List<ItemDefinition> get allFish {
    if (ItemService.instance.isLoaded) {
      return ItemService.instance.allFish;
    }
    return all.values.where((item) => item.type == ItemType.fish).toList();
  }

  /// Get fish item ID from water type and tier
  static String getFishId(WaterType waterType, int tier) {
    return 'fish_${waterType.name}_$tier';
  }
}

/// Fish asset with water type and tier
class FishAsset {
  final String path;
  final WaterType waterType;
  final int tier;

  const FishAsset({
    required this.path,
    required this.waterType,
    required this.tier,
  });
}

/// Fish assets organized by water type and tier
class FishAssets {
  FishAssets._();

  // Pond fish (tier 1-4)
  static const FishAsset pond1 = FishAsset(
    path: '${AssetPaths.fish}/fish_pond_1.png',
    waterType: WaterType.pond,
    tier: 1,
  );
  static const FishAsset pond2 = FishAsset(
    path: '${AssetPaths.fish}/fish_pond_2.png',
    waterType: WaterType.pond,
    tier: 2,
  );
  static const FishAsset pond3 = FishAsset(
    path: '${AssetPaths.fish}/fish_pond_3.png',
    waterType: WaterType.pond,
    tier: 3,
  );
  static const FishAsset pond4 = FishAsset(
    path: '${AssetPaths.fish}/fish_pond_4.png',
    waterType: WaterType.pond,
    tier: 4,
  );

  // River fish (tier 1-4)
  static const FishAsset river1 = FishAsset(
    path: '${AssetPaths.fish}/fish_river_1.png',
    waterType: WaterType.river,
    tier: 1,
  );
  static const FishAsset river2 = FishAsset(
    path: '${AssetPaths.fish}/fish_river_2.png',
    waterType: WaterType.river,
    tier: 2,
  );
  static const FishAsset river3 = FishAsset(
    path: '${AssetPaths.fish}/fish_river_3.png',
    waterType: WaterType.river,
    tier: 3,
  );
  static const FishAsset river4 = FishAsset(
    path: '${AssetPaths.fish}/fish_river_4.png',
    waterType: WaterType.river,
    tier: 4,
  );

  // Ocean fish (tier 1-4)
  static const FishAsset ocean1 = FishAsset(
    path: '${AssetPaths.fish}/fish_ocean_1.png',
    waterType: WaterType.ocean,
    tier: 1,
  );
  static const FishAsset ocean2 = FishAsset(
    path: '${AssetPaths.fish}/fish_ocean_2.png',
    waterType: WaterType.ocean,
    tier: 2,
  );
  static const FishAsset ocean3 = FishAsset(
    path: '${AssetPaths.fish}/fish_ocean_3.png',
    waterType: WaterType.ocean,
    tier: 3,
  );
  static const FishAsset ocean4 = FishAsset(
    path: '${AssetPaths.fish}/fish_ocean_4.png',
    waterType: WaterType.ocean,
    tier: 4,
  );

  // Night fish (tier 1-4)
  static const FishAsset night1 = FishAsset(
    path: '${AssetPaths.fish}/fish_night_1.png',
    waterType: WaterType.night,
    tier: 1,
  );
  static const FishAsset night2 = FishAsset(
    path: '${AssetPaths.fish}/fish_night_2.png',
    waterType: WaterType.night,
    tier: 2,
  );
  static const FishAsset night3 = FishAsset(
    path: '${AssetPaths.fish}/fish_night_3.png',
    waterType: WaterType.night,
    tier: 3,
  );
  static const FishAsset night4 = FishAsset(
    path: '${AssetPaths.fish}/fish_night_4.png',
    waterType: WaterType.night,
    tier: 4,
  );

  /// All pond fish by tier
  static const List<FishAsset> pondFish = [pond1, pond2, pond3, pond4];

  /// All river fish by tier
  static const List<FishAsset> riverFish = [river1, river2, river3, river4];

  /// All ocean fish by tier
  static const List<FishAsset> oceanFish = [ocean1, ocean2, ocean3, ocean4];

  /// All night fish by tier
  static const List<FishAsset> nightFish = [night1, night2, night3, night4];

  /// Get fish by water type and tier (1-4)
  static FishAsset getFish(WaterType waterType, int tier) {
    assert(tier >= 1 && tier <= 4, 'Fish tier must be between 1 and 4');
    switch (waterType) {
      case WaterType.pond:
        return pondFish[tier - 1];
      case WaterType.river:
        return riverFish[tier - 1];
      case WaterType.ocean:
        return oceanFish[tier - 1];
      case WaterType.night:
        return nightFish[tier - 1];
    }
  }

  /// Get all fish for a water type
  static List<FishAsset> getFishByWaterType(WaterType waterType) {
    switch (waterType) {
      case WaterType.pond:
        return pondFish;
      case WaterType.river:
        return riverFish;
      case WaterType.ocean:
        return oceanFish;
      case WaterType.night:
        return nightFish;
    }
  }
}

/// Image assets (characters, environments, etc.)
class ImageAssets {
  ImageAssets._();

  // Character sprites
  static const String characterIdle = '${AssetPaths.characters}/base_idle_strip9.png';
  static const String characterWalk = '${AssetPaths.characters}/base_walk_strip8.png';

  // Plant sprites
  static const String sunflower = '${AssetPaths.plants}/sunflower.png';
  static const String tree01 = '${AssetPaths.plants}/tree_01_strip4.png';
  static const String tree02 = '${AssetPaths.plants}/tree_02_strip4.png';
}
