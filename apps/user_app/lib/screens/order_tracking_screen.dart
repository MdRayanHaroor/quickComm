
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../services/supabase_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? _order;
  List<dynamic>? _orderItems;
  Map<String, dynamic>? _riderLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _subscribeToOrderUpdates();
  }

  Future<void> _fetchOrderDetails() async {
    final response = await SupabaseService.client
        .from('orders')
        .select('*, profiles:rider_id(full_name, phone_number)')
        .eq('id', widget.orderId)
        .single();
    
    final itemsResponse = await SupabaseService.client
        .from('order_items')
        .select('*, products(name, image_url)')
        .eq('order_id', widget.orderId);

    if (!mounted) return;

    setState(() {
      _order = response;
      _orderItems = itemsResponse;
      _isLoading = false;
    });

    // Load location in background (don't block UI)
    if (_order!['rider_id'] != null) {
      _subscribeToRiderLocation(_order!['rider_id']);
    }
  }

  void _subscribeToOrderUpdates() {
    SupabaseService.client
        .channel('public:orders:id=eq.${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, 
            column: 'id', 
            value: widget.orderId
          ),
          callback: (payload) {
            if (!mounted) return;
            setState(() {
              _order = payload.newRecord;
            });
            // If rider is assigned and we aren't tracking yet
            if (payload.newRecord['rider_id'] != null && _riderLocation == null) {
              _subscribeToRiderLocation(payload.newRecord['rider_id']);
            }
          },
        )
        .subscribe();
  }

  Future<void> _subscribeToRiderLocation(String riderId) async {
    print("📍 Subscribing to location for Rider ID: $riderId");
    
    // 1. Initial Fetch
    try {
      final data = await SupabaseService.client
        .from('rider_locations')
        .select()
        .eq('rider_id', riderId)
        .order('last_updated', ascending: false) // Get latest
        .limit(1) // Force single row
        .maybeSingle();
      
      print("📍 Initial Location Data: $data");

      if (data != null && mounted) {
          setState(() { _riderLocation = data; });
      } else {
          print("⚠️ No location data found for rider in DB.");
      }
    } catch (e) {
      print("❌ Error fetching initial location: $e");
    }

    // 2. Realtime Subscription
    SupabaseService.client
        .channel('public:rider_locations:rider_id=eq.$riderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rider_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, 
            column: 'rider_id', 
            value: riderId
          ),
          callback: (payload) {
             print("📡 Realtime Location Update: ${payload.newRecord}");
             if (payload.newRecord != null && mounted) {
               setState(() {
                 _riderLocation = payload.newRecord;
               });
             }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final status = _order!['status'];
    // Refined Logic (Map Mode): If status implies rider activity AND rider is assigned, we show Map View (or Map Loader)
    // This prevents layout shift.
    final shouldShowMap = (status != 'delivered' && status != 'pending' && _order!['rider_id'] != null);
    
    
    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.orderId}')),
      body: Column(
        children: [
          // status stepper
          if (status != 'delivered')
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusIcon('pending', Icons.receipt_long, "Placed"),
                _buildStatusIcon('confirmed', Icons.kitchen, "Preparing"),
                _buildStatusIcon('out_for_delivery', Icons.delivery_dining, "On Way"),
                _buildStatusIcon('delivered', Icons.home_filled, "Delivered"),
              ],
            ),
          ),
          
          if (status == 'delivered')
             Expanded(
               child: Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     const Icon(Icons.check_circle, color: Colors.green, size: 80),
                     const SizedBox(height: 20),
                     const Text("Order Delivered!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 10),
                     Text("Time Taken: ${_calculateTimeTaken()}", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                     const SizedBox(height: 30),
                     const Text("Thank you for ordering with us.", style: TextStyle(fontSize: 16)),
                   ],
                 ),
               )
             )
          else if (shouldShowMap)
            Expanded(
              child: _riderLocation == null 
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(), 
                        SizedBox(height: 10), 
                        Text("Locating Rider...")
                      ],
                    )
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(_riderLocation!['lat'], _riderLocation!['lng']),
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.quickcomm.user_app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_riderLocation!['lat'], _riderLocation!['lng']),
                            width: 60,
                            height: 60,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black26)]),
                                  child: Icon(Icons.delivery_dining, color: Theme.of(context).primaryColor, size: 30),
                                ),
                                Container(
                                    color: Colors.white, 
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: const Text("Rider", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
            )
          else 
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        status == 'pending' ? Icons.hourglass_top : 
                        status == 'confirmed' ? Icons.soup_kitchen :
                        status == 'delivered' ? Icons.check_circle_outline : Icons.watch_later_outlined, 
                        size: 80, 
                        color: Colors.grey[300]
                    ),
                    const SizedBox(height: 20),
                    Text(
                      status == 'pending' ? 'Waiting for Confirmation...' :
                      status == 'confirmed' ? 'Chef is Preparing your meal!' :
                      status == 'out_for_delivery' ? 'Rider is on the way!' :
                      'Order Delivered!',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // Order Details
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0,4))]
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                const Text("Order Items", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
                                const Divider(),
                                ...(_orderItems ?? []).map((item) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                        children: [
                                            Text("${item['quantity']}x", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                                            const SizedBox(width: 10),
                                            Expanded(child: Text(item['products']?['name'] ?? 'Item')),
                                            Text("₹${item['price_at_time']}"),
                                        ],
                                    ),
                                )),
                                const Divider(),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        const Text("Total Amount", style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text("₹${_order!['total_amount']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).primaryColor)),
                                    ],
                                )
                            ],
                        ),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _calculateTimeTaken() {
     try {
       if (_order == null) return "N/A";
       final created = DateTime.parse(_order!['created_at']);
       final updated = DateTime.parse(_order!['updated_at']);
       final diff = updated.difference(created);
       return "${diff.inMinutes} mins";
     } catch (e) {
       return "N/A";
     }
  }

  Widget _buildStatusIcon(String stepStatus, IconData icon, String label) {
    final currentStatus = _order!['status'];
    final steps = ['pending', 'confirmed', 'out_for_delivery', 'delivered'];
    final currentIndex = steps.indexOf(currentStatus);
    final stepIndex = steps.indexOf(stepStatus);
    
    final isActive = stepIndex <= currentIndex;
    
    return Column(
      children: [
        CircleAvatar(
            backgroundColor: isActive ? Theme.of(context).primaryColor : Colors.grey[200],
            radius: 20,
            child: Icon(icon, color: isActive ? Colors.white : Colors.grey, size: 20),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(color: isActive ? Colors.black : Colors.grey, fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}
