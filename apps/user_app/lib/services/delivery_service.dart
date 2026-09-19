import 'package:geolocator/geolocator.dart';
import 'supabase_service.dart';

class DeliveryEstimate {
  final int minutes;
  final double? distanceKm;
  final bool isDynamic;

  const DeliveryEstimate({
    required this.minutes,
    this.distanceKm,
    this.isDynamic = false,
  });

  String? get formattedDistance {
    if (distanceKm == null) return null;
    final meters = distanceKm! * 1000.0;
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${distanceKm!.toStringAsFixed(1)} km';
    }
  }

  String get displayText {
    if (isDynamic && distanceKm != null && formattedDistance != null) {
      return 'Delivery in ~$minutes mins ($formattedDistance) ⚡';
    }
    return 'Delivery in ~12 minutes ⚡';
  }
}

class DeliveryService {
  static Map<String, dynamic>? _cachedSettings;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Fetch store settings from Supabase with memory caching
  static Future<Map<String, dynamic>?> getStoreSettings({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedSettings != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedSettings;
    }

    try {
      final response = await SupabaseService.client
          .from('store_settings')
          .select()
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _cachedSettings = response;
        _cacheTimestamp = DateTime.now();
      }
      return _cachedSettings;
    } catch (e) {
      return _cachedSettings;
    }
  }

  /// Check user location permissions and obtain position safely
  static Future<Position?> getUserPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  /// Calculates dynamic ETA based on user location vs store coordinates
  /// Falls back to static ~12 minutes if permission denied or unavailable
  static Future<DeliveryEstimate> getDeliveryEstimate() async {
    try {
      final settings = await getStoreSettings();
      if (settings == null) return const DeliveryEstimate(minutes: 12);

      final storeLat = (settings['lat'] as num?)?.toDouble();
      final storeLng = (settings['lng'] as num?)?.toDouble();
      if (storeLat == null || storeLng == null) {
        return const DeliveryEstimate(minutes: 12);
      }

      final userPos = await getUserPosition();
      if (userPos == null) {
        return const DeliveryEstimate(minutes: 12);
      }

      final distanceMeters = Geolocator.distanceBetween(
        storeLat,
        storeLng,
        userPos.latitude,
        userPos.longitude,
      );

      final distanceKm = distanceMeters / 1000.0;
      // 5 mins store packing + 2.5 mins per km travel time
      final calculatedMinutes = (5 + (distanceKm * 2.5)).round().clamp(8, 45);

      return DeliveryEstimate(
        minutes: calculatedMinutes,
        distanceKm: distanceKm,
        isDynamic: true,
      );
    } catch (_) {
      return const DeliveryEstimate(minutes: 12);
    }
  }

  /// Computes delivery fee strictly from store_settings in the DB.
  /// Returns null if no delivery fee is configured in the DB (caller should omit it).
  /// Returns 0.0 if subtotal qualifies for free delivery.
  static Future<double?> getEffectiveDeliveryFee(double subtotal) async {
    final settings = await getStoreSettings();
    if (settings == null) return null;

    final feeFixed = (settings['delivery_fee_fixed'] as num?)?.toDouble();
    if (feeFixed == null) return null;

    final freeAbove = (settings['free_delivery_above'] as num?)?.toDouble();
    if (freeAbove != null && freeAbove > 0 && subtotal >= freeAbove) {
      return 0.0;
    }

    return feeFixed;
  }
}
