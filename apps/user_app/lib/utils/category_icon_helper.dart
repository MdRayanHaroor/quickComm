import 'package:flutter/material.dart';

/// Helper to map category names to clean, attractive icons (like Blinkit)
/// Supports both outlined (unselected) and filled (selected) states with vibrant category colors.
class CategoryIconHelper {
  CategoryIconHelper._();

  /// Returns an outlined icon when [selected] is false, and a filled/rounded icon when [selected] is true.
  static IconData getIcon(String? categoryName, {bool selected = false}) {
    if (categoryName == null || categoryName.isEmpty) {
      return selected ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined;
    }

    final name = categoryName.toLowerCase().trim();

    if (name == 'all') {
      return selected ? Icons.grid_view_rounded : Icons.grid_view_outlined;
    }

    if (name.contains('dairy') ||
        name.contains('milk') ||
        name.contains('egg') ||
        name.contains('cheese') ||
        name.contains('butter') ||
        name.contains('bread')) {
      return selected
          ? Icons.breakfast_dining_rounded
          : Icons.breakfast_dining_outlined;
    }

    if (name.contains('tea') ||
        name.contains('coffee') ||
        name.contains('beverage') ||
        name.contains('drink') ||
        name.contains('juice') ||
        name.contains('soda') ||
        name.contains('cola')) {
      return selected
          ? Icons.emoji_food_beverage_rounded
          : Icons.emoji_food_beverage_outlined;
    }

    if (name.contains('snack') ||
        name.contains('munch') ||
        name.contains('chip') ||
        name.contains('crisp') ||
        name.contains('namkeen') ||
        name.contains('biscuit')) {
      return selected ? Icons.fastfood_rounded : Icons.fastfood_outlined;
    }

    if (name.contains('fruit') ||
        name.contains('veg') ||
        name.contains('produce') ||
        name.contains('fresh') ||
        name.contains('farm')) {
      return selected ? Icons.eco_rounded : Icons.eco_outlined;
    }

    if (name.contains('electronic') ||
        name.contains('gadget') ||
        name.contains('mobile') ||
        name.contains('headphone') ||
        name.contains('earphone') ||
        name.contains('cable')) {
      return selected ? Icons.headphones_rounded : Icons.headphones_outlined;
    }

    if (name.contains('beauty') ||
        name.contains('makeup') ||
        name.contains('cosmetic') ||
        name.contains('skin') ||
        name.contains('hair') ||
        name.contains('care') ||
        name.contains('personal')) {
      return selected ? Icons.spa_rounded : Icons.spa_outlined;
    }

    if (name.contains('pharmacy') ||
        name.contains('medicine') ||
        name.contains('health') ||
        name.contains('wellness') ||
        name.contains('first aid')) {
      return selected
          ? Icons.local_pharmacy_rounded
          : Icons.local_pharmacy_outlined;
    }

    if (name.contains('clean') ||
        name.contains('house') ||
        name.contains('detergent') ||
        name.contains('wash') ||
        name.contains('dish')) {
      return selected
          ? Icons.cleaning_services_rounded
          : Icons.cleaning_services_outlined;
    }

    if (name.contains('instant') ||
        name.contains('noodle') ||
        name.contains('maggi') ||
        name.contains('pasta') ||
        name.contains('ready')) {
      return selected
          ? Icons.ramen_dining_rounded
          : Icons.ramen_dining_outlined;
    }

    if (name.contains('bake') ||
        name.contains('cake') ||
        name.contains('cookie') ||
        name.contains('pastry') ||
        name.contains('toast')) {
      return selected
          ? Icons.bakery_dining_rounded
          : Icons.bakery_dining_outlined;
    }

    if (name.contains('meat') ||
        name.contains('fish') ||
        name.contains('chicken') ||
        name.contains('seafood')) {
      return selected ? Icons.set_meal_rounded : Icons.set_meal_outlined;
    }

    if (name.contains('pet') || name.contains('dog') || name.contains('cat')) {
      return selected ? Icons.pets_rounded : Icons.pets_outlined;
    }

    if (name.contains('baby') ||
        name.contains('diaper') ||
        name.contains('infant')) {
      return selected ? Icons.child_care_rounded : Icons.child_care_outlined;
    }

    if (name.contains('sweet') ||
        name.contains('ice cream') ||
        name.contains('choc')) {
      return selected ? Icons.icecream_rounded : Icons.icecream_outlined;
    }

    if (name.contains('festive') ||
        name.contains('pooja') ||
        name.contains('ganesh')) {
      return selected ? Icons.celebration_rounded : Icons.celebration_outlined;
    }

    return selected
        ? Icons.shopping_basket_rounded
        : Icons.shopping_basket_outlined;
  }

