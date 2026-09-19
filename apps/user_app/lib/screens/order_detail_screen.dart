import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/cart_provider.dart';
import 'order_tracking_screen.dart';
import 'cart_screen.dart';
import '../widgets/cart_bar.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  List<dynamic> _orderItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrder();
  }

  Future<void> _fetchOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderRes = await SupabaseService.client
          .from('orders')
          .select('*, profiles:rider_id(full_name, phone_number)')
          .eq('id', widget.orderId)
          .single();

      final itemsRes = await SupabaseService.client
          .from('order_items')
          .select('*, products(name, image_url)')
          .eq('order_id', widget.orderId);

      if (mounted) {
        setState(() {
          _order = orderRes;
          _orderItems = List<dynamic>.from(itemsRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching order details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not load order details';
        });
      }
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final day = dt.day;
      final month = months[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day $month $year, $hour:$minute $period';
    } catch (_) {
      return isoString;
    }
  }

  String _calculateDeliveryDuration() {
    try {
      if (_order == null) return '';
      final createdStr = _order!['created_at']?.toString();
      if (createdStr == null) return '';
      final created = DateTime.parse(createdStr);

      DateTime? delivered;
      if (_order!['delivered_at'] != null) {
        try {
          delivered = DateTime.parse(_order!['delivered_at'].toString());
        } catch (_) {}
      } else if (_order!['updated_at'] != null) {
        try {
          final up = DateTime.parse(_order!['updated_at'].toString());
          if (up.difference(created).inSeconds > 30) {
            delivered = up;
          }
        } catch (_) {}
      }

      if (delivered == null) return '';
      final diff = delivered.difference(created);

      if (diff.inSeconds <= 0) return '';
      if (diff.inMinutes < 1) return 'Delivered in under a minute';
      return 'Delivered in ${diff.inMinutes} mins';
    } catch (_) {
      return '';
    }
  }

  void _reorderAllItems() {
    if (_orderItems.isEmpty) return;

    final cart = Provider.of<CartProvider>(context, listen: false);

    for (final item in _orderItems) {
      final productId = item['product_id']?.toString() ?? '';
      final variantId = item['variant_id']?.toString();
      final productName = (item['product_name_snapshot'] ??
              item['products']?['name'] ??
              'Product')
          .toString();
      final variantName = (item['variant_name_snapshot'] ?? '').toString();
      final price = (item['price_at_time'] as num?)?.toDouble() ?? 0.0;
      final mrp = (item['mrp_at_time'] as num?)?.toDouble() ?? price;
      final imageUrl = item['products']?['image_url']?.toString();
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;

      if (productId.isNotEmpty) {
        final cartItem = CartItem(
          productId: productId,
          variantId: variantId,
          productName: productName,
          variantName: variantName,
          sellingPrice: price,
          mrp: mrp,
          imageUrl: imageUrl,
          quantity: qty,
        );
        cart.addOrMergeItem(cartItem, quantityToAdd: qty);
      }
    }
  }

  void _showHelpBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need Help with this Order?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Order #${widget.orderId}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.report_problem_outlined, color: AppColors.error),
                  title: const Text('Item missing or damaged'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support ticket raised. Our team will contact you shortly.')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                  title: const Text('Billing or Payment query'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Our billing team has been notified.')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded, color: AppColors.info),
                  title: const Text('Chat with Customer Support'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connecting to QuickComm Support representative...')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderNum = 'Order #${widget.orderId}';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(
          orderNum,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: AppColors.textPrimary),
            tooltip: 'Need Help?',
            onPressed: _showHelpBottomSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: AppTheme.bodyMd),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchOrder,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    _buildContent(),
                    // ── Floating Cart Bar (identical to home screen, no background behind it) ──
                    Consumer<CartProvider>(
                      builder: (context, cart, _) {
                        if (cart.itemCount == 0) return const SizedBox.shrink();
                        return Positioned(
                          left: 0,
                          right: 0,
                          bottom: 16,
                          child: Center(
                            child: CartBar(
                              itemCount: cart.itemCount,
                              items: cart.items,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CartScreen(),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
      bottomNavigationBar: !_isLoading && _order != null
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _reorderAllItems,
                    icon: const Icon(Icons.replay_rounded, size: 20),
                    label: const Text(
                      'Reorder Item(s)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildContent() {
    final status = (_order!['status'] as String? ?? 'pending').toLowerCase();
    final isActive = status != 'delivered' && status != 'cancelled';
    final createdAt = _formatDateTime(_order!['created_at']);
    final duration = _calculateDeliveryDuration();

    // Bill calculations
    double itemsTotal = 0;
    double mrpTotal = 0;
    for (final it in _orderItems) {
      final p = (it['price_at_time'] as num?)?.toDouble() ?? 0.0;
      final m = (it['mrp_at_time'] as num?)?.toDouble() ?? p;
      final q = (it['quantity'] as num?)?.toInt() ?? 1;
      itemsTotal += (p * q);
      mrpTotal += (m * q);
    }

    final deliveryFee = (_order!['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    final discountAmount = (_order!['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final grandTotal = (_order!['total_amount'] as num?)?.toDouble() ?? (itemsTotal + deliveryFee - discountAmount);
    final totalSavings = (mrpTotal - itemsTotal) + discountAmount;

    // Payment details
    final paymentMethodRaw = (_order!['payment_method'] as String? ?? 'cod').toLowerCase();
    final paymentStatusRaw = (_order!['payment_status'] as String? ?? 'pending').toLowerCase();
    final paymentMethodText = paymentMethodRaw == 'cod'
        ? 'Cash on Delivery'
        : paymentMethodRaw == 'upi'
            ? 'UPI Payment'
            : paymentMethodRaw.toUpperCase();

    // Delivery address
    final deliveryAddress = _order!['delivery_address']?.toString() ?? 'No address recorded';
    final riderProfile = _order!['profiles'] as Map<String, dynamic>?;
    final riderName = riderProfile?['full_name']?.toString();
    final deliveryNotes = _order!['delivery_notes']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status Banner ─────────────────────────────────────────
          _buildStatusBanner(status, createdAt, duration, isActive),
          const SizedBox(height: 16),

          // ── Active Order Live Tracking Prompt ─────────────────────
          if (isActive) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order is in Progress',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Track rider and store status live on map',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(orderId: widget.orderId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Track Live', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Items Ordered Card ────────────────────────────────────
          _buildSectionCard(
            title: 'ITEMS IN THIS ORDER (${_orderItems.length})',
            child: Column(
              children: [
                if (_orderItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No item details recorded', style: TextStyle(color: AppColors.textMuted)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _orderItems.length,
                    separatorBuilder: (context, index) => const Divider(height: 16),
                    itemBuilder: (context, i) {
                      final it = _orderItems[i];
                      final name = (it['product_name_snapshot'] ?? it['products']?['name'] ?? 'Product').toString();
                      final variant = it['variant_name_snapshot']?.toString() ?? '';
                      final price = (it['price_at_time'] as num?)?.toDouble() ?? 0.0;
                      final mrp = (it['mrp_at_time'] as num?)?.toDouble() ?? price;
                      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                      final img = it['products']?['image_url']?.toString();
                      final lineTotal = price * qty;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Product Image Thumbnail
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: img != null && img.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: img,
                                      fit: BoxFit.contain,
                                      errorWidget: (context, url, error) => const Icon(
                                        Icons.shopping_bag_outlined,
                                        color: AppColors.textMuted,
                                        size: 24,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.shopping_bag_outlined,
                                      color: AppColors.textMuted,
                                      size: 24,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Product details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (variant.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    variant,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  'Qty: $qty × ₹$price',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Price & Strikethrough
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹$lineTotal',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (mrp > price)
                                Text(
                                  '₹${mrp * qty}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.strikeMrp,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Bill Summary Card ─────────────────────────────────────
          _buildSectionCard(
            title: 'BILL SUMMARY',
            child: Column(
              children: [
                _buildBillRow('Item Total', '₹${itemsTotal.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _buildBillRow(
                  'Delivery Partner Fee',
                  deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toStringAsFixed(2)}',
                  isFree: deliveryFee == 0,
                ),
                if (discountAmount > 0) ...[
                  const SizedBox(height: 8),
                  _buildBillRow(
                    'Coupon Discount',
                    '-₹${discountAmount.toStringAsFixed(2)}',
                    isDiscount: true,
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                    ),
                    Text(
                      '₹${grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (totalSavings > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.celebration_rounded, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'You saved ₹${totalSavings.toStringAsFixed(2)} on this order!',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Payment Information Card ──────────────────────────────
          _buildSectionCard(
            title: 'PAYMENT DETAILS',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    paymentMethodRaw == 'cod'
                        ? Icons.payments_rounded
                        : Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paymentMethodText,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        paymentStatusRaw == 'paid'
                            ? 'Payment Completed'
                            : 'Payment Pending on Delivery',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: paymentStatusRaw == 'paid' ? AppColors.success : AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: paymentStatusRaw == 'paid' ? AppColors.successLight : AppColors.warningLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    paymentStatusRaw.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: paymentStatusRaw == 'paid' ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Delivery Information Card ─────────────────────────────
          _buildSectionCard(
            title: 'DELIVERY DETAILS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery Address',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            deliveryAddress,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (riderName != null && riderName.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.delivery_dining_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delivery Partner',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              riderName,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (deliveryNotes != null && deliveryNotes.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sticky_note_2_outlined, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Instructions: $deliveryNotes',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String status, String createdAt, String duration, bool isActive) {
    Color badgeColor;
    Color badgeBg;
    IconData icon;
    String statusTitle;

    switch (status) {
      case 'delivered':
        badgeColor = AppColors.success;
        badgeBg = AppColors.successLight;
        icon = Icons.check_circle_rounded;
        statusTitle = 'Order Delivered';
        break;
      case 'cancelled':
        badgeColor = AppColors.error;
        badgeBg = AppColors.errorLight;
        icon = Icons.cancel_rounded;
        statusTitle = 'Order Cancelled';
        break;
      case 'out_for_delivery':
        badgeColor = AppColors.info;
        badgeBg = const Color(0xFFE3F2FD);
        icon = Icons.delivery_dining_rounded;
        statusTitle = 'Out for Delivery';
        break;
      case 'confirmed':
        badgeColor = AppColors.warning;
        badgeBg = AppColors.warningLight;
        icon = Icons.soup_kitchen_rounded;
        statusTitle = 'Confirmed & Preparing';
        break;
      default:
        badgeColor = AppColors.primary;
        badgeBg = AppColors.primarySurface;
        icon = Icons.hourglass_top_rounded;
        statusTitle = 'Order Placed';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
            child: Icon(icon, color: badgeColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  duration.isNotEmpty ? duration : 'Placed on $createdAt',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isFree = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDiscount ? AppColors.success : AppColors.textSecondary,
            fontWeight: isDiscount ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isFree || isDiscount ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
