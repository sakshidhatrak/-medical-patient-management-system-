-- ================================================================
-- 005_neurosurgery_rls.sql
-- Row Level Security Policies — all authenticated users full access
-- Run AFTER 004_neurosurgery_schema.sql
-- ================================================================

DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'patients','visits','examinations','radiology','prescriptions',
    'surgeries','photos','timeline_events','audit_logs','sync_queue'
  ] LOOP
    EXECUTE format('
      CREATE POLICY "%s_select" ON %s FOR SELECT TO authenticated USING (true);
      CREATE POLICY "%s_insert" ON %s FOR INSERT TO authenticated WITH CHECK (true);
      CREATE POLICY "%s_update" ON %s FOR UPDATE TO authenticated USING (true);
      CREATE POLICY "%s_delete" ON %s FOR DELETE TO authenticated USING (true);
    ', t, t, t, t, t, t, t, t);
  END LOOP;
END $$;

-- drugs_master: read by all, write by admin only
CREATE POLICY "drugs_select" ON drugs_master
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "drugs_insert" ON drugs_master
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "drugs_update" ON drugs_master
  FOR UPDATE TO authenticated USING (true);
