import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = response.user?.id;
      if (userId == null) throw "Login failed";

      if (!mounted) return;

      // Check Role directly from Supabase profiles
      final profile = await SupabaseService.client.from('profiles').select('role').eq('id', userId).single();

      if (!mounted) return;

      if (profile['role'] == 'rider') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else {
        await SupabaseService.client.auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access Denied: Not a Rider Account'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Rider Login', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.delivery_dining_rounded, size: 36, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'QuickComm Partner',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to access your delivery dashboard',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
