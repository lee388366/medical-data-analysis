-- ============================================================
-- 07) Outcomes: 28-day mortality + renal recovery (Scr<=1.5x baseline @28d)
-- Output:
--   data_extract_crrt.outcomes_28d_renal_v1
--
-- Definitions:
-- - baseline Scr proxy: MIN creatinine in [admittime, t0]
-- - Scr_28d: last creatinine in (t0, t0+28d]
-- - alive_28d: deathtime is NULL or > t0+28d
-- - renal_recovery_28d_scr: alive_28d=1 AND scr_28d <= 1.5*scr_baseline
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt.outcomes_28d_renal_v1 CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt.outcomes_28d_renal_v1 AS
WITH
cohort AS (
  SELECT
    c.subject_id, c.hadm_id, c.stay_id,
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
  JOIN adm a
    ON a.hadm_id=c.hadm_id
  JOIN mimiciv_derived.chemistry ch
    ON ch.hadm_id=c.hadm_id
  WHERE
    ch.charttime >= a.admittime
    AND ch.charttime <= c.t0_time
    AND ch.creatinine IS NOT NULL
  GROUP BY c.stay_id
),

scr_28d AS (
  SELECT
    c.stay_id,
    (SELECT ch.creatinine
     FROM mimiciv_derived.chemistry ch
     WHERE ch.hadm_id=c.hadm_id
       AND ch.charttime > c.t0_time
       AND ch.charttime <= c.t0_time + interval '28 day'
       AND ch.creatinine IS NOT NULL
     ORDER BY ch.charttime DESC
     LIMIT 1) AS scr_28d
  FROM cohort c
),

mort AS (
  SELECT
    c.stay_id,
    a.deathtime,
    CASE
      WHEN a.deathtime IS NOT NULL
       AND a.deathtime > c.t0_time
       AND a.deathtime <= c.t0_time + interval '28 day'
      THEN 1 ELSE 0 END AS death_28d,
    CASE
      WHEN a.deathtime IS NULL OR a.deathtime > c.t0_time + interval '28 day'
      THEN 1 ELSE 0 END AS alive_28d
  FROM cohort c
  JOIN adm a ON a.hadm_id=c.hadm_id
)

SELECT
  c.subject_id, c.hadm_id, c.stay_id,
  c.t0_time,
  m.deathtime,
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
LEFT JOIN mort m ON m.stay_id=c.stay_id
LEFT JOIN scr_baseline b ON b.stay_id=c.stay_id
LEFT JOIN scr_28d s ON s.stay_id=c.stay_id
;

CREATE INDEX IF NOT EXISTS idx_outcome_stay
  ON data_extract_crrt.outcomes_28d_renal_v1(stay_id);

ANALYZE data_extract_crrt.outcomes_28d_renal_v1;