-- 1. ADD MISSING COLUMNS
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS is_active boolean default true not null;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS credit_limit numeric default 0 not null check (credit_limit >= 0);
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS owner_id uuid references auth.users(id) on delete cascade;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS due_date timestamp with time zone;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS title text;

-- Backfill owner_id for transactions if it's missing (link via customer)
UPDATE public.transactions t
SET owner_id = c.owner_id
FROM public.customers c
WHERE t.customer_id = c.id AND t.owner_id IS NULL;

-- Make owner_id NOT NULL after backfill
-- ALTER TABLE public.transactions ALTER COLUMN owner_id SET NOT NULL; 
-- (Commented out above in case some transactions are orphaned, but recommended)

-- 2. CREATE COMPLAINTS TABLE
create table if not exists public.complaints (
    id uuid default uuid_generate_v4() primary key,
    customer_id uuid references public.customers(id) on delete cascade not null,
    owner_id uuid references auth.users(id) on delete cascade not null,
    message text not null,
    status text not null default 'pending' check (status in ('pending', 'in_progress', 'completed')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. COMPLAINTS ROW LEVEL SECURITY (RLS)
alter table public.complaints enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'Owners can read their complaints' and tablename = 'complaints') then
    create policy "Owners can read their complaints"
    on public.complaints for select
    using (auth.uid() = owner_id);
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Owners can update their complaints' and tablename = 'complaints') then
    create policy "Owners can update their complaints"
    on public.complaints for update
    using (auth.uid() = owner_id);
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Customers can read their own complaints' and tablename = 'complaints') then
    create policy "Customers can read their own complaints"
    on public.complaints for select
    using (
        exists (
            select 1 from public.customers 
            where customers.id = complaints.customer_id 
            and customers.auth_user_id = auth.uid()
        )
    );
  end if;

  if not exists (select 1 from pg_policies where policyname = 'Customers can insert complaints' and tablename = 'complaints') then
    create policy "Customers can insert complaints"
    on public.complaints for insert
    with check (
        exists (
            select 1 from public.customers 
            where customers.id = complaints.customer_id 
            and customers.auth_user_id = auth.uid()
        )
    );
  end if;
end $$;


-- 4. CREATE RPCS FOR USER MANAGEMENT

-- Drop the old fragile RPC if it exists
drop function if exists public.create_customer_user(text, text, text, uuid);

-- Delete Own User Account RPC
-- FIX: Performs FULL cascade auth deletion:
--   Step 1 — Deletes each customer's auth.users row (removes login credentials/sessions)
--   Step 2 — Deletes the owner's auth.users row (cascades all remaining DB records)
create or replace function public.delete_user_account()
returns void language plpgsql security definer
set search_path = public
as $$
declare
  owner_uid         uuid;
  customer_auth_uid uuid;
begin
  owner_uid := auth.uid();
  if owner_uid is null then
    raise exception 'Unauthorized: must be authenticated to delete account';
  end if;

  -- Step 1: Delete every customer's auth account (credentials/sessions/tokens)
  for customer_auth_uid in
    select auth_user_id
    from   public.customers
    where  owner_id     = owner_uid
      and  auth_user_id is not null
  loop
    delete from auth.users where id = customer_auth_uid;
  end loop;

  -- Step 2: Delete the owner's auth account (cascades all DB records)
  delete from auth.users where id = owner_uid;
end;
$$;

revoke all on function public.delete_user_account() from public;
grant  execute on function public.delete_user_account() to authenticated;

-- Delete Customer Auth Account RPC
create or replace function public.delete_customer_auth_account(target_customer_id uuid)
returns void language plpgsql security definer as $$
declare
  owner_uid uuid;
  target_auth_id uuid;
begin
  owner_uid := auth.uid();
  
  if owner_uid is null then
    raise exception 'Unauthorized';
  end if;

  -- Verify the owner owns this customer, and get the customer's auth_user_id
  select auth_user_id into target_auth_id 
  from public.customers 
  where id = target_customer_id and owner_id = owner_uid;

  -- Delete the auth user if linked
  if target_auth_id is not null then
    delete from auth.users where id = target_auth_id;
  end if;

  -- Delete customer record
  delete from public.customers where id = target_customer_id and owner_id = owner_uid;
end;
$$;

-- 5. UPDATE TRANSACTIONS TYPE CONSTRAINT FOR REFUND
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS "transaction-type-check";
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS "transactions_type_check";
ALTER TABLE public.transactions ADD CONSTRAINT "transactions_type_check" CHECK (type IN ('credit', 'payment', 'refund'));

