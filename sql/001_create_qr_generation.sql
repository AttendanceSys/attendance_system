-- Migration: create qr_generation table
-- Run this in Supabase SQL editor or with psql as a privileged user

CREATE TABLE IF NOT EXISTS public.qr_generation (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  generate_qr_code text NULL,
  teacher_id uuid NULL,
  created_at timestamptz NULL DEFAULT now(),
  CONSTRAINT qr_generation_pkey PRIMARY KEY (id),
  CONSTRAINT qr_generation_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES teachers (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Optional: grant insert/select on the table to authenticated role (adjust for your RLS policies)
-- GRANT SELECT, INSERT ON public.qr_generation TO authenticated;
