import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/supabase_service.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/ad_banner.dart';
import '../widgets/product_card.dart';
import '../widgets/typewriter_search_hint.dart';
import '../widgets/delivery_location_sheet.dart';
import '../utils/category_icon_helper.dart';
import 'category_screen.dart';
import 'login_screen.dart';
import 'search_screen.dart';
import 'account_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  bool _isLoadingProducts = true;
  bool _isLoadingCategories = true;
  String? _selectedCategoryId; // null = 'All'

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().fetchUserProfile();
      }
    });
  }

  Map<String, List<Map<String, dynamic>>> get _productsByCategory {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final p in _products) {
      final productMap = p as Map<String, dynamic>;
      final catId = productMap['category_id']?.toString() ?? 'other';
      map.putIfAbsent(catId, () => []).add(productMap);
    }
    return map;
  }

  List<Map<String, dynamic>> get _displayCategories {
    final prodMap = _productsByCategory;
    // ONLY show categories that have at least 1 product
    final available = _categories
        .map((c) => c as Map<String, dynamic>)
        .where((cat) {
          final catId = cat['id']?.toString() ?? '';
          final prods = prodMap[catId];
          return prods != null && prods.isNotEmpty;
        })
        .toList()
      ..sort((a, b) {
        final nameA = (a['name'] ?? '').toString().trim().toLowerCase();
        final nameB = (b['name'] ?? '').toString().trim().toLowerCase();
        if (nameA == 'others' || nameA == 'other') return 1;
        if (nameB == 'others' || nameB == 'other') return -1;
        return nameA.compareTo(nameB);
      });

    if (_selectedCategoryId != null) {
      final filtered = available
          .where((cat) => cat['id']?.toString() == _selectedCategoryId)
          .toList();
      if (filtered.isNotEmpty) return filtered;
    }
    return available;
  }

  List<String> get _searchHintCombo {
    final catNames = _categories
        .map((c) => c['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final prodNames = _products
        .map((p) => p['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final combo = [...catNames, ...prodNames];
    if (combo.isNotEmpty) {
      combo.shuffle();
    }
    return combo;
  }

  Future<void> _fetchCategories() async {
    try {
      // Try the backend API first, fallback to Supabase direct
      final response = await SupabaseService.client
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('name');
      if (mounted) {
        final list = List<dynamic>.from(response)
          ..sort((a, b) {
            final nameA =
                (a is Map ? a['name'] : '')?.toString().trim().toLowerCase() ?? '';
            final nameB =
                (b is Map ? b['name'] : '')?.toString().trim().toLowerCase() ?? '';
            if (nameA == 'others' || nameA == 'other') return 1;
            if (nameB == 'others' || nameB == 'other') return -1;
            return nameA.compareTo(nameB);
          });
        setState(() {
          _categories = list;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _fetchProducts({String? categoryId}) async {
    setState(() => _isLoadingProducts = true);
    try {
      var query = SupabaseService.client
          .from('products')
          .select('*, product_variants(*)')
          .eq('is_available', true);

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      final response = await query.order('name').limit(40);

      if (mounted) {
        final list = List<dynamic>.from(response);
        list.shuffle(); // Random order combo discovery
        setState(() {
          _products = list;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await Future.wait([
              _fetchCategories(),
              _fetchProducts(),
              context.read<LocationProvider>().refreshStoreSettings(),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Top Section: Distance, Address Info & Profile (Scrolls Away) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Consumer<LocationProvider>(
                    builder: (context, locProv, _) {
                      return Row(
                        children: [
                          // GestureDetector(
                          //   onTap: () => DeliveryLocationSheet.show(context),
                          //   behavior: HitTestBehavior.opaque,
                          //   child: Container(
                          //     padding: const EdgeInsets.all(7),
                          //     decoration: BoxDecoration(
                          //       color: AppColors.primary.withValues(alpha: 0.12),
                          //       shape: BoxShape.circle,
                          //     ),
                          //     child: const Icon(Icons.location_on_rounded,
                          //         color: AppColors.primary, size: 20),
                          //   ),
                          // ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => DeliveryLocationSheet.show(context),
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!locProv.isStoreOpen) ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            locProv.closedReason ?? 'Closed for Now',
                                            style: AppTheme.captionSm.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.primary,
                                              letterSpacing: 0.3,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color: AppColors.primary.withValues(alpha: 0.22), width: 1.0),
                                          ),
                                          child: Text(
                                            'Currently unavailable',
                                            style: AppTheme.captionSm.copyWith(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          locProv.isLocationPermissionGranted
                                              ? 'Deliver in ${locProv.formattedEta}'
                                              : 'DELIVER TO',
                                          style: AppTheme.captionSm.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primary,
                                            letterSpacing: 0.4,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (locProv.isLocationPermissionGranted &&
                                            locProv.formattedDistance != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceVariant,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: AppColors.border, width: 1.0),
                                            ),
                                            child: Text(
                                              locProv.formattedDistance!,
                                              style: AppTheme.captionSm.copyWith(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 1),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          locProv.displayAddressLabel,
                                          style: AppTheme.titleSm.copyWith(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(Icons.keyboard_arrow_down_rounded,
                                          size: 16, color: AppColors.textPrimary),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Profile icon
                          GestureDetector(
                            onTap: () {
                              if (user == null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const AccountScreen()),
                                );
                              }
                            },
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: user != null
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.surfaceVariant,
                              child: user == null
                                  ? const Icon(
                                      Icons.person_outline_rounded,
                                      size: 20,
                                      color: AppColors.textPrimary,
                                    )
                                  : Builder(
                                      builder: (context) {
                                        final inits = context.watch<AuthProvider>().initials;
                                        final displayText = inits.isNotEmpty
                                            ? inits
                                            : (user.email?.substring(0, 1).toUpperCase() ?? '');
                                        return Text(
                                          displayText,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // ── Pinned Search Bar & Category Icon Slider ────────
              SliverAppBar(
                pinned: true,
                floating: false,
                primary: false,
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 1,
                shadowColor: AppColors.border,
                toolbarHeight: 0,
                collapsedHeight: 0,
                automaticallyImplyLeading: false,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(130),
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SearchBar(hintItems: _searchHintCombo),
                        _CategoryIconSlider(
                          categories: _categories,
                          selectedCategoryId: _selectedCategoryId,
                          onSelectCategory: (id) {
                            setState(() => _selectedCategoryId = id);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Clickable Ad Spot (replaces auto slider) ──────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: const AdBanner(),
              ).animate().fadeIn(duration: 400.ms),
            ),

            // ── Category-wise Products with "View all" ──────────
            if (_isLoadingProducts || _isLoadingCategories)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.pagePadding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 140,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 240,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: 4,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (_, __) => const SizedBox(
                                width: 156,
                                child: ProductCardSkeleton(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    childCount: 3,
                  ),
                ),
              )
            else if (_displayCategories.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🛒', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('No products available.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 15)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cat = _displayCategories[index];
                    final catId = cat['id']?.toString() ?? '';
                    final catName = cat['name']?.toString() ?? 'Category';
                    final categoryProducts = _productsByCategory[catId] ?? [];
                    final displayProducts = categoryProducts.take(8).toList();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Category Section Header ──────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.pagePadding),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    // Icon(
                                    //   CategoryIconHelper.getIcon(catName,
                                    //       selected: true),
                                    //   size: 22,
                                    //   color: CategoryIconHelper
                                    //       .getCategoryColor(catName),
                                    // ),
                                    // const SizedBox(width: 8),
                                    Text(
                                      catName,
                                      style: AppTheme.titleLg.copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CategoryScreen(
                                          categoryId: catId,
                                          categoryName: catName,
                                          initialProducts: categoryProducts,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'View all',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Horizontal Product Scroll ────────────
                          SizedBox(
                            height: 292,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.pagePadding),
                              itemCount: displayProducts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (context, i) {
                                final product = displayProducts[i];
                                final variants = (product['product_variants']
                                            as List?)
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
                  },
                  childCount: _displayCategories.length,
                ),
              ),

            // Bottom spacing for floating dock
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final List<String> hintItems;

  const _SearchBar({required this.hintItems});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchScreen(searchSuggestions: hintItems),
            ),
          );
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  color: Colors.black, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TypewriterSearchHint(
                  items: hintItems,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ── Category slider under search bar (Blinkit style with icons) ─────
class _CategoryIconSlider extends StatelessWidget {
  final List<dynamic> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelectCategory;

  const _CategoryIconSlider({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    final isAllSelected = selectedCategoryId == null;

    final sortedCategories = List<dynamic>.from(categories)
      ..sort((a, b) {
        final nameA =
            (a is Map ? a['name'] : '')?.toString().trim().toLowerCase() ?? '';
        final nameB =
            (b is Map ? b['name'] : '')?.toString().trim().toLowerCase() ?? '';
        if (nameA == 'others' || nameA == 'other') return 1;
        if (nameB == 'others' || nameB == 'other') return -1;
        return nameA.compareTo(nameB);
      });

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: sortedCategories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryIconItem(
              categoryName: 'all',
              label: 'All',
              isSelected: isAllSelected,
              onTap: () => onSelectCategory(null),
            );
          }
          final cat = sortedCategories[index - 1] as Map<String, dynamic>;
          final catId = cat['id']?.toString() ?? '';
          final catName = cat['name']?.toString() ?? '';
          final isSelected = selectedCategoryId == catId;

          return _CategoryIconItem(
            categoryName: catName,
            label: catName,
            isSelected: isSelected,
            onTap: () => onSelectCategory(catId),
          );
        },
      ),
    );
  }
}

class _CategoryIconItem extends StatelessWidget {
  final String categoryName;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryIconItem({
    required this.categoryName,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = CategoryIconHelper.getIcon(categoryName, selected: isSelected);
    final selectedColor = CategoryIconHelper.getCategoryColor(categoryName);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // No background container, larger icon size (28)
          AnimatedScale(
            scale: isSelected ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 180),
            child: Icon(
              icon,
              size: 28,
              color: isSelected ? selectedColor : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 62,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? Colors.black : const Color(0xFF4B5563),
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 20 : 0,
            height: 2.5,
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
