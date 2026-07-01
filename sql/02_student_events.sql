-- ============================================================
-- 02_student_events.sql
-- Rebuilds student_events (fact table) from the 3 source
-- booking/registration tables: oncehub, airtable, eventbrite.
--
-- Safe to re-run: each source is DELETEd then re-INSERTed,
-- so re-running this script never duplicates or orphans rows.
-- Run this AFTER oncehub_bookings, airtable_bookings, and
-- event_attendees have all been refreshed.
-- ============================================================

-- 1) ONCEHUB ---------------------------------------------------
DELETE FROM student_events WHERE source_system = 'oncehub';

INSERT INTO student_events (
  event_key, source_system, source_record_id, event_type,
  booker_name, booker_email_norm, booked_at, event_at, student_id
)
SELECT DISTINCT ON (b.id)
  'oncehub_' || b.id          AS event_key,
  'oncehub'                   AS source_system,
  b.id                        AS source_record_id,
  'booking'                   AS event_type,
  b.booker                    AS booker_name,
  lower(trim(b.booker_email)) AS booker_email_norm,
  b.created_at                AS booked_at,
  b.starting_at               AS event_at,
  s.contact_id                AS student_id
FROM oncehub_bookings b
LEFT JOIN student_dim s ON lower(trim(b.booker_email)) IN (
    s.preferred_email_norm,
    s.sma_registration_email_norm,
    s.permanent_email_norm,
    s.secondary_email_norm
)
ORDER BY b.id,
  CASE
    WHEN lower(trim(b.booker_email)) = s.preferred_email_norm        THEN 1
    WHEN lower(trim(b.booker_email)) = s.sma_registration_email_norm THEN 2
    WHEN lower(trim(b.booker_email)) = s.permanent_email_norm        THEN 3
    WHEN lower(trim(b.booker_email)) = s.secondary_email_norm        THEN 4
    ELSE 99
  END;


-- 2) AIRTABLE ----------------------------------------------------
DELETE FROM student_events WHERE source_system = 'airtable';

INSERT INTO student_events (
  event_key, source_system, source_record_id, event_type,
  booker_name, booker_email_norm, booked_at, event_at, student_id
)
WITH booking_emails AS (
  SELECT
    a.unique_id AS source_record_id,
    'airtable_' || a.unique_id AS event_key,
    'airtable' AS source_system,
    'expert_booking' AS event_type,
    a.booker AS booker_name,
    lower(trim(a.booker_email)) AS booker_email_norm,
    a.created_at AS booked_at,
    a.starting_at AS event_at,
    s.contact_id AS student_id,
    ROW_NUMBER() OVER (
      PARTITION BY a.unique_id
      ORDER BY
        CASE
          WHEN lower(trim(a.booker_email)) = s.preferred_email_norm THEN 1
          WHEN lower(trim(a.booker_email)) = s.sma_registration_email_norm THEN 2
          WHEN lower(trim(a.booker_email)) = s.permanent_email_norm THEN 3
          WHEN lower(trim(a.booker_email)) = s.secondary_email_norm THEN 4
          ELSE 99
        END
    ) AS rn
  FROM airtable_bookings a
  LEFT JOIN student_dim s
    ON lower(trim(a.booker_email)) IN (
      s.preferred_email_norm,
      s.sma_registration_email_norm,
      s.permanent_email_norm,
      s.secondary_email_norm
    )
)
SELECT
  event_key, source_system, source_record_id, event_type,
  booker_name, booker_email_norm, booked_at, event_at, student_id
FROM booking_emails
WHERE rn = 1;


-- 3) EVENTBRITE ----------------------------------------------------
DELETE FROM student_events WHERE source_system = 'eventbrite';

INSERT INTO student_events (
  event_key, source_system, source_record_id, event_type,
  booker_name, booker_email_norm, booked_at, event_at, student_id
)
SELECT DISTINCT ON (ea.event_id, ea.attendee_id)
  'eventbrite_' || ea.event_id || ':' || ea.attendee_id AS event_key,
  'eventbrite'                                           AS source_system,
  ea.event_id || ':' || ea.attendee_id                  AS source_record_id,
  'event_registration'                                   AS event_type,
  ea.first || ' ' || ea.last                            AS booker_name,
  lower(trim(ea.email))                                 AS booker_email_norm,
  ea.created_at                                         AS booked_at,
  e.starts_at                                           AS event_at,
  s.contact_id                                          AS student_id
FROM event_attendees ea
JOIN events e ON e.id = ea.event_id
LEFT JOIN student_dim s ON lower(trim(ea.email)) IN (
    s.preferred_email_norm,
    s.sma_registration_email_norm,
    s.permanent_email_norm,
    s.secondary_email_norm
)
ORDER BY ea.event_id, ea.attendee_id,
  CASE
    WHEN lower(trim(ea.email)) = s.preferred_email_norm        THEN 1
    WHEN lower(trim(ea.email)) = s.sma_registration_email_norm THEN 2
    WHEN lower(trim(ea.email)) = s.permanent_email_norm        THEN 3
    WHEN lower(trim(ea.email)) = s.secondary_email_norm        THEN 4
    ELSE 99
  END;
