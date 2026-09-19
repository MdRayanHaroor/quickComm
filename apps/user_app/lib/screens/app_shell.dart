import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/cart_provider.dart';
import '../widgets/cart_bar.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'order_history_screen.dart';
import 'account_screen.dart';
import 'cart_screen.dart';

/// Persistent bottom navigation shell — mirrors Blinkit/Zepto tab structure
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const List<_TabItem> _tabs = [
    _TabItem(label: 'Home', selectedIcon: Icons.home_rounded, unselectedIcon: Icons.home_outlined),
    _TabItem(label: 'Search', selectedIcon: Icons.search_rounded, unselectedIcon: Icons.search_rounded),
    _TabItem(label: 'Orders', selectedIcon: Icons.receipt_long_rounded, unselectedIcon: Icons.receipt_long_outlined),
    _TabItem(label: 'Account', selectedIcon: Icons.person_rounded, unselectedIcon: Icons.person_outline_rounded),
  ];

  final List<Widget> _pages = const [
    HomeScreen(),
    SearchScreen(),
    OrderHistoryScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final hasCartItems = cart.itemCount > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Cart Bar (shown when cart has items) ────────────────
              if (hasCartItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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

              // ── Apple-Style Floating Frosted Glass Dock ──────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      height: 68,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.65),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: List.generate(_tabs.length, (i) {
                          final tab = _tabs[i];
                          final selected = _currentIndex == i;
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _currentIndex = i),
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.black.withValues(alpha: 0.08)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        selected
                                            ? tab.selectedIcon
                                            : tab.unselectedIcon,
                                        size: 24,
                                        color: selected
                                            ? Colors.black
                                            : const Color(0xFF6B7280),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        tab.label,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: selected
                                              ? Colors.black
                                              : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData selectedIcon;
  final IconData unselectedIcon;

  const _TabItem({
    required this.label,
    required this.selectedIcon,
    required this.unselectedIcon,
  });
}
