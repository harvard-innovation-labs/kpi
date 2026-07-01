-- ============================================================
-- 01_student_dim.sql
-- Rebuilds student_dim (one row per student) from
-- salesforce_members_raw (one row per student per term).
--
-- Safe to re-run: truncates and rebuilds from scratch each time.
-- Run this AFTER salesforce_members_raw has been refreshed.
-- ============================================================

TRUNCATE student_dim;

INSERT INTO student_dim (
  contact_id, first_name, last_name, full_name, first_team, last_team,
  preferred_email_norm, sma_registration_email_norm, permanent_email_norm, secondary_email_norm,
  gender, race_ethnicity, school_1, school_2,
  first_term, last_term, first_term_venture_stage, last_term_venture_stage, join_date
)
WITH norm AS (
  SELECT
    contact_id,
    NULLIF(first_name, '') AS first_name,
    NULLIF(last_name, '')  AS last_name,
    team,
    lower(trim(NULLIF(preferred_email, '')))        AS preferred_email_norm,
    lower(trim(NULLIF(sma_registration_email, ''))) AS sma_registration_email_norm,
    lower(trim(NULLIF(permanent_email, '')))        AS permanent_email_norm,
    lower(trim(NULLIF(secondary_email, '')))        AS secondary_email_norm,
    NULLIF(gender, '')                              AS gender,
    NULLIF(race_ethnicity, '')                      AS race_ethnicity,
    NULLIF(harvard_school_affiliation_1, '')        AS school_1,
    NULLIF(harvard_school_affiliation_2, '')        AS school_2,
    lab_term,
    team_member_created                             AS join_date,
    NULLIF(term_venture_stage, '')                  AS term_venture_stage,
    CASE
      WHEN lab_term ILIKE '%Spring%' THEN CAST(SPLIT_PART(lab_term, ' ', 1) AS int) * 10 + 1
      WHEN lab_term ILIKE '%Summer%' THEN CAST(SPLIT_PART(lab_term, ' ', 1) AS int) * 10 + 2
      WHEN lab_term ILIKE '%Fall%'   THEN CAST(SPLIT_PART(lab_term, ' ', 1) AS int) * 10 + 3
    END AS term_sort
  FROM salesforce_members_raw
),
first_row AS (
  SELECT DISTINCT ON (contact_id) contact_id,
    lab_term           AS first_term,
    team               AS first_team,
    term_venture_stage AS first_term_venture_stage,
    join_date                                -- earliest term's join date
  FROM norm WHERE term_sort IS NOT NULL
  ORDER BY contact_id, term_sort ASC
),
last_row AS (
  SELECT DISTINCT ON (contact_id) contact_id,
    first_name, last_name,
    lab_term           AS last_term,
    team               AS last_team,
    term_venture_stage AS last_term_venture_stage,
    preferred_email_norm, sma_registration_email_norm,  -- most recent values
    permanent_email_norm, secondary_email_norm,
    gender, race_ethnicity, school_1, school_2
  FROM norm WHERE term_sort IS NOT NULL
  ORDER BY contact_id, term_sort DESC
)
SELECT
  l.contact_id,
  l.first_name, l.last_name,
  TRIM(COALESCE(l.first_name, '') || ' ' || COALESCE(l.last_name, '')) AS full_name,
  f.first_team,
  l.last_team,
  l.preferred_email_norm, l.sma_registration_email_norm,
  l.permanent_email_norm, l.secondary_email_norm,
  l.gender, l.race_ethnicity, l.school_1, l.school_2,
  f.first_term, l.last_term,
  f.first_term_venture_stage, l.last_term_venture_stage,
  f.join_date
FROM last_row l
JOIN first_row f USING (contact_id);
