-- Migration: Add delivered_at to orders table
-- Run in Supabase SQL Editor
-- This enables accurate "Time Taken" calculation (delivered_at - created_at)
-- rather than relying on updated_at which changes on every field update.

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz;
