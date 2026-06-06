-- Migration: Add speed, heading, accuracy columns to rider_locations
-- Run this on your Supabase SQL Editor to add the new columns

ALTER TABLE public.rider_locations 
  ADD COLUMN IF NOT EXISTS speed float DEFAULT 0,
  ADD COLUMN IF NOT EXISTS heading float DEFAULT 0,
  ADD COLUMN IF NOT EXISTS accuracy float DEFAULT 0;
