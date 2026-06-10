-- =============================================================
-- Migration: 002_rls_policies.sql
-- Description: Row Level Security policies
-- Run AFTER 001_schema.sql
-- =============================================================

-- -------------------------------------
-- USERS
-- -------------------------------------
CREATE POLICY "users_select" ON users
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "users_insert" ON users
  FOR INSERT TO authenticated WITH CHECK (id = auth.uid());

CREATE POLICY "users_update" ON users
  FOR UPDATE TO authenticated USING (id = auth.uid());

-- -------------------------------------
-- PATIENTS
-- -------------------------------------
CREATE POLICY "patients_select" ON patients
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "patients_insert" ON patients
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "patients_update" ON patients
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "patients_delete" ON patients
  FOR DELETE TO authenticated USING (true);

-- -------------------------------------
-- APPOINTMENTS
-- -------------------------------------
CREATE POLICY "appointments_select" ON appointments
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "appointments_insert" ON appointments
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "appointments_update" ON appointments
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "appointments_delete" ON appointments
  FOR DELETE TO authenticated USING (true);

-- -------------------------------------
-- MEDICAL RECORDS
-- -------------------------------------
CREATE POLICY "records_select" ON medical_records
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "records_insert" ON medical_records
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "records_update" ON medical_records
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "records_delete" ON medical_records
  FOR DELETE TO authenticated USING (true);

-- -------------------------------------
-- PATIENT DETAILS
-- -------------------------------------
CREATE POLICY "patient_details_select" ON patient_details
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "patient_details_insert" ON patient_details
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "patient_details_update" ON patient_details
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "patient_details_delete" ON patient_details
  FOR DELETE TO authenticated USING (true);
