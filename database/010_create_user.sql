-- =============================================================
-- 010_create_user.sql
-- Creates a new user in both auth.users and public.users
-- Run in: Supabase SQL Editor
--
-- HOW TO USE:
--   1. Replace the values in the SET block below
--   2. Paste the whole script into SQL Editor and click Run
--   3. Supported roles: 'admin' | 'assistant' | 'doctor' | 'nurse' | 'receptionist'
-- =============================================================

DO $$
DECLARE
  v_email      TEXT    := 'newuser@example.com';   -- ← change this
  v_password   TEXT    := 'Change@123';             -- ← change this
  v_first_name TEXT    := 'First';                  -- ← change this
  v_last_name  TEXT    := 'Last';                   -- ← change this
  v_role       TEXT    := 'assistant';              -- ← change this
  v_uid        UUID;
BEGIN

  -- ── Guard: skip if email already exists ───────────────────────
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_email) THEN
    RAISE NOTICE 'User % already exists — skipped.', v_email;
    RETURN;
  END IF;

  -- ── Step 1: Create Supabase Auth user ────────────────────────
  v_uid := gen_random_uuid();

  INSERT INTO auth.users (
    id,
    instance_id,
    email,
    encrypted_password,
    email_confirmed_at,
    role,
    aud,
    raw_app_meta_data,
    raw_user_meta_data,
    is_super_admin,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token,
    created_at,
    updated_at
  ) VALUES (
    v_uid,
    '00000000-0000-0000-0000-000000000000',
    v_email,
    crypt(v_password, gen_salt('bf')),
    now(),                                           -- email confirmed immediately
    'authenticated',
    'authenticated',
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('first_name', v_first_name, 'last_name', v_last_name),
    false,
    '', '', '', '',
    now(),
    now()
  );

  -- ── Step 2: Create identity record (needed for email login) ──
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    v_uid,
    jsonb_build_object('sub', v_uid::text, 'email', v_email),
    'email',
    v_email,
    now(),
    now(),
    now()
  );

  -- ── Step 3: Create profile in public.users ────────────────────
  INSERT INTO public.users (id, email, first_name, last_name, role)
  VALUES (v_uid, v_email, v_first_name, v_last_name, v_role);

  RAISE NOTICE 'User % created successfully with role %.', v_email, v_role;

END $$;

-- ── Verify ────────────────────────────────────────────────────────
SELECT
  u.id,
  u.email,
  u.first_name,
  u.last_name,
  u.role,
  u.created_at
FROM public.users u
ORDER BY u.created_at DESC
LIMIT 10;
