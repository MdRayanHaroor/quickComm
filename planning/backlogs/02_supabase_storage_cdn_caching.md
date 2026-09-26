# 02 — Supabase Storage CDN Caching Headers (Task 8.1)

## Objective
Ensure all uploaded assets (product images, category images, and brand logos) served via Supabase Storage include high-performance HTTP `Cache-Control` response headers to enable CDN edge caching and client-side disk caching.

---

## 1. Problem Statement
Without explicit `cache-control` file options specified during upload, Supabase Storage serves images with a default short or missing cache header. This leads to:
- Redundant downloads of the same images on mobile apps and admin panel.
- UI stutter / image reloading flashes during screen transitions.
- Unnecessary bandwidth consumption and increased latency.

---

## 2. Technical Implementation
In `backend/routers/uploads.py`:
- In `_upload_to_storage()`, pass `file_options` with:
  ```python
  file_options={
      "content-type": file.content_type,
      "cache-control": "31536000", # 1 year (31,536,000 seconds)
      "upsert": "true"
  }
  ```
- Because uploaded file paths use unique UUIDs (e.g., `products/{id}/{uuid}.jpg`), images are content-immutable.
- Caching for 1 year (`max-age=31536000`) allows Cloudflare CDN and local device caches to store images permanently while guaranteeing that updated product images (which receive a new UUID filename) bust the cache automatically.
