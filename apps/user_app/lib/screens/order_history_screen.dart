import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'order_tracking_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final String? _userId = SupabaseService.client.auth.currentUser?.id;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;
  Timer? _autoRefreshTimer;
  RealtimeChannel? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _setupRealtimeSubscription();
    _startAutoRefreshTimer();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _ordersSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (_userId == null) return;
    if (!silent && mounted && _orders.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('*, order_items(*, products(name))')
          .eq('user_id', _userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('❌ OrderHistoryScreen._fetchOrders error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_orders.isEmpty) {
            _error = 'Error loading orders';
          }
        });
      }
    }
  }

  void _setupRealtimeSubscription() {
    if (_userId == null) return;
    try {
      _ordersSubscription = SupabaseService.client
          .channel('user_orders_$_userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: _userId,
            ),
            callback: (payload) {
              debugPrint('⚡ OrderHistoryScreen realtime update: ${payload.eventType}');
              _fetchOrders(silent: true);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('⚠️ OrderHistoryScreen realtime subscription error: $e');
    }
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    // Poll every 5 seconds while any order is pending/out_for_delivery/confirmed
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final hasActiveOrders = _orders.any((o) {
        final s = (o['status'] as String? ?? '').toLowerCase();
        return s != 'delivered' && s != 'cancelled';
      });
      if (hasActiveOrders) {
        _fetchOrders(silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Your Orders')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📦', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text('Please log in to see your orders', style: AppTheme.bodyMd),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Orders'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh orders',
            onPressed: () => _fetchOrders(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchOrders(),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        itemCount: 5,
        itemBuilder: (_, i) => const _OrderCardSkeleton(),
      );
    }

    if (_error != null && _orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('Error loading orders', style: AppTheme.bodyMd),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _fetchOrders(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📦', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text('No orders yet', style: AppTheme.titleMd),
                  const SizedBox(height: 8),
                  Text('Start shopping to see your orders here',
                      style: AppTheme.bodyMd),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      itemCount: _orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _OrderCard(
        order: _orders[i],
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderTrackingScreen(orderId: _orders[i]['id']),
            ),
          );
          _fetchOrders(silent: true);
        },
      ).animate().fadeIn(
            delay: Duration(milliseconds: i * 50),
            duration: 300.ms,
          ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = (order['order_items'] as List<dynamic>?) ?? [];
    final status = order['status'] as String? ?? 'pending';
    final total = order['total_amount'] ?? 0;
    final createdAt = order['created_at'] as String? ?? '';

    final itemSummary = items.take(3).map((i) {
      final name = i['products']?['name'] ?? 'Item';
      final variantName = i['variant_name_snapshot'];
      return variantName != null ? '$name ($variantName)' : name;
    }).join(', ');
    final moreCount = items.length > 3 ? ' +${items.length - 3} more' : '';

    final statusInfo = _statusInfo(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order #${order['id']}', style: AppTheme.titleSm),
                _StatusChip(status: status, info: statusInfo),
              ],
            ),
            const SizedBox(height: 8),

            // ── Item summary ────────────────────────────────────
            Text(
              itemSummary + moreCount,
              style: AppTheme.bodyMd,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // ── Footer row ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDate(createdAt), style: AppTheme.captionSm),
                Row(
                  children: [
                    Text(
                      '₹${total is num ? total.toStringAsFixed(0) : total}',
                      style: AppTheme.titleSm.copyWith(color: AppColors.primary),
                    ),
                    if (status != 'delivered' && status != 'cancelled') ...[
                      const SizedBox(width: 12),
                      Text(
                        'Track →',
                        style: AppTheme.labelMd
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _statusInfo(String status) {
    switch (status) {
      case 'delivered':
        return {'label': 'Delivered', 'color': AppColors.success, 'bg': AppColors.successLight};
      case 'cancelled':
        return {'label': 'Cancelled', 'color': AppColors.error, 'bg': AppColors.errorLight};
      case 'pending':
        return {'label': 'Pending', 'color': AppColors.warning, 'bg': AppColors.warningLight};
      case 'confirmed':
        return {'label': 'Confirmed', 'color': AppColors.info, 'bg': const Color(0xFFE3F2FD)};
      case 'out_for_delivery':
        return {'label': 'On the Way', 'color': AppColors.info, 'bg': const Color(0xFFE3F2FD)};
      default:
        return {'label': status, 'color': AppColors.textSecondary, 'bg': AppColors.surfaceVariant};
    }
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}  ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final Map<String, dynamic> info;

  const _StatusChip({required this.status, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: info['bg'] as Color,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        info['label'] as String,
        style: TextStyle(
          color: info['color'] as Color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Simple skeleton for order list items
class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
    );
  }
}
