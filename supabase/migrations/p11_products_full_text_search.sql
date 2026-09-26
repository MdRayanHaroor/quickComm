-- ============================================================
-- Migration: p11_products_full_text_search.sql
-- Description: Adds PostgreSQL tsvector full-text search and GIN index to products table
-- Task: 8.7 Full-text search on products
-- ============================================================

-- 1. Add search_vector column if not exists
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS search_vector tsvector;

-- 2. Trigger function to compute search vector automatically
CREATE OR REPLACE FUNCTION public.products_generate_search_vector()
RETURNS trigger AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', COALESCE(NEW.name, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(array_to_string(NEW.tags, ' '), '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'C');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create or replace trigger on products table
DROP TRIGGER IF EXISTS trg_products_search_vector ON public.products;
CREATE TRIGGER trg_products_search_vector
BEFORE INSERT OR UPDATE ON public.products
FOR EACH ROW EXECUTE FUNCTION public.products_generate_search_vector();

-- 4. Backfill existing products
UPDATE public.products
SET search_vector =
  setweight(to_tsvector('english', COALESCE(name, '')), 'A') ||
  setweight(to_tsvector('english', COALESCE(array_to_string(tags, ' '), '')), 'B') ||
  setweight(to_tsvector('english', COALESCE(description, '')), 'C')
WHERE search_vector IS NULL;

-- 5. Create GIN index for sub-millisecond full-text queries
CREATE INDEX IF NOT EXISTS idx_products_search_vector
ON public.products USING gin(search_vector);
