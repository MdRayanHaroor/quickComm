import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single product that the user viewed in ProductDetailScreen
class RecentlyViewedItem {
  final String productId;
  Map<String, dynamic> product;
  List<dynamic> variants;
  int viewCount;
  DateTime lastViewedAt;

  RecentlyViewedItem({
    required this.productId,
    required this.product,
    this.variants = const [],
    this.viewCount = 1,
    required this.lastViewedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'product': product,
      'variants': variants,
      'viewCount': viewCount,
      'lastViewedAt': lastViewedAt.toIso8601String(),
    };
  }

  factory RecentlyViewedItem.fromJson(Map<String, dynamic> json) {
    return RecentlyViewedItem(
      productId: (json['productId'] ?? '').toString(),
      product: json['product'] != null
          ? Map<String, dynamic>.from(json['product'] as Map)
          : {},
      variants: json['variants'] != null
          ? List<dynamic>.from(json['variants'] as List)
          : const [],
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 1,
      lastViewedAt: json['lastViewedAt'] != null
          ? DateTime.tryParse(json['lastViewedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Manages recently viewed products in-memory and persists across app restarts using SharedPreferences
class RecentlyViewedProvider extends ChangeNotifier {
  static const String _storageKey = 'recently_viewed_products_v1';
  static const int _maxItems = 50;

  final List<RecentlyViewedItem> _items = [];
  bool _isLoaded = false;

  RecentlyViewedProvider() {
    _loadFromPrefs();
  }

  bool get isLoaded => _isLoaded;
  bool get hasItems => _items.isNotEmpty;
  int get count => _items.length;

  /// Returns items sorted by most recently viewed first
  List<RecentlyViewedItem> get itemsByRecency {
    final list = List<RecentlyViewedItem>.from(_items);
    list.sort((a, b) => b.lastViewedAt.compareTo(a.lastViewedAt));
    return list;
  }

  /// Returns items sorted by view counter (most viewed first)
  List<RecentlyViewedItem> get itemsByFrequency {
    final list = List<RecentlyViewedItem>.from(_items);
    list.sort((a, b) {
      final cmp = b.viewCount.compareTo(a.viewCount);
      if (cmp != 0) return cmp;
      return b.lastViewedAt.compareTo(a.lastViewedAt);
    });
    return list;
  }

  /// Records a view when a product detail page is opened
  Future<void> recordView(
    Map<String, dynamic> product,
    List<dynamic> variants,
  ) async {
    final productId = (product['id'] ?? '').toString().trim();
    if (productId.isEmpty) return;

    final existingIndex = _items.indexWhere((it) => it.productId == productId);
    if (existingIndex >= 0) {
      final existing = _items.removeAt(existingIndex);
      existing.viewCount += 1;
      existing.lastViewedAt = DateTime.now();
      existing.product = product;
      if (variants.isNotEmpty) {
        existing.variants = variants;
      }
      _items.insert(0, existing);
    } else {
      _items.insert(
        0,
        RecentlyViewedItem(
          productId: productId,
          product: product,
          variants: variants,
          viewCount: 1,
          lastViewedAt: DateTime.now(),
        ),
      );
    }

    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }

    notifyListeners();
    await _saveToPrefs();
  }

  /// Removes a single product from the history
  Future<void> removeItem(String productId) async {
    final targetId = productId.trim();
    final initialLen = _items.length;
    _items.removeWhere((it) => it.productId == targetId);

    if (_items.length != initialLen) {
      notifyListeners();
      await _saveToPrefs();
    }
  }

  /// Removes all products that were purchased in an order
  Future<void> removeOrderedProducts(List<String> productIds) async {
    if (productIds.isEmpty) return;
    final idsSet = productIds.map((id) => id.trim()).toSet();
    final initialLen = _items.length;
    _items.removeWhere((it) => idsSet.contains(it.productId));

    if (_items.length != initialLen) {
      notifyListeners();
      await _saveToPrefs();
    }
  }

  /// Clears all items
  Future<void> clearAll() async {
    _items.clear();
    notifyListeners();
    await _saveToPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final decoded = jsonDecode(rawJson);
        if (decoded is List) {
          _items.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _items.add(RecentlyViewedItem.fromJson(item));
            } else if (item is Map) {
              _items.add(RecentlyViewedItem.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading recently viewed from SharedPreferences: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_items.map((it) => it.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('Error saving recently viewed to SharedPreferences: $e');
    }
  }
}
