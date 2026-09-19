import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import '../widgets/skeleton_loader.dart';

class CategoryScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client
          .from('products')
          .select('*, product_variants(*)')
          .eq('is_available', true)
          .eq('category_id', widget.categoryId)
          .order('name')
          .limit(50);
      if (mounted) {
        setState(() {
          _products = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? GridView.builder(
              padding: const EdgeInsets.all(AppTheme.pagePadding),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 6,
              itemBuilder: (_, __) => const ProductCardSkeleton(),
            )
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📦', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'No products in ${widget.categoryName}',
                        style: AppTheme.bodyMd,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _fetchProducts,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppTheme.pagePadding),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.58,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, i) {
                      final product = _products[i] as Map<String, dynamic>;
                      final variants =
                          (product['product_variants'] as List?)
                                  ?.cast<Map<String, dynamic>>() ??
                              [];
                      return ProductCard(product: product, variants: variants);
                    },
                  ),
                ),
    );
  }
}
