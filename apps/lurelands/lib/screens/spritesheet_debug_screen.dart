import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';

/// Debug screen to view all tiles from the fish spritesheet
class SpritesheetDebugScreen extends StatefulWidget {
  const SpritesheetDebugScreen({super.key});

  @override
  State<SpritesheetDebugScreen> createState() => _SpritesheetDebugScreenState();
}

class _SpritesheetDebugScreenState extends State<SpritesheetDebugScreen> {
  ui.Image? _spritesheetImage;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSpritesheet();
  }

  Future<void> _loadSpritesheet() async {
    try {
      final data = await rootBundle.load(FishingPoleAsset.spritesheetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          _spritesheetImage = frame.image;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Spritesheet Debug'),
        backgroundColor: Colors.grey[900],
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                '${FishingPoleAsset.columns}x${FishingPoleAsset.rows} tiles @ ${FishingPoleAsset.spriteSize.toInt()}px',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error loading spritesheet:\n$_error',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_spritesheetImage == null) {
      return const Center(
        child: Text(
          'No image loaded',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show full spritesheet first
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Full Spritesheet:',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Image.asset(
                    FishingPoleAsset.spritesheetPath,
                    filterQuality: FilterQuality.none,
                    scale: 0.5, // Show at 2x size
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24),

          // Fishing poles section (row 3, tiles 75-99)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fishing Poles (Row 3, Tiles 75-99):',
                  style: TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(25, (index) {
                    final column = index;
                    const row = 3;
                    final tileId = row * FishingPoleAsset.columns + column;
                    return _buildTilePreview(column, row, tileId);
                  }),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24),

          // All tiles grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All Tiles Grid:',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: FishingPoleAsset.columns,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: FishingPoleAsset.columns * FishingPoleAsset.rows,
                  itemBuilder: (context, index) {
                    final column = index % FishingPoleAsset.columns;
                    final row = index ~/ FishingPoleAsset.columns;
                    return _buildSmallTile(column, row);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTilePreview(int column, int row, int tileId) {
    const displaySize = 48.0;

    return Column(
      children: [
        Container(
          width: displaySize,
          height: displaySize,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.yellow.withOpacity(0.5)),
            color: Colors.grey[800],
          ),
          child: CustomPaint(
            size: const Size(displaySize, displaySize),
            painter: _TilePainter(
              image: _spritesheetImage!,
              column: column,
              row: row,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$tileId',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
        Text(
          '($column,$row)',
          style: const TextStyle(color: Colors.white54, fontSize: 8),
        ),
      ],
    );
  }

  Widget _buildSmallTile(int column, int row) {
    final tileId = row * FishingPoleAsset.columns + column;
    final isPoleTile = row == 3; // Fishing poles are in row 3

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tile $tileId (col: $column, row: $row)'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isPoleTile ? Colors.yellow.withOpacity(0.5) : Colors.white12,
            width: isPoleTile ? 1 : 0.5,
          ),
        ),
        child: CustomPaint(
          painter: _TilePainter(
            image: _spritesheetImage!,
            column: column,
            row: row,
          ),
        ),
      ),
    );
  }
}

/// Custom painter to draw a single tile from the spritesheet
class _TilePainter extends CustomPainter {
  final ui.Image image;
  final int column;
  final int row;

  _TilePainter({
    required this.image,
    required this.column,
    required this.row,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(
      column * FishingPoleAsset.spriteSize,
      row * FishingPoleAsset.spriteSize,
      FishingPoleAsset.spriteSize,
      FishingPoleAsset.spriteSize,
    );

    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }

  @override
  bool shouldRepaint(covariant _TilePainter oldDelegate) {
    return oldDelegate.column != column || oldDelegate.row != row;
  }
}
