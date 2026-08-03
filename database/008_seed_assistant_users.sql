-- =============================================================
-- Seed: 008_seed_assistant_users.sql
-- Description: Creates 2 assistant (view-only) users
-- Run in: Supabase SQL Editor
-- =============================================================

-- ── Assistant 1: Priya Sharma ────────────────────────────────

-- Step 0: Clean up any previous broken insert
DELETE FROM public.users   WHERE email = 'priya.assistant@medimanage.com';
DELETE FROM auth.identities WHERE provider = 'email'
  AND identity_data->>'email' = 'priya.assistant@medimanage.com';
DELETE FROM auth.users     WHERE email = 'priya.assistant@medimanage.com';

-- Step 1: Create auth user
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password,
  email_confirmed_at, role, aud,
  raw_app_meta_data, raw_user_meta_data,
  is_super_admin, confirmation_token,
  email_change, email_change_token_new, recovery_token,
  created_at, updated_at
) VALUES (
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000000',
  'priya.assistant@medimanage.com',
  crypt('Assist@123', gen_salt('bf')),
  now(),
  'authenticated',
  'authenticated',
  '{"provider":"email","providers":["email"]}',
  '{}',
  false, '', '', '', '',
  now(), now()
);

-- Step 2: Create identity record
INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id,
  last_sign_in_at, created_at, updated_at
)
SELECT
  gen_random_uuid(), id,
  json_build_object('sub', id::text, 'email', email),
  'email', email, now(), now(), now()
FROM auth.users
WHERE email = 'priya.assistant@medimanage.com';

-- Step 3: Create profile in public.users
INSERT INTO public.users (id, email, first_name, last_name, role)
SELECT id, email, 'Priya', 'Sharma', 'assistant'
FROM auth.users
WHERE email = 'priya.assistant@medimanage.com';


-- ── Assistant 2: Rahul Desai ─────────────────────────────────

-- Step 0: Clean up any previous broken insert
DELETE FROM public.users   WHERE email = 'rahul.assistant@medimanage.com';
DELETE FROM auth.identities WHERE provider = 'email'
  AND identity_data->>'email' = 'rahul.assistant@medimanage.com';
DELETE FROM auth.users     WHERE email = 'rahul.assistant@medimanage.com';

-- Step 1: Create auth user
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password,
  email_confirmed_at, role, aud,
  raw_app_meta_data, raw_user_meta_data,
  is_super_admin, confirmation_token,
  email_change, email_change_token_new, recovery_token,
  created_at, updated_at
) VALUES (
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000000',
  'rahul.assistant@medimanage.com',
  crypt('Assist@456', gen_salt('bf')),
  now(),
  'authenticated',
  'authenticated',
  '{"provider":"email","providers":["email"]}',
  '{}',
  false, '', '', '', '',
  now(), now()
);

-- Step 2: Create identity record
INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id,
  last_sign_in_at, created_at, updated_at
)
SELECT
  gen_random_uuid(), id,
  json_build_object('sub', id::text, 'email', email),
  'email', email, now(), now(), now()
FROM auth.users
WHERE email = 'rahul.assistant@medimanage.com';

-- Step 3: Create profile in public.users
INSERT INTO public.users (id, email, first_name, last_name, role)
SELECT id, email, 'Rahul', 'Desai', 'assistant'
FROM auth.users
WHERE email = 'rahul.assistant@medimanage.com';


-- ── Verify both assistants were created ──────────────────────
SELECT email, first_name, last_name, role
FROM public.users
WHERE role = 'assistant';
