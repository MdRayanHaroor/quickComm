import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import 'rider_order_detail_screen.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final riderId = SupabaseService.client.auth.currentUser?.id;
    if (riderId == null) return;

    try {
      final data = await SupabaseService.client
          .from('orders')
          .select()
          .eq('rider_id', riderId)
          .inFilter('status', ['delivered', 'cancelled'])
          .order('updated_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Delivery History',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchHistory();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No delivery history yet.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Completed or cancelled orders will appear here.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, i) {
                    final order = _orders[i];
                    final date = DateTime.tryParse(order['updated_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
                    final status = (order['status']?.toString() ?? 'unknown').toLowerCase();
                    final color = _statusColor(status);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RiderOrderDetailScreen(orderId: order['id']),
                              ),
                            );
                            _fetchHistory();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.receipt_rounded,
                                            size: 16,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Order #${order['id']}',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: color.withValues(alpha: 0.35)),
                                      ),
                                      child: Text(
                                        status.replaceAll('_', ' ').toUpperCase(),
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  order['delivery_address'] ?? 'Address not specified',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '₹${order['total_amount'] ?? '0'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          '${date.day}/${date.month}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textMuted),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
