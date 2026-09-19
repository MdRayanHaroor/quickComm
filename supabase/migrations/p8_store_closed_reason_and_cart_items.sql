-- ============================================================
-- P8 Migration: Store Closed Reason and Persistent Cart Items
-- ============================================================

-- 1. Add closed_reason to store_settings
ALTER TABLE public.store_settings
  ADD COLUMN IF NOT EXISTS closed_reason text DEFAULT 'Closed for Now';

-- Set default closed_reason for the existing store_settings record
UPDATE public.store_settings
SET closed_reason = 'Closed for Now'
WHERE id = 1 AND closed_reason IS NULL;

-- 2. Create cart_items table for persistent shopping cart
CREATE TABLE IF NOT EXISTS public.cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    variant_id BIGINT REFERENCES public.product_variants(id) ON DELETE CASCADE,
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Unique constraint index: one entry per user + product + variant
CREATE UNIQUE INDEX IF NOT EXISTS unique_user_cart_item_idx 
  ON public.cart_items (user_id, product_id, COALESCE(variant_id, 0));

-- Indexes for fast user cart lookups
CREATE INDEX IF NOT EXISTS idx_cart_items_user_id ON public.cart_items(user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only access and modify their own cart items
DROP POLICY IF EXISTS "Users can view own cart items" ON public.cart_items;
CREATE POLICY "Users can view own cart items"
    ON public.cart_items FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own cart items" ON public.cart_items;
CREATE POLICY "Users can insert own cart items"
    ON public.cart_items FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own cart items" ON public.cart_items;
CREATE POLICY "Users can update own cart items"
    ON public.cart_items FOR UPDATE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own cart items" ON public.cart_items;
CREATE POLICY "Users can delete own cart items"
    ON public.cart_items FOR DELETE
    USING (auth.uid() = user_id);

-- 3. Ensure store_settings broadcasts realtime changes
ALTER TABLE public.store_settings REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables 
      WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'store_settings'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.store_settings;
    END IF;
  END IF;
END $$;

