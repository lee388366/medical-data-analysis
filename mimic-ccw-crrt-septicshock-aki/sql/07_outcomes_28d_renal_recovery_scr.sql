-- ============================================================
-- 07) Outcomes: 28-day mortality + renal recovery (Scr<=1.5x baseline @28d)
-- Output:
--   data_extract_crrt.outcomes_28d_renal_v1
--
-- Definitions:
--   scr_baseline: MIN creatinine in [admittime, t0]
--   scr_28d: last creatinine in (t0, t0+28d]
--   death_7d / alive_7d: deathtime in (t0, t0+7d] or NULL/>t0+7d（次要结局用）
--   death_28d / alive_28d: deathtime in (t0, t0+28d] or NULL/>t0+28d
--   renal_recovery_28d_scr: alive_28d=1 AND scr_28d <= 1.5*scr_baseline
--
-- Optimizations (postgres-patterns): Explicit cohort; scr_28d as LATERAL; B-tree indexes; Navicat.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

-- 若 505/606 已建 chemistry 索引可跳过
CREATE INDEX IF NOT EXISTS idx_mimic_derived_chemistry_hadm_chart
  ON mimiciv_derived.chemistry (hadm_id, charttime DESC);

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt.outcomes_28d_renal_v1 CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt.outcomes_28d_renal_v1 AS
WITH
cohort AS (
  SELECT
    c.subject_id,
    c.hadm_id,
    c.stay_id,
    c.t0_time
  FROM data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort" c
),

adm AS (
  SELECT
    a.hadm_id,
    a.admittime,
    a.deathtime
  FROM mimiciv_hosp.admissions a
),

scr_baseline AS (
  SELECT
    c.stay_id,
    MIN(ch.creatinine) AS scr_baseline
  FROM cohort c
  JOIN adm a ON a.hadm_id = c.hadm_id
  JOIN mimiciv_derived.chemistry ch
    ON ch.hadm_id = c.hadm_id
  WHERE ch.charttime >= a.admittime
    AND ch.charttime <= c.t0_time
    AND ch.creatinine IS NOT NULL
  GROUP BY c.stay_id
),

mort AS (
  SELECT
    c.stay_id,
    a.deathtime,
    CASE
      WHEN a.deathtime IS NOT NULL
       AND a.deathtime > c.t0_time
       AND a.deathtime <= c.t0_time + interval '7 day'
      THEN 1 ELSE 0 END AS death_7d,
    CASE
      WHEN a.deathtime IS NULL OR a.deathtime > c.t0_time + interval '7 day'
      THEN 1 ELSE 0 END AS alive_7d,
    CASE
      WHEN a.deathtime IS NOT NULL
       AND a.deathtime > c.t0_time
       AND a.deathtime <= c.t0_time + interval '28 day'
      THEN 1 ELSE 0 END AS death_28d,
    CASE
      WHEN a.deathtime IS NULL OR a.deathtime > c.t0_time + interval '28 day'
      THEN 1 ELSE 0 END AS alive_28d
  FROM cohort c
  JOIN adm a ON a.hadm_id = c.hadm_id
)
SELECT
  c.subject_id,
  c.hadm_id,
  c.stay_id,
  c.t0_time,
  m.deathtime,
  m.death_7d,
  m.alive_7d,
  m.death_28d,
  m.alive_28d,
  b.scr_baseline,
  s.scr_28d,
  CASE
    WHEN m.alive_28d = 1
     AND b.scr_baseline IS NOT NULL
     AND s.scr_28d IS NOT NULL
     AND s.scr_28d <= 1.5 * b.scr_baseline
    THEN 1 ELSE 0 END AS renal_recovery_28d_scr
FROM cohort c
LEFT JOIN mort m ON m.stay_id = c.stay_id
LEFT JOIN scr_baseline b ON b.stay_id = c.stay_id
LEFT JOIN LATERAL (
  SELECT ch.creatinine AS scr_28d
  FROM mimiciv_derived.chemistry ch
  WHERE ch.hadm_id = c.hadm_id
    AND ch.charttime > c.t0_time
    AND ch.charttime <= c.t0_time + interval '28 day'
    AND ch.creatinine IS NOT NULL
  ORDER BY ch.charttime DESC
  LIMIT 1
) s ON true;

CREATE INDEX IF NOT EXISTS idx_outcome_stay
  ON data_extract_crrt.outcomes_28d_renal_v1 (stay_id);

CREATE INDEX IF NOT EXISTS idx_outcome_hadm
  ON data_extract_crrt.outcomes_28d_renal_v1 (hadm_id);

CREATE INDEX IF NOT EXISTS idx_outcome_subject
  ON data_extract_crrt.outcomes_28d_renal_v1 (subject_id);

ANALYZE data_extract_crrt.outcomes_28d_renal_v1;

-- 在 Navicat 显示（需先有 301）
SELECT * FROM data_extract_crrt.outcomes_28d_renal_v1;
