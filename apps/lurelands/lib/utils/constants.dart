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
