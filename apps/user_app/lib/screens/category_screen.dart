import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/typewriter_search_hint.dart';
import '../widgets/cart_bar.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';

class CategoryScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final List<dynamic>? initialProducts;

  const CategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.initialProducts,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<dynamic> _products = [];
  List<Map<String, dynamic>> _subcategories = [];
  String? _selectedSubcategoryId; // null = 'All'
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialProducts != null && widget.initialProducts!.isNotEmpty) {
      _products = List<dynamic>.from(widget.initialProducts!);
      _isLoading = false;
    }
    _fetchProducts();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final catIdInt = int.tryParse(widget.categoryId);

      // 1. Fetch any active subcategories for this category
      final subcatsResponse = await SupabaseService.client
          .from('categories')
          .select('id, name, parent_id, sort_order')
          .eq('is_active', true)
          .eq('parent_id', catIdInt ?? widget.categoryId)
          .order('sort_order');

      final subcats = List<Map<String, dynamic>>.from(subcatsResponse);

      // Collect all relevant category IDs: the category itself + any subcategories
      final List<dynamic> categoryIds = [
        catIdInt ?? widget.categoryId,
        ...subcats.map((c) => int.tryParse(c['id'].toString()) ?? c['id']),
      ];

      // 2. Fetch products belonging to any of these category IDs
      final response = await SupabaseService.client
          .from('products')
          .select('*, product_variants(*)')
          .eq('is_available', true)
          .inFilter('category_id', categoryIds)
          .order('name')
          .limit(100);

      if (mounted) {
        setState(() {
          _subcategories = subcats;
          _products = List<dynamic>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading category products: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredProducts {
    var list = _products;
    if (_selectedSubcategoryId != null) {
      list = list.where((p) {
        final cId = p['category_id']?.toString() ?? '';
        return cId == _selectedSubcategoryId;
      }).toList();
    }

    if (_searchQuery.isEmpty) return list;
    final query = _searchQuery.toLowerCase();
    return list.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      if (name.contains(query) || desc.contains(query)) return true;

      final variants = (p['product_variants'] as List?) ?? [];
      for (final v in variants) {
        final vName = (v['name'] ?? '').toString().toLowerCase();
        final unit = (v['unit_type'] ?? '').toString().toLowerCase();
        if (vName.contains(query) || unit.contains(query)) return true;
      }
      return false;
    }).toList();
  }

  List<String> get _categoryProductNames {
    // If a subcategory chip is active, scope typewriter hint to that subcategory's products;
    // otherwise, scope across all products in the category.
    final list = _selectedSubcategoryId != null
        ? _products
            .where((p) => p['category_id']?.toString() == _selectedSubcategoryId)
            .toList()
        : _products;

    return list
        .map((p) => (p['name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final hasCartItems = cart.itemCount > 0;
    final displayed = _filteredProducts;
    final productNames = _categoryProductNames;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Search Bar with Scoped Typewriter Hint ──────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Input TextField (transparent so typewriter hint shows through)
                      TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: '',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.black,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      size: 18, color: AppColors.textMuted),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                      // Typewriter hint overlay when empty (placed above TextField with IgnorePointer so clicks go to TextField)
                      if (_searchQuery.isEmpty)
                        Positioned(
                          left: 48,
                          right: 40,
                          child: IgnorePointer(
                            child: TypewriterSearchHint(
                              key: ValueKey(
                                  'typewriter_${widget.categoryId}_${_selectedSubcategoryId ?? "all"}_${productNames.length}'),
                              items: productNames.isNotEmpty
                                  ? productNames
                                  : [widget.categoryName],
                              prefix: 'Search "',
                              suffix: '"',
                              textStyle: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Subcategory Filter Chips (if category has subcategories) ─
              if (_subcategories.isNotEmpty)
                Container(
                  height: 36,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _subcategories.length + 1,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isAll = index == 0;
                      final isSelected = isAll
                          ? _selectedSubcategoryId == null
                          : _selectedSubcategoryId ==
                              _subcategories[index - 1]['id']?.toString();

                      final count = isAll
                          ? _products.length
                          : _products
                              .where((p) =>
                                  p['category_id']?.toString() ==
                                  _subcategories[index - 1]['id']?.toString())
                              .length;

                      final label = isAll
                          ? 'All ($count)'
                          : '${_subcategories[index - 1]['name']} ($count)';

                      return FilterChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            if (isAll) {
                              _selectedSubcategoryId = null;
                            } else {
                              final subId =
                                  _subcategories[index - 1]['id']?.toString();
                              _selectedSubcategoryId =
                                  _selectedSubcategoryId == subId ? null : subId;
                            }
                          });
                        },
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                        backgroundColor: AppColors.surfaceVariant,
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    },
                  ),
                ),

              // ── Product Grid or Empty / Loading State ────────────
              Expanded(
                child: _isLoading
                    ? GridView.builder(
                        padding: const EdgeInsets.all(AppTheme.pagePadding),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) =>
                            const ProductCardSkeleton(),
                      )
                    : displayed.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _searchQuery.isNotEmpty ? '🔍' : '📦',
                                    style: const TextStyle(fontSize: 48),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No products matching "$_searchQuery"'
                                        : 'No products in ${widget.categoryName}',
                                    style: AppTheme.titleSm,
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_searchQuery.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    TextButton(
                                      onPressed: () =>
                                          _searchController.clear(),
                                      child: const Text('Clear search'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _fetchProducts,
                            child: GridView.builder(
                              padding: EdgeInsets.fromLTRB(
                                AppTheme.pagePadding,
                                4,
                                AppTheme.pagePadding,
                                hasCartItems ? 120 : 30,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.58,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: displayed.length,
                              itemBuilder: (context, i) {
                                final product =
                                    displayed[i] as Map<String, dynamic>;
                                final variants =
                                    (product['product_variants'] as List?)
                                            ?.cast<Map<String, dynamic>>() ??
                                        [];
                                return ProductCard(
                                  product: product,
                                  variants: variants,
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),

          // ── Floating Cart Bar ─────────────────────────────────────
          if (hasCartItems)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
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
