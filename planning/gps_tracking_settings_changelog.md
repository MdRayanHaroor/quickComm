# Rider Location Tracking — Settings Change Log

> **Purpose:** Reference document for the GPS accuracy improvements made on 2026-06-06.
> Use this to understand why each setting was changed and how to revert if needed.
> 
> File saved at: `planning/gps_tracking_settings_changelog.md`

---

## delivery_app — `lib/services/location_service.dart`

### Android Location Settings

| Parameter | Original | New | Reason |
|---|---|---|---|
| `accuracy` | `LocationAccuracy.high` | `LocationAccuracy.bestForNavigation` | Higher precision mode on Android; uses all available sensors |
| `distanceFilter` | `5` (meters) | `0` (every fix) | No distance gating — every GPS fix is sent so the user sees continuous movement |
| `intervalDuration` | `Duration(seconds: 5)` | `Duration(seconds: 3)` | More frequent updates = smoother marker movement on user's map |
| `forceLocationManager` | `true` | **removed** | `true` was bypassing Google Fused Location Provider (FLP). FLP fuses GPS + WiFi + cell towers + accelerometer for ~5–10m accuracy vs raw GPS ~20–50m |

> **To revert:**
> ```dart
> locationSettings = AndroidSettings(
>   accuracy: LocationAccuracy.high,
>   distanceFilter: 5,
>   forceLocationManager: true,   // re-add this line
>   intervalDuration: const Duration(seconds: 5),
>   ...
> );
> ```

---

### Accuracy Input Filter

| Parameter | Original | New | Reason |
|---|---|---|---|
| Accuracy threshold | `> 50m → skip` | `> 30m → skip` | Tighter threshold rejects more low-quality readings for cleaner input |

> **To revert:** Change `if (position.accuracy > 30)` back to `if (position.accuracy > 50)`

---

### Stationary Jitter Gate

| Parameter | Original | New | Reason |
|---|---|---|---|
| Gate enabled | `true` | **removed** | The gate used `position.speed < 1.0 m/s` as a condition, but GPS-reported speed on Android is unreliable at low velocities — often reads 0 m/s even when moving slowly. This caused real movement to be incorrectly suppressed, making accuracy **worse** on slow approaches |
| Speed threshold | `1.0 m/s` | N/A | — |
| Distance threshold | `3.0 m` | N/A | — |

> **To revert (add back inside `_processPosition`, before Kalman filter):**
> ```dart
> if (_lastSentLat != null && _lastSentLng != null) {
>   final distFromLast = _haversineDistance(
>     _lastSentLat!, _lastSentLng!,
>     position.latitude, position.longitude,
>   );
>   final speed = position.speed >= 0 ? position.speed : 0.0;
>   if (speed < 1.0 && distFromLast < 3.0) {
>     return; // suppress stationary jitter
>   }
> }
> ```
> Note: Only re-enable if GPS speed is reliable on the target device.

---

### Kalman Filter

| Parameter | Original | New | Reason |
|---|---|---|---|
| Process noise `Q` | `0.0001` | `0.008` | Q controls how fast the filter responds to real movement. At 0.0001 the filter was extremely sluggish — the estimated position lagged the real position by 30–50m, so the marker never reached the destination accurately. 0.008 is 80× more responsive while still smoothing noise |

> **To revert:** Change `static const double _kfQ = 0.008;` back to `static const double _kfQ = 0.0001;`

---

### High-Accuracy Bypass (NEW)

| Parameter | Original | New | Reason |
|---|---|---|---|
| Bypass threshold | none | `accuracy < 10m → skip Kalman` | When FLP gives a high-confidence reading (< 10m), the raw GPS is trusted directly and Kalman state is reset. This is critical for the destination-arrival case: the filter would otherwise lag and show the rider 30–50m from destination even after they've arrived |

> **To revert:** Remove the `if (position.accuracy < 10.0)` branch and let all readings go through the Kalman filter unconditionally.

---

## user_app — `lib/screens/order_tracking_screen.dart`

### Marker Animation Duration

| Parameter | Original | New | Reason |
|---|---|---|---|
| `_animationDuration` | `3000 ms` | `1000 ms` | 3s animation felt sluggish and introduced visual lag between real position and displayed position. 1s is snappy while still being smooth |

> **To revert:** Change `Duration(milliseconds: 1000)` back to `Duration(milliseconds: 3000)`

---

### Route Fetching Debounce

| Parameter | Original | New | Reason |
|---|---|---|---|
| `_routeFetchInterval` | `30 seconds` then `5 seconds` | **removed (0)** | Every location event now triggers a fresh OSRM route fetch. The polyline always reflects the current rider position. Note: OSRM public server rate-limits at ~1 req/s; with 3s location updates this is well within limits |

> **To revert:** Re-add the constant and guard:
> ```dart
> static const _routeFetchInterval = Duration(seconds: 5);
> DateTime? _lastRouteFetchTime;
> 
> // At the top of _fetchRoute():
> final now = DateTime.now();
> if (_lastRouteFetchTime != null &&
>     now.difference(_lastRouteFetchTime!) < _routeFetchInterval) {
>   return;
> }
> _lastRouteFetchTime = now;
> ```

---

### OSRM Bearing Parameter (removed)

| Parameter | Original | New | Reason |
|---|---|---|---|
| `bearings` param | `&bearings=$heading,45;,` | **removed** | The trailing `,` after the semicolon was invalid OSRM syntax. OSRM returned `NoRoute` when the bearing couldn't be satisfied, causing `_routePoints` to stay empty and the fallback straight-line to render. Road-following works correctly without bearings |

> **To re-add (only if needed):** The correct OSRM format for 2-waypoint bearing with empty destination is `&bearings=$heading,45;` (semicolon at end, no trailing comma). Test carefully — OSRM sometimes fails to route with a heading constraint in complex road geometries.

---

### Polyline Fallback (removed)

| Parameter | Original | New | Reason |
|---|---|---|---|
| Straight-line fallback | shown when `_routePoints.isEmpty` | **hidden** | The fallback drew a straight line across buildings while waiting for the first OSRM call. Now the polyline layer is hidden until `_routePoints.isNotEmpty`, so nothing shows until the correct road-following path is ready |

> **To revert:**
> ```dart
> points: _routePoints.isNotEmpty
>     ? _routePoints
>     : [LatLng(riderLat, riderLng), LatLng(orderLat, orderLng)],
> ```

---

## Summary — Net Effect

| Aspect | Before | After |
|---|---|---|
| GPS accuracy | ~20–50m (raw GPS, FLP disabled) | ~5–10m (FLP + bestForNavigation) |
| Marker lag | 30–50m behind real position | Snaps to real position; high-accuracy bypass removes Kalman lag |
| Stationary gate | On (incorrectly blocked slow movement) | Removed |
| Polyline on load | Straight line across buildings | Hidden until road-following path ready |
| Route refresh rate | Every 30s (original), then 5s | Every ~3s (every location event) |
| Animation speed | 3s (sluggish) | 1s (snappy) |