  /// Returns a rich, vibrant brand accent color for the selected category
  static Color getCategoryColor(String? categoryName) {
    if (categoryName == null || categoryName.isEmpty) {
      return const Color(0xFF0C831F);
    }

    final name = categoryName.toLowerCase().trim();

    if (name == 'all') return const Color(0xFF0C831F);

    if (name.contains('dairy') ||
        name.contains('milk') ||
        name.contains('egg') ||
        name.contains('cheese') ||
        name.contains('butter') ||
        name.contains('bread')) {
      return const Color(0xFF2563EB); // Royal Blue
    }

    if (name.contains('tea') ||
        name.contains('coffee') ||
        name.contains('beverage') ||
        name.contains('drink') ||
        name.contains('juice') ||
        name.contains('soda') ||
        name.contains('cola')) {
      return const Color(0xFFEA580C); // Warm Orange
    }

    if (name.contains('snack') ||
        name.contains('munch') ||
        name.contains('chip') ||
        name.contains('crisp') ||
        name.contains('namkeen') ||
        name.contains('biscuit')) {
      return const Color(0xFFD97706); // Amber Gold
    }

    if (name.contains('fruit') ||
        name.contains('veg') ||
        name.contains('produce') ||
        name.contains('fresh') ||
        name.contains('farm')) {
      return const Color(0xFF16A34A); // Emerald Green
    }

    if (name.contains('electronic') ||
        name.contains('gadget') ||
        name.contains('mobile') ||
        name.contains('headphone') ||
        name.contains('earphone') ||
        name.contains('cable')) {
      return const Color(0xFF4F46E5); // Indigo
    }

    if (name.contains('beauty') ||
        name.contains('makeup') ||
        name.contains('cosmetic') ||
        name.contains('skin') ||
        name.contains('hair') ||
        name.contains('care') ||
        name.contains('personal')) {
      return const Color(0xFFDB2777); // Vibrant Pink
    }

    if (name.contains('pharmacy') ||
        name.contains('medicine') ||
        name.contains('health') ||
        name.contains('wellness') ||
        name.contains('first aid')) {
      return const Color(0xFF0D9488); // Teal
    }

    if (name.contains('clean') ||
        name.contains('house') ||
        name.contains('detergent') ||
        name.contains('wash') ||
        name.contains('dish')) {
      return const Color(0xFF0284C7); // Sky Blue
    }

    if (name.contains('instant') ||
        name.contains('noodle') ||
        name.contains('maggi') ||
        name.contains('pasta') ||
        name.contains('ready')) {
      return const Color(0xFFE11D48); // Crimson Rose
    }

    if (name.contains('bake') ||
        name.contains('cake') ||
        name.contains('cookie') ||
        name.contains('pastry') ||
        name.contains('toast')) {
      return const Color(0xFFCA8A04); // Golden Bakery
    }

    if (name.contains('meat') ||
        name.contains('fish') ||
        name.contains('chicken') ||
        name.contains('seafood')) {
      return const Color(0xFFDC2626); // Coral Red
    }

    if (name.contains('pet') || name.contains('dog') || name.contains('cat')) {
      return const Color(0xFF7C3AED); // Violet
    }

    if (name.contains('baby') ||
        name.contains('diaper') ||
        name.contains('infant')) {
      return const Color(0xFF0EA5E9); // Soft Sky
    }

    if (name.contains('sweet') ||
        name.contains('ice cream') ||
        name.contains('choc')) {
      return const Color(0xFFF43F5E); // Strawberry Pink
    }

    if (name.contains('festive') ||
        name.contains('pooja') ||
        name.contains('ganesh')) {
      return const Color(0xFF9333EA); // Royal Purple
    }

    return const Color(0xFF0C831F); // Default green
  }
}
