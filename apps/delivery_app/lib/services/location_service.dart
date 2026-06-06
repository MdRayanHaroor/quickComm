import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;

  // ─── Kalman Filter State ─────────────────────────────────────
  // Simple 1D Kalman filter applied independently to lat and lng.
  // Higher Q = faster response to real movement, less smoothing.
  // Lower Q = more smoothing, slower to converge on destination.
  // Q=0.008 is tuned for delivery riding (5–40 km/h, updates every 3s).

  double? _kfLat;
  double? _kfLng;
  double _kfP = 1.0;
  static const double _kfQ = 0.008; // Raised from 0.0001 for faster convergence

  // ─── Speed Validation (teleport guard only) ──────────────────
  // Rejects GPS jumps that imply physically impossible speed.
  // NOTE: Stationary jitter gate removed — GPS-reported speed is unreliable
  // at low velocities on Android and was incorrectly suppressing real movement.
  double? _lastSentLat;
  double? _lastSentLng;
  DateTime? _lastPositionTime;
  static const double _maxReasonableSpeed = 60.0; // m/s (~216 km/h)

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

    // Reset Kalman filter state on each new session
    _kfLat = null;
    _kfLng = null;
    _kfP = 1.0;
    _lastSentLat = null;
    _lastSentLng = null;
    _lastPositionTime = null;

    late LocationSettings locationSettings;

    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,   // Send every fix — accuracy over bandwidth
        // forceLocationManager intentionally omitted → enables Google FLP
        // (fuses GPS + WiFi + cell + accelerometer for ~5–10m accuracy)
        intervalDuration: const Duration(seconds: 3), // Update every 3s
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Rider App",
          notificationText: "Broadcasting location...",
          notificationIcon: AndroidResource(name: 'ic_launcher'),
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _processPosition(riderId, position);
    }, onError: (e) {
      print("❌ Location Stream Error: $e");
    });
  }

  /// Full processing pipeline for each GPS position update.
  /// Order: Accuracy Filter → Teleport Guard → Kalman Filter (or raw bypass) → Upsert
  void _processPosition(String riderId, Position position) {
    // ── Step 1: Accuracy Filter ──────────────────────────────────
    // Skip readings with poor horizontal accuracy (indoors, urban canyons).
    // 30m threshold — tighter than before for better quality input.
    if (position.accuracy > 30) {
      print("⚠️ Skipping inaccurate GPS (accuracy: ${position.accuracy.toStringAsFixed(1)}m > 30m)");
      return;
    }

    // ── Step 2: Teleport Guard ───────────────────────────────────
    // Reject GPS jumps that imply physically impossible speed.
    final now = DateTime.now();
    if (_lastSentLat != null && _lastPositionTime != null) {
      final elapsedSeconds = now.difference(_lastPositionTime!).inMilliseconds / 1000.0;
      if (elapsedSeconds > 0) {
        final distMeters = _haversineDistance(
          _lastSentLat!, _lastSentLng!,
          position.latitude, position.longitude,
        );
        final impliedSpeed = distMeters / elapsedSeconds;
        if (impliedSpeed > _maxReasonableSpeed) {
          print("⚠️ Rejecting GPS teleport (implied speed: ${impliedSpeed.toStringAsFixed(1)} m/s)");
          return;
        }
      }
    }

    // ── Step 3: Kalman Filter (with high-accuracy bypass) ────────
    // If GPS accuracy is very good (< 10m), trust the raw reading directly.
    // This ensures the marker snaps precisely to destination when the rider
    // arrives, instead of the filter lagging 30–50m behind.
    double filteredLat;
    double filteredLng;

    if (position.accuracy < 10.0) {
      // High-confidence reading — skip filter, use raw GPS directly.
      // Resets Kalman state so next lower-quality reading doesn't drag back.
      filteredLat = position.latitude;
      filteredLng = position.longitude;
      _kfLat = position.latitude;
      _kfLng = position.longitude;
      _kfP = position.accuracy * position.accuracy;
      print("📍 High-accuracy bypass (${position.accuracy.toStringAsFixed(1)}m): using raw GPS directly");
    } else {
      final r = position.accuracy * position.accuracy; // measurement noise variance

      if (_kfLat == null || _kfLng == null) {
        _kfLat = position.latitude;
        _kfLng = position.longitude;
        _kfP = r;
        filteredLat = position.latitude;
        filteredLng = position.longitude;
      } else {
        _kfP = _kfP + _kfQ;                      // Predict: covariance grows
        final k = _kfP / (_kfP + r);             // Kalman gain
        _kfLat = _kfLat! + k * (position.latitude  - _kfLat!);  // Update lat
        _kfLng = _kfLng! + k * (position.longitude - _kfLng!);  // Update lng
        _kfP   = (1.0 - k) * _kfP;               // Update covariance
        filteredLat = _kfLat!;
        filteredLng = _kfLng!;
      }
      print("📍 Kalman filtered (${position.accuracy.toStringAsFixed(1)}m): "
            "raw=(${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}) "
            "→ filtered=(${filteredLat.toStringAsFixed(6)},${filteredLng.toStringAsFixed(6)})");
    }

    // Track what we last sent (for stationary gate + teleport guard)
    _lastSentLat = filteredLat;
    _lastSentLng = filteredLng;
    _lastPositionTime = now;

    // Send filtered position to Supabase
    _updateLocation(riderId, filteredLat, filteredLng, position);
    _checkGeofences(position);
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

  Future<void> _updateLocation(
    String riderId,
    double filteredLat,
    double filteredLng,
    Position rawPosition,
  ) async {
    try {
      await SupabaseService.client.from('rider_locations').upsert({
        'rider_id': riderId,
        'order_id': _activeOrderId,
        'lat': filteredLat,           // Kalman-filtered position
        'lng': filteredLng,           // Kalman-filtered position
        'speed': rawPosition.speed >= 0 ? rawPosition.speed : 0,
        'heading': rawPosition.heading >= 0 ? rawPosition.heading : 0,
        'accuracy': rawPosition.accuracy, // Raw accuracy for display circle in user_app
        'last_updated': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'rider_id');
    } catch (e) {
      print("❌ Error upserting location: $e");
    }
  }
}
