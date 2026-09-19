-- ============================================================
-- Migration p10: Orders Auto updated_at and delivered_at Trigger
-- Automatically keeps updated_at fresh on any order modification,
-- and automatically stamps delivered_at = now() whenever an order
-- transitions to 'delivered'.
-- ============================================================

-- 1. Ensure delivered_at column exists
ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz;

-- 2. Ensure REPLICA IDENTITY FULL so realtime subscribers receive all columns on changes
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.rider_locations REPLICA IDENTITY FULL;

-- 3. Create or replace trigger function for orders
CREATE OR REPLACE FUNCTION public.handle_order_updated()
RETURNS TRIGGER AS $$
BEGIN
  -- Always advance updated_at on every update
  NEW.updated_at = now();

  -- If status changed to 'delivered' and delivered_at is not already set, auto-stamp now()
  IF NEW.status = 'delivered' AND (OLD.status IS DISTINCT FROM 'delivered' OR NEW.delivered_at IS NULL) THEN
    NEW.delivered_at = COALESCE(NEW.delivered_at, now());
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Attach trigger to orders table
DROP TRIGGER IF EXISTS orders_set_updated_at ON public.orders;
CREATE TRIGGER orders_set_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_order_updated();
