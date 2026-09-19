import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import '../widgets/skeleton_loader.dart';

import '../widgets/typewriter_search_hint.dart';

class SearchScreen extends StatefulWidget {
  final List<String> searchSuggestions;

  const SearchScreen({super.key, this.searchSuggestions = const []});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<dynamic> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    // Debounce 300ms
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_controller.text.trim() == query && mounted) {
        _search(query);
      }
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    try {
      final response = await SupabaseService.client
          .from('products')
          .select('*, product_variants(*)')
          .eq('is_available', true)
          .ilike('name', '%$query%')
          .order('name')
          .limit(40);

      if (mounted) {
        setState(() {
          _results = response;
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
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: false,
        title: Stack(
          alignment: Alignment.centerLeft,
          children: [
            if (_controller.text.isEmpty)
              Positioned(
                left: 48,
                right: 48,
                child: IgnorePointer(
                  child: TypewriterSearchHint(
                    items: widget.searchSuggestions,
                  ),
                ),
              ),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) _search(v.trim());
              },
              style: const TextStyle(color: Colors.black, fontSize: 15),
              decoration: InputDecoration(
                hintText: null,
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.black, size: 20),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textMuted, size: 20),
                        onPressed: () {
                          _controller.clear();
                          _focusNode.requestFocus();
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_hasSearched) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text('🔍', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                'Search for groceries',
                style: AppTheme.titleMd.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Try "Amul Milk", "Tea & Coffee", "Bread"',
                style: AppTheme.bodyMd,
              ),
              if (widget.searchSuggestions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: widget.searchSuggestions.take(8).map((s) {
                    return ActionChip(
                      label: Text(s),
                      backgroundColor: AppColors.surfaceVariant,
                      side: const BorderSide(color: AppColors.border),
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        _controller.text = s;
                        _search(s);
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const ProductCardSkeleton(),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'No results for "${_controller.text}"',
              style: AppTheme.titleMd.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different name or browse categories',
              style: AppTheme.bodyMd,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${_results.length} results for "${_controller.text}"',
            style: AppTheme.bodyMd,
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.58,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _results.length,
            itemBuilder: (context, i) {
              final product = _results[i] as Map<String, dynamic>;
              final variants = (product['product_variants'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [];
              return ProductCard(product: product, variants: variants);
            },
          ),
        ),
      ],
    );
  }
}
