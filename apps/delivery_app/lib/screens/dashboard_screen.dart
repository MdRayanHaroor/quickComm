import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'delivery_history_screen.dart';
import 'attendance_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  bool _isOnline = false;
  final LocationService _locationService = LocationService();
  String? _riderId;
  Map<String, dynamic>? _activeOrder;
  RealtimeChannel? _ordersSubscription;
  
  // Online Time Tracking
  int _onlineMinutes = 0;
  Timer? _onlineTimer;

  // Polling fallback — ensures rider never misses an order even if realtime drops
  Timer? _pollTimer;

  // Rider profile
  Map<String, dynamic>? _profile;
  bool _mustChangePassword = false;
  bool _passwordDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _riderId = SupabaseService.client.auth.currentUser?.id;
    WakelockPlus.enable(); 
    _fetchProfile();
    _fetchActiveOrder();
    _subscribeToNewOrders();
    _fetchTodayStats();
    // Poll every 15 seconds as a fallback for realtime
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchActiveOrder();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print('📱 App resumed — refreshing dashboard');
      _fetchActiveOrder();
      _fetchTodayStats();
      _resubscribeToOrders();
    }
  }

  void _resubscribeToOrders() {
    if (_ordersSubscription != null) {
      SupabaseService.client.removeChannel(_ordersSubscription!);
      _ordersSubscription = null;
    }
    _subscribeToNewOrders();
  }

  Future<void> _fetchProfile() async {
    if (_riderId == null) return;
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select('full_name, phone_number, must_change_password')
          .eq('id', _riderId!)
          .single();
      if (mounted) {
        setState(() {
          _profile = data;
          _mustChangePassword = data['must_change_password'] == true;
        });
        // Show the blocking password-change dialog after first frame
        if (_mustChangePassword && !_passwordDialogShown) {
          _passwordDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showChangePasswordDialog();
          });
        }
      }
    } catch (e) {
      print('Error fetching profile: $e');
    }
  }

  void _showChangePasswordDialog() {
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false, // Cannot dismiss without changing password
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.lock_reset, color: Colors.orange.shade600),
              const SizedBox(width: 10),
              const Text('Change Default Password'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'Your account uses a default password set by the admin. Please set a new password before continuing.',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPwdCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPwdCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        final newPwd = newPwdCtrl.text.trim();
                        final confirmPwd = confirmPwdCtrl.text.trim();

                        if (newPwd.length < 8) {
                          setDialogState(() => errorText = 'Minimum 8 characters');
                          return;
                        }
                        if (newPwd != confirmPwd) {
                          setDialogState(() => errorText = 'Passwords do not match');
                          return;
                        }

                        setDialogState(() { isLoading = true; errorText = null; });

                        try {
                          await SupabaseService.client.auth.updateUser(UserAttributes(password: newPwd));
                          await SupabaseService.client.from('profiles').update({'must_change_password': false}).eq('id', _riderId!);
                          if (mounted) {
                            setState(() => _mustChangePassword = false);
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password updated successfully! 🎉'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          setDialogState(() { isLoading = false; errorText = 'Error: $e'; });
                        }
                      },
                child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Set New Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTodayDate() {
    return DateTime.now().toIso8601String().split('T')[0];
  }

  Future<void> _fetchTodayStats() async {
    if (_riderId == null) return;
    try {
      final data = await SupabaseService.client
          .from('rider_daily_stats')
          .select('online_minutes')
          .eq('rider_id', _riderId!)
          .eq('date', _getTodayDate())
          .maybeSingle();
      
      if (mounted && data != null) {
        setState(() {
          _onlineMinutes = data['online_minutes'] as int;
        });
      }
    } catch (e) {
      print("Error fetching stats: $e");
    }
  }

  Future<void> _updateDailyStats() async {
    if (_riderId == null) return;
    try {
      await SupabaseService.client.from('rider_daily_stats').upsert({
        'rider_id': _riderId,
        'date': _getTodayDate(),
        'online_minutes': _onlineMinutes,
        'last_updated': DateTime.now().toUtc().toIso8601String()
      }, onConflict: 'rider_id, date');
    } catch (e) {
      print("Error updating stats: $e");
    }
  }

  void _startOnlineTimer() {
    _stopOnlineTimer();
    _onlineTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _onlineMinutes++;
        });
        _updateDailyStats();
      }
    });
  }

  void _stopOnlineTimer() {
    _onlineTimer?.cancel();
    _onlineTimer = null;
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
          
          _fetchActiveOrder();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Delivered!')));
      } catch(e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
  }

  void _subscribeToNewOrders() {
    if (_riderId == null) return;
    _ordersSubscription = SupabaseService.client
        .channel('public:orders:rider_id=eq.$_riderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, 
            column: 'rider_id', 
            value: _riderId!
          ),
          callback: (payload) {
             print('📦 Order realtime event: ${payload.eventType}');
             _fetchActiveOrder();
           },
        )
        .subscribe((status, error) {
          print('📡 Orders channel status: $status');
          if (error != null) {
            print('❌ Orders channel error: $error');
          }
        });
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
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    if (_isOnline) {
      _locationService.stopBroadcasting();
      _stopOnlineTimer();
      _updateDailyStats();
    }
    if (_ordersSubscription != null) {
      SupabaseService.client.removeChannel(_ordersSubscription!);
    }
    WakelockPlus.disable();
    super.dispose();
  }

  void _toggleOnline() async {
    if (_riderId == null) return;

    if (_isOnline) {
      _locationService.stopBroadcasting();
      _stopOnlineTimer();
      await _updateDailyStats();
      setState(() => _isOnline = false);
    } else {
      try {
        await _locationService.startBroadcasting(_riderId!);
        _startOnlineTimer();
        setState(() => _isOnline = true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
  
  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return "${hours}h ${mins}m";
  }

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout Confirmation'),
        content: Text(_isOnline 
          ? 'If you logout, your status will change to offline. Are you sure you want to logout?' 
          : 'Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (_isOnline) _toggleOnline();
    await SupabaseService.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Colors.orange.shade600,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: const Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _profile?['full_name'] ?? 'Rider',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    SupabaseService.client.auth.currentUser?.email ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (_mustChangePassword)
                    GestureDetector(
                      onTap: _showChangePasswordDialog,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('⚠️ Change default password', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: const Text('Dashboard'),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Delivery History'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryHistoryScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Attendance'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profile & Password'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                    },
                  ),
                ],
              ),
            ),

            // Logout at bottom
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
        ],
      ),
      drawer: _buildDrawer(),
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
               const SizedBox(height: 10),
               // Online Time Display
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 decoration: BoxDecoration(
                   color: Colors.blue.shade50,
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: Colors.blue.shade200)
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     const Icon(Icons.timer, size: 20, color: Colors.blue),
                     const SizedBox(width: 8),
                     Text(
                       "Today's Online Time: ${_formatDuration(_onlineMinutes)}",
                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                     ),
                   ],
                 ),
               ),
               
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
