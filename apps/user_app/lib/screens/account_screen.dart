import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'order_history_screen.dart';
import 'app_shell.dart';
import '../widgets/delivery_location_sheet.dart';
import '../providers/cart_provider.dart';
import 'package:provider/provider.dart';

/// Full account/profile tab — replaces the old modal bottom sheet
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().fetchUserProfile();
      }
    });
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Account?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete your account?\n\nThis will permanently erase all your order history, saved addresses, cart items, and profile information.\n\nThis action cannot be undone.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.error),
        ),
      );
      try {
        await context.read<AuthProvider>().deleteAccount();
        if (context.mounted) {
          context.read<CartProvider>().clearCart(syncToDb: false);
          Navigator.pop(context); // close spinner
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // close AccountScreen
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account and all associated data have been permanently deleted.'),
              backgroundColor: AppColors.textPrimary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // close spinner
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Account'),
          backgroundColor: AppColors.surface,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline_rounded,
                    size: 40, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              Text('Not logged in', style: AppTheme.titleMd),
              const SizedBox(height: 8),
              Text(
                'Login to view your profile and orders',
                style: AppTheme.bodyMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Login / Sign Up'),
              ),
            ],
          ),
        ),
      );
    }

    final email = user.email ?? '';
    final name = auth.fullName;
    final phone = auth.phoneNumber;
    final initials = auth.initials.isNotEmpty ? auth.initials : (email.isNotEmpty ? email[0].toUpperCase() : '?');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: true,
      ),
      body: ListView(
        children: [
          // ── Profile header ─────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(AppTheme.pagePadding),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    initials,
                    style: AppTheme.titleLg.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name != null && name.trim().isNotEmpty) ...[
                        Text(
                          name.trim(),
                          style: AppTheme.titleMd.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: AppTheme.bodyMd.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ] else ...[
                        Text(email, style: AppTheme.titleSm),
                      ],
                      if (phone != null && phone.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              phone.trim(),
                              style: AppTheme.captionSm.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Menu items ─────────────────────────────────────────
          _Section(
            title: 'Orders',
            items: [
              _MenuItem(
                icon: Icons.receipt_long_rounded,
                label: 'My Orders',
                onTap: () {
                  if (AppShell.activeShell != null) {
                    AppShell.selectTab(2);
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                    );
                  }
                },
              ),
            ],
          ),

          _Section(
            title: 'Delivery',
            items: [
              _MenuItem(
                icon: Icons.location_on_rounded,
                label: 'Saved Addresses',
                onTap: () => DeliveryLocationSheet.show(context),
              ),
            ],
          ),

          _Section(
            title: 'Account',
            items: [
              _MenuItem(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.info_outline_rounded,
                label: 'About QuickComm',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.delete_outline_rounded,
                iconColor: AppColors.error,
                label: 'Delete Account',
                labelColor: AppColors.error,
                onTap: () => _confirmDeleteAccount(context),
              ),
            ],
          ),

          // ── Logout ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                context.read<CartProvider>().clearCart(syncToDb: false);
                await context.read<AuthProvider>().signOut();
                if (context.mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(AppTheme.pagePadding, 16, AppTheme.pagePadding, 8),
          child: Text(title, style: AppTheme.labelMd.copyWith(color: AppColors.textMuted)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              return Column(
                children: [
                  items[i],
                  if (i < items.length - 1)
                    const Divider(height: 1, indent: 52),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? AppColors.primary;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Icon(icon, size: 18, color: effectiveColor),
      ),
      title: Text(
        label,
        style: AppTheme.bodyLg.copyWith(
          color: labelColor ?? AppColors.textPrimary,
          fontWeight: labelColor != null ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: labelColor ?? AppColors.textMuted, size: 20),
      onTap: onTap,
    );
  }
}
