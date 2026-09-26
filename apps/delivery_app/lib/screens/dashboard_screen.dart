import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../services/sound_service.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'delivery_history_screen.dart';
import 'attendance_screen.dart';
import 'rider_order_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  bool _isOnline = false;
  final LocationService _locationService = LocationService();
  String? _riderId;

  // Active Order State
  Map<String, dynamic>? _activeOrder;
  Map<String, dynamic>? _activeCustomerProfile;
  List<dynamic> _activeOrderItems = [];
  int? _lastAlertedOrderId;
  bool _isUpdatingStatus = false;

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

    // Geofence event handler — auto-notify on proximity to store or delivery
    _locationService.onGeofenceEvent = _handleGeofenceEvent;

    // Poll every 15 seconds as a fallback for realtime
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchActiveOrder();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed — refreshing dashboard');
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
        if (_mustChangePassword && !_passwordDialogShown) {
          _passwordDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showChangePasswordDialog();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  void _showChangePasswordDialog() {
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    bool isLoading = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: AppColors.warning),
              SizedBox(width: 10),
              Text('Change Default Password'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Your account uses a default password set by the admin. Please set a new password before continuing.',
                  style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
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
                  backgroundColor: AppColors.primary,
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

                        setDialogState(() {
                          isLoading = true;
                          errorText = null;
                        });

                        try {
                          await SupabaseService.client.auth.updateUser(UserAttributes(password: newPwd));
                          await SupabaseService.client.from('profiles').update({'must_change_password': false}).eq('id', _riderId!);
                          if (mounted) {
                            setState(() => _mustChangePassword = false);
                            Navigator.of(context, rootNavigator: true).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password updated successfully! 🎉'), backgroundColor: AppColors.success),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isLoading = false;
                            errorText = 'Error: $e';
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Set New Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
      debugPrint("Error fetching stats: $e");
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
      debugPrint("Error updating stats: $e");
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

  /// Fetches active order, customer profile, items, and triggers audio alert for new orders
  Future<void> _fetchActiveOrder() async {
    if (_riderId == null) return;
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select()
          .eq('rider_id', _riderId!)
          .neq('status', 'delivered')
          .neq('status', 'cancelled')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        if (response != null) {
          final int orderId = response['id'] as int;

          // 🚨 P0 Requirement: Play sound when a new order arrives!
          if (_lastAlertedOrderId != orderId) {
            _lastAlertedOrderId = orderId;
            SoundService.instance.playNewOrderAlert();
          }

          // Fetch Customer profile
          Map<String, dynamic>? customer;
          final userId = response['user_id'];
          if (userId != null) {
            try {
              customer = await SupabaseService.client
                  .from('profiles')
                  .select('full_name, phone_number')
                  .eq('id', userId)
                  .maybeSingle();
            } catch (e) {
              debugPrint('⚠️ Could not fetch customer: $e');
            }
          }

          // Fetch Order items with product images
          List<dynamic> items = [];
          try {
            final itemsRes = await SupabaseService.client
                .from('order_items')
                .select('*, products(name, image_url)')
                .eq('order_id', orderId);
            items = List<dynamic>.from(itemsRes);
          } catch (e) {
            debugPrint('⚠️ Could not fetch items: $e');
          }

          setState(() {
            _activeOrder = response;
            _activeCustomerProfile = customer;
            _activeOrderItems = items;
          });

          _locationService.setActiveOrder(
            orderId,
            deliveryLat: response['delivery_lat']?.toDouble(),
            deliveryLng: response['delivery_lng']?.toDouble(),
          );
        } else {
          // No active order currently assigned
          if (_lastAlertedOrderId != null) {
            _lastAlertedOrderId = null;
            SoundService.instance.stopAlert();
          }
          setState(() {
            _activeOrder = null;
            _activeCustomerProfile = null;
            _activeOrderItems = [];
          });
          _locationService.setActiveOrder(null);
        }
      }
    } catch (e) {
      debugPrint("Error fetching active order: $e");
    }
  }

  void _handleGeofenceEvent(String event, int orderId) {
    if (!mounted) return;

    switch (event) {
      case 'near_store':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 You are near the store! Ready for pickup.'),
            duration: Duration(seconds: 5),
            backgroundColor: AppColors.warning,
          ),
        );
        break;
      case 'near_delivery':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 You are near the delivery address!'),
            duration: Duration(seconds: 5),
            backgroundColor: AppColors.success,
          ),
        );
        break;
    }
  }

  Future<void> _updateActiveOrderStatus(String newStatus) async {
    if (_activeOrder == null) return;
    setState(() => _isUpdatingStatus = true);
    SoundService.instance.stopAlert();

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
          .eq('id', _activeOrder!['id']);

      await _fetchActiveOrder();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'delivered' ? 'Order Delivered! 🎉' : 'Status updated to ${newStatus.toUpperCase()}!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
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
            value: _riderId!,
          ),
          callback: (payload) {
            debugPrint('📦 Order realtime event: ${payload.eventType}');
            _fetchActiveOrder();
          },
        )
        .subscribe((status, error) {
          debugPrint('📡 Orders channel status: $status');
          if (error != null) {
            debugPrint('❌ Orders channel error: $error');
          }
        });
  }

  Future<void> _launchMaps(String? address, double? lat, double? lng) async {
    Uri url;
    if (lat != null && lng != null) {
      url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    } else if (address != null && address.isNotEmpty) {
      final query = Uri.encodeComponent(address);
      url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No location coordinates available')));
      return;
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
    }
  }

  Future<void> _callCustomer(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone number not available'), backgroundColor: AppColors.warning),
      );
      return;
    }
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open dialer for $phone'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    SoundService.instance.stopAlert();
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (_isOnline) _toggleOnline();
    SoundService.instance.stopAlert();
    await SupabaseService.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // QuickComm Maroon Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _profile?['full_name'] ?? 'Delivery Partner',
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
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('⚠️ Change default password',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                    leading: const Icon(Icons.home_rounded, color: AppColors.primary),
                    title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.history_rounded, color: AppColors.primary),
                    title: const Text('Delivery History', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryHistoryScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                    title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_rounded, color: AppColors.primary),
                    title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
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
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
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
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Rider Dashboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          // Audio Mute/Unmute Toggle
          IconButton(
            icon: Icon(
              SoundService.instance.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: SoundService.instance.isMuted ? AppColors.textMuted : AppColors.primary,
            ),
            tooltip: SoundService.instance.isMuted ? 'Unmute Order Sounds' : 'Mute Order Sounds',
            onPressed: () {
              setState(() {
                SoundService.instance.setMuted(!SoundService.instance.isMuted);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(SoundService.instance.isMuted ? 'Order sound alert muted' : 'Order sound alert active 🔔'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              _fetchActiveOrder();
              _fetchTodayStats();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Sound Alerting Banner (P0: Sound Acknowledgment) ──
              if (SoundService.instance.isAlerting)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.elevatedShadow,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NEW ORDER ARRIVED! 🔔',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                            Text(
                              'Sound playing — tap to acknowledge',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            SoundService.instance.stopAlert();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Silence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              // ── Active Order Section (P0: Full Details & Customer Contact) ──
              if (_activeOrder != null)
                _buildActiveOrderCard()
              else
                _buildNoActiveOrderCard(),

              const SizedBox(height: 24),

              // ── Online / Offline Control Card ────────────────────────
              _buildOnlineStatusCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOrderCard() {
    final status = (_activeOrder!['status'] as String? ?? 'pending').toLowerCase();
    final orderId = _activeOrder!['id'];
    final deliveryAddress = _activeOrder!['delivery_address']?.toString() ?? 'No address provided';
    final deliveryLat = (_activeOrder!['delivery_lat'] as num?)?.toDouble();
    final deliveryLng = (_activeOrder!['delivery_lng'] as num?)?.toDouble();

    final customerName = _activeCustomerProfile?['full_name']?.toString() ?? 'Customer';
    final customerPhone = _activeCustomerProfile?['phone_number']?.toString();

    // Bill info
    double itemsTotal = 0;
    for (final it in _activeOrderItems) {
      final p = (it['price_at_time'] as num?)?.toDouble() ?? 0.0;
      final q = (it['quantity'] as num?)?.toInt() ?? 1;
      itemsTotal += (p * q);
    }
    final deliveryFee = (_activeOrder!['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    final grandTotal = (_activeOrder!['total_amount'] as num?)?.toDouble() ?? (itemsTotal + deliveryFee);
    final paymentMethod = (_activeOrder!['payment_method'] as String? ?? 'cod').toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Active Badge & Order #
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ACTIVE ORDER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#$orderId',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'out_for_delivery' ? AppColors.warningLight : AppColors.infoLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: status == 'out_for_delivery' ? AppColors.warning : AppColors.info,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: status == 'out_for_delivery' ? AppColors.warning : AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Customer Info Section (P0 Requirement) ─────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: const Icon(Icons.person, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        Text(
                          customerPhone != null && customerPhone.isNotEmpty ? customerPhone : 'No phone provided',
                          style: TextStyle(
                            fontSize: 12,
                            color: customerPhone != null && customerPhone.isNotEmpty ? AppColors.textSecondary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: customerPhone != null && customerPhone.isNotEmpty ? () => _callCustomer(customerPhone) : null,
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Delivery Address & Navigation ──────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deliveryAddress,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launchMaps(deliveryAddress, deliveryLat, deliveryLng),
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Navigate to Customer in Google Maps'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Ordered Items List with Images (P0 Requirement) ────────
            if (_activeOrderItems.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ORDERED ITEMS (${_activeOrderItems.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                  ),
                  Text(
                    '₹${grandTotal.toStringAsFixed(0)} ($paymentMethod)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activeOrderItems.length > 3 ? 3 : _activeOrderItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = _activeOrderItems[i];
                    final name = (it['product_name_snapshot'] ?? it['products']?['name'] ?? 'Product').toString();
                    final variant = it['variant_name_snapshot']?.toString() ?? '';
                    final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                    final price = (it['price_at_time'] as num?)?.toDouble() ?? 0.0;
                    final img = it['products']?['image_url']?.toString();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: img != null && img.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: img,
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => const Center(
                                        child: SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => const Icon(
                                        Icons.shopping_bag_outlined,
                                        color: AppColors.textMuted,
                                        size: 20,
                                      ),
                                    )
                                  : const Icon(Icons.shopping_bag_outlined, color: AppColors.textMuted, size: 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  variant.isNotEmpty ? '$variant • Qty: $qty' : 'Qty: $qty',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${(price * qty).toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_activeOrderItems.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '+ ${_activeOrderItems.length - 3} more items...',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 14),
            ],

            // ── View Full Details Button (P0 Requirement) ─────────────
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiderOrderDetailScreen(orderId: orderId),
                    ),
                  );
                  _fetchActiveOrder();
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('View Full Order Details & Receipt'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ),
            const SizedBox(height: 10),

            // ── Order Action Buttons ──────────────────────────────────
            if (status == 'rider_assigned' || status == 'preparing')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdatingStatus ? null : () => _updateActiveOrderStatus('out_for_delivery'),
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

            if (status == 'out_for_delivery')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdatingStatus ? null : () => _updateActiveOrderStatus('delivered'),
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
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
        ),
      ),
    );
  }

  Widget _buildNoActiveOrderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No active orders assigned',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Keep your status ONLINE to receive incoming delivery requests.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Icon(
            _isOnline ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
            size: 64,
            color: _isOnline ? AppColors.success : Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            _isOnline ? "You are ONLINE" : "You are OFFLINE",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            _isOnline ? "Broadcasting live GPS location & receiving orders" : "Go online to start receiving deliveries",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Online Time Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_rounded, size: 18, color: AppColors.info),
                const SizedBox(width: 8),
                Text(
                  "Today's Online Time: ${_formatDuration(_onlineMinutes)}",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.info),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Online / Offline Toggle Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _toggleOnline,
              icon: Icon(_isOnline ? Icons.power_settings_new_rounded : Icons.flash_on_rounded),
              label: Text(
                _isOnline ? "GO OFFLINE" : "GO ONLINE",
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isOnline ? AppColors.error : AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
