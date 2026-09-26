# QuickComm — Manual Testing Checklist

This guide provides step-by-step instructions to manually test and verify all newly implemented production hardening features:
- **Task 8.3:** Admin-Only Endpoint Protection & Access Control
- **Task 8.2:** Server-Side Input Validation
- **Task 8.5:** Consistent Error Response Format
- **Task 8.6:** Rate Limiting on Binary Upload Endpoints
- **Task 8.1:** Supabase Storage CDN Caching Headers
- **Task 8.7:** PostgreSQL Full-Text Search (`tsvector`)

---

> [!IMPORTANT]
> **Windows Shell Syntax Note (CMD vs PowerShell):**
> * **In Windows Command Prompt (`cmd.exe`):** Single quotes `'` are NOT treated as string delimiters. You **must** use outer double quotes and escape inner double quotes with backslashes:
>   `-d "{\"name\":\"Test\"}"`
>   *(Using single quotes `'{"name":"Test"}'` in CMD strips inner quotes and sends malformed JSON, producing a `422 JSON decode error` before reaching auth checks).*
> * **In PowerShell / macOS / Linux:** Single quotes work directly:
>   `-d '{"name":"Test"}'`
> * Both shells are supported below with explicit examples for each command.

---

## Prerequisites

1. **Start Backend Server:**
   ```powershell
   cd d:\quickComm-Full\quickComm\backend
   uvicorn main:app --reload --port 8000
   ```
   *Base URL:* `http://localhost:8000`

2. **Start Admin Panel:**
   ```powershell
   cd d:\quickComm-Full\quickComm\apps\admin_panel
   npm run dev
   ```
   *Admin Panel URL:* `http://localhost:5173` (or port shown in terminal)

3. **Obtain Admin Token:**
   * Log in to the Admin Panel (`http://localhost:5173`).
   * Press **F12** -> Open **Console** -> Run:
     ```js
     (await (await import('./src/supabaseClient.ts')).supabase.auth.getSession()).data.session.access_token
     ```
   * Or in **Application tab** -> **Local Storage** -> `sb-<project-id>-auth-token` -> copy `access_token`.

---

## Test Suite 1: Admin-Only Endpoint Protection (Task 8.3)

### Test 1.1: Unauthenticated Write Request is Rejected (401)
* **Goal:** Verify that calling administrative write endpoints without a token fails with 401.

* **Windows Command Prompt (`cmd.exe`):**
  ```cmd
  curl -i -X POST http://localhost:8000/products/ -H "Content-Type: application/json" -d "{\"name\":\"Hacker Product\",\"store_id\":1}"
  ```

* **PowerShell / Bash:**
  ```powershell
  curl -i -X POST http://localhost:8000/products/ -H "Content-Type: application/json" -d '{"name":"Hacker Product","store_id":1}'
  ```

* **Expected Result:**
  * **HTTP Status:** `HTTP/1.1 401 Unauthorized`
  * **Response Body:**
    ```json
    {
      "success": false,
      "detail": "Authentication required. Please provide a valid Bearer token.",
      "error": {
        "code": "UNAUTHORIZED",
        "message": "Authentication required. Please provide a valid Bearer token.",
        "status_code": 401
      }
    }
    ```

---

### Test 1.2: Invalid Token is Rejected (401)

* **Windows Command Prompt (`cmd.exe`):**
  ```cmd
  curl -i -X POST http://localhost:8000/categories/ -H "Authorization: Bearer invalid_garbage_token" -H "Content-Type: application/json" -d "{\"name\":\"Test Cat\",\"slug\":\"test-cat\"}"
  ```

* **PowerShell / Bash:**
  ```powershell
  curl -i -X POST http://localhost:8000/categories/ -H "Authorization: Bearer invalid_garbage_token" -H "Content-Type: application/json" -d '{"name":"Test Cat","slug":"test-cat"}'
  ```

* **Expected Result:**
  * **HTTP Status:** `HTTP/1.1 401 Unauthorized`
  * **Response Message:** `"Invalid or expired authentication token."`

---

