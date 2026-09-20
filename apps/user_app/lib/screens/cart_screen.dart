import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../services/supabase_service.dart';
import '../services/delivery_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import 'category_screen.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Cart${cart.itemCount > 0 ? ' (${cart.itemCount})' : ''}',
        ),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, cart),
              child: const Text('Clear', style: TextStyle(color: AppColors.error)),
            ),
        ],
      ),
      body: cart.items.isEmpty ? _EmptyCart() : _CartBody(cart: cart),
    );
  }

  void _confirmClear(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text('All items will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🛒', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text('Your cart is empty', style: AppTheme.titleMd),
          const SizedBox(height: 8),
          Text('Add items to start shopping', style: AppTheme.bodyMd),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Browse Products'),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

class _CategoryRecommendation {
  final String categoryId;
  final String categoryName;
  final List<Map<String, dynamic>> products;

  const _CategoryRecommendation({
    required this.categoryId,
    required this.categoryName,
    required this.products,
  });
}

class _CartBody extends StatefulWidget {
  final CartProvider cart;
  const _CartBody({required this.cart});

  @override
  State<_CartBody> createState() => _CartBodyState();
}

class _CartBodyState extends State<_CartBody> {
  DeliveryEstimate _estimate = const DeliveryEstimate(minutes: 12);
  double? _deliveryFee;
  List<_CategoryRecommendation> _categoryRecommendations = [];
  String _lastProductIdsKey = '';

  @override
  void initState() {
    super.initState();
    _loadDeliveryDetails();
    _loadRecommendations();
  }

  Future<void> _loadDeliveryDetails() async {
    final estimate = await DeliveryService.getDeliveryEstimate();
    final fee = await DeliveryService.getEffectiveDeliveryFee(widget.cart.subtotal);
    if (mounted) {
      setState(() {
        _estimate = estimate;
        _deliveryFee = fee;
      });
    }
  }

  String _buildProductIdsKey(List<CartItem> items) {
    final ids = items.map((i) => i.productId).toList()..sort();
    return ids.join(',');
  }

  Future<void> _loadRecommendations() async {
    final cart = widget.cart;
    final cartProductIds = cart.items.map((i) => i.productId).toSet();
    if (cartProductIds.isEmpty) {
      if (mounted) setState(() => _categoryRecommendations = []);
      return;
    }

    _lastProductIdsKey = _buildProductIdsKey(cart.items);

    try {
      final categoryIdsSet = <String>{};
      final missingProductIds = <String>[];

      for (final item in cart.items) {
        if (item.categoryId != null && item.categoryId!.isNotEmpty) {
          categoryIdsSet.add(item.categoryId!);
        } else {
          missingProductIds.add(item.productId);
        }
      }

      // If categoryId was missing for any item, query product records
      if (missingProductIds.isNotEmpty) {
        final missingRes = await SupabaseService.client
            .from('products')
            .select('id, category_id')
            .inFilter('id', missingProductIds.map((id) => int.tryParse(id) ?? id).toList());

        for (final row in missingRes) {
          final cId = row['category_id']?.toString();
          if (cId != null && cId.isNotEmpty) {
            categoryIdsSet.add(cId);
          }
        }
      }

      if (categoryIdsSet.isEmpty) {
        if (mounted) {
          setState(() {
            _categoryRecommendations = [];
          });
        }
        return;
      }

      // Fetch category names
      final categoriesRes = await SupabaseService.client
          .from('categories')
          .select('id, name')
          .inFilter('id', categoryIdsSet.map((id) => int.tryParse(id) ?? id).toList());

      final categoryNameMap = <String, String>{};
      for (final cat in categoriesRes) {
        categoryNameMap[cat['id'].toString()] =
            cat['name']?.toString() ?? 'Category';
      }

      // Fetch active products in these categories
      final productsRes = await SupabaseService.client
          .from('products')
          .select('*, product_variants(*)')
          .inFilter('category_id', categoryIdsSet.map((id) => int.tryParse(id) ?? id).toList())
          .eq('is_available', true)
          .limit(40);

      final List<Map<String, dynamic>> allProds =
          List<Map<String, dynamic>>.from(productsRes);

      final List<_CategoryRecommendation> results = [];

      for (final catId in categoryIdsSet) {
        final catName = categoryNameMap[catId] ?? 'Category';
        // Filter out any product that is already in the cart
        final catProds = allProds.where((p) {
          final pCatId = p['category_id']?.toString();
          final pId = p['id']?.toString();
          return pCatId == catId && !cartProductIds.contains(pId);
        }).toList();

        if (catProds.isNotEmpty) {
          results.add(_CategoryRecommendation(
            categoryId: catId,
            categoryName: catName,
            products: catProds,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _categoryRecommendations = results;
        });
      }
    } catch (e) {
      debugPrint('Error loading cart recommendations: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _CartBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cart.subtotal != widget.cart.subtotal) {
      DeliveryService.getEffectiveDeliveryFee(widget.cart.subtotal).then((fee) {
        if (mounted) setState(() => _deliveryFee = fee);
      });
    }

    final newKey = _buildProductIdsKey(widget.cart.items);
    if (_lastProductIdsKey != newKey) {
      _loadRecommendations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    final locProv = Provider.of<LocationProvider>(context);
    final feeToAdd = _deliveryFee ?? 0.0;
    final grandTotal = cart.subtotal + feeToAdd;

    final String deliveryText;
    if (locProv.isLocationPermissionGranted && locProv.formattedDistance != null) {
      deliveryText = 'Delivery in ~${locProv.etaMinutes} mins (${locProv.formattedDistance}) ⚡';
    } else if (_estimate.isDynamic && _estimate.formattedDistance != null) {
      deliveryText = _estimate.displayText;
    } else {
      deliveryText = 'Delivery in ~12 minutes ⚡';
    }

    return Column(
      children: [
        // ── Scrollable Cart Content ──────────────────────────────
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // 1. Delivery estimate strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.successLight,
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        deliveryText,
                        style: AppTheme.labelMd.copyWith(color: AppColors.success),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Cart items container
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items in Cart (${cart.itemCount})',
                      style: AppTheme.titleSm.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return _CartItemRow(item: item, cart: cart);
                      },
                    ),
                  ],
                ),
              ),

              // 3. Bill Details
              _BillCard(cart: cart, deliveryFee: _deliveryFee),

              // 4. "You might also like" recommendations
              if (_categoryRecommendations.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.pagePadding),
                  child: Row(
                    children: [
                      // const Icon(Icons.auto_awesome_rounded,
                      //     color: AppColors.primary, size: 20),
                      // const SizedBox(width: 8),
                      Text(
                        'You might also like',
                        style: AppTheme.titleLg.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // One recommendation row per category present in the cart
                for (final catRec in _categoryRecommendations)
                  _CartCategoryRecommendationRow(
                    categoryName: catRec.categoryName,
                    categoryId: catRec.categoryId,
                    products: catRec.products,
                  ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),

        // ── Checkout button ────────────────────────────────────
        Consumer<LocationProvider>(
          builder: (context, locProv, _) {
            final isClosed = !locProv.isStoreOpen;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isClosed)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDA4AF)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFFBE123C), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${locProv.closedReason ?? "Closed for Now"} • Currently unavailable for orders',
                                style: const TextStyle(
                                  color: Color(0xFFBE123C),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isClosed
                            ? null
                            : () {
                                final user = SupabaseService.client.auth.currentUser;
                                if (user == null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const LoginScreen(returnToCheckout: true)),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            CheckoutScreen(deliveryFee: _deliveryFee)),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: isClosed ? AppColors.textMuted : AppColors.primary,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isClosed ? 'Store Currently Unavailable' : 'Proceed to Checkout',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            if (!isClosed) ...[
                              const SizedBox(width: 8),
                              Text(
                                '₹${grandTotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Category recommendation horizontal row in CartScreen
class _CartCategoryRecommendationRow extends StatelessWidget {
  final String categoryName;
  final String categoryId;
  final List<Map<String, dynamic>> products;

  const _CartCategoryRecommendationRow({
    required this.categoryName,
    required this.categoryId,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subheader: Category Name + "View all >"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  categoryName,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryScreen(
                          categoryId: categoryId,
                          categoryName: categoryName,
                          initialProducts: products,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View all',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal scroll of ProductCard
          SizedBox(
            height: 292,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final product = products[i];
                final variants = (product['product_variants'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
                return SizedBox(
                  width: 168,
                  child: ProductCard(
                    product: product,
                    variants: variants,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final CartProvider cart;

  const _CartItemRow({required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: item.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _imgFallback(),
                  )
                : _imgFallback(),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AppTheme.titleSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.variantName.isNotEmpty)
                  Text(item.variantName, style: AppTheme.captionSm),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${item.sellingPrice.toStringAsFixed(0)}',
                      style: AppTheme.titleSm.copyWith(
                          color: AppColors.primary, fontSize: 14),
                    ),
                    if (item.mrp > item.sellingPrice) ...[
                      const SizedBox(width: 6),
                      Text(
                        '₹${item.mrp.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppColors.strikeMrp,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.strikeMrp,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Stepper
          _CartStepper(
            qty: item.quantity,
            onIncrease: () =>
                cart.increaseQuantity(item.productId, item.variantId),
            onDecrease: () =>
                cart.decreaseQuantity(item.productId, item.variantId),
          ),
        ],
      ),
    );
  }

  Widget _imgFallback() {
    return Container(
      width: 60,
      height: 60,
      color: AppColors.surfaceVariant,
      child: const Center(child: Text('🛒', style: TextStyle(fontSize: 24))),
    );
  }
}

class _CartStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const _CartStepper(
      {required this.qty,
      required this.onIncrease,
      required this.onDecrease});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrease,
            child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.remove, size: 14, color: Colors.white)),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              '$qty',
              key: ValueKey(qty),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: onIncrease,
            child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.add, size: 14, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final CartProvider cart;
  final double? deliveryFee;

  const _BillCard({required this.cart, required this.deliveryFee});

  @override
  Widget build(BuildContext context) {
    final feeToAdd = deliveryFee ?? 0.0;
    final grandTotal = cart.subtotal + feeToAdd;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bill Details', style: AppTheme.titleSm),
          const SizedBox(height: 12),
          _BillRow('Item Total', '₹${cart.subtotal.toStringAsFixed(0)}'),
          if (deliveryFee != null)
            _BillRow(
              'Delivery Fee',
              deliveryFee == 0
                  ? 'FREE'
                  : '₹${deliveryFee!.toStringAsFixed(0)}',
              valueColor: deliveryFee == 0 ? AppColors.success : null,
            ),
          if (cart.totalSavings > 0)
            _BillRow(
              'Total Savings',
              '-₹${cart.totalSavings.toStringAsFixed(0)}',
              valueColor: AppColors.success,
            ),
          const Divider(height: 20),
          _BillRow(
            'To Pay',
            '₹${grandTotal.toStringAsFixed(0)}',
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _BillRow(this.label, this.value,
      {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold ? AppTheme.titleSm : AppTheme.bodyMd,
          ),
          Text(
            value,
            style: (bold ? AppTheme.titleSm : AppTheme.titleSm.copyWith(
              fontWeight: FontWeight.w600,
            )).copyWith(
              color: valueColor,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
