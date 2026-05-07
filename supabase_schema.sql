-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- CUSTOMERS TABLE
create table if not exists public.customers (
    id uuid default uuid_generate_v4() primary key,
    name text not null,
    phone text not null,
    owner_id uuid references auth.users(id) on delete cascade not null,
    auth_user_id uuid references auth.users(id) on delete set null,
    is_active boolean default true not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(owner_id, phone) -- An owner cannot have duplicate phone numbers for customers
);

-- TRANSACTIONS TABLE
create table if not exists public.transactions (
    id uuid default uuid_generate_v4() primary key,
    customer_id uuid references public.customers(id) on delete cascade not null,
    amount numeric not null check (amount > 0),
    type text not null check (type in ('credit', 'payment')),
    title text,
    date timestamp with time zone default timezone('utc'::text, now()) not null,
    due_date timestamp with time zone,
    note text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- COMPLAINTS TABLE
create table if not exists public.complaints (
    id uuid default uuid_generate_v4() primary key,
    customer_id uuid references public.customers(id) on delete cascade not null,
    owner_id uuid references auth.users(id) on delete cascade not null,
    message text not null,
    status text not null default 'pending' check (status in ('pending', 'in_progress', 'completed')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ROW LEVEL SECURITY (RLS)

-- Enable RLS
alter table public.customers enable row level security;
alter table public.transactions enable row level security;

-- Customers Policies:
-- 1. Owners can read their own customers
create policy "Owners can read their own customers" 
on public.customers for select 
using (auth.uid() = owner_id);

-- 2. Owners can insert their own customers
create policy "Owners can insert their own customers" 
on public.customers for insert 
with check (auth.uid() = owner_id);

-- 3. Owners can update their own customers
create policy "Owners can update their own customers" 
on public.customers for update 
using (auth.uid() = owner_id);

-- 4. Owners can delete their own customers
create policy "Owners can delete their own customers" 
on public.customers for delete 
using (auth.uid() = owner_id);

-- 5. Customers can read their own profile
create policy "Customers can read their own profile" 
on public.customers for select 
using (auth.uid() = auth_user_id);


-- Transactions Policies:
-- 1. Owners can read transactions of their customers
create policy "Owners can read transactions of their customers"
on public.transactions for select
using (
    exists (
        select 1 from public.customers 
        where customers.id = transactions.customer_id 
        and customers.owner_id = auth.uid()
    )
);

-- 2. Owners can insert transactions for their customers
create policy "Owners can insert transactions for their customers"
on public.transactions for insert
with check (
    exists (
        select 1 from public.customers 
        where customers.id = transactions.customer_id 
        and customers.owner_id = auth.uid()
    )
);

-- 3. Customers can read their own transactions
create policy "Customers can read their own transactions"
on public.transactions for select
using (
    exists (
        select 1 from public.customers 
        where customers.id = transactions.customer_id 
        and customers.auth_user_id = auth.uid()
    )
);

-- Complaints Policies:
alter table public.complaints enable row level security;

-- 1. Owners can read complaints for their customers
create policy "Owners can read their complaints"
on public.complaints for select
using (auth.uid() = owner_id);

-- 2. Owners can update complaints (resolve)
create policy "Owners can update their complaints"
on public.complaints for update
using (auth.uid() = owner_id);

-- 3. Customers can read their own complaints
create policy "Customers can read their own complaints"
on public.complaints for select
using (
    exists (
        select 1 from public.customers 
        where customers.id = complaints.customer_id 
        and customers.auth_user_id = auth.uid()
    )
);

-- 4. Customers can insert complaints
create policy "Customers can insert complaints"
on public.complaints for insert
with check (
    exists (
        select 1 from public.customers 
        where customers.id = complaints.customer_id 
        and customers.auth_user_id = auth.uid()
    )
);

-- RPCs for User Management

-- Create Customer User RPC has been removed. 
-- Please use the Supabase Edge Function `create-customer-user` instead.
drop function if exists public.create_customer_user;

-- Delete Own User Account RPC
create or replace function public.delete_user_account()
returns void language plpgsql security definer as $$
begin
  if auth.uid() is null then
    raise exception 'Unauthorized';
  end if;
  
  -- The trigger on auth.users will cascade delete public.customers, etc.
  delete from auth.users where id = auth.uid();
end;
$$;