### Test 1.3: Non-Admin Token is Rejected (403)
* **Goal:** Verify that a regular customer or rider token cannot create/edit admin resources.

* **Windows Command Prompt (`cmd.exe`):**
  ```cmd
  curl -i -X POST http://localhost:8000/brands/ -H "Authorization: Bearer <CUSTOMER_OR_RIDER_TOKEN>" -H "Content-Type: application/json" -d "{\"name\":\"Rider Brand\"}"
  ```

* **PowerShell / Bash:**
  ```powershell
  curl -i -X POST http://localhost:8000/brands/ -H "Authorization: Bearer <CUSTOMER_OR_RIDER_TOKEN>" -H "Content-Type: application/json" -d '{"name":"Rider Brand"}'
  ```

* **Expected Result:**
  * **HTTP Status:** `HTTP/1.1 403 Forbidden`
  * **Response Message:** `"Access denied: Admin privileges required."`

---

### Test 1.4: Valid Admin Token Succeeds (200/201)

* **Method A (Admin Panel UI):**
  1. Open `http://localhost:5173` and log in as an Admin.
  2. Navigate to **Categories** or **Brands**.
  3. Click **Add Brand** -> Enter "Dairy Fresh" -> Save.
  4. Open DevTools (F12) **Network tab** -> Click the `POST /brands/` request -> Verify `Authorization: Bearer <token>` was automatically attached by Axios interceptor and returned `201 Created`.

* **Method B (Windows Command Prompt `cmd.exe`):**
  ```cmd
  curl -i -X POST http://localhost:8000/brands/ -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d "{\"name\":\"Test Brand Verified\"}"
  ```

* **Method C (PowerShell):**
  ```powershell
  curl -i -X POST http://localhost:8000/brands/ -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d '{"name":"Test Brand Verified"}'
  ```

* **Expected Result:** `HTTP/1.1 201 Created` with created brand JSON object.

---

### Test 1.5: Public Endpoints Remain Accessible Without Authentication
* **Goal:** Verify that shoppers and visitors can browse products and categories without any token.

* **Commands (both shells):**
  ```cmd
  curl -i http://localhost:8000/products/
  curl -i http://localhost:8000/categories/
  curl -i http://localhost:8000/categories/tree
  curl -i http://localhost:8000/brands/
  ```
* **Expected Result:** All return `HTTP/1.1 200 OK`.

---

## Test Suite 2: Server-Side Input Validation (Task 8.2)

*(Pass your valid admin token `<ADMIN_TOKEN>` in each command below)*

### Test 2.1: Blank / Empty Name Validation

* **Windows Command Prompt (`cmd.exe`):**
  ```cmd
  curl -X POST http://localhost:8000/categories/ -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d "{\"name\":\"   \",\"slug\":\"blank-slug\"}"
  ```

* **PowerShell:**
  ```powershell
  curl -X POST http://localhost:8000/categories/ -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d '{"name":"   ","slug":"blank-slug"}'
  ```

* **Expected Result:**
  * **HTTP Status:** `422 Unprocessable Entity`
  * **Error Details:** `"Category name cannot be empty"`.

---

### Test 2.2: Selling Price Exceeds MRP Validation

* **Windows Command Prompt (`cmd.exe`):**
  ```cmd
  curl -X POST http://localhost:8000/products/1/variants -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d "{\"variant_name\":\"1L Pack\",\"mrp\":50.0,\"selling_price\":85.0,\"product_id\":1}"
  ```

* **PowerShell:**
  ```powershell
  curl -X POST http://localhost:8000/products/1/variants -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d '{"variant_name":"1L Pack","mrp":50.0,"selling_price":85.0,"product_id":1}'
  ```

* **Expected Result:**
  * **HTTP Status:** `422 Unprocessable Entity`
  * **Error Details:** `"selling_price (85.0) cannot exceed mrp (50.0)"`.

---

### Test 2.3: Negative Price or Stock Validation

