# 07 — Manual Testing Checklist (Task 8.8)

This document is the manual verification checklist for the newly implemented production hardening tasks (8.1, 8.2, 8.3, 8.5, 8.6, 8.7).

The complete testing guide with dual Windows Command Prompt (`cmd.exe`) and PowerShell commands is maintained at the root of the repository:
👉 [**`TESTING.md`**](../../TESTING.md)

---

## Quick Reference Summary

| Test Suite | Target Feature | Tested Endpoint / Action | Expected Result |
|---|---|---|---|
| **Suite 1** | **Admin-Only Endpoint Protection (8.3)** | `POST /products/`, `POST /categories/` without token or with non-admin token | `401 Unauthorized` / `403 Forbidden` |
| **Suite 2** | **Server-Side Validation (8.2)** | Empty names, `selling_price > mrp`, negative stock/prices, invalid GST | `422 Unprocessable Entity` with field path details |
| **Suite 3** | **Consistent Error Format (8.5)** | Any HTTP/Validation/Server error | Standardized JSON: `{ success: false, detail, error: { code, message, status_code, details } }` |
| **Suite 4** | **Upload Rate Limiting (8.6)** | >15 binary uploads in 60s to `POST /upload/...` | `429 Too Many Requests` with `Retry-After` header |
| **Suite 5** | **Storage CDN Caching (8.1)** | Uploaded image via Supabase Storage | HTTP Response header `Cache-Control: 31536000` |
| **Suite 6** | **Full-Text Search (8.7)** | Migration `p11` + `GET /products/?search=...` | Sub-millisecond matching on `search_vector` GIN index with fallback |
