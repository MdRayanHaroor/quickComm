import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // Ensure this dependency is added or use simple intent
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isOnline = false;
  final LocationService _locationService = LocationService();
  String? _riderId;
  Map<String, dynamic>? _activeOrder;

  @override
  void initState() {
    super.initState();
    _riderId = SupabaseService.client.auth.currentUser?.id;
    WakelockPlus.enable(); // Keep screen on for delivery
    _fetchActiveOrder();
    _subscribeToNewOrders();
  }

  Future<void> _fetchActiveOrder() async {
    if (_riderId == null) return;
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select()
          .eq('rider_id', _riderId!)
          .neq('status', 'delivered') 
          .neq('status', 'cancelled')
          .limit(1)
          .maybeSingle();
      
      if (mounted) {
        setState(() {
          _activeOrder = response;
        });
        
        // Update Location Service with active order
        if (_activeOrder != null) {
            _locationService.setActiveOrder(_activeOrder!['id']);
        } else {
            _locationService.setActiveOrder(null);
        }
      }
    } catch (e) {
      print("Error fetching active order: $e");
    }
  }

  Future<void> _markDelivered() async {
      if (_activeOrder == null) return;
      try {
          await SupabaseService.client
              .from('orders')
              .update({'status': 'delivered'})
              .eq('id', _activeOrder!['id']);
          
          _fetchActiveOrder(); // Refresh
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Delivered!')));
      } catch(e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
  }

  void _subscribeToNewOrders() {
    if (_riderId == null) return;
    SupabaseService.client
        .channel('public:orders:rider_id=eq.$_riderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, 
            column: 'rider_id', 
            value: _riderId!
          ),
          callback: (payload) {
             _fetchActiveOrder(); // Refresh on assignment
          },
        )
        .subscribe();
  }

  Future<void> _launchMaps(String? address, double? lat, double? lng) async {
    Uri url;
    if (lat != null && lng != null) {
      url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    } else if (address != null) {
      final query = Uri.encodeComponent(address);
      url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    } else {
      return;
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
    }
  }

  @override
  void dispose() {
    if (_isOnline) {
      _locationService.stopBroadcasting();
    }
    WakelockPlus.disable();
    super.dispose();
  }

  void _toggleOnline() async {
    if (_riderId == null) return;

    if (_isOnline) {
      _locationService.stopBroadcasting();
      setState(() => _isOnline = false);
    } else {
      try {
        await _locationService.startBroadcasting(_riderId!);
        setState(() => _isOnline = true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchActiveOrder,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (_isOnline) _toggleOnline();
              await SupabaseService.client.auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false
              );
            },
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               // Active Order Card
               if (_activeOrder != null)
                 Card(
                   color: Colors.orange.shade50,
                   elevation: 4,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   child: Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text("ACTIVE ORDER", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                         const Divider(),
                         Text("Order #${_activeOrder!['id']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                         const SizedBox(height: 10),
                         Text("${_activeOrder!['delivery_address']}", style: const TextStyle(fontSize: 16)),
                         const SizedBox(height: 15),
                         Row(
                           children: [
                             Expanded(
                               child: ElevatedButton.icon(
                                 onPressed: () => _launchMaps(
                                   _activeOrder!['delivery_address'],
                                   _activeOrder!['delivery_lat'],
                                   _activeOrder!['delivery_lng']
                                 ),
                                 icon: const Icon(Icons.map),
                                 label: const Text("Navigate"),
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                               ),
                             ),
                           ],
                         ),
                         const SizedBox(height: 10),
                         SizedBox(
                             width: double.infinity,
                             child: ElevatedButton.icon(
                                 onPressed: _markDelivered,
                                 icon: const Icon(Icons.check_circle),
                                 label: const Text("Mark Delivered"),
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                             )
                         )
                       ],
                     ),
                   ),
                 )
               else 
                 const Card(
                   child: Padding(
                     padding: EdgeInsets.all(20.0),
                     child: Text("No active orders assigned."),
                   ),
                 ),

               const SizedBox(height: 40),

               Icon(
                 _isOnline ? Icons.circle : Icons.circle_outlined,
                 size: 80,
                 color: _isOnline ? Colors.green : Colors.grey,
               ),
               const SizedBox(height: 10),
               Text(_isOnline ? "You are ONLINE" : "You are OFFLINE", style: Theme.of(context).textTheme.headlineMedium),
               const SizedBox(height: 20),
               ElevatedButton(
                 onPressed: _toggleOnline,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: _isOnline ? Colors.red : Colors.green,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)
                 ),
                 child: Text(_isOnline ? "GO OFFLINE" : "GO ONLINE"),
               ),
            ],
          ),
        ),
      ),
    );
  }
}
