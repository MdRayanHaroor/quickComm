# QuickComm - Next Steps & Planning

This document tracks upcoming features and UI enhancements across the QuickComm monorepo.

---

## 1. Delivery App (Flutter)

### Improve the Current UI
*   **Goal:** Make the interface more professional, premium, and dynamic.
*   **Technical Details:** 
    *   Transition away from generic Material components to a refined, cohesive design system (custom typography, tailored colors, rounded corners).
    *   Implement subtle micro-animations for button presses and order acceptance cards using `flutter_animate` or native `AnimatedContainer`.
    *   Add skeleton loaders during Supabase data fetching rather than simple circular progress indicators.

### Delivery History Page
*   **Goal:** Allow riders to see their past deliveries and earnings.
*   **Technical Details:**
    *   Create a new `DeliveryHistoryScreen` in the `delivery_app` routing.
    *   Query the `orders` table in Supabase: `.from('orders').select('*').eq('rider_id', currentUser.id).eq('status', 'delivered')`.
    *   Implement pagination or infinite scrolling for performance if the order history is large.
    *   Build a UI listing past orders, timestamps (using `intl` for date formatting), payout/earnings per order, and total stats at the top.

---

## 2. User App (Flutter)

### Better Login Page UI
*   **Goal:** Create a "wow" first impression for users opening the app.
*   **Technical Details:**
    *   Revamp `LoginScreen` and `SignupScreen`.
    *   Introduce smooth gradient backgrounds, or a subtle Lottie animation playing in the background.
    *   Use premium form field designs (e.g., floating labels, custom focused borders, glassmorphism containers).
    *   Ensure smooth keyboard focus transitions and robust error handling toasts.

### Order Success Screen
*   **Goal:** Make the post-purchase experience more rewarding.
*   **Technical Details:**
    *   **File:** `apps/user_app/lib/screens/order_success_screen.dart`
    *   Replace the current generic network Lottie checkmark (`lf20_t24tpvcu.json`) with a higher quality, branded local asset or a more dynamic premium animation.
    *   Implement a staggered animation entrance for the "Order Placed!" text and action buttons using `TickerProviderStateMixin`.

---

## 3. Admin Panel (React/Vite)

### Map & Routing Enhancements
*   **Goal:** Provide fleet managers a clear view of an active rider's route, matching the functionality recently added to the User App.
*   **Technical Details:**
    *   **File:** `apps/admin_panel/src/components/LiveMap.tsx`
    *   **Current State:** The map only drops a polyline connecting raw historical coordinates.
    *   **Improvement:** When `selectedRiderId` is active, fetch the rider's currently assigned active order from Supabase to obtain `delivery_lat` and `delivery_lng`.
    *   **OSRM Integration:** Implement a `fetchRoute()` function in React that calls the Open Source Routing Machine (OSRM) API (`https://router.project-osrm.org/route/v1/driving/{rider_lng},{rider_lat};{delivery_lng},{delivery_lat}?overview=full&geometries=geojson`).
    *   **Rendering:** Extract the GeoJSON coordinates from the OSRM response and feed them into a React-Leaflet `<Polyline>` to display the actual street-following route from the rider to the destination.