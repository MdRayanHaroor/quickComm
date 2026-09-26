# 05 — Rate Limiting on Binary Upload Endpoints (Task 8.6)

## Objective
Implement rate limiting specifically targeted at binary file upload endpoints to prevent disk/storage exhaustion, cloud cost spikes, and spamming, while not interfering with normal product metadata updates where an existing image URL is simply provided.

---

## 1. Distinction: File Uploads vs URL Assignment
- **Image URL provided (No Rate Limiting Needed):**
  When a product is created or updated with an existing external URL (e.g. `image_url: "https://..."`), it is a small JSON payload storing a string in PostgreSQL. It does NOT hit the file upload endpoints.
- **Binary Image Uploaded (Rate Limited):**
  When an admin drags-and-drops or selects a file in the UI, it sends multipart form-data to `POST /upload/product/{id}/image`, `/upload/category/{id}/image`, or `/upload/brand/{id}/logo`. This writes bytes directly into Supabase Storage and consumes network/disk resources.

---

## 2. Technical Implementation
1. **Sliding Window Rate Limiter (`backend/rate_limiter.py`):**
   - High performance, lightweight in-memory sliding window algorithm.
   - Keyed by client IP / authenticated user ID.
   - Limit: **15 file uploads per minute** per client (generous enough for normal bulk catalog creation, but strictly caps abusive scripts).
2. **HTTP 429 Response:**
   - When the limit is exceeded, responds with `HTTP 429 Too Many Requests`.
   - Includes standard `Retry-After: 60` response header and a clear message: `"Upload rate limit exceeded. Please wait a minute before uploading more images."`
3. **Integration:**
   - Injected as a dependency `Depends(upload_rate_limiter)` on:
     - `POST /upload/product/{product_id}/image`
     - `POST /upload/category/{category_id}/image`
     - `POST /upload/brand/{brand_id}/logo`
