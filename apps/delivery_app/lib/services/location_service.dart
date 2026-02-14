import 'dart:async';
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

    // Platform specific settings for background/foreground usage
    late LocationSettings locationSettings;

    if (const bool.fromEnvironment('dart.library.io') && (await Geolocator.checkPermission() != LocationPermission.denied)) {
         locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
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
            distanceFilter: 0,
        );
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      print("📍 Location Update: ${position.latitude}, ${position.longitude}");
      _updateLocation(riderId, position);
    }, onError: (e) {
      print("❌ Location Stream Error: $e");
    });
  }

  void stopBroadcasting() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  int? _activeOrderId;

  void setActiveOrder(int? orderId) {
    _activeOrderId = orderId;
  }

  Future<void> _updateLocation(String riderId, Position position) async {
    try {
      // Upsert location
      await SupabaseService.client.from('rider_locations').upsert({
        'rider_id': riderId,
        'order_id': _activeOrderId,
        'lat': position.latitude,
        'lng': position.longitude,
        'last_updated': DateTime.now().toUtc().toIso8601String()
      }, onConflict: 'rider_id');
    } catch (e) {
      print("❌ Error upserting location: $e");
    }
  }
}
