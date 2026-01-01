import 'dart:ui';

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
  static const double lureSitDuration = 8.0; // seconds before auto-reel

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
  static const String icons = 'assets/icons';
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

/// Icon assets (UI icons, indicators, etc.)
class IconAssets {
  IconAssets._();

  static const String fishingPole = '${AssetPaths.icons}/fishing_pole.png';
  static const String fishingPoleCasted = '${AssetPaths.icons}/fishing_pole_casted.png';
}

/// Water type enum for fish categorization
enum WaterType {
  pond,
  river,
  ocean,
  night, // Special night-time fish
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
