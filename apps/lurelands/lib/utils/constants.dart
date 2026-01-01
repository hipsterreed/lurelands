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

  const FishingPoleAsset({
    required this.normal,
    required this.casted,
    required this.tier,
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
  static const FishingPoleAsset fishingPole1 = FishingPoleAsset(
    normal: '${AssetPaths.items}/fishing_pole_1.png',
    casted: '${AssetPaths.items}/fishing_pole_alt_1.png',
    tier: 1,
  );

  static const FishingPoleAsset fishingPole2 = FishingPoleAsset(
    normal: '${AssetPaths.items}/fishing_pole_2.png',
    casted: '${AssetPaths.items}/fishing_pole_alt_2.png',
    tier: 2,
  );

  static const FishingPoleAsset fishingPole3 = FishingPoleAsset(
    normal: '${AssetPaths.items}/fishing_pole_3.png',
    casted: '${AssetPaths.items}/fishing_pole_alt_3.png',
    tier: 3,
  );

  static const FishingPoleAsset fishingPole4 = FishingPoleAsset(
    normal: '${AssetPaths.items}/fishing_pole_4.png',
    casted: '${AssetPaths.items}/fishing_pole_alt_4.png',
    tier: 4,
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
