import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Renders a single category tile — image + name below.
/// Used in the horizontal category grid on HomeScreen.
class CategoryTile extends StatelessWidget {
  final Map<String, dynamic> category;
  final VoidCallback? onTap;

  const CategoryTile({
    super.key,
    required this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = category['name'] as String? ?? '';
    final imageUrl = category['image_url'] as String?;

    // Generate a pastel color based on the category name
    final colors = _categoryColors(name);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors[0],
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: colors[0]),
                        errorWidget: (_, __, ___) => _fallbackIcon(colors),
                      ),
                    )
                  : _fallbackIcon(colors),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: AppTheme.captionSm.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _fallbackIcon(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors[0],
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Center(
        child: Text(
          _emoji(category['name'] as String? ?? ''),
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }

  // Pastel background color based on category name hash
  List<Color> _categoryColors(String name) {
    final palettes = [
      [const Color(0xFFFFE0E6), const Color(0xFF8B1A2B)],
      [const Color(0xFFE8F5E9), const Color(0xFF388E3C)],
      [const Color(0xFFE3F2FD), const Color(0xFF1565C0)],
      [const Color(0xFFFFF8E1), const Color(0xFFF57F17)],
      [const Color(0xFFF3E5F5), const Color(0xFF7B1FA2)],
      [const Color(0xFFE0F7FA), const Color(0xFF00838F)],
      [const Color(0xFFFCE4EC), const Color(0xFFAD1457)],
      [const Color(0xFFF9FBE7), const Color(0xFF558B2F)],
    ];
    return palettes[name.length % palettes.length];
  }

  // Emoji fallback for common grocery categories
  String _emoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('fruit') || n.contains('fresh')) return '🍎';
    if (n.contains('vegetable') || n.contains('veggie')) return '🥦';
    if (n.contains('dairy') || n.contains('milk')) return '🥛';
    if (n.contains('snack') || n.contains('chip')) return '🍿';
    if (n.contains('drink') || n.contains('beverage')) return '🧃';
    if (n.contains('bread') || n.contains('bakery')) return '🍞';
    if (n.contains('meat') || n.contains('chicken')) return '🍗';
    if (n.contains('rice') || n.contains('grain')) return '🍚';
    if (n.contains('oil') || n.contains('ghee')) return '🫙';
    if (n.contains('spice') || n.contains('masala')) return '🌶️';
    if (n.contains('sweet') || n.contains('dessert')) return '🍬';
    if (n.contains('frozen')) return '🧊';
    if (n.contains('baby')) return '👶';
    if (n.contains('personal') || n.contains('hygiene')) return '🧴';
    if (n.contains('clean') || n.contains('household')) return '🧹';
    return '🛒';
  }
}
