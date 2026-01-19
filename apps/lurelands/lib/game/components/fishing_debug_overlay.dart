import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../utils/constants.dart';
import '../lurelands_game.dart';
import '../world/tiled_map_world.dart';

/// Debug overlay that shows fishable water areas and casting state.
/// Only renders when debug mode is enabled.
class FishingDebugOverlay extends PositionComponent with HasGameReference<LurelandsGame> {
  FishingDebugOverlay() : super(priority: 1000); // Render on top

  /// Radius to check for nearby fishable tiles (in world units)
  static const double debugRenderRadius = 300.0;

  /// Colors for different water types (for collision areas - the actual water)
  static const Map<WaterType, Color> waterTypeColors = {
    WaterType.pond: Color(0x8000FF00), // Green with alpha
    WaterType.river: Color(0x800000FF), // Blue with alpha
    WaterType.ocean: Color(0x8000FFFF), // Cyan with alpha
    WaterType.night: Color(0x80800080), // Purple with alpha
  };

  @override
  void render(Canvas canvas) {
    // Only render in debug mode
    if (!game.debugModeNotifier.value) return;

    final player = game.player;
    if (player == null) return;

    final playerPos = player.position;
    final tiledMapWorld = game.world;
    if (tiledMapWorld is! TiledMapWorld) return;

    // Get nearby fishable tiles
    final nearbyTiles = tiledMapWorld.getFishableTilesNear(playerPos, debugRenderRadius);

    // Draw total fishable tile count in top-left of screen (camera space)
    final totalFishable = tiledMapWorld.fishableTileCache.length;
    _drawScreenText(
      canvas,
      'FISHING DEBUG\n'
      'Total fishable tiles in map: $totalFishable\n'
      'Nearby fishable tiles: ${nearbyTiles.length}\n'
      'Player pos: (${playerPos.x.toInt()}, ${playerPos.y.toInt()})',
      Offset(playerPos.x - 200, playerPos.y - 150),
      const Color(0xFFFFFF00),
      12,
    );

    int tilesWithCollision = 0;
    int tilesWithoutCollision = 0;

    // Draw fishable tiles
    for (final tile in nearbyTiles) {
      final color = waterTypeColors[tile.waterType] ?? const Color(0x8000FF00);

      // Calculate full tile bounds
      final tileSize = TiledMapWorld.renderedTileSize;
      final tileRect = Rect.fromLTWH(
        tile.tileX * tileSize,
        tile.tileY * tileSize,
        tileSize,
        tileSize,
      );

      // Draw tile boundary (orange dashed border to show "this tile is fishable")
      final tileBorderPaint = Paint()
        ..color = const Color(0xFFFF8800) // Orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(tileRect, tileBorderPaint);

      // Draw "F" label in corner to indicate fishable
      final labelPainter = TextPainter(
        text: TextSpan(
          text: tile.waterType.name[0].toUpperCase(), // P, R, O, N
          style: const TextStyle(
            color: Color(0xFFFF8800),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Color(0xFF000000), blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(tileRect.left + 2, tileRect.top + 2));

      // Check if this tile has actual collision rects or just uses full tile
      final hasRealCollision = tile.collisionRects.length != 1 ||
          tile.collisionRects.first != tileRect;

      if (hasRealCollision) {
        tilesWithCollision++;
        // Draw collision areas (the actual water parts) - filled
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;

        final borderPaint = Paint()
          ..color = color.withAlpha(255)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        for (final rect in tile.collisionRects) {
          canvas.drawRect(rect, paint);
          canvas.drawRect(rect, borderPaint);
        }
      } else {
        tilesWithoutCollision++;
        // No collision defined - draw X pattern to indicate missing collision
        final missingPaint = Paint()
          ..color = const Color(0x60FF0000) // Red with alpha
          ..style = PaintingStyle.fill;
        canvas.drawRect(tileRect, missingPaint);

        // Draw X
        final xPaint = Paint()
          ..color = const Color(0xFFFF0000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawLine(tileRect.topLeft, tileRect.bottomRight, xPaint);
        canvas.drawLine(tileRect.topRight, tileRect.bottomLeft, xPaint);
      }
    }

    // Draw casting range circle around player
    const castingBuffer = 50.0;
    final rangePaint = Paint()
      ..color = const Color(0xFFFFFF00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(
      Offset(playerPos.x, playerPos.y),
      castingBuffer,
      rangePaint,
    );

    // Check if player can fish and draw indicator
    final canFish = tiledMapWorld.isPlayerNearWater(playerPos, castingBuffer);

    // Draw status text above player
    _drawText(
      canvas,
      canFish ? 'CAN FISH' : 'NO WATER NEARBY',
      Offset(playerPos.x, playerPos.y - 85),
      canFish ? const Color(0xFF00FF00) : const Color(0xFFFF6666),
      14,
    );

    // Draw tile count info
    _drawText(
      canvas,
      'Fishable tiles: ${nearbyTiles.length} (${tilesWithCollision} with collision, $tilesWithoutCollision without)',
      Offset(playerPos.x, playerPos.y - 70),
      const Color(0xFFFFFFFF),
      10,
    );

    // Draw legend
    _drawText(
      canvas,
      'Orange border = fishable tile | Colored fill = water collision area | Red X = no collision',
      Offset(playerPos.x, playerPos.y - 55),
      const Color(0xFFCCCCCC),
      8,
    );
  }

  void _drawText(Canvas canvas, String text, Offset position, Color color, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(color: Color(0xFF000000), blurRadius: 3, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(canvas, Offset(position.dx - painter.width / 2, position.dy));
  }

  void _drawScreenText(Canvas canvas, String text, Offset position, Color color, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          backgroundColor: const Color(0xAA000000),
          shadows: const [
            Shadow(color: Color(0xFF000000), blurRadius: 3, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(canvas, position);
  }
}
