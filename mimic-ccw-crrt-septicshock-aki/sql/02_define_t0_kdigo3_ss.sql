-- ============================================================
-- 02) Define t0: KDIGO stage 3 anchored (t0 = max(ICU intime, KDIGO3_time - 6h))
-- Output:
--   data_extract_crrt."201_patients_t0_cohort_sepsis"
-- Depends on:
--   data_extract_crrt."101_patients_core_cohort_sepsis"
--   mimiciv_derived.kdigo_stages (column: aki_stage, charttime)
--
-- Schema alignment (local MIMIC):
--   kdigo_stages uses aki_stage (0,1,2,3), not kdigo_stage; charttime = stage time.
--
-- Optimizations (postgres-patterns):
--   Explicit core columns; single-pass join + t0 expr; indexes stay_id, t0_time, subject_id.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt."201_patients_t0_cohort_sepsis" CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt."201_patients_t0_cohort_sepsis" AS
WITH
-- Explicit columns from 101 for stable MV definition
core AS (
  SELECT
    stay_id,
    subject_id,
    hadm_id,
    intime,
    outtime,
    age,
    gender,
    race,
    insurance,
    los_icu
  FROM data_extract_crrt."101_patients_core_cohort_sepsis"
),

-- First KDIGO stage 3 time per stay (MIMIC-IV: aki_stage = 3)
kdigo3 AS (
  SELECT
    k.stay_id,
    MIN(k.charttime) AS kdigo3_time
  FROM mimiciv_derived.kdigo_stages k
  WHERE k.aki_stage = 3
    AND k.charttime IS NOT NULL
  GROUP BY k.stay_id
)

SELECT
  c.stay_id,
  c.subject_id,
  c.hadm_id,
  c.intime,
  c.outtime,
  c.age,
  c.gender,
  c.race,
  c.insurance,
  c.los_icu,
  k.kdigo3_time,
  GREATEST(c.intime, k.kdigo3_time - interval '6 hour') AS t0_time
FROM core c
JOIN kdigo3 k ON k.stay_id = c.stay_id;

-- B-tree indexes: equality on stay_id/hadm_id/subject_id, range on t0_time
CREATE INDEX IF NOT EXISTS idx_201_t0_stay
  ON data_extract_crrt."201_patients_t0_cohort_sepsis" (stay_id);

CREATE INDEX IF NOT EXISTS idx_201_t0_hadm
  ON data_extract_crrt."201_patients_t0_cohort_sepsis" (hadm_id);

CREATE INDEX IF NOT EXISTS idx_201_t0_subject
  ON data_extract_crrt."201_patients_t0_cohort_sepsis" (subject_id);

CREATE INDEX IF NOT EXISTS idx_201_t0_t0
  ON data_extract_crrt."201_patients_t0_cohort_sepsis" (t0_time);

ANALYZE data_extract_crrt."201_patients_t0_cohort_sepsis";

-- 在 Navicat 结果窗口显示全部数据（最后一条 SELECT 会出结果）
SELECT * FROM data_extract_crrt."201_patients_t0_cohort_sepsis";
