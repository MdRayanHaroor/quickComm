# Admin Panel UI Plan — Blinkit-Style Redesign

---

## Design Direction

**Reference:** Blinkit / Zepto admin dashboards  
**Style:** Clean, high-density, functional. Light background primary.  
**NOT:** Dark gold luxury (current). The new store serves kirana customers — functional and fast.

### New Design Tokens

```css
/* Blinkit-inspired palette */
:root {
  --brand-primary: #1BA672;      /* Blinkit green */
  --brand-dark: #158a5e;
  --brand-light: #E8F8F2;
  --brand-accent: #F8C900;       /* Zepto yellow for CTAs */

  --bg-page: #F4F5F7;            /* Light gray page bg */
  --bg-surface: #FFFFFF;
  --bg-surface-hover: #F9FAFB;

  --text-primary: #1A1A2E;       /* Near-black */
  --text-secondary: #4A5568;
  --text-muted: #9CA3AF;

  --danger: #EF4444;
  --warning: #F59E0B;
  --success: #10B981;
  --info: #3B82F6;

  --border: #E2E8F0;
  --shadow-card: 0 1px 3px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.04);
  --shadow-elevated: 0 4px 16px rgba(0,0,0,0.10);
  --radius-sm: 8px;
  --radius-md: 12px;
  --radius-lg: 16px;
}
```

---

## Page-by-Page Plan

### Page 1: Sidebar (Update)

**Current:** Restaurant icons (`FaUtensils`), gold accent  
**New:** Grocery icons, green accent, cleaner layout

```
📊 Dashboard
📦 Products          ← Renamed from "Item Management", grocery icon
  └─ All Products
  └─ Categories
  └─ Brands
🏪 Inventory         ← NEW section
  └─ Stock Overview
  └─ Low Stock Alerts
📋 Orders
🚀 Fleet & Riders
📅 Rider Attendance
📜 Delivery History
⚙️ Store Settings
```

---

### Page 2: Products Page (MAJOR REWRITE — `Menu.tsx` → `Products.tsx`)

This is the most important new page. Three main sub-views:

#### 2a. Products List View (default)

**Layout:** Table view (better for bulk management than cards)
- Columns: Image thumbnail | Name | Category | Brand | Variants count | Price range | Stock | Status | Actions
- Filters bar: Category dropdown | Brand dropdown | Status toggle | Search input
- Bulk actions: Select all | Toggle availability | Delete selected
- Pagination: 20 per page
- "Add Product" button (primary CTA)

**Product Row Example:**
```
[img] Amul Gold Full Cream Milk | Dairy > Milk | Amul | 3 variants | ₹27–₹99 | In Stock | ● Active | [Edit] [Variants] [Delete]
```

#### 2b. Add / Edit Product Form (Modal → Full page slide-in panel)

The current modal is too small for all the new fields. Use a **right-side drawer** or **full dedicated page**.

**Sections:**
1. **Basic Info** — Name, Slug (auto-generate from name), Description
2. **Classification** — Category (hierarchical dropdown), Brand (searchable dropdown), Tags (multi-select chip input)
3. **Images** — Drag-and-drop upload zone (multiple images, reorderable), shows preview thumbnails
4. **Variants** — Add/edit variants inline:
   - Variant table with: Variant Name | MRP | Selling Price | Stock | Unit | Barcode | Actions
   - "Add Variant" button adds a new row
5. **Tax & Compliance** — GST Rate selector (0% / 5% / 12% / 18% / 28%)
6. **Status** — Is Available toggle

**Validation:**
- Selling price must be ≤ MRP
- At least one variant required before saving
- Image required (warning, not blocking)

#### 2c. Categories Sub-page (`/products/categories`)

**Layout:** Split panel
- Left: Category tree (expand/collapse, drag to reorder)
- Right: Edit selected category (name, slug, image, parent)
- "Add Category" button opens inline form
- Visual tree showing parent-child relationships

**Category Card:**
```
📁 Dairy, Bread & Eggs                [Edit] [Delete]
  📂 Milk (24 products)
  📂 Curd & Yoghurt (8 products)
  📂 Bread & Bakery (15 products)
```

#### 2d. Brands Sub-page (`/products/brands`)

Simple table: Logo | Name | Products Count | Status | Actions

---

### Page 3: Inventory Page (NEW — `/inventory`)

**Priority: Medium — Phase 3**

**Layout:** Three tabs

**Tab 1: Stock Overview**
- Grid of cards by category showing total products, in-stock count, out-of-stock count
- Chart: Stock health donut per category

