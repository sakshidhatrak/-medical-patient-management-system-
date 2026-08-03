-- =============================================================
-- 011_fix_users_rls.sql
-- Fix: make _user_role() SECURITY DEFINER so it can bypass RLS
-- and add SELECT policy on public.users so profile fetch works.
-- Run in: Supabase SQL Editor  (run ONCE after 009_complete_schema.sql)
-- =============================================================

-- 1. Make the role-helper bypass RLS (prevents circular-dependency)
CREATE OR REPLACE FUNCTION _user_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM public.users WHERE id = auth.uid();
$$;

-- 2. Every authenticated user can read their own profile row
DROP POLICY IF EXISTS users_read_own ON public.users;
CREATE POLICY users_read_own ON public.users
  FOR SELECT TO authenticated
  USING (id = auth.uid());

-- 3. Admin can read ALL user profiles
DROP POLICY IF EXISTS admin_read_users ON public.users;
CREATE POLICY admin_read_users ON public.users
  FOR SELECT TO authenticated
  USING (_user_role() = 'admin');

-- 4. Admin can create / update / delete user profiles
DROP POLICY IF EXISTS admin_write_users ON public.users;
CREATE POLICY admin_write_users ON public.users
  FOR ALL TO authenticated
  USING     (_user_role() = 'admin')
  WITH CHECK(_user_role() = 'admin');

-- Verify
SELECT id, email, role FROM public.users ORDER BY created_at;
