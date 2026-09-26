# Backlogs & Production Hardening Plans

This folder contains detailed planning and implementation specifications for the platform-wide production hardening tasks.

## Document Index

| # | Plan Document | Feature / Hardening Area | Status |
|---|---|---|---|
| **01** | [`01_admin_endpoint_protection.md`](./01_admin_endpoint_protection.md) | Admin-only endpoint protection (FastAPI auth & role checks, Axios interceptor) | Implemented |
| **02** | [`02_supabase_storage_cdn_caching.md`](./02_supabase_storage_cdn_caching.md) | Supabase Storage CDN Caching Headers (Task 8.1) | Implemented |
| **03** | [`03_server_side_input_validation.md`](./03_server_side_input_validation.md) | Server-Side Input Validation (Task 8.2) | Implemented |
| **04** | [`04_consistent_error_handling.md`](./04_consistent_error_handling.md) | Consistent Error Handling Format (Task 8.5) | Implemented |
| **05** | [`05_rate_limiting_upload_endpoints.md`](./05_rate_limiting_upload_endpoints.md) | Rate Limiting on Binary Upload Endpoints (Task 8.6) | Implemented |
| **06** | [`06_full_text_search_products.md`](./06_full_text_search_products.md) | PostgreSQL `tsvector` Full-Text Search on Products (Task 8.7) | Implemented |
| **07** | [`07_manual_testing_checklist.md`](./07_manual_testing_checklist.md) | Manual Test Checklist & Verification Guide (Task 8.8) | Complete |
