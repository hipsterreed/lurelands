import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

/// Service for managing item definitions loaded from the database.
/// Provides the same interface as the hardcoded GameItems class.
class ItemService {
  ItemService._();

  static final ItemService instance = ItemService._();

  /// All loaded items indexed by ID
  final Map<String, ItemDefinition> _items = {};

  /// Whether items have been loaded from API
  bool _isLoaded = false;

  /// Whether we're using fallback data
  bool _usingFallback = false;

  bool get isLoaded => _isLoaded;
  bool get usingFallback => _usingFallback;

  /// Load items from Bridge API.
  /// Returns true if loaded from API, false if using fallback.
  Future<bool> loadItems(String bridgeUrl) async {
    try {
      final uri = Uri.parse('$bridgeUrl/api/items');
      debugPrint('[ItemService] Fetching items from: $uri');

      final response = await http
          .get(
            uri,
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _items.clear();

        for (final json in data) {
          final item = _parseItemFromApi(json as Map<String, dynamic>);
          if (item != null) {
            _items[item.id] = item;
          }
        }

        _isLoaded = true;
        _usingFallback = false;
        debugPrint('[ItemService] Loaded ${_items.length} items from API');
        return true;
      } else {
        debugPrint(
            '[ItemService] API returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ItemService] Failed to load items: $e');
    }

    // Fallback to hardcoded items
    _loadFallbackItems();
    return false;
  }

  void _loadFallbackItems() {
    _items.clear();
    _items.addAll(GameItems.all);
    _isLoaded = true;
    _usingFallback = true;
    debugPrint(
        '[ItemService] Using fallback hardcoded items (${_items.length} items)');
  }

  /// Parse API response to ItemDefinition
  ItemDefinition? _parseItemFromApi(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String;
      final name = json['name'] as String;
      final category = json['category'] as String;
      final waterTypeStr = json['waterType'] as String?;
      final tier = json['tier'] as int;
      final sellPrice = json['sellPrice'] as int;
      final spriteId = json['spriteId'] as String;
      final description = json['description'] as String?;
      final rarityMultipliersJson = json['rarityMultipliers'] as String?;

      // Convert category to ItemType
      final type = _parseItemType(category);

      // Convert waterType string to WaterType enum
      final waterType = _parseWaterType(waterTypeStr);

      // Convert spriteId to assetPath
      final assetPath = _spriteIdToAssetPath(spriteId, category);

      // Parse rarity multipliers
      final rarityMultipliers = _parseRarityMultipliers(rarityMultipliersJson);

      return ItemDefinition(
        id: id,
        name: name,
        description: description ?? '',
        type: type,
        basePrice: sellPrice, // Use sell price as base
        assetPath: assetPath,
        waterType: waterType,
        tier: tier,
        rarityMultipliers: rarityMultipliers,
      );
    } catch (e) {
      debugPrint('[ItemService] Error parsing item: $e');
      return null;
    }
  }

  ItemType _parseItemType(String category) {
    switch (category.toLowerCase()) {
      case 'fish':
        return ItemType.fish;
      case 'pole':
        return ItemType.pole;
      case 'lure':
        return ItemType.lure;
      case 'bait':
        return ItemType.bait;
      default:
        return ItemType.fish;
    }
  }

  WaterType? _parseWaterType(String? waterType) {
    if (waterType == null) return null;
    switch (waterType.toLowerCase()) {
      case 'pond':
        return WaterType.pond;
      case 'river':
        return WaterType.river;
      case 'ocean':
        return WaterType.ocean;
      case 'night':
        return WaterType.night;
      default:
        return null;
    }
  }

  String _spriteIdToAssetPath(String spriteId, String category) {
    // Map spriteId to asset path based on category
    // Database stores: "fish_pond_1" -> "assets/images/fish/fish_pond_1.png"
    // Database stores: "fishing_pole_1" -> "assets/items/fishing_pole_1.png"
    if (category == 'fish') {
      return '${AssetPaths.fish}/$spriteId.png';
    } else {
      return '${AssetPaths.items}/$spriteId.png';
    }
  }

  Map<int, double>? _parseRarityMultipliers(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final Map<String, dynamic> parsed = jsonDecode(json);
      return parsed.map(
        (k, v) => MapEntry(int.parse(k), (v as num).toDouble()),
      );
    } catch (_) {
      return null;
    }
  }

  // === Public API (matching GameItems interface) ===

  /// Get item definition by ID
  ItemDefinition? get(String id) => _items[id];

  /// Get all items
  Map<String, ItemDefinition> get all => Map.unmodifiable(_items);

  /// Get all fish items
  List<ItemDefinition> get allFish =>
      _items.values.where((item) => item.type == ItemType.fish).toList();

  /// Get fish item ID from water type and tier
  String getFishId(WaterType waterType, int tier) {
    return 'fish_${waterType.name}_$tier';
  }
}
