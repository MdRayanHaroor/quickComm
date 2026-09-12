-- ============================================================
-- P4 Migration: Order & Order Items Enhancements
-- Adds payment, delivery notes, variant support to orders
-- ============================================================

-- ============================================================
-- 1. ALTER ORDERS TABLE
-- ============================================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS delivery_fee      numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_amount   numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS coupon_code       text,
  ADD COLUMN IF NOT EXISTS payment_method    text DEFAULT 'cod',
  ADD COLUMN IF NOT EXISTS payment_status    text DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS delivery_notes    text;

-- Add check constraints (won't fail if column already exists, just creates constraints)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE table_name = 'orders' AND constraint_name = 'orders_payment_method_check'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_payment_method_check
        CHECK (payment_method IN ('cod', 'upi', 'card', 'wallet', 'netbanking'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE table_name = 'orders' AND constraint_name = 'orders_payment_status_check'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_payment_status_check
        CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded'));
  END IF;
END $$;

-- Index for payment status queries
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON public.orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON public.orders(user_id);


-- ============================================================
-- 2. ALTER ORDER ITEMS TABLE
-- ============================================================

ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS variant_id            bigint REFERENCES public.product_variants(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS product_name_snapshot text,    -- e.g. "Amul Gold Milk"
  ADD COLUMN IF NOT EXISTS variant_name_snapshot text,    -- e.g. "1 L"
  ADD COLUMN IF NOT EXISTS mrp_at_time           numeric, -- MRP at time of order
  ADD COLUMN IF NOT EXISTS discount_at_time      numeric DEFAULT 0; -- mrp - selling_price

CREATE INDEX IF NOT EXISTS idx_order_items_variant ON public.order_items(variant_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items(order_id);
