import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/water_body_data.dart';
import '../../utils/constants.dart';
import '../components/pond.dart';

/// The game world containing the ground and ponds
class GameWorld extends Component {
  final List<PondData> ponds;

  GameWorld({required this.ponds});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Add ground
    await add(Ground());

    // Add ponds
    for (final pondData in ponds) {
      await add(Pond(data: pondData));
    }
  }
}

/// The ground/grass layer of the world - solid green with pixel shade spots
class Ground extends PositionComponent {
  Ground()
      : super(
          position: Vector2.zero(),
          size: Vector2(
            GameConstants.worldWidth,
            GameConstants.worldHeight,
          ),
          priority: GameLayers.ground.toInt(),
        );

  // Size of shade pixels
  static const double pixelSize = 6.0;
  
  // Cached texture image
  Image? _textureImage;
  bool _textureGenerated = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _generateTexture();
  }

  /// Generate the ground texture with sparse pixel spots
  Future<void> _generateTexture() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Draw solid base color
    final basePaint = Paint()..color = GameColors.grassGreen;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), basePaint);
    
    // Seeded random for consistent spots
    final random = Random(789);
    
    // Shade colors
    final darkPaint = Paint()..color = GameColors.grassGreenDark;
    final lightPaint = Paint()..color = GameColors.grassGreenLight;
    
    // Scatter sparse pixel spots across the map
    final spotCount = 800;
    
    for (var i = 0; i < spotCount; i++) {
      final x = (random.nextDouble() * size.x / pixelSize).floor() * pixelSize;
      final y = (random.nextDouble() * size.y / pixelSize).floor() * pixelSize;
      final isLight = random.nextBool();
      
      canvas.drawRect(
        Rect.fromLTWH(x, y, pixelSize, pixelSize),
        isLight ? lightPaint : darkPaint,
      );
    }
    
    // Convert to image
    final picture = recorder.endRecording();
    _textureImage = await picture.toImage(size.x.toInt(), size.y.toInt());
    _textureGenerated = true;
  }

  @override
  void render(Canvas canvas) {
    if (_textureGenerated && _textureImage != null) {
      canvas.drawImage(_textureImage!, Offset.zero, Paint());
    } else {
      // Fallback while texture generates
      final basePaint = Paint()..color = GameColors.grassGreen;
      canvas.drawRect(size.toRect(), basePaint);
    }
  }
}
