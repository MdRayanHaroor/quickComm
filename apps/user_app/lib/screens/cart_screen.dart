import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../services/supabase_service.dart';
import '../services/delivery_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Cart${cart.itemCount > 0 ? ' (${cart.itemCount})' : ''}',
        ),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, cart),
              child: const Text('Clear', style: TextStyle(color: AppColors.error)),
            ),
        ],
      ),
      body: cart.items.isEmpty ? _EmptyCart() : _CartBody(cart: cart),
    );
  }

  void _confirmClear(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text('All items will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🛒', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text('Your cart is empty', style: AppTheme.titleMd),
          const SizedBox(height: 8),
          Text('Add items to start shopping', style: AppTheme.bodyMd),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Browse Products'),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

class _CartBody extends StatefulWidget {
  final CartProvider cart;
  const _CartBody({required this.cart});

  @override
  State<_CartBody> createState() => _CartBodyState();
}

class _CartBodyState extends State<_CartBody> {
  DeliveryEstimate _estimate = const DeliveryEstimate(minutes: 12);
  double? _deliveryFee;

  @override
  void initState() {
    super.initState();
    _loadDeliveryDetails();
  }

  Future<void> _loadDeliveryDetails() async {
    final estimate = await DeliveryService.getDeliveryEstimate();
    final fee = await DeliveryService.getEffectiveDeliveryFee(widget.cart.subtotal);
    if (mounted) {
      setState(() {
        _estimate = estimate;
        _deliveryFee = fee;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _CartBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cart.subtotal != widget.cart.subtotal) {
      DeliveryService.getEffectiveDeliveryFee(widget.cart.subtotal).then((fee) {
        if (mounted) setState(() => _deliveryFee = fee);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    final locProv = Provider.of<LocationProvider>(context);
    final feeToAdd = _deliveryFee ?? 0.0;
    final grandTotal = cart.subtotal + feeToAdd;

    final String deliveryText;
    if (locProv.isLocationPermissionGranted && locProv.formattedDistance != null) {
      deliveryText = 'Delivery in ~${locProv.etaMinutes} mins (${locProv.formattedDistance}) ⚡';
    } else if (_estimate.isDynamic && _estimate.formattedDistance != null) {
      deliveryText = _estimate.displayText;
    } else {
      deliveryText = 'Delivery in ~12 minutes ⚡';
    }

    return Column(
      children: [
        // ── Delivery estimate strip ─────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.successLight,
          child: Row(
            children: [
              const Icon(Icons.timer_outlined,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deliveryText,
                  style: AppTheme.labelMd.copyWith(color: AppColors.success),
                ),
              ),
            ],
          ),
        ),

        // ── Cart items ──────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            itemCount: cart.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return _CartItemRow(item: item, cart: cart);
            },
          ),
        ),

        // ── Bill Details ────────────────────────────────────────
        _BillCard(cart: cart, deliveryFee: _deliveryFee),

        // ── Checkout button ────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final user = SupabaseService.client.auth.currentUser;
                  if (user == null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const LoginScreen(returnToCheckout: true)),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CheckoutScreen(deliveryFee: _deliveryFee)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Proceed to Checkout',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      '₹${grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final CartProvider cart;

  const _CartItemRow({required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: item.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _imgFallback(),
                  )
                : _imgFallback(),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AppTheme.titleSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.variantName.isNotEmpty)
                  Text(item.variantName, style: AppTheme.captionSm),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${item.sellingPrice.toStringAsFixed(0)}',
                      style: AppTheme.titleSm.copyWith(
                          color: AppColors.primary, fontSize: 14),
                    ),
                    if (item.mrp > item.sellingPrice) ...[
                      const SizedBox(width: 6),
                      Text(
                        '₹${item.mrp.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppColors.strikeMrp,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.strikeMrp,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Stepper
          _CartStepper(
            qty: item.quantity,
            onIncrease: () =>
                cart.increaseQuantity(item.productId, item.variantId),
            onDecrease: () =>
                cart.decreaseQuantity(item.productId, item.variantId),
          ),
        ],
      ),
    );
  }

  Widget _imgFallback() {
    return Container(
      width: 60,
      height: 60,
      color: AppColors.surfaceVariant,
      child: const Center(child: Text('🛒', style: TextStyle(fontSize: 24))),
    );
  }
}

class _CartStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const _CartStepper(
      {required this.qty,
      required this.onIncrease,
      required this.onDecrease});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDecrease,
            child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.remove, size: 14, color: Colors.white)),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              '$qty',
              key: ValueKey(qty),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: onIncrease,
            child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.add, size: 14, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final CartProvider cart;
  final double? deliveryFee;

  const _BillCard({required this.cart, required this.deliveryFee});

  @override
  Widget build(BuildContext context) {
    final feeToAdd = deliveryFee ?? 0.0;
    final grandTotal = cart.subtotal + feeToAdd;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bill Details', style: AppTheme.titleSm),
          const SizedBox(height: 12),
          _BillRow('Item Total', '₹${cart.subtotal.toStringAsFixed(0)}'),
          if (deliveryFee != null)
            _BillRow(
              'Delivery Fee',
              deliveryFee == 0
                  ? 'FREE'
                  : '₹${deliveryFee!.toStringAsFixed(0)}',
              valueColor: deliveryFee == 0 ? AppColors.success : null,
            ),
          if (cart.totalSavings > 0)
            _BillRow(
              'Total Savings',
              '-₹${cart.totalSavings.toStringAsFixed(0)}',
              valueColor: AppColors.success,
            ),
          const Divider(height: 20),
          _BillRow(
            'To Pay',
            '₹${grandTotal.toStringAsFixed(0)}',
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _BillRow(this.label, this.value,
      {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold ? AppTheme.titleSm : AppTheme.bodyMd,
          ),
          Text(
            value,
            style: (bold ? AppTheme.titleSm : AppTheme.titleSm.copyWith(
              fontWeight: FontWeight.w600,
            )).copyWith(
              color: valueColor,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
