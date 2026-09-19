import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/cart_provider.dart';
import '../widgets/variant_bottom_sheet.dart';
import '../widgets/cart_bar.dart';
import 'cart_screen.dart';

/// Full product detail screen with image carousel, variant chips, and add-to-cart
class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final List<dynamic> variants;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.variants,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _pageController = PageController();
  int _selectedVariantIndex = 0;

  List<String> get _images {
    final imgs = widget.product['images'];
    if (imgs is List && imgs.isNotEmpty) {
      return imgs.map((e) => e.toString()).toList();
    }
    final single = widget.product['image_url']?.toString();
    if (single != null && single.isNotEmpty) return [single];
    return [];
  }

  Map<String, dynamic>? get _selectedVariant =>
      widget.variants.isNotEmpty
          ? widget.variants[_selectedVariantIndex] as Map<String, dynamic>
          : null;

  double get _sellingPrice {
    final v = _selectedVariant;
    if (v != null) {
      return (v['selling_price'] ?? v['price'] ?? widget.product['price'] ?? 0.0).toDouble();
    }
    return (widget.product['price'] ?? 0.0).toDouble();
  }

  double get _mrp {
    final v = _selectedVariant;
    if (v != null) return (v['mrp'] ?? _sellingPrice).toDouble();
    return _sellingPrice;
  }

  int get _discount => _mrp > _sellingPrice
      ? ((_mrp - _sellingPrice) / _mrp * 100).round()
      : 0;

  String get _variantName {
    final v = _selectedVariant;
    if (v == null) return '';
    if (v['variant_name'] != null &&
        v['variant_name'].toString().trim().isNotEmpty) {
      return v['variant_name'].toString().trim();
    }
    if (v['unit_value'] != null) {
      final type = v['unit_type']?.toString().trim() ?? '';
      return '${v['unit_value']} $type'.trim();
    }
    return (v['unit_label'] ?? v['name'] ?? '').toString();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final variants = widget.variants;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Consumer<CartProvider>(
          builder: (context, cart, _) {
            return CustomScrollView(
              slivers: [
                // ── Image Carousel App Bar ─────────────────────────
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  primary: false,
                  backgroundColor: AppColors.surface,
                  leading: IconButton(
                    icon: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 20, color: AppColors.textPrimary),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _images.isEmpty
                      ? Container(
                          color: AppColors.surfaceVariant,
                          child: Center(
                            child: Text(
                              '🛒',
                              style: const TextStyle(fontSize: 72),
                            ),
                          ),
                        )
                      : Stack(
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              itemCount: _images.length,
                              itemBuilder: (_, i) => CachedNetworkImage(
                                imageUrl: _images[i],
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: AppColors.surfaceVariant),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.surfaceVariant,
                                  child: const Center(
                                      child: Text('🛒',
                                          style: TextStyle(fontSize: 48))),
                                ),
                              ),
                            ),
                            if (_images.length > 1)
                              Positioned(
                                bottom: 16,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: SmoothPageIndicator(
                                    controller: _pageController,
                                    count: _images.length,
                                    effect: ExpandingDotsEffect(
                                      activeDotColor: AppColors.primary,
                                      dotColor: Colors.white.withValues(alpha: 0.6),
                                      dotHeight: 6,
                                      dotWidth: 6,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),

              // ── Product Info ────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(AppTheme.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand
                      if (product['brand_name'] != null)
                        Text(
                          product['brand_name'].toString().toUpperCase(),
                          style: AppTheme.captionSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),

                      const SizedBox(height: 4),
                      Text(product['name'] ?? '', style: AppTheme.titleLg),

                      const SizedBox(height: 8),

                      // Prices
                      Row(
                        children: [
                          Text(
                            '₹${_sellingPrice.toStringAsFixed(0)}',
                            style: AppTheme.titleLg.copyWith(
                              color: AppColors.primary,
                              fontSize: 24,
                            ),
                          ),
                          if (_mrp > _sellingPrice) ...[
                            const SizedBox(width: 10),
                            Text(
                              'MRP ₹${_mrp.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: AppColors.strikeMrp,
                                fontSize: 15,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: AppColors.strikeMrp,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusFull),
                              ),
                              child: Text(
                                '$_discount% OFF',
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 4),
                      Text(
                        'Inclusive of all taxes',
                        style: AppTheme.captionSm,
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms),
              ),

              // ── Variant Selector ────────────────────────────────
              if (variants.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    color: AppColors.surface,
                    padding: const EdgeInsets.all(AppTheme.pagePadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Select Variant', style: AppTheme.titleSm),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(variants.length, (i) {
                            final v = variants[i] as Map<String, dynamic>;
                            final isSelected = _selectedVariantIndex == i;
                            final label = (v['variant_name'] != null &&
                                    v['variant_name']
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                ? v['variant_name'].toString().trim()
                                : (v['unit_value'] != null
                                    ? '${v['unit_value']} ${v['unit_type'] ?? ''}'
                                        .trim()
                                    : (v['unit_label'] ??
                                        v['name'] ??
                                        'Pack ${i + 1}'));
                            final price = (v['selling_price'] ?? v['price'] ?? 0.0).toDouble();

                            return GestureDetector(
                              onTap: () => setState(() => _selectedVariantIndex = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.06)
                                      : AppColors.surfaceVariant,
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMd),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: isSelected ? 1.5 : 0.8,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      label.toString(),
                                      style: AppTheme.titleSm.copyWith(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '₹${price.toStringAsFixed(0)}',
                                      style: AppTheme.captionSm.copyWith(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
                ),

              // ── Description ─────────────────────────────────────
              if (product['description'] != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    color: AppColors.surface,
                    padding: const EdgeInsets.all(AppTheme.pagePadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('About this product', style: AppTheme.titleSm),
                        const SizedBox(height: 8),
                        Text(
                          product['description'].toString(),
                          style: AppTheme.bodyMd,
                        ),
                      ],
                    ),
                  ),
                ),

              // Space for bottom bar
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    ),

      // ── Bottom Add to Cart bar with Floating CartBar ──────────
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cart, _) {
          final variantId = _selectedVariant?['id']?.toString();
          final productId = (widget.product['id'] ?? '').toString();
          final qty = cart.quantityOf(productId, variantId);
          final hasCartItems = cart.itemCount > 0;

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Floating View Cart dock (same as home screen)
                  if (hasCartItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Center(
                        child: CartBar(
                          itemCount: cart.itemCount,
                          items: cart.items,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CartScreen(),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Bottom action: Add to Cart button or Quantity Stepper
                  qty == 0
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (widget.variants.length > 1) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => VariantBottomSheet(
                                    product: widget.product,
                                    variants: widget.variants,
                                  ),
                                );
                              } else {
                                cart.addItem(CartItem(
                                  productId: productId,
                                  variantId: variantId,
                                  productName: widget.product['name'] ?? '',
                                  variantName: _variantName,
                                  sellingPrice: _sellingPrice,
                                  mrp: _mrp,
                                  imageUrl: _images.isNotEmpty ? _images[0] : null,
                                ));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Add to Cart',
                                style: TextStyle(fontSize: 16)),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMd),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    GestureDetector(
                                      onTap: () => cart.decreaseQuantity(
                                          productId, variantId),
                                      child: const Icon(Icons.remove,
                                          color: Colors.white, size: 20),
                                    ),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      child: Text(
                                        '$qty in cart',
                                        key: ValueKey(qty),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => cart.increaseQuantity(
                                          productId, variantId),
                                      child: const Icon(Icons.add,
                                          color: Colors.white, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
