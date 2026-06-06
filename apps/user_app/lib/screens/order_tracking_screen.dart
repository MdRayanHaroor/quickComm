import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../services/supabase_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  Map<String, dynamic>? _order;
  List<dynamic>? _orderItems;
  Map<String, dynamic>? _riderLocation;
  bool _isLoading = true;
  
  // Subscription management
  RealtimeChannel? _riderLocationSubscription;
  RealtimeChannel? _orderUpdatesSubscription;
  Timer? _retryTimer;
  bool _isStreamError = false;

  // Configurable boolean to show/hide path
  bool _showPath = true;

  // Road-following route points from OSRM
  List<LatLng> _routePoints = [];
  bool _isFetchingRoute = false;

  // ETA from OSRM
  int? _etaSeconds;
  double? _distanceMeters;

  // OSRM debounce — max 1 call per 30 seconds
  DateTime? _lastRouteFetchTime;
  static const _routeFetchInterval = Duration(seconds: 30);

  // Smooth marker animation
  LatLng? _animatedRiderPosition;
  LatLng? _animationStartPos;
  LatLng? _animationEndPos;
  Timer? _animationTimer;
  static const _animationDuration = Duration(milliseconds: 3000);
  static const _animationFrameInterval = Duration(milliseconds: 16); // ~60fps

  // Store location (for showing pickup point on map)
  LatLng? _storeLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchOrderDetails();
    _fetchStoreLocation();
    _subscribeToOrderUpdates();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App returned from background — refresh everything
      print('📱 App resumed — refreshing order tracking');
      _refreshOnResume();
    }
  }

  Future<void> _refreshOnResume() async {
    // 1. Re-fetch latest order data from DB
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('*, profiles:rider_id(full_name, phone_number)')
          .eq('id', widget.orderId)
          .single();

      if (!mounted) return;

      setState(() {
        _order = response;
      });

      // 2. Re-fetch latest rider location if rider is assigned
      if (_order!['rider_id'] != null) {
        try {
          final locData = await SupabaseService.client
              .from('rider_locations')
              .select()
              .eq('rider_id', _order!['rider_id'])
              .maybeSingle();

          if (locData != null && mounted) {
            setState(() {
              _riderLocation = locData;
              _isStreamError = false;
            });
          }
        } catch (e) {
          print('❌ Error refreshing rider location: $e');
        }
      }

      // 3. Reconnect realtime subscriptions
      _reconnectAllSubscriptions();
    } catch (e) {
      print('❌ Error refreshing order on resume: $e');
    }
  }

  void _reconnectAllSubscriptions() {
    // Tear down existing subscriptions
    if (_orderUpdatesSubscription != null) {
      SupabaseService.client.removeChannel(_orderUpdatesSubscription!);
      _orderUpdatesSubscription = null;
    }
    if (_riderLocationSubscription != null) {
      SupabaseService.client.removeChannel(_riderLocationSubscription!);
      _riderLocationSubscription = null;
    }
    _retryTimer?.cancel();

    // Re-subscribe
    _subscribeToOrderUpdates();
    if (_order != null && _order!['rider_id'] != null) {
      _subscribeToRiderLocation(_order!['rider_id']);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_riderLocationSubscription != null) {
      SupabaseService.client.removeChannel(_riderLocationSubscription!);
    }
    if (_orderUpdatesSubscription != null) {
      SupabaseService.client.removeChannel(_orderUpdatesSubscription!);
    }
    _retryTimer?.cancel();
    _animationTimer?.cancel();
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

  Future<void> _fetchStoreLocation() async {
    try {
      final data = await SupabaseService.client
          .from('store_settings')
          .select('lat, lng')
          .eq('id', 1)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _storeLocation = LatLng(data['lat'], data['lng']);
        });
      }
    } catch (e) {
      print('❌ Error fetching store location: $e');
    }
  }

  void _subscribeToOrderUpdates() {
    _orderUpdatesSubscription = SupabaseService.client
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
      SupabaseService.client.removeChannel(_riderLocationSubscription!);
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
          .maybeSingle();

      if (initialData != null && mounted) {
        print("📍 Initial Rider Location: ${initialData['lat']}, ${initialData['lng']}");
        setState(() {
          _riderLocation = initialData;
          _animatedRiderPosition = LatLng(initialData['lat'], initialData['lng']);
          _isStreamError = false;
        });
        // Move camera to initial position
        try {
          _mapController.move(
              LatLng(_riderLocation!['lat'], _riderLocation!['lng']), 
              _mapController.camera.zoom
          );
        } catch (e) {
          // Controller might not be ready
        }
        // Fetch road-following route
        _fetchRoute();
      }
    } catch (e) {
      print("❌ Error fetching initial location: $e");
    }

    // 2. Realtime Subscription
    try {
      _riderLocationSubscription =
        SupabaseService.client.channel('rider_location_$riderId')
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
            print("📍 Realtime Event Received: ${payload.eventType}");
            if (!mounted) return;
            
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
                 print("📍 New Location (Realtime): ${newRecord['lat']}, ${newRecord['lng']}");
                 setState(() {
                    _riderLocation = newRecord;
                    _isStreamError = false;
                 });
                 // Start smooth animation to new position
                 _startMarkerAnimation(
                   LatLng(newRecord['lat'], newRecord['lng'])
                 );
                 // Smoothly move camera
                 try {
                   _mapController.move(
                       LatLng(newRecord['lat'], newRecord['lng']), 
                       _mapController.camera.zoom
                   );
                 } catch (e) {
                   // Controller might not be ready
                 }
                 // Re-fetch road route (debounced)
                 _fetchRoute();
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
      return diff.inMinutes < 2; // Unified: 2 min threshold across all apps
    } catch (e) {
      return false;
    }
  }

  /// Smoothly animate the rider marker from current to target position
  void _startMarkerAnimation(LatLng target) {
    _animationTimer?.cancel();
    
    _animationStartPos = _animatedRiderPosition ?? target;
    _animationEndPos = target;
    
    final startTime = DateTime.now();
    
    _animationTimer = Timer.periodic(_animationFrameInterval, (timer) {
      final elapsed = DateTime.now().difference(startTime);
      final progress = (elapsed.inMilliseconds / _animationDuration.inMilliseconds).clamp(0.0, 1.0);
      
      // Cubic ease-out for natural deceleration
      final eased = 1.0 - pow(1.0 - progress, 3).toDouble();
      
      final newLat = _animationStartPos!.latitude + 
          (_animationEndPos!.latitude - _animationStartPos!.latitude) * eased;
      final newLng = _animationStartPos!.longitude + 
          (_animationEndPos!.longitude - _animationStartPos!.longitude) * eased;
      
      if (mounted) {
        setState(() {
          _animatedRiderPosition = LatLng(newLat, newLng);
        });
      }
      
      if (progress >= 1.0) {
        timer.cancel();
      }
    });
  }

  /// Fetches road-following route from OSRM between rider and delivery location.
  /// Debounced to max 1 call per 30 seconds to avoid rate limiting.
  Future<void> _fetchRoute() async {
    if (_isFetchingRoute) return;
    if (_riderLocation == null || _order == null) return;

    // Debounce: skip if last fetch was < 30 seconds ago
    final now = DateTime.now();
    if (_lastRouteFetchTime != null && 
        now.difference(_lastRouteFetchTime!) < _routeFetchInterval) {
      return;
    }

    final riderLat = _riderLocation!['lat'];
    final riderLng = _riderLocation!['lng'];
    final orderLat = _order!['delivery_lat'];
    final orderLng = _order!['delivery_lng'];

    if (orderLat == null || orderLng == null) return;

    _isFetchingRoute = true;
    _lastRouteFetchTime = now;

    try {
      // OSRM uses longitude,latitude order
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$riderLng,$riderLat;$orderLng,$orderLat'
        '?overview=full&geometries=polyline'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final encodedPolyline = route['geometry'] as String;
          final decoded = _decodePolyline(encodedPolyline);

          // Extract ETA and distance
          final duration = route['duration']; // seconds
          final distance = route['distance']; // meters

          if (mounted) {
            setState(() {
              _routePoints = decoded;
              _etaSeconds = (duration is num) ? duration.toInt() : null;
              _distanceMeters = (distance is num) ? distance.toDouble() : null;
            });
          }
        }
      } else {
        print('❌ OSRM API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching route: $e');
    } finally {
      _isFetchingRoute = false;
    }
  }

  /// Decodes an encoded polyline string into a list of LatLng points
  /// Uses the standard Google Polyline Algorithm
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;

      // Decode latitude
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final status = _order!['status'];
    final shouldShowMap = (status == 'out_for_delivery');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Status stepper
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

          // ETA Banner
          if (shouldShowMap && _etaSeconds != null && _riderLocation != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _etaSeconds! < 60 
                        ? 'Arriving in less than a minute'
                        : 'Arriving in ~${(_etaSeconds! / 60).ceil()} min',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Spacer(),
                  if (_distanceMeters != null)
                    Text(
                      _distanceMeters! >= 1000
                          ? '${(_distanceMeters! / 1000).toStringAsFixed(1)} km'
                          : '${_distanceMeters!.toInt()} m',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
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
                                
                                // Road-following route polyline
                                if (_showPath && isOnline && orderLat != null && orderLng != null)
                                    PolylineLayer(
                                        polylines: [
                                            Polyline(
                                                points: _routePoints.isNotEmpty
                                                    ? _routePoints
                                                    : [
                                                        LatLng(riderLat, riderLng),
                                                        LatLng(orderLat, orderLng),
                                                      ],
                                                strokeWidth: 5.0,
                                                color: Colors.blue,
                                            )
                                        ],
                                    ),

                                // Store Marker (pickup point)
                                if (_storeLocation != null)
                                    MarkerLayer(
                                        markers: [
                                            Marker(
                                                point: _storeLocation!,
                                                width: 50,
                                                height: 50,
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.pink.shade50,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [const BoxShadow(blurRadius: 5, color: Colors.black26)],
                                                        border: Border.all(color: Colors.pink, width: 2),
                                                      ),
                                                      child: const Icon(Icons.store, color: Colors.pink, size: 22),
                                                    ),
                                                    Container(
                                                      color: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                      child: const Text("Store", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                                    )
                                                  ],
                                                ),
                                            )
                                        ]
                                    ),

                                // Rider Marker Layer (uses animated position for smooth movement)
                                if (isOnline && _animatedRiderPosition != null)
                                MarkerLayer(
                                    markers: [
                                        Marker(
                                            point: _animatedRiderPosition!,
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
