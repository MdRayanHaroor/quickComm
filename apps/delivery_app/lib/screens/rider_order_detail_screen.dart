import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class RiderOrderDetailScreen extends StatefulWidget {
  final int orderId;
  const RiderOrderDetailScreen({super.key, required this.orderId});

  @override
  State<RiderOrderDetailScreen> createState() => _RiderOrderDetailScreenState();
}

class _RiderOrderDetailScreenState extends State<RiderOrderDetailScreen> {
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _customerProfile;
  List<dynamic> _orderItems = [];
  bool _isLoading = true;
  String? _error;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Fetch order directly from Supabase
      final orderRes = await SupabaseService.client
          .from('orders')
          .select()
          .eq('id', widget.orderId)
          .single();

      // 2. Fetch customer profile directly from profiles table
      Map<String, dynamic>? customer;
      final userId = orderRes['user_id'];
      if (userId != null) {
        try {
          customer = await SupabaseService.client
              .from('profiles')
              .select('full_name, phone_number')
              .eq('id', userId)
              .maybeSingle();
        } catch (e) {
          debugPrint('⚠️ Could not fetch customer profile: $e');
        }
      }

      // 3. Fetch order items with joined products (name, image_url)
      final itemsRes = await SupabaseService.client
          .from('order_items')
          .select('*, products(name, image_url)')
          .eq('order_id', widget.orderId);

