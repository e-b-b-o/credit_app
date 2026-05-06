-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- CUSTOMERS TABLE
create table if not exists public.customers (
    id uuid default uuid_generate_v4() primary key,
    name text not null,
    phone text not null,
    owner_id uuid references auth.users(id) on delete cascade not null,
    auth_user_id uuid references auth.users(id) on delete set null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(owner_id, phone) -- An owner cannot have duplicate phone numbers for customers
);

-- TRANSACTIONS TABLE
create table if not exists public.transactions (
    id uuid default uuid_generate_v4() primary key,
    customer_id uuid references public.customers(id) on delete cascade not null,
    amount numeric not null check (amount > 0),
    type text not null check (type in ('credit', 'payment')),
    date timestamp with time zone default timezone('utc'::text, now()) not null,
    note text,
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
