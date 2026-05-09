-- =============================================================================
-- CASCADE AUTH DELETION FIX
-- =============================================================================
-- PROBLEM: When an owner deletes their account via delete_user_account():
--   1. Owner row in auth.users is deleted ✅
--   2. customers rows are cascade-deleted (owner_id FK) ✅
--   3. BUT customer auth.users rows are NOT deleted ❌
--      Because the FK is `auth_user_id references auth.users(id) ON DELETE SET NULL`
--      which only NULLs the column — it never removes the customer's auth record.
--
-- FIX: Replace delete_user_account() with a version that:
--   Step 1 — Collects all auth_user_ids from the owner's customers
--   Step 2 — Deletes each customer's auth.users row (removes credentials/sessions)
--   Step 3 — Deletes the owner's own auth.users row (cascades remaining DB records)
-- =============================================================================

-- Replace the old, incomplete delete_user_account RPC
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  owner_uid         uuid;
  customer_auth_uid uuid;
BEGIN
  -- 1. Identify the calling owner
  owner_uid := auth.uid();
  IF owner_uid IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: must be authenticated to delete account';
  END IF;

  -- 2. Delete every customer auth account that belongs to this owner.
  --    We iterate because auth.users cannot be bulk-deleted via a subquery
  --    in some Supabase environments (RLS on auth schema).
  FOR customer_auth_uid IN
    SELECT auth_user_id
    FROM   public.customers
    WHERE  owner_id     = owner_uid
      AND  auth_user_id IS NOT NULL   -- only customers who have credentials
  LOOP
    -- Remove the customer's auth identity, sessions, tokens, and refresh tokens.
    -- Deleting from auth.users cascades to auth.identities, auth.sessions,
    -- auth.refresh_tokens, and auth.mfa_* tables automatically.
    DELETE FROM auth.users WHERE id = customer_auth_uid;
  END LOOP;

  -- 3. Delete the owner's own auth.users row.
  --    This cascades to:
  --      • public.customers (owner_id FK → ON DELETE CASCADE)
  --      • public.transactions (owner_id FK → ON DELETE CASCADE)
  --      • public.complaints (owner_id FK → ON DELETE CASCADE)
  --      • public.notifications (owner_id FK → ON DELETE CASCADE)
  --    Any remaining customers whose auth_user_id was already NULL (no credentials)
  --    are also removed here via the customers → owner_id cascade.
  DELETE FROM auth.users WHERE id = owner_uid;
END;
$$;

-- Grant execute to authenticated users only (anon must not call this)
REVOKE ALL ON FUNCTION public.delete_user_account() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;

-- =============================================================================
-- ALSO ensure delete_customer_auth_account is correct (individual deletion)
-- No change needed — it already deletes auth.users for the customer.
-- Reproduced here for documentation completeness:
-- =============================================================================

-- Refresh delete_customer_auth_account to also be explicit about search_path
CREATE OR REPLACE FUNCTION public.delete_customer_auth_account(target_customer_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  owner_uid       uuid;
  target_auth_id  uuid;
BEGIN
  owner_uid := auth.uid();

  IF owner_uid IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- Verify ownership and fetch customer's auth_user_id atomically
  SELECT auth_user_id INTO target_auth_id
  FROM   public.customers
  WHERE  id       = target_customer_id
    AND  owner_id = owner_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer not found or access denied';
  END IF;

  -- Delete customer auth account if they have credentials
  IF target_auth_id IS NOT NULL THEN
    -- Deletes auth.users row → cascades identities/sessions/tokens
    DELETE FROM auth.users WHERE id = target_auth_id;
  END IF;

  -- Delete customer record (also cascades transactions, complaints, notifications)
  DELETE FROM public.customers
  WHERE  id       = target_customer_id
    AND  owner_id = owner_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_customer_auth_account(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.delete_customer_auth_account(uuid) TO authenticated;
