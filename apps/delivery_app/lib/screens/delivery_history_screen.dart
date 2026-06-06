import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

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

      if (mounted) setState(() { _orders = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () { setState(() => _isLoading = true); _fetchHistory(); })
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('No delivery history yet.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, i) {
                    final order = _orders[i];
                    final date = DateTime.parse(order['updated_at']).toLocal();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order #${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(order['status']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _statusColor(order['status']).withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    order['status'].toString().replaceAll('_', ' ').toUpperCase(),
                                    style: TextStyle(color: _statusColor(order['status']), fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(order['delivery_address'] ?? '', style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('₹${order['total_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(
                                  '${date.day}/${date.month}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