* **Windows Command Prompt (`cmd.exe`):**
  ```cmd
  curl -X POST http://localhost:8000/products/1/variants -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d "{\"variant_name\":\"Negative Test\",\"mrp\":-10.0,\"selling_price\":-5.0,\"stock_quantity\":-20,\"product_id\":1}"
  ```

* **PowerShell:**
  ```powershell
  curl -X POST http://localhost:8000/products/1/variants -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d '{"variant_name":"Negative Test","mrp":-10.0,"selling_price":-5.0,"stock_quantity":-20,"product_id":1}'
  ```

* **Expected Result:**
  * **HTTP Status:** `422 Unprocessable Entity`
  * **Error Details:** Rejects negative mrp and negative stock.

---

### Test 2.4: Invalid GST Rate Validation

* **Windows Command Prompt (`cmd.exe`):**
  ```cmd
  curl -X POST http://localhost:8000/products/ -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d "{\"name\":\"GST Test\",\"gst_rate\":9.0}"
  ```

* **PowerShell:**
  ```powershell
  curl -X POST http://localhost:8000/products/ -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d '{"name":"GST Test","gst_rate":9.0}'
  ```

* **Expected Result:**
  * **HTTP Status:** `422 Unprocessable Entity`
  * **Error Details:** `"Invalid GST rate 9.0. Allowed rates: 0, 5, 12, 18, 28"`.

---

### Test 2.5: Zero-Quantity Stock Adjustment Validation

* **Windows Command Prompt (`cmd.exe`):**
  ```cmd
  curl -X POST http://localhost:8000/inventory/adjust -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d "{\"adjustments\":[{\"variant_id\":1,\"quantity\":0}]}"
  ```

* **PowerShell:**
  ```powershell
  curl -X POST http://localhost:8000/inventory/adjust -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d '{"adjustments":[{"variant_id":1,"quantity":0}]}'
  ```

* **Expected Result:**
  * **HTTP Status:** `422 Unprocessable Entity`
  * **Error Details:** `"Adjustment quantity cannot be zero"`.

---

### Test 2.6: Short Password for Rider Creation

* **Windows Command Prompt (`cmd.exe`):**
  ```cmd
  curl -X POST http://localhost:8000/admin/riders/ -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d "{\"full_name\":\"Rider Test\",\"email\":\"rider123@quickcomm.com\",\"password\":\"123\"}"
  ```

* **PowerShell:**
  ```powershell
  curl -X POST http://localhost:8000/admin/riders/ -H "Authorization: Bearer <ADMIN_TOKEN>" -H "Content-Type: application/json" -d '{"full_name":"Rider Test","email":"rider123@quickcomm.com","password":"123"}'
  ```

* **Expected Result:**
  * **HTTP Status:** `422 Unprocessable Entity`
  * **Error Details:** Password must be at least 6 characters.

---

## Test Suite 3: Consistent Error Handling Format (Task 8.5)

### Test 3.1: Verify Standardized JSON Error Structure
* Run any validation or auth test above.
* **Observe Response Structure:**
  ```json
  {
    "success": false,
    "detail": "Descriptive error message",
    "error": {
      "code": "STATUS_OR_ERROR_CODE",
      "message": "Descriptive error message",
      "status_code": 422,
      "details": [ ... ]
    }
  }
  ```
* *Verify:*
  1. `"success": false` is present.
  2. `"detail"` string is retained for backward-compatible frontend checks.
  3. `"error.code"` and `"error.message"` are populated.

---

## Test Suite 4: Rate Limiting on Binary File Uploads (Task 8.6)

### Test 4.1: Normal Single Upload Works (200)
* In Admin Panel -> Edit any product -> Attach/upload a single image.
* **Expected Result:** Image uploads normally and displays thumbnail preview.

---

### Test 4.2: Rate Limit Trigger on Rapid Batch Uploads (429)
* **Goal:** Verify that more than 15 binary uploads within 60 seconds are blocked.

* **PowerShell Script:**
  ```powershell
  "test image content" | Out-File -FilePath test_upload.jpg
  $TOKEN = "<ADMIN_TOKEN>"
  1..18 | ForEach-Object {
    $code = curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8000/upload/category/1/image -H "Authorization: Bearer $TOKEN" -F "file=@test_upload.jpg;type=image/jpeg"
    Write-Host "Upload #$_ -> HTTP Status: $code"
  }
  Remove-Item test_upload.jpg
  ```

