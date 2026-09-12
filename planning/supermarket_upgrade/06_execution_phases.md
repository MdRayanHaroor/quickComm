# Execution Phases — Master Plan

> **This is the single source of truth for execution order.**  
> Work within each phase before moving to the next.

---

## Phase Overview

```
Phase 1 — DB Foundation         (Priority: CRITICAL)
Phase 2 — Backend API           (Priority: CRITICAL)
Phase 3 — Admin Panel Products  (Priority: HIGH)
Phase 4 — Admin Panel Inventory (Priority: HIGH)
Phase 5 — User App (Flutter)    (Priority: MEDIUM)
Phase 6 — Rider App (Flutter)   (Priority: LOW - minor changes)
Phase 7 — Polish & Harden       (Priority: ONGOING)
```

---

## Phase 1 — Database Foundation ⚡

**Goal:** Get the new schema into Supabase without breaking anything existing.  
**Duration estimate:** 1-2 coding sessions  
**Dependency:** Everything else depends on this.

### Tasks

- [ ] **1.1** Create `supabase/migrations/p3_supermarket_product_catalog.sql`
  - Create `brands` table + RLS
  - Create `categories` table (with self-ref) + RLS + indexes
  - ALTER `products` table — add new columns (additive, no drops)
  - Create `product_variants` table + RLS + indexes
  - Seed default categories (supermarket tree — 3-4 top-level, ~15 sub-categories)
  - Seed sample brands (Amul, Britannia, Mother Dairy, Parle, Haldiram's)
  - Add `updated_at` auto-trigger on `products` and `product_variants`

- [ ] **1.2** Create `supabase/migrations/p4_order_payment_fields.sql`
  - ALTER `orders` — add `delivery_fee`, `discount_amount`, `coupon_code`, `payment_method`, `payment_status`, `delivery_notes`
  - ALTER `order_items` — add `variant_id`, `product_name_snapshot`, `variant_name_snapshot`, `mrp_at_time`, `discount_at_time`
  - Add `decrement_variant_stock()` RPC function
  - Add `increment_variant_stock()` RPC (for cancellations)

- [ ] **1.3** Create `supabase/migrations/p5_customer_addresses.sql`
  - Create `customer_addresses` table + RLS
  - Keep `customers.address` as fallback (don't drop)

- [ ] **1.4** Create `supabase/migrations/p6_store_settings_extend.sql`
  - ALTER `store_settings` — add all new config columns
  - UPDATE the existing row with sensible defaults

- [ ] **1.5** Create Supabase Storage buckets
  - `product-images` (public)
  - `category-images` (public)
  - `brand-logos` (public)
  - Set storage policies: public read, admin-only write

- [ ] **1.6** Data migration — migrate existing products
  - For each existing product: create a default `product_variants` row
  - Set `category_id` to "Uncategorized" for all existing products
  - Test that existing orders still return correct data via JOIN

**✅ Phase 1 complete when:** All migrations run without error, no existing data is broken, product_variants table has rows for all existing products.

---

## Phase 2 — Backend API 🔧

**Goal:** New endpoints for categories, brands, variants, inventory, image upload  
**Duration estimate:** 2-3 coding sessions  
**Dependency:** Phase 1

### Tasks

- [ ] **2.1** Update `backend/models.py`
  - Add `Category`, `CategoryCreate`, `CategoryTree` models
  - Add `Brand`, `BrandCreate` models
  - Add `ProductVariant`, `ProductVariantCreate`, `ProductVariantUpdate` models
  - Update `Product` model — add new fields, include `variants: List[ProductVariant]`
  - Update `OrderCreate` — switch to `variant_id` instead of `product_id`
  - Update `OrderItemBase` — add snapshot fields

- [ ] **2.2** Create `backend/routers/categories.py`
  - `GET /categories/` — flat list
  - `GET /categories/tree` — nested JSON tree
  - `POST /categories/` — create (admin)
  - `PUT /categories/{id}` — update (admin)
  - `DELETE /categories/{id}` — delete (admin)

- [ ] **2.3** Create `backend/routers/brands.py`
  - Full CRUD

- [ ] **2.4** Major rewrite of `backend/routers/products.py`
  - `GET /products/` — add query params: `category_id`, `brand_id`, `search`, `is_available`, `page`, `limit`, `sort`
  - `GET /products/{id}` — return with variants nested
  - `POST /products/` — create product (without variants; variants added separately)
  - `PUT /products/{id}` — update product metadata
  - `DELETE /products/{id}` — cascade deletes variants

- [ ] **2.5** Create `backend/routers/variants.py`
  - `GET /products/{product_id}/variants`
  - `POST /products/{product_id}/variants`
  - `PUT /products/{product_id}/variants/{variant_id}`
  - `DELETE /products/{product_id}/variants/{variant_id}`
  - `PATCH /products/{product_id}/variants/{variant_id}/stock`

- [ ] **2.6** Create `backend/routers/uploads.py`
  - `POST /upload/product/{product_id}/image` — upload to Supabase Storage
  - `DELETE /upload/product/{product_id}/image` — remove image
  - `POST /upload/category/{category_id}/image`
  - `POST /upload/brand/{brand_id}/logo`

- [ ] **2.7** Create `backend/routers/inventory.py`
  - `GET /inventory/low-stock`
  - `GET /inventory/out-of-stock`
  - `POST /inventory/adjust` — bulk stock adjustment

- [ ] **2.8** Update `backend/routers/orders.py`
  - `create_order` — use `variant_id`, capture snapshots, decrement stock
  - `cancel_order` — restore stock via RPC

- [ ] **2.9** Register all new routers in `backend/main.py`

- [ ] **2.10** Update `requirements.txt`
  - Add `python-multipart` (for file upload endpoints)

**✅ Phase 2 complete when:** All endpoints tested via FastAPI `/docs` swagger UI. Products with variants can be created, categories can be managed, image upload works.

---

## Phase 3 — Admin Panel: Product Catalog UI 🎨

**Goal:** Redesign the Products section of the admin panel (the main user-facing goal)  
**Duration estimate:** 3-5 coding sessions  
**Dependency:** Phase 2

### Tasks

- [ ] **3.1** Update `index.css` — New design tokens (green brand, light theme default)
- [ ] **3.2** Update `Sidebar.tsx` — New nav items, grocery icons, green styling
- [ ] **3.3** Create `src/components/ui/` — Design system components
  - `Badge.tsx`, `DataTable.tsx`, `FilterBar.tsx`, `DrawerPanel.tsx`, `ImageDropzone.tsx`, `HierarchySelect.tsx`
- [ ] **3.4** Create `src/pages/Products.tsx` — Main products table list view
  - Table with image, name, category, brand, variants, price range, stock status
  - Filter bar (search, category, brand, status)
  - Pagination
- [ ] **3.5** Create `src/components/products/ProductForm.tsx` — Add/Edit right-drawer
  - All form sections (basic info, classification, images, variants, GST, status)
  - Validates selling_price ≤ MRP
- [ ] **3.6** Create `src/components/products/ProductImageUpload.tsx` — Drag-drop uploader
  - Multiple images, preview thumbnails, reorderable, delete button
- [ ] **3.7** Create `src/components/products/VariantEditor.tsx` — Inline variant table
  - Add/edit/delete variants inline within ProductForm
  - Auto-compute discount %
- [ ] **3.8** Create `src/pages/Categories.tsx` — Category tree manager
  - Tree with expand/collapse
  - Add/Edit/Delete category
  - Image upload per category
- [ ] **3.9** Create `src/pages/Brands.tsx` — Brands table
  - Logo upload, active toggle
- [ ] **3.10** Update `App.tsx` — New routes: `/products`, `/categories`, `/brands`
- [ ] **3.11** Install new packages: `react-dropzone`, `react-select`, `react-hot-toast`, `recharts`

**✅ Phase 3 complete when:** Admin can add a product with multiple variants and images from the UI, browse by category, search by name.

---

## Phase 4 — Admin Panel: Inventory & Dashboard 📊

**Goal:** Inventory management view + updated dashboard  
**Duration estimate:** 2-3 sessions  
**Dependency:** Phase 3

### Tasks

- [ ] **4.1** Create `src/pages/Inventory.tsx` — Three-tab stock view
- [ ] **4.2** Create `src/components/inventory/LowStockTable.tsx`
- [ ] **4.3** Create `src/components/inventory/BulkStockUpdate.tsx`
- [ ] **4.4** Update `src/pages/Dashboard.tsx` — Add new stat cards, charts
- [ ] **4.5** Update `src/components/StoreSettings.tsx` — Delivery config, hours, logo

**✅ Phase 4 complete when:** Admin can see stock alerts, update stock, and has full store config control.

---

## Phase 5 — User App (Flutter) 📱

**Goal:** Upgrade the user shopping experience for grocery browsing  
**Duration estimate:** 4-6 sessions  
**Dependency:** Phase 2 backend

### Tasks

- [ ] **5.1** Category-based home screen (grid of category tiles, like Blinkit)
- [ ] **5.2** Category browse screen (product list with filters)
- [ ] **5.3** Product detail screen (image carousel, variant selector, add to cart)
- [ ] **5.4** Updated cart (shows variant name, MRP strikethrough, savings)
- [ ] **5.5** Saved addresses — select/add delivery address
- [ ] **5.6** Search screen (with autocomplete, search by product name/brand)
- [ ] **5.7** Order placement — send `variant_id` instead of `product_id`

---

## Phase 6 — Rider App (Flutter) 🛵

**Goal:** Minor updates for supermarket context  
**Duration estimate:** 1 session  
**Dependency:** Phase 5

### Tasks

- [ ] **6.1** Order detail screen — show variant names in item list (not just product names)
- [ ] **6.2** Item count badge on order card (supermarket orders can have 20+ items)

---

## Phase 7 — Production Hardening 🛡️

**Goal:** Make it production-ready  
**Duration estimate:** Ongoing

### Tasks

- [ ] **7.1** Supabase Storage CDN — ensure images have proper caching headers
- [ ] **7.2** Input validation — server-side validation for all new endpoints
- [ ] **7.3** Admin-only endpoint protection — verify role check on all write endpoints
- [ ] **7.4** Pagination on all list endpoints (no unbounded queries)
- [ ] **7.5** Error handling — consistent error response format
- [ ] **7.6** Rate limiting on upload endpoints
- [ ] **7.7** Full-text search on products — add PostgreSQL `tsvector` index
- [ ] **7.8** Write a `TESTING.md` with manual test checklist

---

## Confirmed Architecture Decisions

> Locked in — do not revisit without explicit change request.

| # | Question | Decision |
|---|---|---|
| 1 | Admin panel theme | **Light theme (Blinkit green `#1BA672`) as default.** Keep dark mode toggle so both work. |
| 2 | Image hosting | **Supabase Storage** — simple, already configured, good enough for now. |
| 3 | Existing restaurant products | **Migrate to 'Uncategorized' category** — don't delete, let admin re-categorize. |
| 4 | Multi-store/franchise | **Design for it now** — `store_id` FK on products/categories so schema is multi-tenant ready. |
| 5 | Online payments | **Show placeholder UI** in Store Settings: "Payment Gateway — Coming Soon (Razorpay)". No real integration yet. |
| 6 | Barcode scanner | **Yes — build it** in the admin product form. Use browser camera (js `BarcodeDetector` API with react-webcam fallback). |

### Impact of Multi-Store Decision on Schema

Adding `store_id` to key tables is a non-breaking additive change:
```sql
-- Add to migrations:
CREATE TABLE public.stores (
  id     bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  name   text NOT NULL,
  slug   text UNIQUE,
  owner_id uuid REFERENCES auth.users,
  created_at timestamptz DEFAULT now()
);

-- Add store_id FK to:
-- products: ADD COLUMN store_id bigint REFERENCES stores(id)
-- categories: ADD COLUMN store_id bigint REFERENCES stores(id)
-- store_settings: make it per-store (rename to stores table or keep as linked)
```
For now: one default store with `id=1`. All products/categories belong to store 1. Future: multi-tenant filtering by `store_id`.
