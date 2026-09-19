import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/delivery_service.dart';

class LocationProvider extends ChangeNotifier with WidgetsBindingObserver {
  Position? _currentPosition;
  bool _isLocationPermissionGranted = false;
  bool _isLoading = false;
  RealtimeChannel? _storeSettingsChannel;
  Timer? _periodicSyncTimer;

  List<Map<String, dynamic>> _savedAddresses = [];
  Map<String, dynamic>? _selectedAddress;

  double? _distanceMeters;
  int _etaMinutes = 12;

  double? _storeLat;
  double? _storeLng;
  bool _isStoreOpen = true;
  String? _closedReason;

  Position? get currentPosition => _currentPosition;
  bool get isLocationPermissionGranted => _isLocationPermissionGranted;
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get savedAddresses => _savedAddresses;
  Map<String, dynamic>? get selectedAddress => _selectedAddress;
  double? get distanceMeters => _distanceMeters;
  int get etaMinutes => _etaMinutes;
  bool get isStoreOpen => _isStoreOpen;
  String? get closedReason => _closedReason;

  /// Formatted distance: shows in meters if < 1 km, otherwise in km.
  String? get formattedDistance {
    if (_distanceMeters == null) return null;
    if (_distanceMeters! < 1000) {
      return '${_distanceMeters!.round()} m';
    } else {
      final km = _distanceMeters! / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Formatted ETA string with lightning emoji
  String get formattedEta {
    return '$_etaMinutes MINS';
  }

  /// Formatted address or current location label for the AppBar
  String get displayAddressLabel {
    if (_selectedAddress != null) {
      final label = _selectedAddress!['label']?.toString() ?? 'Home';
      final line = _selectedAddress!['address_line1']?.toString() ??
          _selectedAddress!['address_line']?.toString() ??
          '';
      if (line.isNotEmpty) {
        return '$label - $line';
      }
      return label;
    }

    if (_isLocationPermissionGranted && _currentPosition != null) {
      return 'Current Location';
    }

    return 'Select Location';
  }

  LocationProvider() {
    WidgetsBinding.instance.addObserver(this);
    init();
    _startPeriodicSync();
  }

  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadStoreCoordinates(forceRefresh: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed: refreshing store settings');
      refreshStoreSettings();
      _startPeriodicSync();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _periodicSyncTimer?.cancel();
    }
  }

  Future<void> init() async {
    await _loadStoreCoordinates();
    _subscribeToStoreSettings();
    await checkPermissionAndFetchLocation();
    await loadSavedAddresses();
  }

  Future<void> _loadStoreCoordinates({bool forceRefresh = false}) async {
    try {
      final settings = await DeliveryService.getStoreSettings(forceRefresh: forceRefresh);
      if (settings != null) {
        _storeLat = (settings['lat'] as num?)?.toDouble();
        _storeLng = (settings['lng'] as num?)?.toDouble();
        _isStoreOpen = settings['is_open'] as bool? ?? true;
        _closedReason = settings['closed_reason']?.toString();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshStoreSettings() async {
    if (_periodicSyncTimer == null || !_periodicSyncTimer!.isActive) {
      _startPeriodicSync();
    }
    await _loadStoreCoordinates(forceRefresh: true);
  }

  Future<void> checkPermissionAndFetchLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isLocationPermissionGranted = false;
        notifyListeners();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _isLocationPermissionGranted = false;
        notifyListeners();
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _isLocationPermissionGranted = false;
        notifyListeners();
        return;
      }

      _isLocationPermissionGranted = true;
      await fetchCurrentPosition();
    } catch (_) {
      _isLocationPermissionGranted = false;
      notifyListeners();
    }
  }

  Future<bool> requestLocationPermission() async {
    _isLoading = true;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _isLocationPermissionGranted = false;
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _isLocationPermissionGranted = false;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLocationPermissionGranted = true;
      await fetchCurrentPosition();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchCurrentPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      _currentPosition = pos;
      _recalculateDistanceAndEta();
      notifyListeners();
    } catch (_) {
      // If timed out, try last known position
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _currentPosition = last;
          _recalculateDistanceAndEta();
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  Future<void> loadSavedAddresses() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await SupabaseService.client
          .from('customer_addresses')
          .select()
          .eq('user_id', user.id)
          .order('is_default', ascending: false);

      _savedAddresses = List<Map<String, dynamic>>.from(response);

      // Auto-select default address if none selected
      if (_selectedAddress == null && _savedAddresses.isNotEmpty) {
        _selectedAddress = _savedAddresses.firstWhere(
          (addr) => addr['is_default'] == true,
          orElse: () => _savedAddresses.first,
        );
      }

      _recalculateDistanceAndEta();
      notifyListeners();
    } catch (_) {
      // Fallback try with customer_id if user_id fails
      try {
        final response = await SupabaseService.client
            .from('customer_addresses')
            .select()
            .eq('customer_id', user.id)
            .order('is_default', ascending: false);
        _savedAddresses = List<Map<String, dynamic>>.from(response);
        if (_selectedAddress == null && _savedAddresses.isNotEmpty) {
          _selectedAddress = _savedAddresses.first;
        }
        _recalculateDistanceAndEta();
        notifyListeners();
      } catch (_) {}
    }
  }

