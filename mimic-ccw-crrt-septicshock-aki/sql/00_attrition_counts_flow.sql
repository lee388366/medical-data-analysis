-- ============================================================
-- 00 Attrition / Flow counts for inclusion-exclusion diagram
-- Output: data_extract_crrt.attrition_counts_v1
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt.attrition_counts_v1 CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt.attrition_counts_v1 AS
WITH
n101 AS (
  SELECT COUNT(*)::int AS n
  FROM data_extract_crrt."101_patients_core_cohort_sepsis"
),

n201 AS (
  SELECT COUNT(*)::int AS n
  FROM data_extract_crrt."201_patients_t0_cohort_sepsis"
),

drop_101_to_201 AS (
  SELECT
    (SELECT n FROM n101) AS n_prev,
    (SELECT n FROM n201) AS n_next,
    ((SELECT n FROM n101) - (SELECT n FROM n201))::int AS n_dropped
),

n301 AS (
  SELECT COUNT(*)::int AS n
  FROM data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"
),

drop_201_to_301 AS (
  SELECT
    (SELECT n FROM n201) AS n_prev,
    (SELECT n FROM n301) AS n_next,
    ((SELECT n FROM n201) - (SELECT n FROM n301))::int AS n_dropped
),

t0 AS (
  SELECT *
  FROM data_extract_crrt."201_patients_t0_cohort_sepsis"
  WHERE t0_time IS NOT NULL
),

sepsis_before_t0 AS (
  SELECT DISTINCT t0.stay_id
  FROM t0
  WHERE t0.sepsis_time IS NOT NULL
    AND t0.sepsis_time <= t0.t0_time
),

vaso_t0 AS (
  SELECT DISTINCT t0.stay_id
  FROM t0
  JOIN mimiciv_derived.vasoactive_agent v
    ON v.stay_id = t0.stay_id
  WHERE v.starttime < t0.t0_time
    AND COALESCE(v.endtime, t0.t0_time) > t0.t0_time - interval '6 hour'
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
  WHERE r.charttime < t0.t0_time
    AND (COALESCE(r.dialysis_present,0)=1 OR COALESCE(r.dialysis_active,0)=1)
),

crrt_before_t0 AS (
  SELECT DISTINCT t0.stay_id
  FROM t0
  JOIN mimiciv_derived.crrt c
    ON c.stay_id = t0.stay_id
  WHERE c.charttime < t0.t0_time
    AND (COALESCE(c.system_active,0)=1 OR c.crrt_mode IS NOT NULL)
),

any_rrt_before_t0 AS (
  SELECT stay_id FROM rrt_before_t0
  UNION
  SELECT stay_id FROM crrt_before_t0
),

fail_sepsis_before_t0 AS (
  SELECT COUNT(*)::int AS n
  FROM t0
  LEFT JOIN sepsis_before_t0 s
    ON s.stay_id = t0.stay_id
  WHERE s.stay_id IS NULL
),

fail_vaso_t0 AS (
  SELECT COUNT(*)::int AS n
  FROM t0
  LEFT JOIN vaso_t0 v
    ON v.stay_id = t0.stay_id
  WHERE v.stay_id IS NULL
),

fail_pre_t0_rrt AS (
  SELECT COUNT(*)::int AS n
  FROM t0
  INNER JOIN any_rrt_before_t0 x
    ON x.stay_id = t0.stay_id
),

flow AS (
  SELECT 1 AS step_order,
         '101 Core cohort (adult, first ICU, LOS>=24h, sepsis3-in-ICU, weight)' AS step_label,
         (SELECT n FROM n101) AS n_value
  UNION ALL
  SELECT 2, '201 Defined t0: KDIGO stage 3 anchored (t0=KDIGO3-6h, cap at ICU intime)', (SELECT n FROM n201)
  UNION ALL
  SELECT 3, 'Dropped 101->201 (no KDIGO3 eligible for t0)', (SELECT n_dropped FROM drop_101_to_201)
  UNION ALL
  SELECT 4, '301 Final cohort: sepsis<=t0 + vaso overlap (t0-6h,t0] + exclude pre-t0 RRT/CRRT', (SELECT n FROM n301)
  UNION ALL
  SELECT 5, 'Dropped 201->301 (total)', (SELECT n_dropped FROM drop_201_to_301)
  UNION ALL
  SELECT 6, 'Reason (201->301): Sepsis not on/before t0', (SELECT n FROM fail_sepsis_before_t0)
  UNION