import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;

  Future<void> startBroadcasting(String riderId) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    // Fetch store location once for geofence checks
    await _fetchStoreLocation();

    // Platform specific settings for background/foreground usage
    late LocationSettings locationSettings;

    if (Platform.isAndroid) {
         locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            forceLocationManager: true,
            intervalDuration: const Duration(seconds: 10),
            // Foreground notification config
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: "Rider App",
              notificationText: "Broadcasting location to admin...",
              notificationIcon: AndroidResource(name: 'ic_launcher'),
            ),
        );
    } else {
        locationSettings = const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
        );
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // Skip inaccurate GPS readings (e.g. indoors, urban canyons)
      if (position.accuracy > 50) {
        print("⚠️ Skipping inaccurate GPS reading (accuracy: ${position.accuracy.toStringAsFixed(1)}m)");
        return;
      }
      print("📍 Location Update: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy.toStringAsFixed(1)}m)");
      _updateLocation(riderId, position);
      _checkGeofences(position);
    }, onError: (e) {
      print("❌ Location Stream Error: $e");
    });
  }

  void stopBroadcasting() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  // ─── Active Order & Geofence State ───────────────────────────

  int? _activeOrderId;
  double? _deliveryLat;
  double? _deliveryLng;
  double? _storeLat;
  double? _storeLng;

  // Geofence thresholds (meters)
  static const double _storeGeofenceRadius = 150;
  static const double _deliveryGeofenceRadius = 200;

  // Prevent duplicate geofence triggers
  bool _hasTriggeredNearStore = false;
  bool _hasTriggeredNearDelivery = false;

  // Callback for geofence events (set by dashboard_screen)
  void Function(String event, int orderId)? onGeofenceEvent;

  void setActiveOrder(int? orderId, {double? deliveryLat, double? deliveryLng}) {
    _activeOrderId = orderId;
    _deliveryLat = deliveryLat;
    _deliveryLng = deliveryLng;
    // Reset geofence triggers for new order
    _hasTriggeredNearStore = false;
    _hasTriggeredNearDelivery = false;
  }

  Future<void> _fetchStoreLocation() async {
    try {
      final data = await SupabaseService.client
          .from('store_settings')
          .select('lat, lng')
          .eq('id', 1)
          .maybeSingle();
      if (data != null) {
        _storeLat = data['lat'];
        _storeLng = data['lng'];
        print("🏪 Store location loaded: $_storeLat, $_storeLng");
      }
    } catch (e) {
      print("❌ Error fetching store location: $e");
    }
  }

  // ─── Geofence Checks ────────────────────────────────────────

  void _checkGeofences(Position position) {
    if (_activeOrderId == null) return;

    // Check proximity to store
    if (!_hasTriggeredNearStore && _storeLat != null && _storeLng != null) {
      final distToStore = _haversineDistance(
        position.latitude, position.longitude,
        _storeLat!, _storeLng!,
      );
      if (distToStore <= _storeGeofenceRadius) {
        _hasTriggeredNearStore = true;
        print("🏪 GEOFENCE: Rider arrived at store (${distToStore.toStringAsFixed(0)}m)");
        onGeofenceEvent?.call('near_store', _activeOrderId!);
      }
    }

    // Check proximity to delivery address
    if (!_hasTriggeredNearDelivery && _deliveryLat != null && _deliveryLng != null) {
      final distToDelivery = _haversineDistance(
        position.latitude, position.longitude,
        _deliveryLat!, _deliveryLng!,
      );
      if (distToDelivery <= _deliveryGeofenceRadius) {
        _hasTriggeredNearDelivery = true;
        print("📦 GEOFENCE: Rider near delivery address (${distToDelivery.toStringAsFixed(0)}m)");
        onGeofenceEvent?.call('near_delivery', _activeOrderId!);
      }
    }
  }

  /// Haversine formula — calculates distance in meters between two lat/lng points
  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  // ─── Location Upsert ────────────────────────────────────────

  Future<void> _updateLocation(String riderId, Position position) async {
    try {
      // Upsert location with enriched GPS data
      await SupabaseService.client.from('rider_locations').upsert({
        'rider_id': riderId,
        'order_id': _activeOrderId,
        'lat': position.latitude,
        'lng': position.longitude,
        'speed': position.speed >= 0 ? position.speed : 0, // m/s, -1 means unavailable
        'heading': position.heading >= 0 ? position.heading : 0, // degrees 0-360
        'accuracy': position.accuracy,
        'last_updated': DateTime.now().toUtc().toIso8601String()
      }, onConflict: 'rider_id');
    } catch (e) {
      print("❌ Error upserting location: $e");
    }
  }
}