**Tab 2: Low Stock Alerts**
- Table: Product | Variant | Current Stock | Alert Threshold | Action (Restock)
- Color coded: Red = 0, Orange = below threshold, Green = healthy
- "Update Stock" quick inline edit

**Tab 3: Bulk Stock Update**
- CSV upload to bulk update stock quantities
- Template download link

---

### Page 4: Dashboard (Update existing)

**Keep:** Live orders table, Fleet map, revenue cards  
**Add:**
- Product stats card: Total products, out-of-stock count
- Today's top-selling products (mini chart)
- Low stock alert banner (if any variants are critical)
- Category-wise order breakdown (pie chart)

---

### Page 5: Store Settings (Extend existing `StoreSettings.tsx`)

**Current:** Just lat/lng  
**Add:**
- Store Name, Logo upload
- Store Address text
- Phone number
- Delivery configuration: Radius (km), Min order (₹), Delivery fee (₹), Free delivery above (₹)
- Operating Hours: Open/Close time, Days open (checkboxes)
- Store Open/Closed toggle (emergency override)

---

## Component Architecture

```
apps/admin_panel/src/
  components/
    Sidebar.tsx              ← Update icons + routes
    ProtectedRoute.tsx       ← No change
    ThemeContext.tsx          ← Adapt for light theme default
    ThemeToggle.tsx           ← Keep
    LiveMap.tsx              ← No change
    RiderMarker.tsx          ← No change
    StoreSettings.tsx        ← Major update
    
    products/                ← NEW folder
      ProductsTable.tsx      ← Table list view
      ProductForm.tsx        ← Add/Edit drawer
      ProductImageUpload.tsx ← Drag-drop image upload
      VariantEditor.tsx      ← Inline variant management
      CategoryTree.tsx       ← Hierarchical category editor
      BrandsTable.tsx        ← Brands management
      
    inventory/               ← NEW folder
      StockOverview.tsx
      LowStockTable.tsx
      BulkStockUpdate.tsx
    
    ui/                      ← NEW: reusable design system components
      Badge.tsx              ← Status badges (In Stock, Low Stock, etc.)
      DataTable.tsx          ← Reusable sortable table
      FilterBar.tsx          ← Search + filter row
      DrawerPanel.tsx        ← Right-side slide-in panel
      ImageDropzone.tsx      ← Reusable image upload zone
      HierarchySelect.tsx    ← Nested category dropdown
      
  pages/
    Dashboard.tsx            ← Update with new cards
    Products.tsx             ← NEW (replaces Menu.tsx)
    Categories.tsx           ← NEW
    Brands.tsx               ← NEW
    Inventory.tsx            ← NEW
    Riders.tsx               ← No change
    FleetManagement.tsx      ← No change
    RiderAttendance.tsx      ← No change
    DeliveryHistory.tsx      ← Minor (show variant names)
    Login.tsx                ← Minor UI update
    
  App.tsx                    ← Add new routes
  index.css                  ← Update design tokens
```

---

## UI/UX Standards for Admin

### Product Image Upload (Blinkit-style)
- Drag-and-drop zone with dashed border
- Shows live preview thumbnails
- First image = "primary" (shown in list views)
- Click to reorder
- Remove button (×) on each
- File validation: JPG/PNG/WebP, max 5MB each

### Variant Editor (inline table)
```
| Variant Name | MRP (₹) | Price (₹) | Discount | Stock | Unit | Actions |
|-------------|---------|-----------|----------|-------|------|---------|
| 500 ml      | 28      | 27        | 4%       | 150   | ml   | [Delete]|
| 1 L         | 54      | 52        | 4%       | 80    | l    | [Delete]|
| 2 L         | 102     | 99        | 3%       | 30    | l    | [Delete]|
[+ Add Variant]
```

### Status Badges
- `In Stock` → Green pill
- `Low Stock` → Orange pill with count
- `Out of Stock` → Red pill
- `Inactive` → Gray pill

### Category Hierarchical Dropdown
- Shows tree structure with indent levels
- "Dairy, Bread & Eggs > Milk" format in breadcrumb
- Searchable

---

## Packages to Install

```bash
# Admin Panel
npm install @dnd-kit/core @dnd-kit/sortable   # Drag-and-drop image reordering
npm install react-dropzone                     # Image upload zone
npm install react-select                       # Hierarchical/searchable dropdowns
npm install recharts                           # Dashboard charts
npm install react-hot-toast                    # Toast notifications (replace alert())
```
