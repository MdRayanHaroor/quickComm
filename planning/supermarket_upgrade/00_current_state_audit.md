# Current State Audit — QuickComm

> **Date:** September 2026  
> **Purpose:** Honest assessment of what exists before we begin the supermarket upgrade

---

## 1. Tech Stack Summary

| Layer | Technology | Status |
|---|---|---|
| Database | Supabase (PostgreSQL + RLS) | ✅ Working |
| Backend | FastAPI (Python) | ✅ Working |
| Admin Panel | React + Vite + TypeScript | ✅ Working |
| User App | Flutter | ✅ Working |
| Rider App | Flutter | ✅ Working |
| Auth | Supabase Auth | ✅ Working |
| Storage | Supabase Storage (images) | ❌ Not set up |
| Realtime | Supabase Realtime | ✅ Working (rider tracking) |

---

## 2. Current DB Schema (What Exists)

### `profiles` — User roles
```sql
id uuid, role text ('admin'|'rider'|'user'), full_name text, phone_number text, created_at
```
> Good. No changes needed here.

### `products` — The problem table
```sql
id bigint, name text, description text, size text, price numeric,
category text DEFAULT 'Main Course', image_url text, is_available boolean, created_at
```
**Problems:**
- `category` is a free-text string with no referential integrity — anyone can type anything
- `size` is free-text with hardcoded options (`Single`, `Family`, `Jumbo`) — nonsensical for groceries
- No support for **product variants** (e.g., 500ml / 1L / 2L for the same product)
- No **brand** field
- No **SKU/barcode** field
- No **unit of measure** (kg, ml, pcs, etc.)
- No **MRP** vs **selling price** distinction (discounts are common in supermarkets)
- No **stock/inventory** tracking
- `image_url` is a single string — no support for multiple product images
- No **tax** information (GST slabs are legally required in India)
- `category` default is `'Main Course'` — clearly restaurant-focused, wrong for groceries

### `orders` — Mostly fine, minor gaps
```sql
id bigint, user_id, rider_id, status, total_amount, delivery_address,
delivery_lat, delivery_lng, created_at, updated_at
```
**Problems:**
- No `delivery_fee` split out from `total_amount`
- No `discount_amount` field
- No `coupon_code` field
- No `payment_method` field
- No `payment_status` field
- No `instructions` / `delivery_notes` from customer

### `order_items` — Missing critical data
```sql
id bigint, order_id, product_id, quantity, price_at_time, created_at
```
**Problems:**
- No link to `product_variant_id` (critical for variants — you need to know WHICH size was ordered)
- No `discount_at_time` (was there a sale price at time of order?)
- No `item_name_snapshot` (if product is deleted, order history breaks)

### `store_settings` — Very basic
```sql
id int (always 1), lat float, lng float, updated_at
```
**Problems:**
- No store name, logo, address string
- No delivery radius config
- No minimum order amount config
- No operating hours

### `customers` — Duplicate of `profiles`
- Appears to be a second user table that was added separately — creates confusion with `profiles`
- Address is a single `text` field — no support for multiple saved addresses

### `rider_locations`, `rider_location_history` — Good, no changes needed

---

## 3. Current Backend API Endpoints

### Products (`/products`)
- `GET /products/` — list all (no filtering, no pagination)
- `POST /products/` — create
- `PUT /products/{id}` — update
- `DELETE /products/{id}` — delete

**Missing:**
- Filter by category
- Search by name
- Pagination
- Category endpoints entirely absent
- No image upload endpoint (just stores a URL string manually)
- No inventory endpoints

### Orders (`/orders`)
- Basic CRUD exists in `orders.py`

### Riders (`/riders`)
- Location tracking, assignment endpoints

---

## 4. Admin Panel Pages (React)

| Page | Route | What it Does |
|---|---|---|
| Login | `/` | Supabase auth login |
| Dashboard | `/dashboard` | Stats cards + live order table + map |
| Item Management | `/menu` | CRUD for products (very basic) |
| Fleet & Map | `/riders` | Live rider tracking map |
| Fleet Management | `/fleet-management` | Rider management |
| Rider Attendance | `/rider-attendance` | Attendance tracking |
| Delivery History | `/delivery-history` | Past orders |

**Problem with `/menu` (Item Management):**
- The form has `Portion Size` with options `Single / Family / Jumbo` — restaurant-specific
- Category is hardcoded as `Main Course / Starters / Drinks / Dessert` — restaurant-specific
- No image upload UI
- No inventory/stock count field
- No MRP vs selling price
- Product cards show no image
- No bulk import/export

**UI Design:**
- Current design is dark-theme, gold-accent — elegant but more suited to a premium restaurant
- For supermarket/Blinkit style: clean white/light background, green accent (`#1BA672` like Blinkit), high-density product grids, category navigation

---

## 5. Key Gaps Summary

### Must Fix (Breaking for supermarket use)
1. ❌ No proper category system (no `categories` table)
2. ❌ No product variants (one product can't have multiple sizes/prices)
3. ❌ No inventory/stock tracking
4. ❌ No brand field on products
5. ❌ No unit of measure (kg/ml/pcs)
6. ❌ No MRP vs sale price
7. ❌ Admin product UI is restaurant-themed

### Should Add (Industry Standard)
8. ❌ No sub-categories (e.g., Beverages > Juices > Cold-pressed)
9. ❌ No product images support (multi-image, Supabase Storage)
10. ❌ No GST/tax configuration
11. ❌ No search + filter in admin product list
12. ❌ No coupon/discount system
13. ❌ Multiple delivery addresses per customer
14. ❌ Store settings missing key config
15. ❌ No bulk product import (CSV)

### Nice to Have (Future)
16. ⏳ Product recommendations / "frequently bought together"
17. ⏳ Flash sale / limited-time offer system
18. ⏳ Loyalty points
19. ⏳ Reviews and ratings
