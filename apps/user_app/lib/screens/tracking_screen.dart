import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/supabase_service.dart';

class TrackingScreen extends StatefulWidget {
  final int orderId;
  const TrackingScreen({super.key, required this.orderId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  String _status = 'pending';
  LatLng? _riderLocation;
  
  @override
  void initState() {
    super.initState();
    _subscribeToOrder();
  }

  void _subscribeToOrder() {
    SupabaseService.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', widget.orderId)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            final order = data.first;
             setState(() {
               _status = order['status'];
             });
             if (order['rider_id'] != null) {
               _subscribeToRiderLocation(order['rider_id']);
             }
          }
        });
  }

  void _subscribeToRiderLocation(String riderId) {
    SupabaseService.client
      .from('rider_locations')
      .stream(primaryKey: ['id'])
      .eq('rider_id', riderId)
      .listen((List<Map<String, dynamic>> data) {
        if (data.isNotEmpty) {
           final loc = data.first;
           setState(() {
             _riderLocation = LatLng(loc['lat'], loc['lng']);
           });
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.orderId}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Status: $_status', style: Theme.of(context).textTheme.headlineSmall),
          ),
          Expanded(
            child: _riderLocation == null 
              ? const Center(child: Text('Waiting for rider location...'))
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: _riderLocation!,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.bds.user_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _riderLocation!,
                          width: 80,
                          height: 80,
                          child: const Icon(Icons.motorcycle, size: 40, color: Colors.blue),
                        ),
                      ],
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}
