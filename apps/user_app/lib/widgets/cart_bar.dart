import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/cart_provider.dart';
import '../theme/app_colors.dart';

/// Floating glass cart bar above bottom docks — shows stacked info, overlapping thumbnails & arrow
class CartBar extends StatelessWidget {
  final int itemCount;
  final List<CartItem> items;
  final VoidCallback onTap;

  const CartBar({
    super.key,
    required this.itemCount,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayItems = items.take(3).toList();
    final overlapWidth = displayItems.isEmpty
        ? 0.0
        : 32.0 + (displayItems.length - 1) * 16.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                // Primary maroon/burgundy with glass transparency
                color: const Color(0xFF6B1124).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.30),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Overlapping item thumbnails
                  if (displayItems.isNotEmpty) ...[
                    SizedBox(
                      width: overlapWidth,
                      height: 32,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: List.generate(displayItems.length, (i) {
                          final item = displayItems[i];
                          return Positioned(
                            left: i * 16.0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                    color: Colors.white, width: 1.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: item.imageUrl != null &&
                                        item.imageUrl!.isNotEmpty
                                    ? Image.network(
                                        item.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                          color: AppColors.surfaceVariant,
                                          child: const Icon(
                                              Icons.shopping_bag_outlined,
                                              size: 15,
                                              color: AppColors.textMuted),
                                        ),
                                      )
                                    : Container(
                                        color: AppColors.surfaceVariant,
                                        child: const Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 15,
                                            color: AppColors.textMuted),
                                      ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Stacked: View Cart & item count (no amount)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'View Cart',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        '$itemCount item${itemCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Arrow to go to cart page
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 250.ms, curve: Curves.easeOut);
  }
}
