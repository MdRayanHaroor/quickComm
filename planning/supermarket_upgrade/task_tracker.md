# Task Tracker — Supermarket Upgrade

---

## Phase 1 — Database Foundation

- [x] **1.1** `p3_supermarket_product_catalog.sql` — stores, brands, categories, products ALTER, product_variants, seeds
- [x] **1.2** `p4_order_payment_fields.sql` — orders and order_items enhancements, RPCs
- [x] **1.3** `p5_customer_addresses.sql` — customer addresses table
- [x] **1.4** `p6_store_settings_extend.sql` — store config columns
- [ ] **1.5** Create Supabase Storage buckets (`product-images`, `category-images`, `brand-logos`) — **MANUAL STEP IN SUPABASE CONSOLE**
- [ ] **1.6** Run migrations `p3`–`p6` in Supabase SQL Editor — **MANUAL STEP IN SUPABASE SQL EDITOR**

## Phase 2 — Backend API

- [x] **2.1** Updated `backend/models.py` — all new models + `Union[Category, str]` backward compatibility & price fallbacks
- [x] **2.2** Created `backend/routers/categories.py` — with `admin_supabase` (RLS bypass)
- [x] **2.3** Created `backend/routers/brands.py` — with `admin_supabase` (RLS bypass)
- [x] **2.4** Rewrote `backend/routers/products.py` — filters, pagination, variant enrichment, auto-slug generation, safe category resolution
- [x] **2.5** Created `backend/routers/variants.py` — variant CRUD, stock adjustments
- [x] **2.6** Created `backend/routers/uploads.py` — Supabase Storage integration
- [x] **2.7** Created `backend/routers/inventory.py` — low stock, out of stock, stock history
- [x] **2.8** Updated `backend/routers/orders.py` — variant support, stock decrement, snapshot capture
- [x] **2.9** Updated `backend/main.py` — all new routers registered
- [x] **2.10** Updated `backend/requirements.txt` — `python-multipart`

## Phase 3 — Admin Panel Products & Catalogue UI

- [x] **3.1** `index.css` — Blinkit-style design tokens, light/dark theme tokens, card & modal system
- [x] **3.2** `Sidebar.tsx` — collapsible to icon-only mode (68px) with hover tooltips, smooth layout transition, persisted collapse state
- [x] **3.3** `ThemeContext.tsx` — light as default, clean dark class toggle without DOMTokenList errors
- [x] **3.4** `pages/Products.tsx` — table view, filters, search, sort, pagination, status toggle, variant count & price ranges
- [x] **3.5** `components/products/ProductDrawer.tsx` — chained Category & Subcategory dropdowns, auto-generated slugs, hardware-accelerated cubic-bezier animation, Escape key closing
- [x] **3.6** `components/products/ProductImageUpload.tsx` — multi-image drag-drop uploader with preview & remove
- [x] **3.7** `components/products/VariantEditor.tsx` — inline variant table with unit, MRP, selling price, stock, and barcode
- [x] **3.8** `pages/Categories.tsx` — tree view with collapsed top-level defaults, leaf rows without chevron, active/inactive toggle, Escape key closing
- [x] **3.9** `pages/Brands.tsx` — table view without redundant logo column, active/inactive toggle, centered modal, Escape key closing
- [x] **3.10** `App.tsx` — new routes registered, `/menu` → `/products` redirect

## Phase 4 — Admin Panel Operations & Polishing

- [x] **4.1** Dark mode form text visibility — bare `input, select, textarea` styled so typed text is always visible
- [x] **4.2** `StoreSettings.tsx` & `LiveMap.tsx` — theme variables connected, light/dark CartoDB map tiles (`dark_all` vs `voyager`)
- [x] **4.3** `DeliveryHistory.tsx` — single-row compact filter toolbar fitting all controls without horizontal scrolling
- [x] **4.4** Universal keyboard accessibility — Escape key closes all modals and side drawers (`ProductDrawer`, `Categories`, `Brands`, `FleetManagement`, `Menu`, `StoreSettings`, `BulkImportModal`)
- [x] **4.5** `pages/Inventory.tsx` — dedicated three-tab stock view (All Stock, Low Stock, Out of Stock, quick stock adjustment)
- [x] **4.6** Update `pages/Dashboard.tsx` — supermarket KPI stat cards with vertically stacked info, Recharts sales activity trend, and separated `pages/Orders.tsx` pipeline
- [x] **4.7** Extended Store Delivery Settings UI (min order, delivery radius, free delivery threshold, open/closed toggle, and Razorpay placeholder)
- [x] **4.8** Barcode scanner in `VariantEditor.tsx` — camera `BarcodeDetector` API + handheld USB scanner support
- [x] **4.9** Bulk Product Import — `BulkImportModal.tsx`, empty Excel/CSV template download, preview validation table, and `POST /products/bulk-import` endpoint

## Phases 5–7 — Future (Customer & Rider Apps)

- [ ] **Phase 5**: Customer App upgrade (Blinkit/Zepto UI, category browsing, variant selectors, multi-item cart)
- [ ] **Phase 6**: Rider App upgrade (itemized order checklist, item counts)
- [ ] **Phase 7**: Production verification & deployment
