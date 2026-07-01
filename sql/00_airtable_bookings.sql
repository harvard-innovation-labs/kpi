-- ============================================================
-- 00_airtable_bookings.sql
-- Rebuilds airtable_bookings for the current AY only.
-- Safe to re-run: deletes current AY rows then re-inserts from airtable_raw.
-- Prior AY data in airtable_bookings is preserved.
--
-- Run this AFTER airtable_raw has been refreshed from the CSV export.
-- Run this BEFORE 02_student_events.sql.
--
-- Requires: airtable_bookings table has an academic_year column.
-- If not yet added, run once:
--   ALTER TABLE airtable_bookings ADD COLUMN academic_year text;
-- ============================================================

-- Delete only current AY rows
WITH current_ay AS (
  SELECT (
    CASE WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= 9
         THEN EXTRACT(YEAR FROM CURRENT_DATE)::int
         ELSE EXTRACT(YEAR FROM CURRENT_DATE)::int - 1
    END)::text || '-' ||
    (CASE WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= 9
         THEN EXTRACT(YEAR FROM CURRENT_DATE)::int + 1
         ELSE EXTRACT(YEAR FROM CURRENT_DATE)::int
    END)::text AS ay
)
DELETE FROM airtable_bookings
WHERE academic_year = (SELECT ay FROM current_ay);

-- Insert current AY rows from airtable_raw
INSERT INTO airtable_bookings (
  unique_id, booker, booker_email, booker_school,
  booker_harvard_affiliation, booker_grad_year,
  startup, startup_description, question,
  expert, expert_vertical, expert_school, expert_type,
  created_at, starting_at, duration, location,
  academic_year
)
SELECT
  unique_id,
  student_name AS booker,
  student_email AS booker_email,
  primary_school_college AS booker_school,
  student_status AS booker_harvard_affiliation,
  NULLIF(graduation_year, '')::int AS booker_grad_year,
  venture_name AS startup,
  short_venture_description AS startup_description,
  agenda AS question,
  full_name_from_expert_from_slot AS expert,
  primary_vertical_from_expert_from_slot AS expert_vertical,
  university_affiliation_from_expert_2_from_slot AS expert_school,
  expert_type_from_expert_from_slot AS expert_type,
  created AS created_at,
  start_local_from_slot AS starting_at,
  CASE
    WHEN start_iso_no_tz_from_slot IS NOT NULL
     AND end_iso_no_tz_from_slot IS NOT NULL
    THEN EXTRACT(
      EPOCH FROM (
        replace(end_iso_no_tz_from_slot, '"T"', 'T')::timestamp -
        replace(start_iso_no_tz_from_slot, '"T"', 'T')::timestamp
      )
    ) / 60
  END::int AS duration,
  location_from_slot AS location,
  (CASE WHEN EXTRACT(MONTH FROM start_local_from_slot) >= 9
        THEN EXTRACT(YEAR FROM start_local_from_slot)::int
        ELSE EXTRACT(YEAR FROM start_local_from_slot)::int - 1
   END)::text || '-' ||
  (CASE WHEN EXTRACT(MONTH FROM start_local_from_slot) >= 9
        THEN EXTRACT(YEAR FROM start_local_from_slot)::int + 1
        ELSE EXTRACT(YEAR FROM start_local_from_slot)::int
   END)::text AS academic_year
FROM airtable_raw
WHERE start_local_from_slot >= MAKE_DATE(
    CASE WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= 9
         THEN EXTRACT(YEAR FROM CURRENT_DATE)::int
         ELSE EXTRACT(YEAR FROM CURRENT_DATE)::int - 1
    END, 9, 1)
  AND start_local_from_slot < MAKE_DATE(
    CASE WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= 9
         THEN EXTRACT(YEAR FROM CURRENT_DATE)::int + 1
         ELSE EXTRACT(YEAR FROM CURRENT_DATE)::int
    END, 9, 1);
