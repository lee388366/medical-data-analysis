-- ============================================================
-- 02) Define t0: KDIGO stage 3 anchored (t0 = max(ICU intime, KDIGO3_time - 6h))
-- Output:
--   data_extract_crrt."201_patients_t0_cohort_sepsis"
-- Depends on:
--   data_extract_crrt."101_patients_core_cohort_sepsis"
--   mimiciv_derived.kdigo_stages
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt."201_patients_t0_cohort_sepsis" CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt."201_patients_t0_cohort_sepsis" AS
WITH
core AS (
  SELECT *
  FROM data_extract_crrt."101_patients_core_cohort_sepsis"
),

kdigo3 AS (
  SELECT
    k.stay_id,
    MIN(k.charttime) AS kdigo3_time
  FROM mimiciv_derived.kdigo_stages k
  WHERE
    k.kdigo_stage = 3
    AND k.charttime IS NOT NULL
  GROUP BY k.stay_id
),

t0 AS (
  SELECT
    c.*,
    k.kdigo3_time,
    GREATEST(c.intime, k.kdigo3_time - interval '6 hour') AS t0_time
  FROM core c
  JOIN kdigo3 k
    ON k.stay_id = c.stay_id
)

SELECT *
FROM t0
;

CREATE INDEX IF NOT EXISTS idx_201_t0_stay
  ON data_extract_crrt."201_patients_t0_cohort_sepsis"(stay_id);

CREATE INDEX IF NOT EXISTS idx_201_t0_t0
  ON data_extract_crrt."201_patients_t0_cohort_sepsis"(t0_time);

ANALYZE data_extract_crrt."201_patients_t0_cohort_sepsis";