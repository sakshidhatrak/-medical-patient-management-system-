-- ================================================================
-- 004_neurosurgery_schema.sql
-- Neurosurgery OPD & Surgery Management — Complete Schema
-- Run AFTER 001_schema.sql
-- ================================================================

-- ── Drop old tables if rebuilding ────────────────────────────────
DROP TABLE IF EXISTS patient_details  CASCADE;
DROP TABLE IF EXISTS appointments     CASCADE;
DROP TABLE IF EXISTS medical_records  CASCADE;
DROP TABLE IF EXISTS sync_queue       CASCADE;
DROP TABLE IF EXISTS patients         CASCADE;

-- ── PATIENTS ─────────────────────────────────────────────────────
CREATE TABLE patients (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  prn          TEXT        NOT NULL UNIQUE,          -- ddmmyyhhmmss
  first_name   TEXT        NOT NULL,
  last_name    TEXT        NOT NULL DEFAULT '',
  age          INTEGER,
  date_of_birth DATE,
  sex          TEXT,                                 -- male/female/other
  phone        TEXT,
  address      TEXT,
  notes        TEXT,
  sync_status  TEXT        NOT NULL DEFAULT 'synced',
  is_active    BOOLEAN     NOT NULL DEFAULT true,
  deleted_at   TIMESTAMPTZ,
  created_by   UUID        REFERENCES users(id),
  updated_by   UUID        REFERENCES users(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_patients_prn    ON patients(prn);
CREATE INDEX idx_patients_name   ON patients(first_name, last_name);
CREATE INDEX idx_patients_phone  ON patients(phone);
CREATE INDEX idx_patients_active ON patients(is_active) WHERE is_active = true;

-- ── VISITS ───────────────────────────────────────────────────────
CREATE TABLE visits (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id          UUID        NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  visit_date          TIMESTAMPTZ NOT NULL DEFAULT now(),
  visit_type          TEXT        NOT NULL DEFAULT 'opd',  -- opd/emergency/follow_up

  -- Free-text sections
  complaints          TEXT,
  examination         TEXT,
  clinical_impression TEXT,
  plan                TEXT,
  notes               TEXT,

  status              TEXT        NOT NULL DEFAULT 'draft',  -- draft/completed
  sync_status         TEXT        NOT NULL DEFAULT 'pending',
  is_active           BOOLEAN     NOT NULL DEFAULT true,
  deleted_at          TIMESTAMPTZ,

  created_by          UUID        REFERENCES users(id),
  updated_by          UUID        REFERENCES users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_visits_patient ON visits(patient_id);
CREATE INDEX idx_visits_date    ON visits(visit_date DESC);

-- ── CNS EXAMINATIONS ─────────────────────────────────────────────
CREATE TABLE examinations (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id         UUID NOT NULL REFERENCES visits(id)   ON DELETE CASCADE,
  patient_id       UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,

  general_text     TEXT,
  motor_text       TEXT,
  sensory_text     TEXT,
  reflexes_text    TEXT,
  cerebellar_text  TEXT,
  special_tests_text TEXT,

  -- Structured data (optional helpers)
  motor_data       JSONB NOT NULL DEFAULT '[]',   -- [{joint,right,left,notes}]
  sensory_data     JSONB NOT NULL DEFAULT '[]',   -- [{dermatome,pain_r,pain_l,touch_r,touch_l}]
  reflex_data      JSONB NOT NULL DEFAULT '{}',   -- {bj,tj,sj,kj,aj,plantars,hoffman}

  created_by       UUID REFERENCES users(id),
  updated_by       UUID REFERENCES users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_examinations_visit ON examinations(visit_id);

-- ── RADIOLOGY ────────────────────────────────────────────────────
CREATE TABLE radiology (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id        UUID REFERENCES visits(id)    ON DELETE CASCADE,
  surgery_id      UUID,
  patient_id      UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,

  investigations  JSONB NOT NULL DEFAULT '[]',
  -- [{type, description, date, findings, impression}]

  text            TEXT,   -- free text override

  created_by      UUID REFERENCES users(id),
  updated_by      UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_radiology_visit    ON radiology(visit_id);
CREATE INDEX idx_radiology_patient  ON radiology(patient_id);

-- ── PRESCRIPTIONS ────────────────────────────────────────────────
CREATE TABLE prescriptions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id    UUID REFERENCES visits(id)    ON DELETE CASCADE,
  patient_id  UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,

  text        TEXT,           -- primary free text
  drugs       JSONB NOT NULL DEFAULT '[]',
  -- [{generic,brand,dose,frequency,duration,instructions,tapering_steps}]

  created_by  UUID REFERENCES users(id),
  updated_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_prescriptions_visit   ON prescriptions(visit_id);
CREATE INDEX idx_prescriptions_patient ON prescriptions(patient_id);

-- ── DRUGS MASTER ─────────────────────────────────────────────────
CREATE TABLE drugs_master (
  id                UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  generic_name      TEXT    NOT NULL,
  brand_names       TEXT[]  NOT NULL DEFAULT '{}',
  composition       TEXT,
  category          TEXT,   -- analgesic/steroid/antibiotic/anticonvulsant/etc
  default_dose      TEXT,
  default_frequency TEXT,
  default_duration  TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_drugs_generic   ON drugs_master(generic_name);
CREATE INDEX idx_drugs_category  ON drugs_master(category);

-- ── SURGERIES ────────────────────────────────────────────────────
CREATE TABLE surgeries (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id          UUID        NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  surgery_date        TIMESTAMPTZ NOT NULL DEFAULT now(),

  your_role           TEXT,          -- primary/assistant/observer
  pre_op_diagnosis    TEXT,
  procedure           TEXT,
  primary_surgeon     TEXT,
  assistant_surgeons  TEXT,
  anesthesia_type     TEXT,
  anesthesiologist    TEXT,
  implants            TEXT,
  implant_details     JSONB NOT NULL DEFAULT '[]',

  intraop_findings    TEXT,
  ot_notes            TEXT,
  complications       TEXT,
  post_op_plan        TEXT,

  status              TEXT        NOT NULL DEFAULT 'draft',
  sync_status         TEXT        NOT NULL DEFAULT 'pending',
  is_active           BOOLEAN     NOT NULL DEFAULT true,
  deleted_at          TIMESTAMPTZ,

  created_by          UUID        REFERENCES users(id),
  updated_by          UUID        REFERENCES users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_surgeries_patient ON surgeries(patient_id);
CREATE INDEX idx_surgeries_date    ON surgeries(surgery_date DESC);

-- ── PHOTOS ───────────────────────────────────────────────────────
CREATE TABLE photos (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id     UUID NOT NULL REFERENCES patients(id)  ON DELETE CASCADE,
  visit_id       UUID REFERENCES visits(id)             ON DELETE CASCADE,
  surgery_id     UUID REFERENCES surgeries(id)          ON DELETE CASCADE,

  storage_path   TEXT NOT NULL,
  url            TEXT,
  thumbnail_path TEXT,

  category       TEXT NOT NULL,
  -- visit/examination/radiology/treatment/surgery_findings/surgery_ot_notes

  caption        TEXT,
  file_size      INTEGER,
  mime_type      TEXT,
  is_uploaded    BOOLEAN     NOT NULL DEFAULT false,
  local_path     TEXT,

  created_by     UUID        REFERENCES users(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_photos_patient  ON photos(patient_id);
CREATE INDEX idx_photos_visit    ON photos(visit_id);
CREATE INDEX idx_photos_surgery  ON photos(surgery_id);

-- ── TIMELINE EVENTS ──────────────────────────────────────────────
CREATE TABLE timeline_events (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id   UUID        NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  event_type   TEXT        NOT NULL,   -- visit/surgery
  reference_id UUID        NOT NULL,
  event_date   TIMESTAMPTZ NOT NULL,
  summary      TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_timeline_patient ON timeline_events(patient_id);
CREATE INDEX idx_timeline_date    ON timeline_events(event_date DESC);

-- ── AUDIT LOGS ───────────────────────────────────────────────────
CREATE TABLE audit_logs (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name     TEXT        NOT NULL,
  record_id      UUID        NOT NULL,
  action         TEXT        NOT NULL,   -- insert/update/delete
  old_data       JSONB,
  new_data       JSONB,
  changed_fields TEXT[],
  performed_by   UUID        REFERENCES users(id),
  performed_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_record ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_time   ON audit_logs(performed_at DESC);

-- ── SYNC QUEUE ───────────────────────────────────────────────────
CREATE TABLE sync_queue (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type  TEXT        NOT NULL,
  entity_id    UUID        NOT NULL,
  operation    TEXT        NOT NULL,   -- insert/update/delete
  payload      JSONB       NOT NULL,
  queued_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  attempts     INTEGER     NOT NULL DEFAULT 0,
  last_error   TEXT
);

CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_type, entity_id);

-- ── AUTO updated_at TRIGGER ──────────────────────────────────────
CREATE OR REPLACE FUNCTION _set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['patients','visits','examinations','radiology','prescriptions','surgeries'] LOOP
    EXECUTE format('
      CREATE TRIGGER trg_%s_updated_at
      BEFORE UPDATE ON %s
      FOR EACH ROW EXECUTE FUNCTION _set_updated_at()', t, t);
  END LOOP;
END $$;

-- ── AUTO TIMELINE POPULATION ─────────────────────────────────────
CREATE OR REPLACE FUNCTION _sync_timeline()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_TABLE_NAME = 'visits' THEN
    INSERT INTO timeline_events(patient_id, event_type, reference_id, event_date, summary)
    VALUES (NEW.patient_id, 'visit', NEW.id, NEW.visit_date,
            COALESCE(LEFT(NEW.complaints, 100), 'OPD Visit'))
    ON CONFLICT DO NOTHING;
  ELSIF TG_TABLE_NAME = 'surgeries' THEN
    INSERT INTO timeline_events(patient_id, event_type, reference_id, event_date, summary)
    VALUES (NEW.patient_id, 'surgery', NEW.id, NEW.surgery_date,
            COALESCE(LEFT(NEW.procedure, 100), 'Surgery'))
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_visits_timeline
  AFTER INSERT ON visits
  FOR EACH ROW EXECUTE FUNCTION _sync_timeline();

CREATE TRIGGER trg_surgeries_timeline
  AFTER INSERT ON surgeries
  FOR EACH ROW EXECUTE FUNCTION _sync_timeline();

-- ── ENABLE RLS ───────────────────────────────────────────────────
ALTER TABLE patients       ENABLE ROW LEVEL SECURITY;
ALTER TABLE visits         ENABLE ROW LEVEL SECURITY;
ALTER TABLE examinations   ENABLE ROW LEVEL SECURITY;
ALTER TABLE radiology      ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescriptions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE drugs_master   ENABLE ROW LEVEL SECURITY;
ALTER TABLE surgeries      ENABLE ROW LEVEL SECURITY;
ALTER TABLE photos         ENABLE ROW LEVEL SECURITY;
ALTER TABLE timeline_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_queue     ENABLE ROW LEVEL SECURITY;
