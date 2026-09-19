import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../screens/order_tracking_screen.dart';

/// Floating live active order tracking pill displayed above the bottom dock
class ActiveOrderBar extends StatelessWidget {
  final Map<String, dynamic> order;

  const ActiveOrderBar({super.key, required this.order});

  static (String, IconData) _statusInfo(String? status) {
    switch (status) {
      case 'confirmed':
        return ('Confirmed', Icons.check_circle_outline_rounded);
      case 'preparing':
        return ('Preparing', Icons.soup_kitchen_rounded);
      case 'out_for_delivery':
        return ('On the way', Icons.delivery_dining_rounded);
      case 'pending':
      default:
        return ('Order Placed', Icons.receipt_long_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString();
    final (statusLabel, iconData) = _statusInfo(status);
    final orderId = order['id'];

    return GestureDetector(
      onTap: () {
        if (orderId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderTrackingScreen(orderId: orderId),
            ),
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                // Dark emerald green glass matching modern live delivery styling
                color: const Color(0xFF064E3B).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated pulsing live icon
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.25),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      iconData,
                      size: 15,
                      color: Colors.white,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.92, 0.92),
                        end: const Offset(1.08, 1.08),
                        duration: 1200.ms,
                        curve: Curves.easeInOut,
                      ),
                  const SizedBox(width: 8),

                  // Status text & Subtitle
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF34D399),
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .fade(begin: 0.35, end: 1.0, duration: 800.ms),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Track Order',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // Forward arrow
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
