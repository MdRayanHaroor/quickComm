# 06 — PostgreSQL tsvector Full-Text Search on Products (Task 8.7)

## Objective
Implement native PostgreSQL full-text search (`tsvector` and GIN indexing) on products to replace slow, un-indexed `ILIKE '%query%'` scans with lightning-fast, linguistic-aware search supporting word stemming, multi-word matching, and weighted ranking.

---

## 1. Problem Statement
SQL `ILIKE '%search%'` has significant drawbacks:
- Performs a full sequential table scan on every search request.
- Fails on word variations (e.g. searching "biscuit" misses "biscuits", or "tomato" vs "tomatoes").
- Cannot match multi-word queries with varied word order.
- Does not rank title matches higher than matches in description.

---

## 2. Technical Implementation

### A. Database Migration (`supabase/migrations/p11_products_full_text_search.sql`)
1. **Add `search_vector` column to `products`:**
   ```sql
   ALTER TABLE products ADD COLUMN IF NOT EXISTS search_vector tsvector;
   ```
2. **Weighted search trigger:**
   Combines `name` (weight 'A'), `tags` (weight 'B'), and `description` (weight 'C') using `to_tsvector('english', ...)`.
   Automatically updates on every `INSERT` or `UPDATE` on `products`.
3. **GIN Index:**
   ```sql
   CREATE INDEX IF NOT EXISTS idx_products_search_vector ON products USING gin(search_vector);
   ```

### B. Backend API Integration (`backend/routers/products.py`)
- In `GET /products/`:
  - When `search` param is present, queries PostgreSQL using `.text_search("search_vector", formatted_query, options={"type": "websearch"})`.
  - Fallbacks seamlessly to `.ilike("name", f"%{search}%")` if full-text search returns empty or if the database column is pending migration execution.
