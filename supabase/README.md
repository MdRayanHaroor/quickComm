# Supabase Database & Migrations

This folder contains the database schema, security policies, triggers, and migrations for the QuickComm suite.

---

## 1. Setting Up from Scratch (New Project / Fresh Clone)

If you are cloning this repository or creating a brand-new Supabase project:

1. Open your Supabase Project Dashboard -> **SQL Editor**.
2. Open [`schema.sql`](./schema.sql) from this folder.
3. Paste and run the entire script.

> **What `schema.sql` includes:**
> - All tables: `profiles`, `stores`, `brands`, `categories`, `products`, `product_variants`, `orders`, `order_items`, `customers`, `customer_addresses`, `rider_locations`, `rider_location_history`, `rider_daily_stats`, `store_settings`.
> - All Row-Level Security (RLS) policies.
> - PostgreSQL triggers (automatic location history logging, new auth user sync to profiles, updated_at timestamps, stock deduction RPCs).
> - Supabase Realtime channel publications (`rider_locations`, `orders`, `profiles`, `rider_daily_stats`, `store_settings`).
> - Default store settings (ID=1) with coordinates, opening hours, and delivery radius defaults.
> - Storage Buckets (`product-images`, `category-images`, `brand-logos`) with public read and admin upload policies.

4. *(Optional Catalog Seed)*: Run [`migrations/p3_supermarket_product_catalog.sql`](./migrations/p3_supermarket_product_catalog.sql) to pre-seed standard Indian grocery categories (Fruits, Dairy, Beverages, Snacks) and brands.

---

## 2. Incremental Migrations (Existing Database)

If you already have a running database and need to bring it up to date with the latest features:

| Migration File | Description |
| :--- | :--- |
| [`add_delivered_at_to_orders.sql`](./migrations/add_delivered_at_to_orders.sql) | Adds `delivered_at` timestamp to orders |
| [`add_rider_location_fields.sql`](./migrations/add_rider_location_fields.sql) | Adds speed, heading, and accuracy to rider locations |
| [`p2_location_history_and_cleanup.sql`](./migrations/p2_location_history_and_cleanup.sql) | Adds audit trail table `rider_location_history` and auto-logging trigger |
| [`p3_supermarket_product_catalog.sql`](./migrations/p3_supermarket_product_catalog.sql) | Multi-variant catalog (`product_variants`, `brands`, `categories`) & stock RPCs |
| [`p4_order_payment_fields.sql`](./migrations/p4_order_payment_fields.sql) | Extended order payment status, fees, discounts, and item snapshots |
| [`p5_customer_addresses.sql`](./migrations/p5_customer_addresses.sql) | Multiple saved delivery addresses table (`customer_addresses`) |
| [`p6_store_settings_extend.sql`](./migrations/p6_store_settings_extend.sql) | Store settings extensions (`is_open`, `delivery_radius_km`, operating hours) |
| [`p7_rider_stats_and_profile_fixes.sql`](./migrations/p7_rider_stats_and_profile_fixes.sql) | `rider_daily_stats` (attendance/online hours), `profiles.must_change_password`, and ensures default `store_settings` row 1 |
| [`p8_store_closed_reason_and_cart_items.sql`](./migrations/p8_store_closed_reason_and_cart_items.sql) | **[LATEST]** Adds `store_settings.closed_reason` and persistent `cart_items` table with RLS |
