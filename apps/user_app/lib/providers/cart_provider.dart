import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// Represents a product variant that can be added to the cart
class CartItem {
  final String productId;
  final String? variantId;
  final String productName;
  final String variantName; // e.g. "500ml", "1kg", "Standard"
  final double sellingPrice; // price customer pays
  final double mrp; // original MRP (for strikethrough)
  final String? imageUrl;
  final String? categoryId;
  final String? categoryName;
  int quantity;

  CartItem({
    required this.productId,
    this.variantId,
    required this.productName,
    required this.variantName,
    required this.sellingPrice,
    required this.mrp,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
    this.quantity = 1,
  });

  double get lineTotal => sellingPrice * quantity;
  double get lineSavings => (mrp - sellingPrice) * quantity;

  String get displayName =>
      variantName.isNotEmpty ? '$productName — $variantName' : productName;
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  bool _isLoadingDb = false;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoadingDb => _isLoadingDb;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);

  double get totalSavings => _items.fold(0, (sum, item) => sum + item.lineSavings);

  CartProvider() {
    loadCartFromDb();
    // Re-sync cart on login/logout
    try {
      SupabaseService.client.auth.onAuthStateChange.listen((data) async {
        if (data.session != null) {
          for (final item in _items) {
            await _syncUpsertItem(item);
          }
          await loadCartFromDb();
        } else {
          _items.clear();
          notifyListeners();
        }
      });
    } catch (_) {}
  }

  /// Key used to identify a unique cart entry (product + variant combo)
  String _key(String productId, String? variantId) {
    return '${productId}_${variantId ?? "default"}';
  }

  bool isInCart(String productId, String? variantId) {
    return _items.any((i) => _key(i.productId, i.variantId) == _key(productId, variantId));
  }

  int quantityOf(String productId, String? variantId) {
    try {
      return _items
          .firstWhere((i) => _key(i.productId, i.variantId) == _key(productId, variantId))
          .quantity;
    } catch (_) {
      return 0;
    }
  }

  /// Loads saved cart items from Supabase database for the logged-in user.
  Future<void> loadCartFromDb() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      _items.clear();
      notifyListeners();
      return;
    }

    _isLoadingDb = true;
    try {
      final res = await SupabaseService.client
          .from('cart_items')
          .select('*, products(name, image_url, category_id), product_variants(variant_name, selling_price, mrp)')
          .eq('user_id', user.id);

      final List<CartItem> loaded = [];
      for (final row in res) {
        final productId = row['product_id']?.toString() ?? '';
        final variantId = row['variant_id']?.toString();
        final qty = (row['quantity'] as num?)?.toInt() ?? 1;
        final product = row['products'] as Map<String, dynamic>?;
        final variant = row['product_variants'] as Map<String, dynamic>?;

        final productName = product?['name']?.toString() ?? 'Item';
        final imageUrl = product?['image_url']?.toString();
        final categoryId = product?['category_id']?.toString();
        final variantName = variant?['variant_name']?.toString() ?? '';
        final sellingPrice = (variant?['selling_price'] as num?)?.toDouble() ?? 0.0;
        final mrp = (variant?['mrp'] as num?)?.toDouble() ?? sellingPrice;

        if (productId.isNotEmpty) {
          loaded.add(CartItem(
            productId: productId,
            variantId: variantId,
            productName: productName,
            variantName: variantName,
            sellingPrice: sellingPrice,
            mrp: mrp,
            imageUrl: imageUrl,
            categoryId: categoryId,
            quantity: qty,
          ));
        }
      }

      _items.clear();
      _items.addAll(loaded);
      notifyListeners();
    } catch (e) {
      debugPrint('CartProvider: Error loading cart from DB: $e');
    } finally {
      _isLoadingDb = false;
    }
  }

  Future<void> _syncUpsertItem(CartItem item) async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      debugPrint('CartProvider: Cannot sync item to DB - user is not logged in');
      return;
    }
    try {
      final pId = int.tryParse(item.productId);
      final vId = item.variantId != null ? int.tryParse(item.variantId!) : null;
      if (pId == null) return;

      var query = SupabaseService.client
          .from('cart_items')
          .select('id')
          .eq('user_id', user.id)
          .eq('product_id', pId);

      if (vId != null) {
        query = query.eq('variant_id', vId);
      } else {
        query = query.isFilter('variant_id', null);
      }

      final existing = await query.maybeSingle();

      if (existing != null && existing['id'] != null) {
        await SupabaseService.client
            .from('cart_items')
            .update({
              'quantity': item.quantity,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);
        debugPrint('CartProvider: Updated DB cart item: ${item.productName} qty=${item.quantity}');
      } else {
        await SupabaseService.client.from('cart_items').insert({
          'user_id': user.id,
          'product_id': pId,
          if (vId != null) 'variant_id': vId,
          'quantity': item.quantity,
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('CartProvider: Inserted DB cart item: ${item.productName} qty=${item.quantity}');
      }
    } catch (e) {
      debugPrint('CartProvider: Error syncing item to DB: $e');
    }
  }

  Future<void> _syncDeleteItem(String productId, String? variantId) async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;
    try {
      final pId = int.tryParse(productId);
      final vId = variantId != null ? int.tryParse(variantId) : null;
      if (pId == null) return;

      var q = SupabaseService.client.from('cart_items').delete().eq('user_id', user.id).eq('product_id', pId);
      if (vId != null) {
        q = q.eq('variant_id', vId);
      } else {
        q = q.isFilter('variant_id', null);
      }
      await q;
    } catch (e) {
      debugPrint('CartProvider: Error deleting item from DB: $e');
    }
  }

  Future<void> _syncClearCart() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;
    try {
      await SupabaseService.client.from('cart_items').delete().eq('user_id', user.id);
    } catch (e) {
      debugPrint('CartProvider: Error clearing cart in DB: $e');
    }
  }

  void addItem(CartItem item) {
    addOrMergeItem(item);
  }

  /// Smart merge: increases quantity by [quantityToAdd] (or item.quantity) if already present, or adds new item.
  void addOrMergeItem(CartItem item, {int? quantityToAdd}) {
    final qty = quantityToAdd ?? (item.quantity > 0 ? item.quantity : 1);
    final idx = _items.indexWhere(
      (i) => _key(i.productId, i.variantId) == _key(item.productId, item.variantId),
    );
    if (idx >= 0) {
      _items[idx].quantity += qty;
      _syncUpsertItem(_items[idx]);
    } else {
      item.quantity = qty;
      _items.add(item);
      _syncUpsertItem(item);
    }
    notifyListeners();
  }

  void increaseQuantity(String productId, String? variantId) {
    final idx = _items.indexWhere(
      (i) => _key(i.productId, i.variantId) == _key(productId, variantId),
    );
    if (idx >= 0) {
      _items[idx].quantity++;
      _syncUpsertItem(_items[idx]);
      notifyListeners();
    }
  }

  void decreaseQuantity(String productId, String? variantId) {
    final idx = _items.indexWhere(
      (i) => _key(i.productId, i.variantId) == _key(productId, variantId),
    );
    if (idx >= 0) {
      if (_items[idx].quantity <= 1) {
        final removed = _items.removeAt(idx);
        _syncDeleteItem(removed.productId, removed.variantId);
      } else {
        _items[idx].quantity--;
        _syncUpsertItem(_items[idx]);
      }
      notifyListeners();
    }
  }

  void removeItem(String productId, String? variantId) {
    _items.removeWhere(
      (i) => _key(i.productId, i.variantId) == _key(productId, variantId),
    );
    _syncDeleteItem(productId, variantId);
    notifyListeners();
  }

  void clearCart({bool syncToDb = true}) {
    _items.clear();
    if (syncToDb) {
      _syncClearCart();
    }
    notifyListeners();
  }
}
