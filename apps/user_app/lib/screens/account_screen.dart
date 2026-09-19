import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'package:provider/provider.dart';

/// Full account/profile tab — replaces the old modal bottom sheet
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
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
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Account'),
        automaticallyImplyLeading: false,
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
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(
                    initial,
                    style: AppTheme.titleLg.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email, style: AppTheme.titleSm),
                      const SizedBox(height: 4),
                      Text('QuickComm Member', style: AppTheme.bodyMd),
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
                onTap: () {},
              ),
            ],
          ),

          _Section(
            title: 'Delivery',
            items: [
              _MenuItem(
                icon: Icons.location_on_rounded,
                label: 'Saved Addresses',
                onTap: () {},
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
                await SupabaseService.client.auth.signOut();
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

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      title: Text(label, style: AppTheme.bodyLg),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textMuted, size: 20),
      onTap: onTap,
    );
  }
}
