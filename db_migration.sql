-- 1. Create Customers Table
create table if not exists public.customers (
  id uuid references auth.users not null primary key,
  full_name text,
  phone_number text,
  address text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Enable RLS on Customers
alter table public.customers enable row level security;

-- 3. Create RLS Policies for Customers
drop policy if exists "Customers can view their own profile" on customers;
create policy "Customers can view their own profile" on customers for select using (auth.uid() = id);

drop policy if exists "Customers can insert their own profile" on customers;
create policy "Customers can insert their own profile" on customers for insert with check (auth.uid() = id);

drop policy if exists "Customers can update their own profile" on customers;
create policy "Customers can update their own profile" on customers for update using (auth.uid() = id);

-- 4. Fix Orders RLS Policies
-- Allow authenticated users to insert orders (linked to their user_id)
drop policy if exists "Users can insert their own orders" on orders;
create policy "Users can insert their own orders" on orders for insert with check (auth.uid() = user_id);

-- Ensure users can see their own orders (likely already exists, but good to ensure)
drop policy if exists "Users can see own orders" on orders;
create policy "Users can see own orders" on orders for select using (auth.uid() = user_id);

-- CRITICAL: Allow Admin/Backend to UPDATE orders (Assign Rider, Change Status)
drop policy if exists "Enable update for all users" on orders;
create policy "Enable update for all users" on orders for update using (true);

-- CRITICAL: Allow public read of products (if not already set)
drop policy if exists "Enable read access for all users" on products;
create policy "Enable read access for all users" on products for select using (true);

-- 5. Fix Order Items RLS
drop policy if exists "Users can insert own order items" on order_items;
create policy "Users can insert own order items" on order_items 
  for insert with check (
    order_id in (select id from orders where user_id = auth.uid())
  );

drop policy if exists "Users can view own order items" on order_items;
create policy "Users can view own order items" on order_items
  for select using (
    order_id in (select id from orders where user_id = auth.uid())
  );

-- 6. RESET RIDER LOCATIONS TABLE (CRITICAL FIX FOR DUPLICATES)
-- Drop table to remove bad duplicate data
drop table if exists public.rider_locations cascade;

-- Recreate with rider_id as PRIMARY KEY (forces 1 row per rider)
-- Added order_id for precise tracking as requested
create table public.rider_locations (
  rider_id uuid references auth.users not null primary key,
  order_id bigint references public.orders(id), -- Nullable, tracks active order
  lat float not null,
  lng float not null,
  last_updated timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 7. REALTIME Configuration
-- Ensure rider_locations is in the realtime publication
alter publication supabase_realtime add table public.rider_locations;
-- Ensure orders is in the realtime publication 
alter publication supabase_realtime add table public.orders;
-- Ensure profiles is in the realtime publication (for new riders)
alter publication supabase_realtime add table public.profiles;

-- 8. RIDER LOCATIONS RLS
alter table public.rider_locations enable row level security;

-- Allow ANYONE to read locations
create policy "Locations viewable by all" on rider_locations for select using (true);

-- Allow Riders to INSERT their own location
create policy "Riders insert own location" on rider_locations for insert with check (auth.uid() = rider_id);

-- Allow Riders to UPDATE their own location
create policy "Riders update own location" on rider_locations for update using (auth.uid() = rider_id);
