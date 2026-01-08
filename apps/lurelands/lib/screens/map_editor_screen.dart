import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor/map_editor_game.dart' show MapEditorGame, TreeType;
import '../editor/placeable_item.dart';
import '../game/world/nature_tileset.dart';
import '../utils/constants.dart';

// Web-only import for file download
import 'map_editor_web_stub.dart'
    if (dart.library.html) 'map_editor_web.dart' as web;

/// Map editor screen - hosts the editor game with sidebar palette
class MapEditorScreen extends StatefulWidget {
  const MapEditorScreen({super.key});

  @override
  State<MapEditorScreen> createState() => _MapEditorScreenState();
}

class _MapEditorScreenState extends State<MapEditorScreen> {
  late MapEditorGame _game;
  PaletteCategory _selectedCategory = PaletteCategory.water;
  PaletteEntry? _selectedEntry;
  bool _showGrid = true;
  bool _snapToGrid = true;

  @override
  void initState() {
    super.initState();
    _game = MapEditorGame();
    _game.onItemsChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(),
          // Game view
          Expanded(
            child: Stack(
              children: [
                GameWidget(game: _game),
                // Top toolbar
                _buildToolbar(),
                // Bottom status bar
                _buildStatusBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F3460),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back to Menu',
                ),
                const SizedBox(width: 8),
                const Text(
                  'Map Editor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Category tabs
          _buildCategoryTabs(),
          
          // Item palette
          Expanded(
            child: _buildPalette(),
          ),
          
          // Water type selector (when water category selected)
          if (_selectedCategory == PaletteCategory.water)
            _buildWaterTypeSelector(),
            
          // Selected item info
          if (_selectedEntry != null)
            _buildSelectedInfo(),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: PaletteCategory.values.map((category) {
            final isSelected = category == _selectedCategory;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilterChip(
                label: Text(
                  category.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                backgroundColor: const Color(0xFF1A1A2E),
                selectedColor: const Color(0xFF0F3460),
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? Colors.white30 : Colors.white10,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPalette() {
    final entries = EditorPalette.getByCategory(_selectedCategory);
    
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = _selectedEntry == entry;
        
        return _buildPaletteItem(entry, isSelected);
      },
    );
  }

  Widget _buildPaletteItem(PaletteEntry entry, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedEntry == entry) {
            // Deselect
            _selectedEntry = null;
            _game.selectedItemType = null;
            _game.selectedTile = null;
          } else {
            _selectedEntry = entry;
            _game.selectedItemType = entry.itemType;
            _game.selectedTile = entry.tile;
            if (entry.treeType != null) {
              _game.selectedTreeType = entry.treeType!;
            }
            if (entry.treeVariant != null) {
              _game.selectedTreeVariant = entry.treeVariant!;
            }
            if (entry.waterType != null) {
              _game.selectedWaterType = entry.waterType!;
            }
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF0F3460) 
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Preview
            Expanded(
              child: Center(
                child: _buildItemPreview(entry),
              ),
            ),
            // Label
            Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                entry.name,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemPreview(PaletteEntry entry) {
    // For tiles, render actual sprite from tileset
    if (entry.tile != null) {
      return _TileSpritePreview(tile: entry.tile!);
    }
    
    // For trees, show the specific variant from the sprite strip
    if (entry.itemType == PlaceableItemType.tree && entry.assetPath != null) {
      return _TreeSpritePreview(
        assetPath: entry.assetPath!,
        variant: entry.treeVariant ?? 0,
        treeType: entry.treeType,
      );
    }
    
    // For other assets, show the full image
    if (entry.assetPath != null) {
      return Image.asset(
        'assets/images/${entry.assetPath}',
        width: 48,
        height: 48,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none, // Pixel art scaling
        errorBuilder: (_, __, ___) => _buildFallbackIcon(entry),
      );
    }
    
    return _buildFallbackIcon(entry);
  }

  Widget _buildFallbackIcon(PaletteEntry entry) {
    IconData icon;
    Color color;
    
    switch (entry.itemType) {
      case PlaceableItemType.tree:
        icon = Icons.park;
        color = Colors.green;
        break;
      case PlaceableItemType.shop:
        icon = Icons.store;
        color = Colors.amber;
        break;
      case PlaceableItemType.questSign:
        icon = Icons.signpost;
        color = Colors.brown;
        break;
      case PlaceableItemType.sunflower:
        icon = Icons.local_florist;
        color = Colors.yellow;
        break;
      case PlaceableItemType.walkableZone:
        icon = Icons.crop_square;
        color = Colors.green;
        break;
      default:
        icon = Icons.square;
        color = Colors.grey;
    }
    
    return Icon(icon, color: color, size: 32);
  }

  Widget _buildWaterTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Water Type:',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildWaterTypeChip(WaterType.pond, 'Pond'),
              const SizedBox(width: 8),
              _buildWaterTypeChip(WaterType.river, 'River'),
              const SizedBox(width: 8),
              _buildWaterTypeChip(WaterType.ocean, 'Ocean'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterTypeChip(WaterType type, String label) {
    final isSelected = _game.selectedWaterType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _game.selectedWaterType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? GameColors.pondBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? GameColors.pondBlue : Colors.white30,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Selected: ${_selectedEntry!.name}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedEntry = null;
                _game.selectedItemType = null;
                _game.selectedTile = null;
              });
            },
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xDD16213E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            // Grid toggle
            _buildToolButton(
              icon: Icons.grid_on,
              label: 'Grid',
              isActive: _showGrid,
              onTap: () {
                setState(() {
                  _showGrid = !_showGrid;
                  _game.showGrid = _showGrid;
                  _game.toggleGrid();
                });
              },
            ),
            const SizedBox(width: 8),
            
            // Snap toggle
            _buildToolButton(
              icon: Icons.grid_4x4,
              label: 'Snap',
              isActive: _snapToGrid,
              onTap: () {
                setState(() {
                  _snapToGrid = !_snapToGrid;
                  _game.snapToGrid = _snapToGrid;
                });
              },
            ),
            
            const Spacer(),
            
            // Item count
            Text(
              '${_game.placedItems.length} items',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            
            const SizedBox(width: 16),
            
            // Load from assets
            _buildToolButton(
              icon: Icons.folder_open,
              label: 'Load',
              onTap: () => _loadFromAssets(),
            ),
            const SizedBox(width: 8),
            
            // Import from file
            _buildToolButton(
              icon: Icons.upload,
              label: 'Import',
              onTap: () => _importMap(),
            ),
            const SizedBox(width: 8),
            
            // Clear all
            _buildToolButton(
              icon: Icons.delete_sweep,
              label: 'Clear',
              onTap: () => _showClearConfirmation(),
            ),
            const SizedBox(width: 8),
            
            // Export
            _buildToolButton(
              icon: Icons.download,
              label: 'Export',
              isPrimary: true,
              onTap: () => _exportMap(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    bool isPrimary = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isPrimary
          ? Colors.amber
          : isActive
              ? const Color(0xFF0F3460)
              : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.black87 : Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.black87 : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Positioned(
      bottom: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xDD16213E),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Click to place • Right-click to delete • Scroll to zoom • Drag to pan',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Clear All?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove all placed items. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _game.clearAll();
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadFromAssets() async {
    try {
      final jsonString = await rootBundle.loadString('assets/maps/world.json');
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _game.importFromJson(json);
      setState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded ${_game.placedItems.length} items from world.json'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load world.json: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _importMap() async {
    if (kIsWeb) {
      // Web: pick file using file input
      final jsonString = await web.pickJsonFile();
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          _game.importFromJson(json);
          setState(() {});
          _showImportSuccess();
        } catch (e) {
          _showImportError('Invalid JSON format: $e');
        }
      }
    } else {
      // Non-web: show dialog to paste JSON
      _showImportDialog();
    }
  }

  void _showImportSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imported ${_game.placedItems.length} items successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showImportError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Import failed: $message'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Import Map', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the JSON content from your world.json file:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 10,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
                decoration: InputDecoration(
                  hintText: '{"version": 1, ...}',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              try {
                final json = jsonDecode(controller.text) as Map<String, dynamic>;
                _game.importFromJson(json);
                Navigator.pop(context);
                setState(() {});
                _showImportSuccess();
              } catch (e) {
                _showImportError('Invalid JSON: $e');
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _exportMap() {
    final json = _game.exportToJson();
    final jsonString = const JsonEncoder.withIndent('  ').convert(json);
    
    if (kIsWeb) {
      // Web: download file
      web.downloadJsonFile(jsonString, 'world.json');
      _showExportSuccess();
    } else {
      // Mobile/Desktop: copy to clipboard or show dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Export Map', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copy this JSON and save it to assets/maps/world.json:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    jsonString,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _showExportSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Map exported successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

/// Widget to render a tile sprite from the nature tileset
class _TileSpritePreview extends StatelessWidget {
  final NatureTile tile;
  
  const _TileSpritePreview({required this.tile});
  
  @override
  Widget build(BuildContext context) {
    // Tile size in the source image
    const tileSize = 16.0;
    // Display size (scaled up for visibility)
    const displaySize = 48.0;
    
    return SizedBox(
      width: displaySize,
      height: displaySize,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(-tile.col * tileSize * 3, -tile.row * tileSize * 3),
            child: Image.asset(
              'assets/images/tiles/nature.png',
              width: 16 * tileSize * 3, // Full tileset width scaled
              height: 16 * tileSize * 3, // Full tileset height scaled
              filterQuality: FilterQuality.none,
              fit: BoxFit.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget to render a tree variant from a sprite strip
class _TreeSpritePreview extends StatelessWidget {
  final String assetPath;
  final int variant;
  final TreeType? treeType;
  
  const _TreeSpritePreview({
    required this.assetPath,
    required this.variant,
    this.treeType,
  });
  
  @override
  Widget build(BuildContext context) {
    // Tree sprite sizes (from tree.dart)
    final isRound = treeType == TreeType.round;
    final srcWidth = isRound ? 32.0 : 28.0;
    final srcHeight = isRound ? 34.0 : 43.0;
    const scale = 1.5; // Scale for preview
    
    return SizedBox(
      width: srcWidth * scale,
      height: srcHeight * scale,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(-variant * srcWidth * scale, 0),
            child: Image.asset(
              'assets/images/$assetPath',
              height: srcHeight * scale,
              filterQuality: FilterQuality.none,
              fit: BoxFit.none,
            ),
          ),
        ),
      ),
    );
  }
}

