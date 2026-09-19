import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'order_tracking_screen.dart';
import 'app_shell.dart';

class OrderSuccessScreen extends StatefulWidget {
  final int orderId;
  final int? estimatedEtaMinutes;
  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    this.estimatedEtaMinutes,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Lottie animation ─────────────────────────────
              Lottie.asset(
                'assets/order_success_lottie.json',
                controller: _lottieController,
                onLoaded: (composition) {
                  _lottieController
                    ..duration = composition.duration
                    ..forward();
                },
                height: 180,
                width: 180,
                repeat: false,
              ),

              const SizedBox(height: 8),

              // ── Staggered text entrance ───────────────────────
              Text(
                'Order Placed! 🎉',
                style: AppTheme.displayLg.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideY(
                    begin: 0.3,
                    end: 0,
                    delay: 400.ms,
                    duration: 500.ms,
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: 12),

              // Text(
              //   'Order #${widget.orderId}',
              //   style: AppTheme.bodyLg.copyWith(color: AppColors.textSecondary),
              // ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

              const SizedBox(height: 8),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      widget.estimatedEtaMinutes != null
                          ? 'Estimated delivery in ~${widget.estimatedEtaMinutes} minutes'
                          : 'Estimated delivery in ~15 minutes',
                      style: AppTheme.labelMd
                          .copyWith(color: AppColors.success),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 700.ms, duration: 400.ms),

              const SizedBox(height: 40),

              // ── Action buttons ────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delivery_dining_rounded, size: 20),
                  label: const Text('Track Order'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const AppShell()),
                      (route) => false,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              OrderTrackingScreen(orderId: widget.orderId)),
                    );
                  },
                ),
              ).animate().fadeIn(delay: 800.ms, duration: 400.ms).slideY(
                    begin: 0.2,
                    end: 0,
                    delay: 800.ms,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const AppShell()),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Continue Shopping'),
                ),
              ).animate().fadeIn(delay: 900.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
