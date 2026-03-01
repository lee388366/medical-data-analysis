-- ============================================================
-- 03) Final cohort: Septic shock proxy ∩ AKI(KDIGO3 anchored) + exclude pre-t0 RRT
-- Criteria:
--   - sepsis suspected infection time <= t0
--   - vasopressor overlap within (t0-6h, t0]
-- Exclusion:
--   - any RRT/CRRT before t0
-- Output:
--   data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"
-- Depends on:
--   data_extract_crrt."201_patients_t0_cohort_sepsis"
--   mimiciv_derived.sepsis3, vasoactive_agent, rrt, crrt
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort" CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort" AS
WITH
t0 AS (
  SELECT *
  FROM data_extract_crrt."201_patients_t0_cohort_sepsis"
),

sepsis_before_t0 AS (
  SELECT DISTINCT
    t0.stay_id
  FROM t0
  JOIN mimiciv_derived.sepsis3 s
    ON s.stay_id = t0.stay_id
  WHERE
    s.sepsis3 IS TRUE
    AND s.suspected_infection_time IS NOT NULL
    AND s.suspected_infection_time <= t0.t0_time
),

vaso_overlap AS (
  SELECT DISTINCT
    t0.stay_id
  FROM t0
  JOIN mimiciv_derived.vasoactive_agent v
    ON v.stay_id = t0.stay_id
  WHERE
    v.starttime < t0.t0_time
    AND COALESCE(v.endtime, t0.t0_time) > (t0.t0_time - interval '6 hour')
    AND (
      COALESCE(v.norepinephrine,0) > 0
      OR COALESCE(v.epinephrine,0) > 0
      OR COALESCE(v.phenylephrine,0) > 0
      OR COALESCE(v.vasopressin,0) > 0
      OR COALESCE(v.dopamine,0) > 0
    )
),

rrt_before_t0 AS (
  SELECT DISTINCT t0.stay_id
  FROM t0
  JOIN mimiciv_derived.rrt r
    ON r.stay_id = t0.stay_id
  WHERE
    r.charttime < t0.t0_time
    AND (r.dialysis_present = 1 OR r.dialysis_active = 1)
),

crrt_before_t0 AS (
  SELECT DISTINCT t0.stay_id
  FROM t0
  JOIN mimiciv_derived.crrt c
    ON c.stay_id = t0.stay_id
  WHERE
    c.charttime < t0.t0_time
    AND (COALESCE(c.system_active,0) = 1 OR c.crrt_mode IS NOT NULL)
),

any_rrt_before_t0 AS (
  SELECT stay_id FROM rrt_before_t0
  UNION
  SELECT stay_id FROM crrt_before_t0
)

SELECT
  t0.*
FROM t0
JOIN sepsis_before_t0 s
  ON s.stay_id = t0.stay_id
JOIN vaso_overlap v
  ON v.stay_id = t0.stay_id
LEFT JOIN any_rrt_before_t0 x
  ON x.stay_id = t0.stay_id
WHERE x.stay_id IS NULL
;

CREATE INDEX IF NOT EXISTS idx_301_stay
  ON data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"(stay_id);

CREATE INDEX IF NOT EXISTS idx_301_t0
  ON data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"(t0_time);

ANALYZE data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort";