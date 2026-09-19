import 'package:flutter/material.dart';

/// Represents a product variant that can be added to the cart
class CartItem {
  final String productId;
  final String? variantId;
  final String productName;
  final String variantName;   // e.g. "500ml", "1kg", "Standard"
  final double sellingPrice;  // price customer pays
  final double mrp;           // original MRP (for strikethrough)
  final String? imageUrl;
  int quantity;

  CartItem({
    required this.productId,
    this.variantId,
    required this.productName,
    required this.variantName,
    required this.sellingPrice,
    required this.mrp,
    this.imageUrl,
    this.quantity = 1,
  });

  double get lineTotal => sellingPrice * quantity;
  double get lineSavings => (mrp - sellingPrice) * quantity;

  String get displayName => variantName.isNotEmpty ? '$productName — $variantName' : productName;
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);

  double get totalSavings => _items.fold(0, (sum, item) => sum + item.lineSavings);

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

  void addItem(CartItem item) {
    final idx = _items.indexWhere(
      (i) => _key(i.productId, i.variantId) == _key(item.productId, item.variantId),
    );
    if (idx >= 0) {
      _items[idx].quantity++;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void increaseQuantity(String productId, String? variantId) {
    final idx = _items.indexWhere(
      (i) => _key(i.productId, i.variantId) == _key(productId, variantId),
    );
    if (idx >= 0) {
      _items[idx].quantity++;
      notifyListeners();
    }
  }

  void decreaseQuantity(String productId, String? variantId) {
    final idx = _items.indexWhere(
      (i) => _key(i.productId, i.variantId) == _key(productId, variantId),
    );
    if (idx >= 0) {
      if (_items[idx].quantity <= 1) {
        _items.removeAt(idx);
      } else {
        _items[idx].quantity--;
      }
      notifyListeners();
    }
  }

  void removeItem(String productId, String? variantId) {
    _items.removeWhere(
      (i) => _key(i.productId, i.variantId) == _key(productId, variantId),
    );
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
