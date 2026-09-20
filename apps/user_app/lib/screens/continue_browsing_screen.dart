import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/recently_viewed_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cart_bar.dart';
import '../widgets/product_card.dart';
import 'cart_screen.dart';

enum BrowsingSortOrder {
  recentlyViewed,
  mostViewed,
}

class ContinueBrowsingScreen extends StatefulWidget {
  const ContinueBrowsingScreen({super.key});

  @override
  State<ContinueBrowsingScreen> createState() => _ContinueBrowsingScreenState();
}

class _ContinueBrowsingScreenState extends State<ContinueBrowsingScreen> {
  BrowsingSortOrder _sortOrder = BrowsingSortOrder.recentlyViewed;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Clear Browsing History?'),
        content: const Text(
          'This will remove all recently viewed products from your continue browsing list.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<RecentlyViewedProvider>().clearAll();
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentProv = context.watch<RecentlyViewedProvider>();
    final cart = context.watch<CartProvider>();
    final hasCartItems = cart.itemCount > 0;

    final rawItems = _sortOrder == BrowsingSortOrder.recentlyViewed
        ? recentProv.itemsByRecency
        : recentProv.itemsByFrequency;

    final filteredItems = _searchQuery.isEmpty
        ? rawItems
        : rawItems.where((item) {
            final name = (item.product['name'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery);
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Continue Browsing',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${recentProv.count} product${recentProv.count == 1 ? '' : 's'} viewed',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (recentProv.hasItems)
            TextButton.icon(
              onPressed: _confirmClearAll,
              icon: const Icon(Icons.delete_sweep_rounded,
                  size: 18, color: AppColors.error),
              label: const Text(
                'Clear',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Search & Filter Controls ─────────────────────────
              if (recentProv.hasItems)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(
                              fontSize: 13.5, color: Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Search viewed products...',
                            hintStyle: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 18, color: AppColors.textMuted),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Sort Filter Chips
                      Row(
                        children: [
                          _SortFilterChip(
                            label: 'Recently Viewed',
                            icon: Icons.history_rounded,
                            isSelected:
                                _sortOrder == BrowsingSortOrder.recentlyViewed,
                            onTap: () {
                              setState(() => _sortOrder =
                                  BrowsingSortOrder.recentlyViewed);
                            },
                          ),
                          const SizedBox(width: 8),
                          _SortFilterChip(
                            label: 'Most Viewed',
                            icon: Icons.trending_up_rounded,
                            isSelected:
                                _sortOrder == BrowsingSortOrder.mostViewed,
                            onTap: () {
                              setState(() => _sortOrder =
                                  BrowsingSortOrder.mostViewed);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // ── Products Grid or Empty State ─────────────────────
              Expanded(
                child: !recentProv.hasItems
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.history_toggle_off_rounded,
                                  size: 44,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'No Recently Viewed Products',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Products you explore in the catalog will appear here so you can easily jump back.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 22),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.shopping_bag_outlined,
                                    size: 18),
                                label: const Text('Start Browsing'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredItems.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off_rounded,
                                      size: 48, color: AppColors.textMuted),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No viewed items match "$_searchQuery"',
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: () => _searchController.clear(),
                                    child: const Text('Clear search'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: EdgeInsets.fromLTRB(
                              AppTheme.pagePadding,
                              12,
                              AppTheme.pagePadding,
                              hasCartItems ? 120 : 30,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.54,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 14,
                            ),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, i) {
                              final item = filteredItems[i];
                              return _BrowsingProductCard(
                                key: ValueKey('browsing_${item.productId}'),
                                item: item,
                                onRemove: () {
                                  recentProv.removeItem(item.productId);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),

          // ── Bottom Floating Cart Bar ──────────────────────────────
          if (hasCartItems)
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Center(
                child: CartBar(
                  itemCount: cart.itemCount,
                  items: cart.items,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sort filter chip
class _SortFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortFilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Product card wrapper in Continue Browsing page with a top-right '✕' remove button
/// and view counter badge
class _BrowsingProductCard extends StatelessWidget {
  final RecentlyViewedItem item;
  final VoidCallback onRemove;

  const _BrowsingProductCard({
    super.key,
    required this.item,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The standard ProductCard with stepper and variant support
        Positioned.fill(
          child: ProductCard(
            product: item.product,
            variants: item.variants,
          ),
        ),

        // View Counter Pill (e.g. "3x viewed")
        if (item.viewCount > 1)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.remove_red_eye_outlined,
                      size: 10.5, color: Colors.white),
                  const SizedBox(width: 3.5),
                  Text(
                    '${item.viewCount}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // '✕' Button to remove from continue browsing list
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.12),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 15,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
