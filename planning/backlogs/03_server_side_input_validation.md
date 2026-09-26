# 03 — Server-Side Input Validation (Task 8.2)

## Objective
Enforce strict validation on all incoming request payloads across Pydantic schemas and router handlers to guarantee database consistency, prevent logic errors (such as negative stock or inverted pricing), and reject malformed inputs before database queries run.

---

## 1. Problem Statement
Client-side form validation (in React or Flutter) can be bypassed by direct API calls or broken due to client-side bugs. Missing server-side constraints can lead to:
- Empty strings or whitespace-only product/category names.
- Negative numbers for MRP, selling prices, or stock counts.
- `selling_price` set higher than `mrp`.
- Invalid GST tax rates.
- Unsanitized file uploads and oversized binaries.

---

## 2. Technical Implementation

### A. Pydantic Models (`backend/models.py`)
1. **Name & Text Fields:**
   - Trimming whitespace and enforcing minimum length (`min_length=1`).
2. **Pricing & Variants (`ProductVariantBase`, `ProductVariantUpdate`):**
   - `mrp >= 0.0`
   - `selling_price >= 0.0`
   - `selling_price <= mrp` cross-field validator.
   - `stock_quantity >= 0`
   - `low_stock_alert >= 0`
3. **GST Rate:**
   - Permitted rates: `[0.0, 5.0, 12.0, 18.0, 28.0]`.
4. **Stock Adjustment (`StockAdjust`):**
   - `quantity != 0` (preventing zero-delta no-op adjustments).
5. **Rider User Request (`CreateRiderRequest`):**
   - `password` length minimum 6 characters.
   - Non-empty `full_name`.

### B. Uploads Router (`backend/routers/uploads.py`)
- MIME type check restricted to `{image/jpeg, image/png, image/webp, image/gif}`.
- Max file size ceiling enforced at 5 MB.
- File extension sanitization.
