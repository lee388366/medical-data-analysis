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
--   data_extract_crrt."201_patients_t0_cohort_sepsis"  ← 必须先执行 201 脚本，否则本脚本会报错
--   mimiciv_derived.sepsis3, vasoactive_agent, rrt, crrt
--
-- 执行顺序：101 → 201 → 本脚本(301)。若报 relation "301_ss_aki3_t0_no_rrt_cohort" does not exist，
-- 多为 201 未创建：请先完整执行 201_patients_t0_cohort_sepsis.sql。
--
-- 本地 MIMIC 表/列已核对：sepsis3(sepsis3,suspected_infection_time), vasoactive_agent(starttime,endtime,norepinephrine,...),
--   rrt(charttime,dialysis_present,dialysis_active), crrt(charttime,system_active,crrt_mode).
--
-- Optimizations (postgres-patterns): Explicit t0 columns; EXISTS/NOT EXISTS semijoins; B-tree indexes.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort" CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort" AS
WITH
t0 AS (
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
    los_icu,
    kdigo3_time,
    t0_time
  FROM data_extract_crrt."201_patients_t0_cohort_sepsis"
)
SELECT
  t0.stay_id,
  t0.subject_id,
  t0.hadm_id,
  t0.intime,
  t0.outtime,
  t0.age,
  t0.gender,
  t0.race,
  t0.insurance,
  t0.los_icu,
  t0.kdigo3_time,
  t0.t0_time
FROM t0
WHERE
  EXISTS (
    SELECT 1
    FROM mimiciv_derived.sepsis3 s
    WHERE s.stay_id = t0.stay_id
      AND s.sepsis3 IS TRUE
      AND s.suspected_infection_time IS NOT NULL
      AND s.suspected_infection_time <= t0.t0_time
  )
  AND EXISTS (
    SELECT 1
    FROM mimiciv_derived.vasoactive_agent v
    WHERE v.stay_id = t0.stay_id
      AND v.starttime < t0.t0_time
      AND COALESCE(v.endtime, t0.t0_time) > (t0.t0_time - interval '6 hour')
      AND (
        COALESCE(v.norepinephrine, 0) > 0
        OR COALESCE(v.epinephrine, 0) > 0
        OR COALESCE(v.phenylephrine, 0) > 0
        OR COALESCE(v.vasopressin, 0) > 0
        OR COALESCE(v.dopamine, 0) > 0
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM mimiciv_derived.rrt r
    WHERE r.stay_id = t0.stay_id
      AND r.charttime < t0.t0_time
      AND (r.dialysis_present = 1 OR r.dialysis_active = 1)
  )
  AND NOT EXISTS (
    SELECT 1
    FROM mimiciv_derived.crrt c
    WHERE c.stay_id = t0.stay_id
      AND c.charttime < t0.t0_time
      AND (COALESCE(c.system_active, 0) = 1 OR c.crrt_mode IS NOT NULL)
  );

-- B-tree indexes: equality on stay_id/hadm_id/subject_id, range on t0_time
CREATE INDEX IF NOT EXISTS idx_301_stay
  ON data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort" (stay_id);

CREATE INDEX IF NOT EXISTS idx_301_hadm
  ON data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort" (hadm_id);

CREATE INDEX IF NOT EXISTS idx_301_subject
  ON data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort" (subject_id);

CREATE INDEX IF NOT EXISTS idx_301_t0
  ON data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort" (t0_time);

ANALYZE data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort";

-- 在 Navicat 显示表格（必须先完整执行本脚本上文，使物化视图创建成功后再执行本句）
-- 若报错 relation "301_ss_aki3_t0_no_rrt_cohort" does not exist：说明上面的 CREATE MATERIALIZED VIEW 未成功，请从脚本第一行起整段执行，并查看是否有依赖/列名报错
SELECT * FROM data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort";
