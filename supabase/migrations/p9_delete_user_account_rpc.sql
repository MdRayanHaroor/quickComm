-- ============================================================
-- Migration p9: Delete User Account RPC Function
-- Allows authenticated users to permanently delete their account
-- and cleans up all associated records across tables.
-- ============================================================

-- 1. Ensure foreign keys on rider tracking tables do not block order deletion
ALTER TABLE public.rider_location_history 
  DROP CONSTRAINT IF EXISTS rider_location_history_order_id_fkey,
  ADD CONSTRAINT rider_location_history_order_id_fkey 
  FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;

ALTER TABLE public.rider_locations 
  DROP CONSTRAINT IF EXISTS rider_locations_order_id_fkey,
  ADD CONSTRAINT rider_locations_order_id_fkey 
  FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;

-- 2. Create the robust delete_user_account function
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Get currently authenticated user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Step 1: Detach order references in rider location tracking tables
  UPDATE public.rider_location_history 
  SET order_id = NULL 
  WHERE order_id IN (SELECT id FROM public.orders WHERE user_id = v_user_id);

  UPDATE public.rider_locations 
  SET order_id = NULL 
  WHERE order_id IN (SELECT id FROM public.orders WHERE user_id = v_user_id);

  -- Step 2: Delete cart items
  DELETE FROM public.cart_items WHERE user_id = v_user_id;

  -- Step 3: Delete customer saved addresses
  DELETE FROM public.customer_addresses WHERE user_id = v_user_id;

  -- Step 4: Delete order items for this user's orders
  DELETE FROM public.order_items 
  WHERE order_id IN (SELECT id FROM public.orders WHERE user_id = v_user_id);

  -- Step 5: If user was assigned as rider on any orders, unassign them
  UPDATE public.orders SET rider_id = NULL WHERE rider_id = v_user_id;

  -- Step 6: Delete user rider tracking data if user was a rider
  DELETE FROM public.rider_daily_stats WHERE rider_id = v_user_id;
  DELETE FROM public.rider_location_history WHERE rider_id = v_user_id;
  DELETE FROM public.rider_locations WHERE rider_id = v_user_id;

  -- Step 7: Unassign store ownership if user was an owner
  UPDATE public.stores SET owner_id = NULL WHERE owner_id = v_user_id;

  -- Step 8: Delete user's orders
  DELETE FROM public.orders WHERE user_id = v_user_id;

  -- Step 9: Delete customer record if present
  DELETE FROM public.customers WHERE id = v_user_id;

  -- Step 10: Delete profile record
  DELETE FROM public.profiles WHERE id = v_user_id;

  -- Step 11: Delete user from auth.users (Supabase Authentication)
  DELETE FROM auth.users WHERE id = v_user_id;
END;
$$;

-- Grant execution permission to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
