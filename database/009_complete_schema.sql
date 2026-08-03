-- ================================================================
-- 009_complete_schema.sql
-- Complete schema mapping EVERY UI field to a proper DB column.
-- Run in Supabase SQL Editor.
-- Safe to run on an existing database — uses ADD COLUMN IF NOT EXISTS
-- and CREATE TABLE IF NOT EXISTS throughout.
-- ================================================================

-- ────────────────────────────────────────────────────────────────────
-- 1. USERS
--    Stores admin + assistant accounts (auth handled by Supabase Auth)
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  email        TEXT        NOT NULL UNIQUE,
  first_name   TEXT        NOT NULL,
  last_name    TEXT        NOT NULL DEFAULT '',
  role         TEXT        NOT NULL DEFAULT 'assistant',
  -- role values: 'admin' | 'assistant' | 'doctor' | 'nurse' | 'receptionist'
  avatar_url   TEXT,
  phone        TEXT,
  is_active    BOOLEAN     NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add missing columns if table already exists
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url  TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone       TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active   BOOLEAN NOT NULL DEFAULT true;

-- ────────────────────────────────────────────────────────────────────
-- 2. PATIENTS
--    Every field from the 5-step registration wizard as a proper column
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS patients (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  prn              TEXT        NOT NULL UNIQUE,   -- Auto-generated: ddmmyyHHmmss

  -- ── Step 1: Identity ───────────────────────────────────────────
  first_name       TEXT        NOT NULL,
  last_name        TEXT        NOT NULL DEFAULT '',
  age              INTEGER,                        -- entered manually OR derived from DOB
  date_of_birth    DATE,
  sex              TEXT,                           -- 'male' | 'female' | 'other'

  -- ── Step 1: Contact ────────────────────────────────────────────
  phone            TEXT,
  alt_phone        TEXT,                           -- alternate / family number
  email            TEXT,
  address          TEXT,                           -- full address (area + city + pincode)

  -- ── Step 1: ID Proof ───────────────────────────────────────────
  id_proof_type    TEXT,                           -- 'Aadhaar' | 'PAN' | 'Passport' | 'Voter ID' | 'DL'
  id_proof_number  TEXT,

  -- ── Step 1: Vitals (registration snapshot) ─────────────────────
  weight           TEXT,                           -- e.g. "72 kg"
  blood_pressure   TEXT,                           -- e.g. "120/80 mmHg"
  temperature      TEXT,                           -- e.g. "98.6 °F"

  -- ── Step 2: Medical History ────────────────────────────────────
  allergies        TEXT,                           -- free text: drug/food/environmental
  medical_history  TEXT,                           -- past medical conditions
  previous_history TEXT,                           -- previous surgical / treatment history

  -- ── Step 3: Chief Complaint ────────────────────────────────────
  chief_complaint  TEXT,                           -- primary presenting complaint

  -- ── Step 3: Examination (registration-level) ───────────────────
  exam_general     TEXT,                           -- general physical exam at registration
  exam_neurological TEXT,                          -- neurological exam at registration

  -- ── Step 4: Investigations ─────────────────────────────────────
  clinical_diagnosis  TEXT,                        -- provisional / clinical diagnosis
  imaging             TEXT,                        -- MRI / CT / X-Ray findings (text)
  other_investigations TEXT,                       -- blood tests, EEG, EMG, etc.

  -- ── Step 5: Treatment Plan ─────────────────────────────────────
  impression       TEXT,                           -- final impression / diagnosis
  plan             TEXT,                           -- treatment plan
  treatment        TEXT,                           -- medications / procedures prescribed
  treatment_notes  TEXT,                           -- additional treatment notes
  advice           TEXT,                           -- discharge / follow-up advice

  -- ── Admin ──────────────────────────────────────────────────────
  notes            TEXT,                           -- legacy JSON blob (kept for backward compat)
  is_active        BOOLEAN     NOT NULL DEFAULT true,
  deleted_at       TIMESTAMPTZ,
  created_by       UUID        REFERENCES users(id),
  updated_by       UUID        REFERENCES users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add all missing columns safely
ALTER TABLE patients ADD COLUMN IF NOT EXISTS alt_phone           TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS email               TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS id_proof_type       TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS id_proof_number     TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS weight              TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS blood_pressure      TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS temperature         TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS allergies           TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS medical_history     TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS previous_history    TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS chief_complaint     TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS exam_general        TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS exam_neurological   TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS clinical_diagnosis  TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS imaging             TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS other_investigations TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS impression          TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS plan                TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS treatment           TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS treatment_notes     TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS advice              TEXT;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_patients_prn    ON patients(prn);
CREATE INDEX IF NOT EXISTS idx_patients_name   ON patients(first_name, last_name);
CREATE INDEX IF NOT EXISTS idx_patients_phone  ON patients(phone);
CREATE INDEX IF NOT EXISTS idx_patients_active ON patients(is_active) WHERE is_active = true;

-- ────────────────────────────────────────────────────────────────────
-- 3. VISITS
--    One row per clinic visit (OPD / Emergency / Follow-up)
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS visits (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id          UUID        NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  visit_date          TIMESTAMPTZ NOT NULL DEFAULT now(),
  visit_type          TEXT        NOT NULL DEFAULT 'opd',
  -- visit_type: 'opd' | 'emergency' | 'follow_up'

  -- ── Free-text sections (Visit Wizard Steps) ────────────────────
  complaints          TEXT,                        -- Chief Complaints (comma-separated chips)
  notes               TEXT,                        -- History / additional notes

  -- ── Vitals (inline in visit form) ─────────────────────────────
  bp                  TEXT,                        -- Blood Pressure e.g. "120/80"
  pulse               TEXT,                        -- Pulse rate e.g. "72 bpm"
  temperature         TEXT,                        -- e.g. "98.6"
  spo2                TEXT,                        -- SpO2 % e.g. "98"
  weight              TEXT,                        -- e.g. "72"
  height              TEXT,                        -- e.g. "165"

  -- ── Examination (general, not CNS-specific) ────────────────────
  exam_physical       TEXT,                        -- General Physical Examination
  exam_systemic       TEXT,                        -- Systemic Examination
  exam_radiology      TEXT,                        -- Radiology / Investigations text

  -- ── Clinical ──────────────────────────────────────────────────
  clinical_impression TEXT,                        -- Diagnosis / Impression
  plan                TEXT,                        -- Treatment Plan

  -- ── Doctor & context ──────────────────────────────────────────
  doctor_assigned     TEXT,                        -- treating doctor name / free text
  medications         TEXT,                        -- free-text medication notes

  -- ── Legacy JSON (examination field — kept for backward compat) ─
  examination         TEXT,                        -- JSON blob from old format

  -- ── Status ────────────────────────────────────────────────────
  status              TEXT        NOT NULL DEFAULT 'draft',  -- 'draft' | 'completed'
  is_active           BOOLEAN     NOT NULL DEFAULT true,
  deleted_at          TIMESTAMPTZ,
  created_by          UUID        REFERENCES users(id),
  updated_by          UUID        REFERENCES users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE visits ADD COLUMN IF NOT EXISTS bp                TEXT;
ALTER TABLE visits ADD COLUMN IF NOT EXISTS pulse             TEXT;
ALTER TABLE visits ADD COLUMN IF NOT EXISTS temperature       TEXT;
ALTER TABLE visits ADD COLUMN IF NOT EXISTS spo2              TEXT;
ALTER TABLE visits ADD COLUMN IF NOT EXISTS weight            TEXT;
ALTER TABLE visits ADD COLUMN IF NOT EXISTS height            TEXT;
ALTER TABLE visits ADD COLUMN IF NOT EXISTS exam_physical     TEXT;
ALTER TABLE visits ADD COLUMN IF NOT EXISTS exam_systemic     TEXT;
ALTER TABLE visits ADD COLUMN IF NOT EXISTS exam_radiology    TEXT;
ALTER TABLE visits ADD COLUMN IF NOT EXISTS doctor_assigned   TEXT;
ALTER TABLE visits ADD COLUMN IF NOT EXISTS medications       TEXT;

CREATE INDEX IF NOT EXISTS idx_visits_patient ON visits(patient_id);
CREATE INDEX IF NOT EXISTS idx_visits_date    ON visits(visit_date DESC);
CREATE INDEX IF NOT EXISTS idx_visits_status  ON visits(status);

-- ────────────────────────────────────────────────────────────────────
-- 4. CNS EXAMINATIONS
--    Neurology-specific examination per visit
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS examinations (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id            UUID NOT NULL REFERENCES visits(id)    ON DELETE CASCADE,
  patient_id          UUID NOT NULL REFERENCES patients(id)  ON DELETE CASCADE,

  -- ── Free-text (primary input for each section) ─────────────────
  general_text        TEXT,          -- General examination summary
  motor_text          TEXT,          -- Motor system free text
  sensory_text        TEXT,          -- Sensory system free text
  reflexes_text       TEXT,          -- Deep tendon reflexes free text
  cerebellar_text     TEXT,          -- Cerebellar signs free text
  special_tests_text  TEXT,          -- Special tests (Romberg, SLR, etc.)

  -- ── Structured helpers (JSONB) ─────────────────────────────────
  motor_data          JSONB NOT NULL DEFAULT '[]',
  -- [{joint, right, left, notes}]
  -- e.g. [{joint:"Shoulder",right:"5/5",left:"4/5",notes:""}]

  sensory_data        JSONB NOT NULL DEFAULT '[]',
  -- [{dermatome, pain_right, pain_left, touch_right, touch_left}]

  reflex_data         JSONB NOT NULL DEFAULT '{}',
  -- {bj, tj, sj, kj, aj, plantars, hoffman}
  -- values: "present" | "absent" | "exaggerated" | "diminished"

  created_by          UUID REFERENCES users(id),
  updated_by          UUID REFERENCES users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_examinations_visit    ON examinations(visit_id);
CREATE INDEX IF NOT EXISTS idx_examinations_patient  ON examinations(patient_id);

-- ────────────────────────────────────────────────────────────────────
-- 5. PRESCRIPTIONS
--    Drugs + free-text Rx per visit
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS prescriptions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id    UUID REFERENCES visits(id)    ON DELETE CASCADE,
  patient_id  UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,

  text        TEXT,           -- Free-text Rx (primary input)

  drugs       JSONB NOT NULL DEFAULT '[]',
  -- [{
  --   id, generic_name, brand_name, composition,
  --   dose, frequency, duration, instructions,
  --   tapering_steps: [{dose, duration, instructions}]
  -- }]

  created_by  UUID REFERENCES users(id),
  updated_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prescriptions_visit   ON prescriptions(visit_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_patient ON prescriptions(patient_id);

-- ────────────────────────────────────────────────────────────────────
-- 6. DRUGS MASTER
--    Reference table for drug autocomplete
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS drugs_master (
  id                UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  generic_name      TEXT    NOT NULL,
  brand_names       TEXT[]  NOT NULL DEFAULT '{}',
  composition       TEXT,
  category          TEXT,
  -- 'analgesic' | 'nsaid' | 'steroid' | 'anticonvulsant' |
  -- 'muscle_relaxant' | 'neuroprotective' | 'antibiotic' | other
  default_dose      TEXT,
  default_frequency TEXT,   -- OD / BD / TDS / QID / SOS
  default_duration  TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_drugs_generic  ON drugs_master(generic_name);
CREATE INDEX IF NOT EXISTS idx_drugs_category ON drugs_master(category);

-- ────────────────────────────────────────────────────────────────────
-- 7. SURGERIES
--    All fields from the Surgery Wizard
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS surgeries (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id          UUID        NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  surgery_date        TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- ── Step 1: Basic Info ─────────────────────────────────────────
  your_role           TEXT,    -- 'primary' | 'assistant' | 'observer'
  pre_op_diagnosis    TEXT,    -- Pre-operative diagnosis
  procedure           TEXT,    -- Procedure name / description

  -- ── Step 2: Surgical Team ──────────────────────────────────────
  primary_surgeon     TEXT,
  assistant_surgeons  TEXT,    -- comma-separated names
  anesthesia_type     TEXT,    -- 'general' | 'spinal' | 'local' | 'epidural'
  anesthesiologist    TEXT,

  -- ── Step 3: Implants ──────────────────────────────────────────
  implants            TEXT,    -- free text summary
  implant_details     JSONB NOT NULL DEFAULT '[]',
  -- [{name, brand, size, serial_number, lot_number}]

  -- ── Step 4: Intraoperative ─────────────────────────────────────
  intraop_findings    TEXT,    -- Intraoperative findings
  ot_notes            TEXT,    -- OT / operative notes
  complications       TEXT,    -- Intraoperative complications

  -- ── Step 5: Post-op ────────────────────────────────────────────
  post_op_plan        TEXT,    -- Post-operative plan / instructions

  -- ── Admin ─────────────────────────────────────────────────────
  status              TEXT        NOT NULL DEFAULT 'draft',  -- 'draft' | 'completed'
  is_active           BOOLEAN     NOT NULL DEFAULT true,
  deleted_at          TIMESTAMPTZ,
  created_by          UUID        REFERENCES users(id),
  updated_by          UUID        REFERENCES users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_surgeries_patient ON surgeries(patient_id);
CREATE INDEX IF NOT EXISTS idx_surgeries_date    ON surgeries(surgery_date DESC);
CREATE INDEX IF NOT EXISTS idx_surgeries_status  ON surgeries(status);

-- ────────────────────────────────────────────────────────────────────
-- 8. PHOTOS
--    All uploaded files — images, PDFs, scans
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS photos (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id     UUID NOT NULL REFERENCES patients(id)  ON DELETE CASCADE,
  visit_id       UUID REFERENCES visits(id)             ON DELETE CASCADE,
  surgery_id     UUID REFERENCES surgeries(id)          ON DELETE CASCADE,

  -- ── Storage ────────────────────────────────────────────────────
  storage_path   TEXT NOT NULL,   -- path inside Supabase bucket
  url            TEXT,            -- public URL
  thumbnail_path TEXT,            -- compressed thumbnail path

  -- ── Categorisation ─────────────────────────────────────────────
  category       TEXT NOT NULL,
  -- 'visit' | 'examination' | 'radiology' | 'treatment' |
  -- 'surgery_findings' | 'surgery_ot_notes' | 'patient_report'

  caption        TEXT,            -- filename or user-supplied label
  file_size      INTEGER,         -- bytes
  mime_type      TEXT,            -- 'image/jpeg' | 'application/pdf' | etc.
  is_uploaded    BOOLEAN     NOT NULL DEFAULT false,
  local_path     TEXT,            -- offline cache path

  created_by     UUID        REFERENCES users(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE photos ADD COLUMN IF NOT EXISTS mime_type TEXT;

CREATE INDEX IF NOT EXISTS idx_photos_patient    ON photos(patient_id);
CREATE INDEX IF NOT EXISTS idx_photos_visit      ON photos(visit_id);
CREATE INDEX IF NOT EXISTS idx_photos_surgery    ON photos(surgery_id);
CREATE INDEX IF NOT EXISTS idx_photos_category   ON photos(category);

-- ────────────────────────────────────────────────────────────────────
-- 9. RADIOLOGY
--    Structured investigations linked to visit or surgery
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS radiology (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id        UUID REFERENCES visits(id)    ON DELETE CASCADE,
  surgery_id      UUID REFERENCES surgeries(id) ON DELETE CASCADE,
  patient_id      UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,

  text            TEXT,   -- free text override / summary

  investigations  JSONB NOT NULL DEFAULT '[]',
  -- [{type, description, date, findings, impression}]
  -- type: 'MRI' | 'CT' | 'X-Ray' | 'USG' | 'Angiogram' | 'PET' | other

  created_by      UUID REFERENCES users(id),
  updated_by      UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_radiology_visit   ON radiology(visit_id);
CREATE INDEX IF NOT EXISTS idx_radiology_patient ON radiology(patient_id);

-- ────────────────────────────────────────────────────────────────────
-- 10. PRINT TEMPLATES
--     Saved report configuration templates (Print & Export screen)
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS print_templates (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT        NOT NULL,
  is_default   BOOLEAN     NOT NULL DEFAULT false,
  created_by   UUID        REFERENCES users(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS print_template_fields (
  id             UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id    UUID    NOT NULL REFERENCES print_templates(id) ON DELETE CASCADE,
  field_key      TEXT    NOT NULL,   -- e.g. 'firstName', 'diagnosis', 'medications'
  field_label    TEXT    NOT NULL,   -- display label
  section        TEXT    NOT NULL,   -- 'patient_info' | 'vitals' | 'clinical' | 'treatment'
  is_enabled     BOOLEAN NOT NULL DEFAULT true,
  display_order  INTEGER NOT NULL DEFAULT 0,
  UNIQUE (template_id, field_key)
);

CREATE INDEX IF NOT EXISTS idx_template_fields ON print_template_fields(template_id);

-- ────────────────────────────────────────────────────────────────────
-- 11. TIMELINE EVENTS
--     Auto-populated from visits + surgeries (via triggers)
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS timeline_events (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID        NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  event_type   TEXT        NOT NULL,   -- 'visit' | 'surgery'
  reference_id UUID        NOT NULL,   -- visits.id or surgeries.id
  event_date   TIMESTAMPTZ NOT NULL,
  summary      TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_timeline_patient ON timeline_events(patient_id);
CREATE INDEX IF NOT EXISTS idx_timeline_date    ON timeline_events(event_date DESC);

-- ────────────────────────────────────────────────────────────────────
-- 12. SYNC QUEUE
--     Offline-first: pending mutations queued for sync
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sync_queue (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type  TEXT        NOT NULL,   -- 'patient' | 'visit' | 'surgery' | 'examination'
  entity_id    UUID        NOT NULL,
  operation    TEXT        NOT NULL,   -- 'insert' | 'update' | 'delete'
  payload      JSONB       NOT NULL,
  queued_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  attempts     INTEGER     NOT NULL DEFAULT 0,
  last_error   TEXT
);

CREATE INDEX IF NOT EXISTS idx_sync_queue_entity ON sync_queue(entity_type, entity_id);

-- ────────────────────────────────────────────────────────────────────
-- 13. AUDIT LOGS
--     Tracks every change for compliance
-- ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name     TEXT        NOT NULL,
  record_id      UUID        NOT NULL,
  action         TEXT        NOT NULL,   -- 'insert' | 'update' | 'delete'
  old_data       JSONB,
  new_data       JSONB,
  changed_fields TEXT[],
  performed_by   UUID        REFERENCES users(id),
  performed_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_record ON audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_user   ON audit_logs(performed_by);
CREATE INDEX IF NOT EXISTS idx_audit_time   ON audit_logs(performed_at DESC);

-- ────────────────────────────────────────────────────────────────────
-- 14. AUTO updated_at TRIGGER
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'users','patients','visits','examinations',
    'radiology','prescriptions','surgeries','print_templates'
  ] LOOP
    EXECUTE format('
      DROP TRIGGER IF EXISTS trg_%s_updated_at ON %s;
      CREATE TRIGGER trg_%s_updated_at
      BEFORE UPDATE ON %s
      FOR EACH ROW EXECUTE FUNCTION _set_updated_at()', t, t, t, t);
  END LOOP;
END $$;

-- ────────────────────────────────────────────────────────────────────
-- 15. AUTO TIMELINE POPULATION (trigger)
-- ────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _sync_timeline()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_TABLE_NAME = 'visits' THEN
    INSERT INTO timeline_events(patient_id, event_type, reference_id, event_date, summary)
    VALUES (NEW.patient_id, 'visit', NEW.id, NEW.visit_date,
            COALESCE(LEFT(NEW.complaints, 120), LEFT(NEW.clinical_impression, 120), 'OPD Visit'))
    ON CONFLICT DO NOTHING;
  ELSIF TG_TABLE_NAME = 'surgeries' THEN
    INSERT INTO timeline_events(patient_id, event_type, reference_id, event_date, summary)
    VALUES (NEW.patient_id, 'surgery', NEW.id, NEW.surgery_date,
            COALESCE(LEFT(NEW.procedure, 120), 'Surgery'))
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_visits_timeline    ON visits;
DROP TRIGGER IF EXISTS trg_surgeries_timeline ON surgeries;

CREATE TRIGGER trg_visits_timeline
  AFTER INSERT ON visits
  FOR EACH ROW EXECUTE FUNCTION _sync_timeline();

CREATE TRIGGER trg_surgeries_timeline
  AFTER INSERT ON surgeries
  FOR EACH ROW EXECUTE FUNCTION _sync_timeline();

-- ────────────────────────────────────────────────────────────────────
-- 16. ROW LEVEL SECURITY
--     Admin: full CRUD.  Assistant: SELECT only on all tables.
-- ────────────────────────────────────────────────────────────────────
ALTER TABLE users             ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients          ENABLE ROW LEVEL SECURITY;
ALTER TABLE visits            ENABLE ROW LEVEL SECURITY;
ALTER TABLE examinations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescriptions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE drugs_master      ENABLE ROW LEVEL SECURITY;
ALTER TABLE radiology         ENABLE ROW LEVEL SECURITY;
ALTER TABLE surgeries         ENABLE ROW LEVEL SECURITY;
ALTER TABLE photos            ENABLE ROW LEVEL SECURITY;
ALTER TABLE print_templates   ENABLE ROW LEVEL SECURITY;
ALTER TABLE print_template_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE timeline_events   ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_queue        ENABLE ROW LEVEL SECURITY;

-- Helper: role of the calling user
CREATE OR REPLACE FUNCTION _user_role()
RETURNS TEXT LANGUAGE sql STABLE AS $$
  SELECT role FROM users WHERE id = auth.uid();
$$;

-- ── Apply policies to every main table ──────────────────────────────
DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'patients','visits','examinations','prescriptions',
    'radiology','surgeries','photos','timeline_events'
  ] LOOP

    -- Admin: full access
    EXECUTE format('
      DROP POLICY IF EXISTS admin_all ON %s;
      CREATE POLICY admin_all ON %s
        FOR ALL TO authenticated
        USING     (_user_role() = ''admin'')
        WITH CHECK(_user_role() = ''admin'')', t, t);

    -- Assistant: read-only
    EXECUTE format('
      DROP POLICY IF EXISTS assistant_read ON %s;
      CREATE POLICY assistant_read ON %s
        FOR SELECT TO authenticated
        USING (_user_role() IN (''assistant'',''doctor'',''nurse'',''receptionist''))',
      t, t);

  END LOOP;
END $$;

-- drugs_master: everyone can read (needed for prescription autocomplete)
DROP POLICY IF EXISTS all_read_drugs ON drugs_master;
CREATE POLICY all_read_drugs ON drugs_master
  FOR SELECT TO authenticated USING (true);

-- print_templates: admin full, assistant read
DROP POLICY IF EXISTS admin_all_templates     ON print_templates;
DROP POLICY IF EXISTS assistant_read_templates ON print_templates;
CREATE POLICY admin_all_templates ON print_templates
  FOR ALL TO authenticated
  USING (_user_role() = 'admin')
  WITH CHECK (_user_role() = 'admin');
CREATE POLICY assistant_read_templates ON print_templates
  FOR SELECT TO authenticated
  USING (_user_role() IN ('assistant','doctor','nurse','receptionist'));

DROP POLICY IF EXISTS admin_all_template_fields     ON print_template_fields;
DROP POLICY IF EXISTS assistant_read_template_fields ON print_template_fields;
CREATE POLICY admin_all_template_fields ON print_template_fields
  FOR ALL TO authenticated
  USING (_user_role() = 'admin')
  WITH CHECK (_user_role() = 'admin');
CREATE POLICY assistant_read_template_fields ON print_template_fields
  FOR SELECT TO authenticated
  USING (_user_role() IN ('assistant','doctor','nurse','receptionist'));

-- audit_logs: admin read-only (no one writes directly, triggers do it)
DROP POLICY IF EXISTS admin_read_audit ON audit_logs;
CREATE POLICY admin_read_audit ON audit_logs
  FOR SELECT TO authenticated
  USING (_user_role() = 'admin');

-- sync_queue: admin full
DROP POLICY IF EXISTS admin_all_sync ON sync_queue;
CREATE POLICY admin_all_sync ON sync_queue
  FOR ALL TO authenticated
  USING (_user_role() = 'admin')
  WITH CHECK (_user_role() = 'admin');

-- ────────────────────────────────────────────────────────────────────
-- 17. VERIFY
-- ────────────────────────────────────────────────────────────────────
SELECT
  table_name,
  COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'users','patients','visits','examinations','prescriptions',
    'radiology','surgeries','photos','print_templates',
    'print_template_fields','timeline_events','audit_logs','sync_queue'
  )
GROUP BY table_name
ORDER BY table_name;
