-- ============================================================
-- 03_kpis.sql
-- Dashboard KPI queries. Read-only -- run AFTER student_dim
-- and student_events have been rebuilt.
--
-- AY runs Sep -> following Aug.
-- e.g. today = 2026-06-30 -> AY year = 2025 -> terms: '2025 Fall', '2026 Spring', '2026 Summer'
--      today = 2026-09-15 -> AY year = 2026 -> terms: '2026 Fall', '2027 Spring', '2027 Summer'
-- ============================================================

-- KPI 1: Total Harvard members for the current AY
-- "Member this AY" = their LAST (most recent) term is in the current AY.
-- Includes both new joiners and returning students who are still active this AY.
WITH ay AS (
  SELECT CASE WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= 9
              THEN EXTRACT(YEAR FROM CURRENT_DATE)::int
              ELSE EXTRACT(YEAR FROM CURRENT_DATE)::int - 1
         END AS ay_year
),
ay_terms AS (
  SELECT unnest(ARRAY[
           ay_year || ' Fall',
           (ay_year + 1) || ' Spring',
           (ay_year + 1) || ' Summer'
         ]) AS term
  FROM ay
)
SELECT
    COUNT(DISTINCT contact_id) AS total_ay_members
FROM student_dim
WHERE school_1 ILIKE 'Harvard %'
  AND last_term IN (SELECT term FROM ay_terms);

-- KPI 1b: Same, broken out by last_term (sanity check / composition view)
WITH ay AS (
  SELECT CASE WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= 9
              THEN EXTRACT(YEAR FROM CURRENT_DATE)::int
              ELSE EXTRACT(YEAR FROM CURRENT_DATE)::int - 1
         END AS ay_year
),
ay_terms AS (
  SELECT unnest(ARRAY[
           ay_year || ' Fall',
           (ay_year + 1) || ' Spring',
           (ay_year + 1) || ' Summer'
         ]) AS term
  FROM ay
)
SELECT
    last_term,
    COUNT(DISTINCT contact_id) AS members
FROM student_dim
WHERE school_1 ILIKE 'Harvard %'
  AND last_term IN (SELECT term FROM ay_terms)
GROUP BY 1
ORDER BY last_term;

-- KPI 1c: NEW members this AY (first_term AND last_term both in this AY,
-- i.e. joined fresh this year, not returning from a prior AY)
WITH ay AS (
  SELECT CASE WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= 9
              THEN EXTRACT(YEAR FROM CURRENT_DATE)::int
              ELSE EXTRACT(YEAR FROM CURRENT_DATE)::int - 1
         END AS ay_year
),
ay_terms AS (
  SELECT unnest(ARRAY[
           ay_year || ' Fall',
           (ay_year + 1) || ' Spring',
           (ay_year + 1) || ' Summer'
         ]) AS term
  FROM ay
)
SELECT
    COUNT(DISTINCT contact_id) AS new_members_this_ay
FROM student_dim
WHERE school_1 ILIKE 'Harvard %'
  AND last_term IN (SELECT term FROM ay_terms)
  AND first_term IN (SELECT term FROM ay_terms);

-- KPI 1d: Members by last_term, with running cumulative total.
-- Grouped by last_term (the term they're currently enrolled in),
-- so cumulative shows total distinct members as each term adds its cohort.
WITH ay AS (
  SELECT CASE WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= 9
              THEN EXTRACT(YEAR FROM CURRENT_DATE)::int
              ELSE EXTRACT(YEAR FROM CURRENT_DATE)::int - 1
         END AS ay_year
),
ay_terms AS (
  SELECT unnest(ARRAY[
           ay_year || ' Fall',
           (ay_year + 1) || ' Spring',
           (ay_year + 1) || ' Summer'
         ]) AS term
  FROM ay
),
by_term AS (
  SELECT
      last_term,
      COUNT(DISTINCT contact_id) AS members
  FROM student_dim
  WHERE school_1 ILIKE 'Harvard %'
    AND last_term IN (SELECT term FROM ay_terms)
  GROUP BY 1
)
SELECT
    last_term,
    members,
    SUM(members) OVER (ORDER BY last_term) AS cumulative_members
FROM by_term
ORDER BY last_term;

-- KPI 2: Monthly Active Members (MAU) -- distinct Harvard students w/ any event that month
SELECT
    DATE_TRUNC('month', se.event_at) AS month,
    COUNT(DISTINCT se.student_id) AS active_members
FROM student_events se
JOIN student_dim s ON se.student_id = s.contact_id
WHERE s.school_1 ILIKE 'Harvard %'
  AND se.event_at >= '2025-09-01'
  AND se.event_at <= now()
GROUP BY 1
ORDER BY 1;

-- KPI 2b: All Harvard members active in the trailing 30 days (point-in-time snapshot)
SELECT
    COUNT(DISTINCT se.student_id) AS active_30d_harvard
FROM student_events se
JOIN student_dim s ON se.student_id = s.contact_id
WHERE se.event_at BETWEEN now() - INTERVAL '30 days' AND now()
  AND s.school_1 ILIKE 'Harvard %';

-- KPI 3: New member activation rate -- had an event within 30 days of join_date
-- Only includes cohorts where 30-day window has fully elapsed (join_date <= now - 30 days)
WITH ay AS (
  SELECT CASE WHEN EXTRACT(MONTH FROM CURRENT_DATE) >= 9
              THEN EXTRACT(YEAR FROM CURRENT_DATE)::int
              ELSE EXTRACT(YEAR FROM CURRENT_DATE)::int - 1
         END AS ay_year
),
ay_terms AS (
  SELECT unnest(ARRAY[
           ay_year || ' Fall',
           (ay_year + 1) || ' Spring',
           (ay_year + 1) || ' Summer'
         ]) AS term
  FROM ay
)
SELECT
    DATE_TRUNC('month', s.join_date) AS cohort_month,
    COUNT(DISTINCT s.contact_id) AS new_members,
    COUNT(DISTINCT se.student_id) AS activated,
    min(se.event_at) as min_event_at,
    max(se.event_at) as max_event_at,
    ROUND(COUNT(DISTINCT se.student_id)::numeric / COUNT(DISTINCT s.contact_id), 3) AS activation_rate
FROM student_dim s
LEFT JOIN student_events se
    ON se.student_id = s.contact_id
   AND se.event_at BETWEEN s.join_date AND s.join_date + INTERVAL '30 days'
WHERE s.school_1 ILIKE 'Harvard %'
  AND last_term IN (SELECT term FROM ay_terms)
  AND s.join_date <= CURRENT_DATE - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1;
