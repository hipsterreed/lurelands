import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/pond_data.dart';
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

/// The ground/grass layer of the world
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

  @override
  void render(Canvas canvas) {
    // Draw base grass color
    final basePaint = Paint()..color = GameColors.grassGreen;
    canvas.drawRect(size.toRect(), basePaint);

    // Draw some grass texture/variation
    final lightPaint = Paint()..color = GameColors.grassGreenLight;
    final darkPaint = Paint()..color = GameColors.grassGreenDark;

    // Draw random grass patches for visual interest
    final random = _SeededRandom(42);
    for (var i = 0; i < 200; i++) {
      final x = random.nextDouble() * size.x;
      final y = random.nextDouble() * size.y;
      final patchSize = 20 + random.nextDouble() * 40;
      final isLight = random.nextBool();

      canvas.drawCircle(
        Offset(x, y),
        patchSize,
        isLight ? lightPaint : darkPaint,
      );
    }
  }
}

/// Simple seeded random for consistent patterns
class _SeededRandom {
  int _seed;

  _SeededRandom(this._seed);

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }

  bool nextBool() => nextDouble() > 0.5;
}
