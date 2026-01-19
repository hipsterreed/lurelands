import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';

/// Shared image cache for spritesheet sprites
class _SpriteImageCache {
  static final Map<String, ui.Image?> images = <String, ui.Image?>{};
  static final Set<String> loading = <String>{};
  static final List<VoidCallback> _listeners = [];

  static void addListener(VoidCallback callback) {
    _listeners.add(callback);
  }

  static void removeListener(VoidCallback callback) {
    _listeners.remove(callback);
  }

  static void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  static Future<void> loadImage(String assetPath) async {
    if (images.containsKey(assetPath) || loading.contains(assetPath)) return;
    loading.add(assetPath);

    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      images[assetPath] = frame.image;
      _notifyListeners();
    } catch (e) {
      images[assetPath] = null;
    }
    loading.remove(assetPath);
  }
}

/// Widget to display a sprite from the fishing spritesheet
/// This is the correct way to render sprites - using CustomPaint with drawImageRect
class SpritesheetSprite extends StatefulWidget {
  final int column;
  final int row;
  final double size;
  final double opacity;
  final double rotation;
  final String? assetPath;

  const SpritesheetSprite({
    super.key,
    required this.column,
    required this.row,
    this.size = 32,
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.assetPath,
  });

  /// Create a sprite widget from an ItemDefinition
  factory SpritesheetSprite.fromItem(ItemDefinition item, {double size = 32, double opacity = 1.0}) {
    return SpritesheetSprite(
      column: item.spriteColumn ?? 0,
      row: item.spriteRow ?? 0,
      size: size,
      opacity: opacity,
      assetPath: item.assetPath,
    );
  }

  @override
  State<SpritesheetSprite> createState() => _SpritesheetSpriteState();
}

class _SpritesheetSpriteState extends State<SpritesheetSprite> {
  @override
  void initState() {
    super.initState();
    _SpriteImageCache.addListener(_onImageLoaded);
    _loadImage();
  }

  @override
  void dispose() {
    _SpriteImageCache.removeListener(_onImageLoaded);
    super.dispose();
  }

  void _onImageLoaded() {
    if (mounted) {
      setState(() {});
    }
  }

  void _loadImage() {
    final path = widget.assetPath ?? FishingPoleAsset.spritesheetPath;
    _SpriteImageCache.loadImage(path);
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.assetPath ?? FishingPoleAsset.spritesheetPath;
    final image = _SpriteImageCache.images[path];

    // Calculate source rectangle in the spritesheet
    final srcX = widget.column * FishingPoleAsset.spriteSize;
    final srcY = widget.row * FishingPoleAsset.spriteSize;

    Widget child;
    if (image != null) {
      child = CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _SpritePainter(
          image: image,
          srcRect: Rect.fromLTWH(srcX, srcY, FishingPoleAsset.spriteSize, FishingPoleAsset.spriteSize),
        ),
      );
    } else {
      // Show placeholder while loading
      child = Container(
        color: Colors.grey.withValues(alpha: 0.3),
      );
    }

    if (widget.rotation != 0.0) {
      child = Transform.rotate(angle: widget.rotation, child: child);
    }

    if (widget.opacity != 1.0) {
      child = Opacity(opacity: widget.opacity, child: child);
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: child,
    );
  }
}

/// Custom painter that draws a sprite from a spritesheet
class _SpritePainter extends CustomPainter {
  final ui.Image image;
  final Rect srcRect;

  _SpritePainter({required this.image, required this.srcRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }

  @override
  bool shouldRepaint(covariant _SpritePainter oldDelegate) {
    return oldDelegate.srcRect != srcRect || oldDelegate.image != image;
  }
}

/// Helper widget that renders either a spritesheet sprite or a regular image
/// based on the ItemDefinition
class ItemImage extends StatelessWidget {
  final ItemDefinition item;
  final double size;
  final double opacity;

  const ItemImage({
    super.key,
    required this.item,
    this.size = 32,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (item.usesSpritesheet) {
      return SpritesheetSprite.fromItem(item, size: size, opacity: opacity);
    }

    // Regular image asset
    return SizedBox(
      width: size,
      height: size,
      child: Opacity(
        opacity: opacity,
        child: Image.asset(
          item.assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.help_outline,
            size: size * 0.6,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
