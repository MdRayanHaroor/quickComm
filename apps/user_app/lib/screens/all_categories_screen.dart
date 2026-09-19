import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../utils/category_icon_helper.dart';
import '../widgets/typewriter_search_hint.dart';
import '../providers/cart_provider.dart';
import 'category_screen.dart';
import 'search_screen.dart';

class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  List<Map<String, dynamic>> _rootCategories = [];
  Map<String, List<Map<String, dynamic>>> _subcategoriesByParentId = {};
  Map<String, String> _categoryImageMap = {};
  List<String> _searchKeywords = [
    'Fresh Fruits',
    'Cold Drinks',
    'Milk',
    'Chips & Namkeen',
    'Atta & Flour',
    'Biscuits & Cookies',
    'Tea & Coffee',
    'Energy Drinks',
  ];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent && mounted && _rootCategories.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final categoriesFuture = SupabaseService.client
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      final productsFuture = SupabaseService.client
          .from('products')
          .select('id, name, category_id, image_url')
          .eq('is_available', true);

      final results = await Future.wait([categoriesFuture, productsFuture]);

      final allCategories = List<Map<String, dynamic>>.from(results[0]);
      final rawProducts = List<Map<String, dynamic>>.from(results[1]);

      // 1. Collect subcategory thumbnail images from products or categories
      final imageMap = <String, String>{};
      for (final cat in allCategories) {
        final catId = cat['id']?.toString() ?? '';
        final img = cat['image_url']?.toString() ?? '';
        if (catId.isNotEmpty && img.isNotEmpty) {
          imageMap[catId] = img;
        }
      }

      for (final p in rawProducts) {
        final catId = p['category_id']?.toString() ?? '';
        final img = p['image_url']?.toString() ?? '';
        if (catId.isNotEmpty && img.isNotEmpty && !imageMap.containsKey(catId)) {
          imageMap[catId] = img;
        }
      }

      // 2. Separate Root categories and Subcategories
      final roots = <Map<String, dynamic>>[];
      final subsMap = <String, List<Map<String, dynamic>>>{};

      for (final cat in allCategories) {
        final parentId = cat['parent_id']?.toString();
        if (parentId == null || parentId.isEmpty || parentId == '0') {
          roots.add(cat);
        } else {
          subsMap.putIfAbsent(parentId, () => []).add(cat);
        }
      }

      // 3. Sort root categories alphabetically (with "Others" placed at the end)
      roots.sort((a, b) {
        final nameA = (a['name'] ?? '').toString().trim().toLowerCase();
        final nameB = (b['name'] ?? '').toString().trim().toLowerCase();
        if (nameA == 'others' || nameA == 'other') return 1;
        if (nameB == 'others' || nameB == 'other') return -1;
        return nameA.compareTo(nameB);
      });

      // 4. Sort subcategories inside each root category by sort_order / alphabetically
      for (final entry in subsMap.entries) {
        entry.value.sort((a, b) {
          final sortA = (a['sort_order'] as num?) ?? 999;
          final sortB = (b['sort_order'] as num?) ?? 999;
          if (sortA != sortB) return sortA.compareTo(sortB);
          final nameA = (a['name'] ?? '').toString().trim().toLowerCase();
          final nameB = (b['name'] ?? '').toString().trim().toLowerCase();
          return nameA.compareTo(nameB);
        });
      }

      // 5. Collect typewriter keywords from all subcategories (and standalone categories)
      final subcategoryHints = <String>[];
      for (final subs in subsMap.values) {
        for (final sub in subs) {
          final name = sub['name']?.toString().trim() ?? '';
          if (name.isNotEmpty && !subcategoryHints.contains(name)) {
            subcategoryHints.add(name);
          }
        }
      }

      // Also add standalone root categories that do not have subcategories
      for (final root in roots) {
        final rootId = root['id']?.toString() ?? '';
        final subs = subsMap[rootId] ?? [];
        if (subs.isEmpty) {
          final name = root['name']?.toString().trim() ?? '';
          if (name.isNotEmpty && !subcategoryHints.contains(name)) {
            subcategoryHints.add(name);
          }
        }
      }

      if (mounted) {
        setState(() {
          _rootCategories = roots;
          _subcategoriesByParentId = subsMap;
          _categoryImageMap = imageMap;
          if (subcategoryHints.isNotEmpty) {
            _searchKeywords = subcategoryHints;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCategory(String catId, String catName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryScreen(
          categoryId: catId,
          categoryName: catName,
        ),
      ),
    );
  }

  static Color _getPastelColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('fruit') ||
        n.contains('veg') ||
        n.contains('fresh') ||
        n.contains('herb') ||
        n.contains('produce')) {
      return const Color(0xFFE8F5EF); // Soft mint green
    }
    if (n.contains('dairy') ||
        n.contains('milk') ||
        n.contains('curd') ||
        n.contains('cheese') ||
        n.contains('paneer') ||
        n.contains('butter')) {
      return const Color(0xFFE9F2F9); // Soft sky blue
    }
    if (n.contains('drink') ||
        n.contains('beverage') ||
        n.contains('juice') ||
        n.contains('soda') ||
        n.contains('water') ||
        n.contains('cola') ||
        n.contains('energy')) {
      return const Color(0xFFE6F4F7); // Soft aqua cyan
    }
    if (n.contains('snack') ||
        n.contains('munch') ||
        n.contains('chip') ||
        n.contains('namkeen') ||
        n.contains('biscuit') ||
        n.contains('cookie') ||
        n.contains('bakery') ||
        n.contains('bread')) {
      return const Color(0xFFFDF2E9); // Soft warm amber / peach
    }
    if (n.contains('sweet') ||
        n.contains('choc') ||
        n.contains('mithai') ||
        n.contains('candy') ||
        n.contains('ice cream')) {
      return const Color(0xFFFDF0F5); // Soft strawberry rose
    }
    if (n.contains('atta') ||
        n.contains('rice') ||
        n.contains('dal') ||
        n.contains('flour') ||
        n.contains('staple') ||
        n.contains('cereal')) {
      return const Color(0xFFF7F3E9); // Soft oat beige
    }
    if (n.contains('oil') ||
        n.contains('ghee') ||
        n.contains('masala') ||
        n.contains('spice') ||
        n.contains('sugar') ||
        n.contains('salt')) {
      return const Color(0xFFFEF8E7); // Soft butter yellow
    }
    if (n.contains('tea') || n.contains('coffee')) {
      return const Color(0xFFF6EFE9); // Soft warm mocha
    }
    if (n.contains('clean') ||
        n.contains('detergent') ||
        n.contains('kitchen') ||
        n.contains('tool') ||
        n.contains('freshener')) {
      return const Color(0xFFEDF3F9); // Soft crisp blue
    }
    if (n.contains('care') ||
        n.contains('skin') ||
        n.contains('hair') ||
        n.contains('bath') ||
        n.contains('oral') ||
        n.contains('hygiene')) {
      return const Color(0xFFF7F0F8); // Soft blush lavender
    }
    if (n.contains('meat') ||
        n.contains('fish') ||
        n.contains('chicken') ||
        n.contains('egg')) {
      return const Color(0xFFFDEEEF); // Soft coral blush
    }
    if (n.contains('baby') || n.contains('diaper')) {
      return const Color(0xFFEFF7FC); // Baby blue
    }
    return const Color(0xFFF2F4F7); // Neutral soft grey
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final hasCartItems = cart.itemCount > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFD),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _loadData(silent: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ── Top Search Bar (Blinkit Style) ─────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SearchScreen(
                                searchSuggestions: _searchKeywords,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.8),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: Colors.black87,
                                size: 21,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TypewriterSearchHint(
                                  items: _searchKeywords,
                                  prefix: 'Search "',
                                  suffix: '"',
                                  textStyle: const TextStyle(
                                    color: Color(0xFF555555),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 20,
                                color: AppColors.divider,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              const Icon(
                                Icons.mic_none_rounded,
                                color: Colors.black87,
                                size: 21,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Loading Skeleton or Category Sections ──────────
                  if (_isLoading)
                    SliverToBoxAdapter(child: _buildSkeleton())
                  else if (_rootCategories.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🏷️', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text(
                              'No categories available',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final parent = _rootCategories[index];
                          final parentId = parent['id']?.toString() ?? '';
                          final parentName =
                              parent['name']?.toString() ?? 'Category';

                          // Get subcategories for this root category
                          final subcats =
                              _subcategoriesByParentId[parentId] ?? [];

                          // If category has no subcategories, display the category itself as an option
                          final itemsToDisplay = subcats.isNotEmpty
                              ? subcats
                              : [parent];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── Section Header (Alphabetical Category) ─
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Text(
                                    parentName,
                                    style: const TextStyle(
                                      fontSize: 17.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1E1E1E),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),

                                // ── 4-Column Auto-Adjusting Rows ────
                                _buildSubcategoryRows(itemsToDisplay),
                              ],
                            ),
                          );
                        },
                        childCount: _rootCategories.length,
                      ),
                    ),

                  // Bottom spacing for floating dock and cart bar
                  SliverToBoxAdapter(
                    child: SizedBox(height: hasCartItems ? 150 : 100),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubcategoryRows(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Chunk into rows of 4 items so section height auto-adjusts to the exact rows needed
    final List<List<Map<String, dynamic>>> rows = [];
    for (int i = 0; i < items.length; i += 4) {
      rows.add(
          items.sublist(i, (i + 4 > items.length) ? items.length : i + 4));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows.map((rowItems) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(4, (col) {
                if (col < rowItems.length) {
                  final item = rowItems[col];
                  final itemId = item['id']?.toString() ?? '';
                  final itemName = item['name']?.toString() ?? '';
                  final pastelBg = _getPastelColor(itemName);
                  final imageUrl = _categoryImageMap[itemId];
                  final icon =
                      CategoryIconHelper.getIcon(itemName, selected: true);
                  final iconColor =
                      CategoryIconHelper.getCategoryColor(itemName);

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: col == 0 ? 0 : 4,
                        right: col == 3 ? 0 : 4,
                      ),
                      child: GestureDetector(
                        onTap: () => _openCategory(itemId, itemName),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Soft Pastel Rounded Image Tile
                            AspectRatio(
                              aspectRatio: 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: pastelBg,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Center(
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.contain,
                                          placeholder: (context, url) => Icon(
                                            icon,
                                            color: iconColor,
                                            size: 30,
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Icon(
                                            icon,
                                            color: iconColor,
                                            size: 30,
                                          ),
                                        )
                                      : Icon(
                                          icon,
                                          color: iconColor,
                                          size: 32,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Subcategory Label (Max 2 lines, centered)
                            Text(
                              itemName,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.2,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF222222),
                                height: 1.16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                } else {
                  // Transparent spacer to preserve uniform 4-column widths
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: col == 0 ? 0 : 4,
                        right: col == 3 ? 0 : 4,
                      ),
                      child: const SizedBox(),
                    ),
                  );
                }
              }),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int s = 0; s < 3; s++) ...[
            Container(
              width: 140,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 4,
                      right: i == 3 ? 0 : 4,
                    ),
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 48,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}
