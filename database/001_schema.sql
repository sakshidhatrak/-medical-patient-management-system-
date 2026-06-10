-- =============================================================
-- Migration: 001_schema.sql
-- Description: Initial schema for Medical Patient Management System
-- =============================================================

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email       TEXT NOT NULL UNIQUE,
  first_name  TEXT NOT NULL,
  last_name   TEXT NOT NULL,
  role        TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Patients table
CREATE TABLE IF NOT EXISTS patients (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name    TEXT NOT NULL,
  last_name     TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  gender        TEXT NOT NULL,
  phone         TEXT NOT NULL,
  email         TEXT,
  address       TEXT,
  blood_type    TEXT,
  allergies     TEXT,
  sync_status   TEXT NOT NULL DEFAULT 'synced',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Appointments table
CREATE TABLE IF NOT EXISTS appointments (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  doctor_id    UUID NOT NULL REFERENCES users(id),
  scheduled_at TIMESTAMPTZ NOT NULL,
  status       TEXT NOT NULL DEFAULT 'scheduled',
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Medical records table
CREATE TABLE IF NOT EXISTS medical_records (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  doctor_id    UUID NOT NULL REFERENCES users(id),
  diagnosis    TEXT NOT NULL,
  treatment    TEXT,
  prescription TEXT,
  notes        TEXT,
  visit_date   DATE NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Patient details table
CREATE TABLE IF NOT EXISTS patient_details (
  patient_id             UUID PRIMARY KEY REFERENCES patients(id) ON DELETE CASCADE,
  visits_json            JSONB NOT NULL DEFAULT '[]',
  vitals_json            JSONB,
  emergency_contact_json JSONB,
  reports_json           JSONB NOT NULL DEFAULT '[]'
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_patients_name    ON patients(last_name, first_name);
CREATE INDEX IF NOT EXISTS idx_appts_patient    ON appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_appts_date       ON appointments(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_records_patient  ON medical_records(patient_id);

-- Enable Row Level Security
ALTER TABLE users           ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients        ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE medical_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_details ENABLE ROW LEVEL SECURITY;
