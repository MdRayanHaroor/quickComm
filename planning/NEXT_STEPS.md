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

---

## 4. Cart Items Database Persistence (Supabase / PostgreSQL)

*Scheduled immediately after User App and Rider App redesigns (Phase 5 & Phase 6).*

### Cross-Device Cart Persistence & Sync
*   **Goal:** Save cart items in Supabase PostgreSQL (analogous to how `orders` and `order_items` are stored), allowing users to access their cart across devices, preventing cart loss on app restart/device swap, and giving store managers abandoned cart analytics.
*   **Technical Details:**
    *   **Database Schema:**
        *   Create `cart_items` table:
            *   `id`: BigInt / UUID Primary Key
            *   `user_id`: UUID FK -> `auth.users(id)` ON DELETE CASCADE
            *   `product_id`: BigInt FK -> `products(id)` ON DELETE CASCADE
            *   `variant_id`: BigInt FK -> `product_variants(id)` ON DELETE CASCADE
            *   `quantity`: Integer NOT NULL CHECK (quantity > 0)
            *   `created_at`: `timestamptz DEFAULT now()`
            *   `updated_at`: `timestamptz DEFAULT now()`
        *   Add `UNIQUE(user_id, variant_id)` constraint.
        *   Enable Row Level Security (RLS) with policies restricting access strictly to `auth.uid() = user_id`.
    *   **Sync & Hydration Logic (`apps/user_app/lib/providers/cart_provider.dart`):**
        *   **On App Launch / Auth State Change:** If user is logged in, fetch `cart_items` joined with `products` and `product_variants` to populate state.
        *   **Guest Cart Migration:** When an anonymous/guest user signs in or registers, push their local device cart to Supabase via a `merge_guest_cart` RPC function to preserve everything they added before logging in.
        *   **Debounced Writes:** To maintain 60/120fps UI responsiveness when users rapidly tap `+` / `-`, update local in-memory state instantly, then debounce writes to Supabase by 400ms.
        *   **Checkout & Post-Order Cleanup:** When order checkout succeeds, run atomic deletion of `cart_items WHERE user_id = current_user.id`.