import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  final bool returnToCheckout;
  const LoginScreen({super.key, this.returnToCheckout = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _userManuallyEditedName = false;
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    if (!_isSignUp || _userManuallyEditedName) return;
    final email = _emailController.text.trim();
    if (email.contains('@')) {
      final username = email.split('@').first;
      final parts = username.split(RegExp(r'[._-]')).where((s) => s.isNotEmpty);
      final derivedName = parts
          .map((s) => s[0].toUpperCase() + (s.length > 1 ? s.substring(1).toLowerCase() : ''))
          .join(' ');
      if (derivedName.isNotEmpty && _nameController.text != derivedName) {
        _nameController.text = derivedName;
      }
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        (_isSignUp && _nameController.text.trim().isEmpty)) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (_isSignUp) {
        await auth.signUp(
          _emailController.text.trim(),
          _passwordController.text,
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
        );
        if (!mounted) return;
        setState(() => _errorMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account created! Please log in.'),
          backgroundColor: AppColors.success,
        ));
        setState(() => _isSignUp = false);
      } else {
        await auth.signIn(
            _emailController.text.trim(), _passwordController.text);
        if (!mounted) return;
        if (widget.returnToCheckout || Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AppShell()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('Invalid login credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (raw.contains('Email not confirmed')) {
      return 'Please confirm your email address first.';
    }
    if (raw.contains('already registered')) {
      return 'This email is already registered. Try logging in.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // ── Background gradient & decorative circles ───────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF5C0F1C), Color(0xFF8B1A2B), Color(0xFFC1273A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          const Positioned(
            top: -60,
            right: -60,
            child: _DecorativeCircle(size: 200, opacity: 0.08),
          ),
          const Positioned(
            top: 100,
            left: -40,
            child: _DecorativeCircle(size: 120, opacity: 0.06),
          ),

          // ── Content ────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),

                // Logo / brand mark
                Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                        boxShadow: AppColors.elevatedShadow,
                      ),
                      child: const Center(
                        child: Text('⚡', style: TextStyle(fontSize: 36)),
                      ),
                    ).animate().scale(
                          duration: 600.ms,
                          curve: Curves.elasticOut,
                        ),
                    const SizedBox(height: 16),
                    Text(
                      'QuickComm',
                      style: AppTheme.displayLg.copyWith(color: Colors.white),
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                    const SizedBox(height: 6),
                    Text(
                      'Groceries delivered in minutes',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                  ],
                ),

                const SizedBox(height: 40),

                // ── Auth Card ──────────────────────────────────────
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppTheme.radiusXl),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          // ── Tab toggle ──────────────────────────
                          _AuthToggle(
                            isSignUp: _isSignUp,
                            onToggle: (v) => setState(() {
                              _isSignUp = v;
                              _errorMessage = null;
                            }),
                          ),
                          const SizedBox(height: 28),

                          // ── Email ──────────────────────────────
                          _FieldLabel('Email'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                          ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
                          const SizedBox(height: 16),

                          // ── Password ───────────────────────────
                          _FieldLabel('Password'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: _isSignUp ? TextInputAction.next : TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_isSignUp) _submit();
                            },
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
                          if (_isSignUp) ...[
                            const SizedBox(height: 16),
                            _FieldLabel('Full Name'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => _userManuallyEditedName = true,
                              decoration: const InputDecoration(
                                hintText: 'e.g. Alex Smith',
                                prefixIcon: Icon(Icons.person_outline, size: 20),
                              ),
                            ).animate().fadeIn(delay: 180.ms, duration: 300.ms),
                            const SizedBox(height: 16),
                            _FieldLabel('Phone Number'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                hintText: 'e.g. +91 98765 43210',
                                prefixIcon: Icon(Icons.phone_outlined, size: 20),
                              ),
                            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                          ],
                          const SizedBox(height: 20),

                          // ── Error message ──────────────────────
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.errorLight,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.error, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                          color: AppColors.error, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().shake(duration: 400.ms),
                            const SizedBox(height: 16),
                          ],

                          // ── Submit button ──────────────────────
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isSignUp ? 'Create Account' : 'Login',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

                          const SizedBox(height: 24),

                          // ── Footer ─────────────────────────────
                          Center(
                            child: Text(
                              _isSignUp
                                  ? 'By signing up, you agree to our Terms & Privacy Policy.'
                                  : 'Forgot password? Contact support.',
                              style: AppTheme.captionSm,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _DecorativeCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _AuthToggle extends StatelessWidget {
  final bool isSignUp;
  final ValueChanged<bool> onToggle;

  const _AuthToggle({required this.isSignUp, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          _ToggleTab(
            label: 'Login',
            selected: !isSignUp,
            onTap: () => onToggle(false),
          ),
          _ToggleTab(
            label: 'Sign Up',
            selected: isSignUp,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            boxShadow: selected ? AppColors.cardShadow : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.labelMd.copyWith(color: AppColors.textSecondary),
    );
  }
}
