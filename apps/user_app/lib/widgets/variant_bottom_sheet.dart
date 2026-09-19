import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/cart_provider.dart';

/// Blinkit/Zepto-style variant selector bottom sheet
/// Opens when ADD is tapped on a product with multiple variants
class VariantBottomSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final List<dynamic> variants;

  const VariantBottomSheet({
    super.key,
    required this.product,
    required this.variants,
  });

  @override
  State<VariantBottomSheet> createState() => _VariantBottomSheetState();
}

class _VariantBottomSheetState extends State<VariantBottomSheet> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final product = widget.product;
    final variants = widget.variants;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                // Product image
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: _buildProductImage(product),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] ?? '',
                        style: AppTheme.titleMd,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product['brand_name'] != null)
                        Text(
                          product['brand_name'],
                          style: AppTheme.captionSm,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 24),

          // Variants list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: variants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final v = variants[index] as Map<String, dynamic>;
                final isSelected = _selectedIndex == index;
                final sellingPrice = (v['selling_price'] ?? v['price'] ?? 0.0).toDouble();
                final mrp = (v['mrp'] ?? sellingPrice).toDouble();
                final label = v['unit_label'] ?? v['name'] ?? 'Pack ${index + 1}';
                final variantId = v['id']?.toString();
                final qtyInCart = cart.quantityOf(
                  (product['id'] ?? '').toString(),
                  variantId,
                );

                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.06)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.5 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Radio
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: 2,
                            ),
                            color: isSelected ? AppColors.primary : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.circle, size: 8, color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        // Label
                        Expanded(
                          child: Text(label, style: AppTheme.titleSm),
                        ),
                        // Price block
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${sellingPrice.toStringAsFixed(0)}',
                              style: AppTheme.titleSm.copyWith(color: AppColors.primary),
                            ),
                            if (mrp > sellingPrice)
                              Text(
                                '₹${mrp.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: AppColors.strikeMrp,
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: AppColors.strikeMrp,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // In-cart stepper or ADD
                        qtyInCart > 0
                            ? _MiniStepper(
                                qty: qtyInCart,
                                onIncrease: () => cart.increaseQuantity(
                                  (product['id'] ?? '').toString(),
                                  variantId,
                                ),
                                onDecrease: () => cart.decreaseQuantity(
                                  (product['id'] ?? '').toString(),
                                  variantId,
                                ),
                              )
                            : _MiniAddButton(
                                onTap: () {
                                  setState(() => _selectedIndex = index);
                                  cart.addItem(CartItem(
                                    productId: (product['id'] ?? '').toString(),
                                    variantId: variantId,
                                    productName: product['name'] ?? '',
                                    variantName: label.toString(),
                                    sellingPrice: sellingPrice,
                                    mrp: mrp,
                                    imageUrl: _getImageUrl(product),
                                  ));
                                },
                              ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom area
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ),
          ),
        ],
      ).animate().slideY(
            begin: 0.1,
            end: 0,
            duration: 300.ms,
            curve: Curves.easeOut,
          ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    final url = _getImageUrl(product);
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _fallbackBox(),
      );
    }
    return _fallbackBox();
  }

  Widget _fallbackBox() {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.surfaceVariant,
      child: const Center(child: Text('🛒', style: TextStyle(fontSize: 24))),
    );
  }

  String? _getImageUrl(Map<String, dynamic> product) {
    final images = product['images'];
    if (images is List && images.isNotEmpty) return images[0].toString();
    return product['image_url']?.toString();
  }
}

// ── Mini ADD button for variant rows ────────────────────────────────
class _MiniAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MiniAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Text(
          'ADD',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── Mini stepper for variant rows ────────────────────────────────────
class _MiniStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const _MiniStepper({
    required this.qty,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
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
              width: 26, height: 30,
              child: Icon(Icons.remove, size: 14, color: Colors.white),
            ),
          ),
          Text(
            '$qty',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
          ),
          GestureDetector(
            onTap: onIncrease,
            child: const SizedBox(
              width: 26, height: 30,
              child: Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
