# 01 — Admin-Only Endpoint Protection (Task 8.3)

## Objective
Ensure that administrative write endpoints (products CRUD, categories, brands, variants, inventory adjustments, rider user creation, and file uploads) are strictly restricted to authenticated administrators, while keeping browsing endpoints open for customers and delivery operations unblocked for riders.

---

## 1. Problem & Vulnerability Analysis
- **Frontend State:** The React Admin Panel UI strictly checks `profile.role === 'admin'` in `Login.tsx` and wraps all private pages in `ProtectedRoute.tsx`.
- **Backend Vulnerability:** The FastAPI backend endpoints in `backend/routers/` use `admin_supabase` (service role) to bypass DB RLS, but previously did NOT verify caller identity or role. Anyone with the API URL could send POST/PUT/DELETE commands without authentication.
- **Client Transport:** The Axios client in `apps/admin_panel/src/api.ts` did not send authorization headers.

---

## 2. Scope & Endpoint Categorization

### A. Protected Endpoints (Admin Only)
These require a valid Supabase JWT Bearer token where `profiles.role == 'admin'`:
- **Products:** `POST /products/`, `PUT /products/{id}`, `DELETE /products/{id}`, `POST /products/bulk-import`
- **Variants:** `POST /products/{id}/variants`, `PUT /products/{id}/variants/{variant_id}`, `DELETE /products/{id}/variants/{variant_id}`, `PATCH /products/{id}/variants/{variant_id}/stock`
- **Categories:** `POST /categories/`, `PUT /categories/{id}`, `DELETE /categories/{id}`
- **Brands:** `POST /brands/`, `PUT /brands/{id}`, `DELETE /brands/{id}`
- **Inventory:** `GET /inventory/all`, `GET /inventory/summary`, `GET /inventory/low-stock`, `GET /inventory/out-of-stock`, `POST /inventory/adjust`
- **Riders:** `GET /admin/riders/`, `POST /admin/riders/`, `PUT /admin/riders/{id}`, `DELETE /admin/riders/{id}`
- **File Uploads:** `POST /upload/product/{id}/image`, `DELETE /upload/product/{id}/image`, `POST /upload/category/{id}/image`, `POST /upload/brand/{id}/logo`

### B. Public / Customer Endpoints (Unrestricted for browsing)
- `GET /products/`, `GET /products/{id}`
- `GET /categories/`, `GET /categories/tree`, `GET /categories/{id}`
- `GET /brands/`, `GET /brands/{id}`
- `GET /products/{id}/variants`
- `POST /orders/` (Order placement for customer app)
- `GET /orders/`, `GET /orders/{id}`, `PUT /orders/{id}/status`, `POST /orders/{id}/cancel`

---

## 3. Technical Implementation
1. **FastAPI Auth Dependency (`backend/auth.py`):**
   - Implements `get_current_admin` using `HTTPBearer`.
   - Extracts token from `Authorization: Bearer <token>`.
   - Calls `admin_supabase.auth.get_user(token)`.
   - Queries `profiles` for `role == 'admin'`.
   - Raises `401 Unauthorized` for missing/invalid tokens, and `403 Forbidden` for non-admin users.
2. **Axios Token Interceptor (`apps/admin_panel/src/api.ts`):**
   - Automatically retrieves the active session access token via `supabase.auth.getSession()` on every request and attaches `Authorization: Bearer <token>`.