  void selectAddress(Map<String, dynamic>? address) {
    _selectedAddress = address;
    _recalculateDistanceAndEta();
    notifyListeners();
  }

  void useCurrentGpsLocation() {
    _selectedAddress = null;
    _recalculateDistanceAndEta();
    notifyListeners();
  }

  Future<bool> addNewAddress({
    required String label,
    required String addressLine1,
    String? addressLine2,
    String? landmark,
    String? pincode,
    bool isDefault = false,
  }) async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ LocationProvider.addNewAddress: User is null (not logged in)');
      return false;
    }

    try {
      final lat = _currentPosition?.latitude;
      final lng = _currentPosition?.longitude;

      final insertData = {
        'user_id': user.id,
        'label': label,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'landmark': landmark,
        'pincode': pincode,
        'is_default': isDefault || _savedAddresses.isEmpty,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

      debugPrint('💾 LocationProvider.addNewAddress: Inserting $insertData');
      final inserted = await SupabaseService.client
          .from('customer_addresses')
          .insert(insertData)
          .select()
          .single();

      debugPrint('✅ LocationProvider.addNewAddress: Saved address id=${inserted['id']}');
      _savedAddresses.insert(0, inserted);
      _selectedAddress = inserted;
      _recalculateDistanceAndEta();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ LocationProvider.addNewAddress failed: $e');
      return false;
    }
  }

  void _recalculateDistanceAndEta() {
    double? targetLat;
    double? targetLng;

    if (_selectedAddress != null) {
      targetLat = (_selectedAddress!['lat'] as num?)?.toDouble();
      targetLng = (_selectedAddress!['lng'] as num?)?.toDouble();
    }

    if ((targetLat == null || targetLng == null) && _currentPosition != null) {
      targetLat = _currentPosition!.latitude;
      targetLng = _currentPosition!.longitude;
    }

    if (targetLat != null &&
        targetLng != null &&
        _storeLat != null &&
        _storeLng != null) {
      _distanceMeters = Geolocator.distanceBetween(
        _storeLat!,
        _storeLng!,
        targetLat,
        targetLng,
      );

      final distanceKm = _distanceMeters! / 1000.0;
      // 5-7 mins store picking & packing + 2.5 mins per km travel
      _etaMinutes = (6 + (distanceKm * 2.5)).round().clamp(8, 45);
    } else {
      _distanceMeters = null;
      _etaMinutes = 12; // Standard fallback
    }
  }

  void _subscribeToStoreSettings() {
    try {
      if (_storeSettingsChannel != null) {
        SupabaseService.client.removeChannel(_storeSettingsChannel!);
      }
      _storeSettingsChannel = SupabaseService.client
          .channel('public:store_settings_feed')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'store_settings',
            callback: (payload) {
              debugPrint('⚡ Realtime store_settings change received: ${payload.newRecord}');
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                if (newRecord.containsKey('is_open')) {
                  _isStoreOpen = newRecord['is_open'] as bool? ?? true;
                }
                if (newRecord.containsKey('closed_reason')) {
                  _closedReason = newRecord['closed_reason']?.toString();
                }
                notifyListeners();
              }
            },
          );
      _storeSettingsChannel!.subscribe((status, [error]) {
        debugPrint('⚡ store_settings realtime status: $status ${error ?? ""}');
      });
    } catch (e) {
      debugPrint('Realtime store_settings error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicSyncTimer?.cancel();
    if (_storeSettingsChannel != null) {
      try {
        SupabaseService.client.removeChannel(_storeSettingsChannel!);
      } catch (_) {}
    }
    super.dispose();
  }
}
