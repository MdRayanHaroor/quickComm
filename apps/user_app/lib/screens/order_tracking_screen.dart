import 'dart:async';
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
  final MapController _mapController = MapController();
  Map<String, dynamic>? _order;
  List<dynamic>? _orderItems;
  Map<String, dynamic>? _riderLocation;
  bool _isLoading = true;
  
  // Subscription management
  RealtimeChannel? _riderLocationSubscription;
  Timer? _retryTimer;
  bool _isStreamError = false;

  // Configurable boolean to show/hide path
  bool _showPath = true; 

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _subscribeToOrderUpdates();
  }

@override
void dispose() {
  if (_riderLocationSubscription != null) {
    SupabaseService.client.removeChannel(_riderLocationSubscription!);
  }
  _retryTimer?.cancel();
  _mapController.dispose();
  super.dispose();
}


  Future<void> _fetchOrderDetails() async {
    try {
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

      // Start tracking if rider is assigned
      if (_order!['rider_id'] != null) {
        _subscribeToRiderLocation(_order!['rider_id']);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching order: $e")));
      }
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
            if (payload.newRecord['rider_id'] != null && _riderLocationSubscription == null) {
              _subscribeToRiderLocation(payload.newRecord['rider_id']);
            }
          },
        )
        .subscribe();
  }

  Future<void> _subscribeToRiderLocation(String riderId) async {
    // Cancel existing subscription if any
    if (_riderLocationSubscription != null) {
      await _riderLocationSubscription!.unsubscribe();
      _riderLocationSubscription = null;
    }

    _retryTimer?.cancel();

    print("📍 Starting Rider Location Subscription for $riderId (Channel API)");

    // 1. Initial Fetch
    try {
      final initialData = await SupabaseService.client
          .from('rider_locations')
          .select()
          .eq('rider_id', riderId)
          .maybeSingle(); // Use maybeSingle to avoid error if no location yet

      if (initialData != null && mounted) {
        print("📍 Initial Rider Location: ${initialData['lat']}, ${initialData['lng']}");
        setState(() {
          _riderLocation = initialData;
          _isStreamError = false;
           // Optional: Smoothly animate camera to new location
            try {
              _mapController.move(
                  LatLng(_riderLocation!['lat'], _riderLocation!['lng']), 
                  _mapController.camera.zoom
              );
            } catch (e) {
              // Controller might not be ready
            }
        });
      }
    } catch (e) {
      print("❌ Error fetching initial location: $e");
    }

    // 2. Realtime Subscription
    try {
      _riderLocationSubscription =
    SupabaseService.client.channel('rider_location_$riderId');

      
      _riderLocationSubscription!.onPostgresChanges(
          event: PostgresChangeEvent.all, // Listen to all events (INSERT/UPDATE)
          schema: 'public',
          table: 'rider_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, 
            column: 'rider_id', 
            value: riderId
          ),
          callback: (payload) {
            print("📍 Realtime Event Received: ${payload.eventType}");
            if (!mounted) return;
            
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
                 print("📍 New Location (Realtime): ${newRecord['lat']}, ${newRecord['lng']}");
                 setState(() {
                    _riderLocation = newRecord;
                     print("📍 Marker Updated: ${_riderLocation!['lat']}, ${_riderLocation!['lng']}");
                    _isStreamError = false;

                     // Optional: Smoothly animate camera to new location
                      try {
                        _mapController.move(
                            LatLng(_riderLocation!['lat'], _riderLocation!['lng']), 
                            _mapController.camera.zoom
                        );
                      } catch (e) {
                        // Controller might not be ready
                      }
                 });
            }
          },
        )
        .subscribe((status, error) {
  print("Realtime status: $status");

  if (status == RealtimeSubscribeStatus.closed) {
    print("Channel closed. Resubscribing...");
    _scheduleRetry(riderId);
  }

  if (error != null) {
    print("Realtime error: $error");
    _scheduleRetry(riderId);
  }
});

        
        // Store channel reference if needed to unsubscribe later? 
        // For Supabase generic channels, we usually just unsubscribe the client channel by name or let it clean up?
        // Actually, the Supabase Flutter SDK handles channel cleanup via .unsubscribe(). 
        // We can't store 'channel' in 'StreamSubscription' variable. 
        // We need to change the type of _riderLocationSubscription or just store the channel.
        
        // NOTE: The previous code used StreamSubscription. We should probably add a RealtimeChannel variable.
        // But to keep changes minimal and since we are using a specific variable name `_riderLocationSubscription`,
        // let's change the class variable type or manage it differently.
        // Wait, `channel.subscribe()` returns `RealtimeChannel`.
        // I will need to update the `_riderLocationSubscription` type in the class or add a new variable `_riderChannel`.
        
    } catch (e) {
        print("❌ Error initializing channel: $e");
        _scheduleRetry(riderId);
    }
  }

  void _scheduleRetry(String riderId) {
      if (!mounted) return;
      _retryTimer?.cancel();
      // Retry in 3 seconds
      _retryTimer = Timer(const Duration(seconds: 3), () {
          print("🔄 Retrying Rider Location Subscription...");
          _subscribeToRiderLocation(riderId);
      });
  }

  bool _isRiderOnline(String lastUpdatedStr) {
    try {
      final lastUpdated = DateTime.parse(lastUpdatedStr);
      final diff = DateTime.now().difference(lastUpdated);
      return diff.inMinutes < 5;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final status = _order!['status'];
    // Refined Logic (Map Mode): If status implies rider activity AND rider is assigned, we show Map View (or Map Loader)
    // This prevents layout shift.
    final shouldShowMap = (status == 'out_for_delivery');
    
    
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
          
          if (_isStreamError && shouldShowMap)
            Container(
                width: double.infinity,
                color: Colors.orangeAccent,
                padding: const EdgeInsets.all(4),
                child: const Text(
                    "Connection unstable. Reconnecting...", 
                    textAlign: TextAlign.center, 
                    style: TextStyle(fontSize: 12)
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
              child: _order!['rider_id'] == null 
                  ? const Center(child: Text("Waiting for rider assignment..."))
                  : _riderLocation == null 
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
                      : Builder(
                          builder: (context) {
                            final isOnline = _isRiderOnline(_riderLocation!['last_updated']);
                            final riderLat = _riderLocation!['lat'];
                            final riderLng = _riderLocation!['lng'];
                            final orderLat = _order!['delivery_lat'];
                            final orderLng = _order!['delivery_lng'];

                            return FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                initialCenter: LatLng(riderLat, riderLng),
                                initialZoom: 15.0,
                                ),
                                children: [
                                TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.quickcomm.user_app',
                                ),
                                
                                // Path Layer
                                if (_showPath && isOnline && orderLat != null && orderLng != null)
                                    PolylineLayer(
                                        polylines: [
                                            Polyline(
                                                points: [
                                                    LatLng(riderLat, riderLng),
                                                    LatLng(orderLat, orderLng),
                                                ],
                                                strokeWidth: 4.0,
                                                color: Colors.blue.withOpacity(0.7),
                                            )
                                        ],
                                    ),

                                // Rider Marker Layer
                                if (isOnline)
                                MarkerLayer(
                                    markers: [
                                        Marker(
                                            point: LatLng(riderLat, riderLng),
                                            width: 60,
                                            height: 60,
                                            child: Column(
                                            children: [
                                                Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [const BoxShadow(blurRadius: 5, color: Colors.black26)]),
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
                                
                                // Destination Marker
                                if (orderLat != null && orderLng != null)
                                    MarkerLayer(
                                        markers: [
                                            Marker(
                                                point: LatLng(orderLat, orderLng),
                                                width: 40,
                                                height: 40,
                                                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                            )
                                        ]
                                    )
                                ],
                            );
                          }
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
                      status == 'confirmed' ? 'Order confirmed! Food is being prepared. Waiting for rider to be assigned.' :
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
