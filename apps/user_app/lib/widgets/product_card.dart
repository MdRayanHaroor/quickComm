import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../screens/product_detail_screen.dart';
import '../services/supabase_service.dart';
import 'variant_bottom_sheet.dart';

/// Blinkit/Zepto-style product card with inline +/- stepper and variant support
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final List<dynamic> variants;

  const ProductCard({
    super.key,
    required this.product,
    this.variants = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Determine the display variant (first/cheapest)
    final displayVariant = variants.isNotEmpty ? variants[0] as Map<String, dynamic> : null;
    final productId = (product['id'] ?? '').toString();

    final sellingPrice = displayVariant != null
        ? (displayVariant['selling_price'] ?? displayVariant['price'] ?? product['price'] ?? 0.0).toDouble()
        : (product['price'] ?? 0.0).toDouble();
    final mrp = displayVariant != null
        ? (displayVariant['mrp'] ?? sellingPrice).toDouble()
        : sellingPrice;
    final imageUrl = _getImageUrl(product);
    final variantName = displayVariant != null
        ? (displayVariant['variant_name'] ??
                displayVariant['unit_label'] ??
                displayVariant['name'] ??
                '')
            .toString()
            .trim()
        : '';

    String unitLabel = '';
    if (displayVariant != null) {
      if (variantName.isNotEmpty) {
        unitLabel = variantName;
      } else if (displayVariant['unit_value'] != null &&
          displayVariant['unit_type'] != null) {
        unitLabel =
            '${displayVariant['unit_value']} ${displayVariant['unit_type']}';
      }
    }
    if (unitLabel.isEmpty) {
      final size = product['size']?.toString().trim() ?? '';
      final unit = product['unit']?.toString().trim() ?? '';
      unitLabel = size.isNotEmpty ? size : (unit.isNotEmpty ? unit : '1 unit');
    }

    final discount = mrp > sellingPrice ? ((mrp - sellingPrice) / mrp * 100).round() : 0;

    final stockVal = displayVariant != null
        ? (displayVariant['stock_quantity'] ?? product['stock_quantity'] ?? 0)
        : (product['stock_quantity'] ?? 0);
    final stockQuantity = (stockVal is num)
        ? stockVal.toInt()
        : (int.tryParse(stockVal.toString()) ?? 0);

    final locProv = context.watch<LocationProvider>();
    final etaText = locProv.formattedEta;

    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final qty = variants.isNotEmpty && displayVariant != null
            ? cart.quantityOf(productId, displayVariant['id']?.toString())
            : cart.quantityOf(productId, null);

        return GestureDetector(
          onTap: () => _navigateToDetail(context),
          child: Container(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image Container (Box with border & light background) ──
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFE5E7EB), width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image area (Full width and height)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        child: SizedBox(
                          height: 125,
                          width: double.infinity,
                          child: (imageUrl != null && imageUrl.isNotEmpty)
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          _imageFallback(),
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: AppColors.surfaceVariant,
                                      child: const Center(
                                        child: Icon(Icons.image_outlined,
                                            color: AppColors.textMuted,
                                            size: 28),
                                      ),
                                    );
                                  },
                                )
                              : _imageFallback(),
                        ),
                      ),

                      // Unit & ADD button row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 8, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                unitLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF374151),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            qty == 0
                                ? _AddButton(
                                    onTap: () => _handleAdd(
                                        context,
                                        cart,
                                        displayVariant,
                                        sellingPrice,
                                        mrp,
                                        imageUrl,
                                        unitLabel),
                                  )
                                : _QuantityStepper(
                                    quantity: qty,
                                    onIncrease: () => _handleIncrease(
                                        cart, displayVariant, productId),
                                    onDecrease: () => _handleDecrease(
                                        cart, displayVariant, productId),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Info Below Image Box ───────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 2, right: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Price & MRP Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹${sellingPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (mrp > sellingPrice) ...[
                            const SizedBox(width: 5),
                            Text(
                              '₹${mrp.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9CA3AF),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // 2. Off discount info (full width, increased text size)
                      if (mrp > sellingPrice && discount > 0) ...[
                        const SizedBox(height: 2),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            '$discount% OFF on MRP',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],

                      // 3. Product Name (increased text size matching price text size)
                      const SizedBox(height: 4),
                      Text(
                        product['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                          height: 1.25,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 4. Delivery time & Stock left info
                      Row(
                        children: [
                          Icon(
                            Icons.watch_later_outlined,
                            size: 13,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            etaText.toLowerCase(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (stockQuantity > 0 && stockQuantity < 10) ...[
                            const Spacer(),
                            _StockProgressBarIndicator(stock: stockQuantity),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Text(
          _emoji(product['name'] ?? ''),
          style: const TextStyle(fontSize: 40),
        ),
      ),
    );
  }

  String? _getImageUrl(Map<String, dynamic> product) {
    final single = product['image_url']?.toString().trim();
    if (single != null && single.isNotEmpty) {
      return _formatUrl(single);
    }
    final images = product['images'];
    if (images is List && images.isNotEmpty) {
      final first = images[0]?.toString().trim();
      if (first != null && first.isNotEmpty) {
        return _formatUrl(first);
      }
    }
    return null;
  }

  String _formatUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('blob:')) return url;
    try {
      final clean = url.replaceFirst('product-images/', '');
      return SupabaseService.client.storage
          .from('product-images')
          .getPublicUrl(clean);
    } catch (_) {
      return url;
    }
  }

  String _emoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('milk')) return '🥛';
    if (n.contains('bread')) return '🍞';
    if (n.contains('egg')) return '🥚';
    if (n.contains('rice')) return '🍚';
    if (n.contains('butter')) return '🧈';
    if (n.contains('oil')) return '🫙';
    if (n.contains('juice') || n.contains('drink')) return '🧃';
    if (n.contains('apple') || n.contains('fruit')) return '🍎';
    if (n.contains('vegetable') || n.contains('carrot')) return '🥕';
    if (n.contains('chicken')) return '🍗';
    if (n.contains('cookie') || n.contains('biscuit')) return '🍪';
    if (n.contains('chip') || n.contains('snack')) return '🍿';
    return '🛒';
  }

  void _handleAdd(
    BuildContext context,
    CartProvider cart,
    Map<String, dynamic>? displayVariant,
    double sellingPrice,
    double mrp,
    String? imageUrl,
    String variantName,
  ) {
    if (variants.length > 1) {
      // Show variant selector bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => VariantBottomSheet(
          product: product,
          variants: variants,
        ),
      );
    } else {
      // Single variant or no variants — add directly
      final variantId = displayVariant != null ? displayVariant['id']?.toString() : null;
      cart.addItem(CartItem(
        productId: (product['id'] ?? '').toString(),
        variantId: variantId,
        productName: product['name'] ?? '',
        variantName: variantName,
        sellingPrice: sellingPrice,
        mrp: mrp,
        imageUrl: imageUrl,
      ));
    }
  }

  void _handleIncrease(CartProvider cart, Map<String, dynamic>? displayVariant, String productId) {
    cart.increaseQuantity(productId, displayVariant?['id']?.toString());
  }

  void _handleDecrease(CartProvider cart, Map<String, dynamic>? displayVariant, String productId) {
    cart.decreaseQuantity(productId, displayVariant?['id']?.toString());
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          variants: variants,
        ),
      ),
    );
  }
}

// ── ADD Button ──────────────────────────────────────────────────────
class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFF16A34A), width: 1.4),
        ),
        child: const Center(
          child: Text(
            'ADD',
            style: TextStyle(
              color: Color(0xFF16A34A),
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    ).animate().scale(duration: 120.ms, curve: Curves.easeOut);
  }
}

// ── Quantity Stepper ────────────────────────────────────────────────
class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const _QuantityStepper({
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(icon: Icons.remove, onTap: onDecrease),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$quantity',
              key: ValueKey(quantity),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          _StepperButton(icon: Icons.add, onTap: onIncrease),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 30,
        alignment: Alignment.center,
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}

/// Mini progress bar indicator showing remaining stock when < 10
class _StockProgressBarIndicator extends StatelessWidget {
  final int stock;

  const _StockProgressBarIndicator({required this.stock});

  @override
  Widget build(BuildContext context) {
    final fillRatio = (stock / 10.0).clamp(0.1, 1.0);
    const Color barColor = Color(0xFF757575);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Mini Progress Bar Track with increased thickness
        Container(
          width: 24,
          height: 6.5,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(3.5),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fillRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(3.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4.5),
        Text(
          '$stock left',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: barColor,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

