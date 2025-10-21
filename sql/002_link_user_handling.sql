-- Migration: 002_link_user_handling.sql
-- Purpose: link teachers, students and admins rows to the central user_handling table
-- Adds a nullable user_id uuid column referencing user_handling(id) with ON DELETE CASCADE

BEGIN;

-- Teachers
ALTER TABLE IF EXISTS teachers
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES user_handling(id) ON DELETE CASCADE;

-- Students
ALTER TABLE IF EXISTS students
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES user_handling(id) ON DELETE CASCADE;

-- Admins
ALTER TABLE IF EXISTS admins
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES user_handling(id) ON DELETE CASCADE;

COMMIT;

-- Notes:
-- - Columns are added as nullable so existing rows won't be rejected.
-- - If you want an index on these columns for lookups, create one per table:
--     CREATE INDEX IF NOT EXISTS idx_students_user_id ON students(user_id);
-- - If your DB has RLS enabled, ensure appropriate policies exist so your migration
--   and application can set or update these columns (or run migration with a service role).
