-- =============================================================
-- Seed: 003_seed_admin_user.sql
-- Description: Creates the first admin user in auth + users table
-- Run in: Supabase SQL Editor
-- =============================================================

-- Step 0: Clean up any previously broken insert
DELETE FROM public.users  WHERE email = 'admin@test.com';
DELETE FROM auth.identities WHERE provider = 'email'
  AND identity_data->>'email' = 'admin@test.com';
DELETE FROM auth.users    WHERE email = 'admin@test.com';

-- Step 1: Create auth user with all required fields
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
)
VALUES (
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000000',
  'admin@test.com',
  crypt('Admin@123', gen_salt('bf')),
  now(),
  'authenticated',
  'authenticated',
  '{"provider":"email","providers":["email"]}',
  '{}',
  false,
  '',
  '',
  '',
  '',
  now(),
  now()
);

-- Step 2: Create identity record (required for email/password sign-in)
INSERT INTO auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
)
SELECT
  gen_random_uuid(),
  id,
  json_build_object('sub', id::text, 'email', email),
  'email',
  email,
  now(),
  now(),
  now()
FROM auth.users
WHERE email = 'admin@test.com';

-- Step 3: Create matching profile in public.users
INSERT INTO public.users (id, email, first_name, last_name, role)
SELECT id, email, 'Admin', 'User', 'admin'
FROM auth.users
WHERE email = 'admin@test.com';
