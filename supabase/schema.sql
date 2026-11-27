-- STIKZO database schema. Run in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'customer' check (role in ('owner','customer')),
  created_at timestamptz not null default now()
);
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  category text not null default 'Accessories',
  description text,
  price numeric(10,2) not null check(price >= 0),
  mrp numeric(10,2) not null default 0 check(mrp >= 0),
  stock integer not null default 0 check(stock >= 0),
  image_url text,
  images jsonb not null default '[]'::jsonb,
  specifications jsonb not null default '{}'::jsonb,
  quantity_prices jsonb not null default '[]'::jsonb,
  featured boolean not null default false,
  published boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  mobile text not null unique,
  email text,
  house_name text not null,
  street text not null,
  city text not null,
  district text not null,
  state text not null,
  pincode text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_code text unique not null default ('STZ-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
  customer_id uuid references public.customers(id),
  customer_name text not null,
  mobile text not null,
  total numeric(10,2) not null check(total >= 0),
  status text not null default 'Pending' check(status in ('Pending','Confirmed','Packed','Shipped','Delivered','Cancelled')),
  payment_method text not null default 'COD' check(payment_method = 'COD'),
  delivery_address jsonb not null,
  created_at timestamptz not null default now()
);
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  quantity integer not null check(quantity > 0),
  unit_price numeric(10,2) not null,
  line_total numeric(10,2) not null
);
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  customer_id uuid references public.customers(id),
  order_id uuid references public.orders(id),
  rating integer not null check(rating between 1 and 5),
  review_text text,
  image_urls jsonb not null default '[]'::jsonb,
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='owner'); $$;

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.reviews enable row level security;

create policy "published products are public" on public.products for select using (published=true or public.is_owner());
create policy "owner manages products" on public.products for all using (public.is_owner()) with check (public.is_owner());
create policy "users read own profile" on public.profiles for select using (id=auth.uid() or public.is_owner());
create policy "owner manages profiles" on public.profiles for all using (public.is_owner()) with check (public.is_owner());
create policy "owner reads customers" on public.customers for select using (public.is_owner());
create policy "owner manages customers" on public.customers for all using (public.is_owner()) with check (public.is_owner());
create policy "owner reads orders" on public.orders for select using (public.is_owner());
create policy "owner manages orders" on public.orders for all using (public.is_owner()) with check (public.is_owner());
create policy "owner reads order items" on public.order_items for select using (public.is_owner());
create policy "owner manages order items" on public.order_items for all using (public.is_owner()) with check (public.is_owner());
create policy "approved reviews are public" on public.reviews for select using (approved=true or public.is_owner());
create policy "owner manages reviews" on public.reviews for all using (public.is_owner()) with check (public.is_owner());

-- Create a private bucket for order/review uploads if desired. Product photos are public.
insert into storage.buckets(id,name,public) values ('product-images','product-images',true) on conflict(id) do nothing;
create policy "public can view product images" on storage.objects for select using (bucket_id='product-images');
create policy "owner uploads product images" on storage.objects for insert with check (bucket_id='product-images' and public.is_owner());
create policy "owner updates product images" on storage.objects for update using (bucket_id='product-images' and public.is_owner());
create policy "owner deletes product images" on storage.objects for delete using (bucket_id='product-images' and public.is_owner());

-- IMPORTANT: after creating the owner login in Supabase Authentication, promote that user:
-- update public.profiles set role='owner' where id='PASTE_AUTH_USER_UUID_HERE';
-- Also insert a profile row for that user first if needed:
-- insert into public.profiles(id, role) values ('PASTE_AUTH_USER_UUID_HERE','owner')
-- on conflict(id) do update set role='owner';