* **Expected Result:**
  * Uploads 1 through 15 return `200` (or `404` if category 1 does not exist, but allowed past limiter).
  * Uploads 16, 17, and 18 return **`HTTP 429 Too Many Requests`**.
  * Response body contains:
    ```json
    {
      "success": false,
      "detail": "Upload rate limit exceeded. Maximum 15 image uploads per minute allowed. Please try again shortly.",
      "error": {
        "code": "TOO_MANY_REQUESTS",
        "message": "Upload rate limit exceeded..."
      }
    }
    ```
  * Response header includes `Retry-After: 60`.

---

### Test 4.3: External Image URLs are NOT Rate-Limited
* In Admin Panel -> Edit product -> Type an external image URL in the URL input box -> Click Save.
* **Expected Result:** Saves directly to database without hitting `/upload/` binary endpoints or triggering rate limit.

---

## Test Suite 5: Supabase Storage CDN Caching Headers (Task 8.1)

### Test 5.1: Verify Cache-Control Header on Uploaded Asset
1. Upload an image in the Admin Panel to any product or category.
2. In the Network tab, copy the image's public URL (or right-click the thumbnail and click "Copy image address").
3. Inspect HTTP response headers:
   ```cmd
   curl -I "<COPIED_IMAGE_URL>"
   ```
4. **Expected Result:**
   * Response contains:
     ```http
     Cache-Control: 31536000
     ```
   * Or `cache-control: max-age=31536000, public` from the Supabase edge CDN.

---

## Test Suite 6: PostgreSQL Full-Text Search (Task 8.7)

### Step 6.1: Run Database Migration in Supabase
1. Open your Supabase Dashboard -> **SQL Editor**.
2. Open [`supabase/migrations/p11_products_full_text_search.sql`](file:///d:/quickComm-Full/quickComm/supabase/migrations/p11_products_full_text_search.sql).
3. Paste and click **RUN**.
4. *Verify:* Success message: `ALTER TABLE`, `CREATE FUNCTION`, `CREATE TRIGGER`, `CREATE INDEX` executed.

### Step 6.2: Test Search Query via API
* **Test Search Query:**
  ```cmd
  curl -s "http://localhost:8000/products/?search=milk"
  ```
  * *Observe:* Returns all matching milk products.
* **Test Stemming / Word Variations:**
  Searching `"milks"` matches `"milk"`; searching `"biscuits"` matches `"biscuit"`.
* **Test in Admin Panel UI:**
  1. Open Admin Panel -> **Products** page.
  2. Type in the search box.
  3. *Observe:* Table filters instantaneously with sub-millisecond full-text response.
* **Fallback Verification:**
  Even before `p11` is run on any database, the endpoint automatically falls back to `ILIKE` pattern matching without failing.

---

## Summary Checklist

| # | Test Area | Status | Verified By |
|---|---|---|---|
| 1 | Admin endpoints reject unauthenticated calls (401) | [ ] Pass | |
| 2 | Admin endpoints reject non-admin roles (403) | [ ] Pass | |
| 3 | Admin Panel UI attaches Bearer token automatically | [ ] Pass | |
| 4 | Public endpoints (`/products/`, `/categories/`, `/brands/`) accessible without auth | [ ] Pass | |
| 5 | Validation rejects empty names, negative prices, price > MRP | [ ] Pass | |
| 6 | Error responses follow standardized `{ success, detail, error }` shape | [ ] Pass | |
| 7 | Binary file uploads enforce 15 req/min rate limit (429) | [ ] Pass | |
| 8 | External image URLs bypass upload rate limiter | [ ] Pass | |
| 9 | Uploaded images have 1-year `cache-control` header | [ ] Pass | |
| 10 | Migration `p11` creates `search_vector` and GIN index | [ ] Pass | |
| 11 | Full-text search returns ranked results with fallback | [ ] Pass | |