      if (mounted) {
        setState(() {
          _order = orderRes;
          _customerProfile = customer;
          _orderItems = List<dynamic>.from(itemsRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching rider order details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not load order details: $e';
        });
      }
    }
  }

  Future<void> _callCustomer(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number provided for this customer.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanedPhone');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open dialer for $phone'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _launchMaps(String? address, double? lat, double? lng) async {
    Uri url;
    if (lat != null && lng != null) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else if (address != null && address.isNotEmpty) {
      final query = Uri.encodeComponent(address);
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location coordinates or address available')),
      );
      return;
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (newStatus == 'delivered') {
        updateData['delivered_at'] = DateTime.now().toUtc().toIso8601String();
      }

      await SupabaseService.client
          .from('orders')
          .update(updateData)
          .eq('id', widget.orderId);

      await _fetchOrderDetails();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to ${newStatus.replaceAll('_', ' ').toUpperCase()}! 🎉'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
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

  String _calculateDuration() {
    try {
      if (_order == null) return '';
      final createdStr = _order!['created_at']?.toString();
      if (createdStr == null) return '';
      final created = DateTime.parse(createdStr);

      DateTime? delivered;
      if (_order!['delivered_at'] != null) {
        delivered = DateTime.parse(_order!['delivered_at'].toString());
      } else if (_order!['status'] == 'delivered' && _order!['updated_at'] != null) {
        delivered = DateTime.parse(_order!['updated_at'].toString());
      }

      if (delivered != null) {
        final diff = delivered.difference(created);
        final mins = diff.inMinutes;
        if (mins < 1) return 'Delivered in under a minute';
        if (mins < 60) return 'Delivered in $mins min${mins == 1 ? '' : 's'}';
        final hours = mins ~/ 60;
        final remMins = mins % 60;
        return 'Delivered in ${hours}h ${remMins}m';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'out_for_delivery':
        return AppColors.warning;
      case 'rider_assigned':
      case 'preparing':
        return AppColors.primary;
      default:
        return AppColors.info;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'out_for_delivery':
        return Icons.delivery_dining_rounded;
      case 'rider_assigned':
      case 'preparing':
        return Icons.inventory_2_rounded;
      default:
        return Icons.access_time_filled_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Order #${widget.orderId}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Order',
            onPressed: _fetchOrderDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_error!, style: AppTheme.bodyMd, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchOrderDetails,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildOrderContent(),
    );
  }

  Widget _buildOrderContent() {
    final status = (_order!['status'] as String? ?? 'pending').toLowerCase();
    final isActive = status != 'delivered' && status != 'cancelled';
    final createdAt = _formatDateTime(_order!['created_at']);
    final duration = _calculateDuration();
    final statusColor = _getStatusColor(status);

    final customerName = _customerProfile?['full_name']?.toString() ?? 'Customer';
    final customerPhone = _customerProfile?['phone_number']?.toString();

    final deliveryAddress = _order!['delivery_address']?.toString() ?? 'No address recorded';
    final deliveryLat = (_order!['delivery_lat'] as num?)?.toDouble();
    final deliveryLng = (_order!['delivery_lng'] as num?)?.toDouble();

    // Bill calculations
    double itemsTotal = 0;
    for (final it in _orderItems) {
      final p = (it['price_at_time'] as num?)?.toDouble() ?? 0.0;
      final q = (it['quantity'] as num?)?.toInt() ?? 1;
      itemsTotal += (p * q);
    }
    final deliveryFee = (_order!['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    final grandTotal = (_order!['total_amount'] as num?)?.toDouble() ?? (itemsTotal + deliveryFee);
    final paymentMethod = (_order!['payment_method'] as String? ?? 'cod').toUpperCase();
    final paymentStatus = (_order!['payment_status'] as String? ?? 'pending').toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Status Banner ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getStatusIcon(status), color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Placed: $createdAt',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (duration.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          duration,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 2. Customer Contact Card (P0 Requirement) ────────────────
          _buildCard(
            title: 'CUSTOMER DETAILS',
            titleIcon: Icons.person_pin_circle_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.person, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customerPhone != null && customerPhone.isNotEmpty
                                ? customerPhone
                                : 'No phone number provided',
                            style: TextStyle(
                              fontSize: 13,
                              color: customerPhone != null && customerPhone.isNotEmpty
                                  ? AppColors.textSecondary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Call Customer Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: customerPhone != null && customerPhone.isNotEmpty
                        ? () => _callCustomer(customerPhone)
                        : null,
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text(
                      customerPhone != null && customerPhone.isNotEmpty
                          ? 'Call Customer ($customerPhone)'
                          : 'Customer Phone Unavailable',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. Delivery Location Card ────────────────────────────────
          _buildCard(
            title: 'DELIVERY LOCATION',
            titleIcon: Icons.location_on_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deliveryAddress,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _launchMaps(deliveryAddress, deliveryLat, deliveryLng),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Navigate in Google Maps'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 4. Ordered Items Card with Images (P0 Requirement) ────────
          _buildCard(
            title: 'ITEMS IN THIS ORDER (${_orderItems.length})',
            titleIcon: Icons.shopping_bag_rounded,
            child: _orderItems.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No item records found.', style: TextStyle(color: AppColors.textMuted)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _orderItems.length,
                    separatorBuilder: (context, index) => const Divider(height: 20),
                    itemBuilder: (context, i) {
                      final it = _orderItems[i];
                      final name = (it['product_name_snapshot'] ?? it['products']?['name'] ?? 'Product').toString();
                      final variant = it['variant_name_snapshot']?.toString() ?? '';
                      final price = (it['price_at_time'] as num?)?.toDouble() ?? 0.0;
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
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: img != null && img.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: img,
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => const Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                        ),
                                      ),
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

                          // Product title & variant
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
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
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  'Qty: $qty × ₹$price',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Line Price
                          Text(
                            '₹${lineTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),

          // ── 5. Payment & Bill Breakdown ──────────────────────────────
          _buildCard(
            title: 'BILL & PAYMENT SUMMARY',
            titleIcon: Icons.receipt_long_rounded,
            child: Column(
              children: [
                _buildBillRow('Items Subtotal', '₹${itemsTotal.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _buildBillRow('Delivery Fee', '₹${deliveryFee.toStringAsFixed(2)}'),
                const Divider(height: 20),
                _buildBillRow('Grand Total', '₹${grandTotal.toStringAsFixed(2)}', isBold: true),
                const SizedBox(height: 14),
                // Payment Mode Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: paymentMethod == 'COD' ? AppColors.warningLight : AppColors.successLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: paymentMethod == 'COD' ? AppColors.warning : AppColors.success,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        paymentMethod == 'COD' ? '💵 Cash on Delivery' : '💳 Online Payment ($paymentMethod)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: paymentMethod == 'COD' ? Colors.orange.shade900 : Colors.green.shade900,
                        ),
                      ),
                      Text(
                        paymentStatus,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: paymentStatus == 'PAID' ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 6. Active Order Action Buttons ───────────────────────────
          if (isActive) ...[
            if (status == 'rider_assigned' || status == 'preparing')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdatingStatus ? null : () => _updateOrderStatus('out_for_delivery'),
                  icon: const Icon(Icons.delivery_dining, size: 20),
                  label: _isUpdatingStatus
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Start Delivery (Out For Delivery)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            if (status == 'out_for_delivery') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdatingStatus ? null : () => _updateOrderStatus('delivered'),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: _isUpdatingStatus
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Mark Order as Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData titleIcon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(titleIcon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
