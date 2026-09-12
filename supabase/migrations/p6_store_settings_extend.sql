-- ============================================================
-- P6 Migration: Extend Store Settings
-- Adds delivery config, hours, and store metadata
-- ============================================================

ALTER TABLE public.store_settings
  ADD COLUMN IF NOT EXISTS store_name           text DEFAULT 'QuickComm Store',
  ADD COLUMN IF NOT EXISTS store_logo_url       text,
  ADD COLUMN IF NOT EXISTS store_address        text,
  ADD COLUMN IF NOT EXISTS phone_number         text,
  ADD COLUMN IF NOT EXISTS delivery_radius_km   numeric DEFAULT 5,
  ADD COLUMN IF NOT EXISTS min_order_amount     numeric DEFAULT 99,
  ADD COLUMN IF NOT EXISTS delivery_fee_fixed   numeric DEFAULT 20,
  ADD COLUMN IF NOT EXISTS free_delivery_above  numeric DEFAULT 299,
  ADD COLUMN IF NOT EXISTS is_open              boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS opening_time         time DEFAULT '09:00',
  ADD COLUMN IF NOT EXISTS closing_time         time DEFAULT '23:00',
  ADD COLUMN IF NOT EXISTS days_open            text[] DEFAULT '{Mon,Tue,Wed,Thu,Fri,Sat,Sun}';

-- Update the existing default row with sensible defaults
UPDATE public.store_settings
SET
  store_name          = 'QuickComm Store',
  delivery_radius_km  = 5,
  min_order_amount    = 99,
  delivery_fee_fixed  = 20,
  free_delivery_above = 299,
  is_open             = true,
  opening_time        = '09:00',
  closing_time        = '23:00',
  days_open           = ARRAY['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
WHERE id = 1;
