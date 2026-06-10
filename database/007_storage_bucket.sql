-- ================================================================
-- 007_storage_bucket.sql
-- Supabase Storage — patient-photos bucket
-- Run in: Supabase SQL Editor
-- ================================================================

-- Create the storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('patient-photos', 'patient-photos', true)
ON CONFLICT (id) DO NOTHING;

-- RLS policies for the bucket
CREATE POLICY "photos_select" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'patient-photos');

CREATE POLICY "photos_insert" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'patient-photos');

CREATE POLICY "photos_delete" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'patient-photos');
