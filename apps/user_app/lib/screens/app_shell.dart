import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/cart_bar.dart';
import '../widgets/active_order_bar.dart';
import 'home_screen.dart';
import 'all_categories_screen.dart';
import 'order_history_screen.dart';
import 'cart_screen.dart';

/// Persistent bottom navigation shell — clean 3-tab structure
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static AppShellState? activeShell;

  static void selectTab(int index) {
    activeShell?.setTab(index);
  }

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    AppShell.activeShell = this;
  }

  @override
  void dispose() {
    if (AppShell.activeShell == this) {
      AppShell.activeShell = null;
    }
    super.dispose();
  }

  void setTab(int index) {
    if (mounted) {
      setState(() => _currentIndex = index);
      context.read<LocationProvider>().refreshStoreSettings();
    }
  }

  static const List<_TabItem> _tabs = [
    _TabItem(
      label: 'Home',
      selectedIcon: Icons.home_rounded,
      unselectedIcon: Icons.home_outlined,
    ),
    _TabItem(
      label: 'Categories',
      selectedIcon: Icons.grid_view_rounded,
      unselectedIcon: Icons.grid_view_outlined,
    ),
    _TabItem(
      label: 'Orders',
      selectedIcon: Icons.receipt_long_rounded,
      unselectedIcon: Icons.receipt_long_outlined,
    ),
  ];

  List<Widget> get _pages => const [
    HomeScreen(),
    AllCategoriesScreen(),
    OrderHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final hasCartItems = cart.itemCount > 0;
    final authUser = context.watch<AuthProvider>().user ?? SupabaseService.client.auth.currentUser;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: authUser != null
          ? SupabaseService.client
              .from('orders')
              .stream(primaryKey: ['id'])
              .eq('user_id', authUser.id)
              .order('created_at', ascending: false)
              .limit(1)
          : const Stream.empty(),
      builder: (context, snapshot) {
        Map<String, dynamic>? activeOrder;
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final latest = snapshot.data!.first;
          final status = latest['status']?.toString();
          if (status != 'delivered' && status != 'cancelled') {
            activeOrder = latest;
          }
        }
        final hasActiveOrder = activeOrder != null;

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
                  // ── Floating Action Row (Cart Bar and / or Live Active Order Tracker) ──
                  if (hasCartItems || hasActiveOrder)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 380),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: hasCartItems
                              ? (hasActiveOrder
                                  ? MainAxisAlignment.spaceBetween
                                  : MainAxisAlignment.center)
                              : MainAxisAlignment.end,
                          children: [
                            if (hasCartItems)
                              CartBar(
                                itemCount: cart.itemCount,
                                items: cart.items,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const CartScreen()),
                                ),
                              ),
                            if (hasActiveOrder && activeOrder != null)
                              ActiveOrderBar(order: activeOrder),
                          ],
                        ),
                      ),
                    ),

                  // ── Apple-Style Floating Frosted Glass Dock ──────────────
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    constraints: const BoxConstraints(maxWidth: 380),
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
                                  onTap: () {
                                    setState(() => _currentIndex = i);
                                    context.read<LocationProvider>().refreshStoreSettings();
                                  },
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeOutCubic,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Icon(
                                                selected
                                                    ? tab.selectedIcon
                                                    : tab.unselectedIcon,
                                                size: 24,
                                                color: selected
                                                    ? AppColors.primary
                                                    : const Color(0xFF6B7280),
                                              ),
                                              // Live indicator dot on Orders tab when delivery is active
                                              if (i == 2 && hasActiveOrder)
                                                Positioned(
                                                  top: -1,
                                                  right: -3,
                                                  child: Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF10B981),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  )
                                                      .animate(onPlay: (c) => c.repeat(reverse: true))
                                                      .scale(
                                                        begin: const Offset(0.8, 0.8),
                                                        end: const Offset(1.25, 1.25),
                                                        duration: 800.ms,
                                                      ),
                                                ),
                                            ],
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
                                                  ? AppColors.primary
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
      },
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
