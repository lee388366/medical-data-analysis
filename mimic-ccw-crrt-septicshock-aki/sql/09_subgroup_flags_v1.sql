-- ============================================================
-- 09) Subgroup flags (baseline-defined) for effect modification & forest plot
-- Output: data_extract_crrt.subgroup_flags_v1
--
-- Windows / rules:
--   All subgroup variables at baseline: (t0 - 6h, t0]
--   "Last observation" for labs/vitals; 6h urine rate for oliguria
--   NE equiv unit: µg/kg/min (mcg/kg/min)
--
-- Depends on:
--   data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"
--   data_extract_crrt.cohort_baseline_v1 (05)
--   mimiciv_derived.urine_output, mimiciv_derived.kdigo_stages
--
-- Navicat: run full script to create MV; then run only last SELECT to view table.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

CREATE INDEX IF NOT EXISTS idx_mimic_derived_kdigo_stages_stay_chart
  ON mimiciv_derived.kdigo_stages (stay_id, charttime DESC);

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt.subgroup_flags_v1 CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt.subgroup_flags_v1 AS
WITH
cohort AS (
  SELECT subject_id, hadm_id, stay_id, t0_time
  FROM data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"
  WHERE t0_time IS NOT NULL
),

cohort_base AS (
  SELECT
    c.subject_id,
    c.hadm_id,
    c.stay_id,
    c.t0_time,
    b.weight_kg,
    b.ne_eq_baseline AS ne_ugkgmin,
    COALESCE(b.mv_baseline, 0)::int AS mv_flag,
    b.lactate AS lactate_mmol,
    b.pf_ratio
  FROM cohort c
  LEFT JOIN data_extract_crrt.cohort_baseline_v1 b ON b.stay_id = c.stay_id
),

uo6h AS (
  SELECT
    cb.stay_id,
    CASE
      WHEN cb.weight_kg IS NULL OR cb.weight_kg <= 0 THEN NULL
      ELSE (
        SELECT SUM(u.urineoutput)
        FROM mimiciv_derived.urine_output u
        WHERE u.stay_id = cb.stay_id
          AND u.charttime > cb.t0_time - interval '6 hour'
          AND u.charttime <= cb.t0_time
          AND u.urineoutput IS NOT NULL
      ) / cb.weight_kg / 6.0
    END AS uo_mlkgph_t0_last6h
  FROM cohort_base cb
),

kdigo_at_t0 AS (
  SELECT
    cb.stay_id,
    k.aki_stage AS aki_stage_uo_t0,
    k.aki_stage AS aki_stage_creat_t0
  FROM cohort_base cb
  LEFT JOIN LATERAL (
    SELECT aki_stage
    FROM mimiciv_derived.kdigo_stages k
    WHERE k.stay_id = cb.stay_id AND k.charttime <= cb.t0_time
    ORDER BY k.charttime DESC
    LIMIT 1
  ) k ON true
),

final AS (
  SELECT
    cb.subject_id,
    cb.hadm_id,
    cb.stay_id,
    cb.t0_time,
    uo.uo_mlkgph_t0_last6h,
    cb.ne_ugkgmin,
    cb.mv_flag,
    cb.lactate_mmol,
    cb.pf_ratio,
    k.aki_stage_uo_t0,
    k.aki_stage_creat_t0,

    CASE
      WHEN uo.uo_mlkgph_t0_last6h IS NULL THEN 'missing'
      WHEN uo.uo_mlkgph_t0_last6h < 0.3 THEN 'oliguria_<0.3'
      WHEN uo.uo_mlkgph_t0_last6h < 0.5 THEN 'oliguria_0.3-0.5'
      ELSE 'non_oliguric_>=0.5'
    END AS oliguria_3grp,

    CASE
      WHEN cb.ne_ugkgmin IS NULL THEN 'missing'
      WHEN cb.ne_ugkgmin < 0.1 THEN 'NE_<0.1'
      WHEN cb.ne_ugkgmin < 0.3 THEN 'NE_0.1-0.3'
      ELSE 'NE_>=0.3'
    END AS ne_3grp,

    CASE WHEN cb.mv_flag = 1 THEN 'MV' ELSE 'no_MV' END AS mv_2grp,

    CASE
      WHEN cb.lactate_mmol IS NULL THEN 'missing'
      WHEN cb.lactate_mmol >= 4 THEN 'lactate_>=4'
      ELSE 'lactate_<4'
    END AS lactate_2grp,

    CASE
      WHEN cb.pf_ratio IS NULL THEN 'missing'
      WHEN cb.pf_ratio < 100 THEN 'PF_<100'
      WHEN cb.pf_ratio < 200 THEN 'PF_100-200'
      ELSE 'PF_>=200'
    END AS pf_3grp,

    CASE
      WHEN k.aki_stage_uo_t0 IS NULL AND k.aki_stage_creat_t0 IS NULL THEN 'unknown'
      WHEN COALESCE(k.aki_stage_uo_t0, 0) = 3 AND COALESCE(k.aki_stage_creat_t0, 0) < 3 THEN 'uo_driven'
      WHEN COALESCE(k.aki_stage_creat_t0, 0) = 3 AND COALESCE(k.aki_stage_uo_t0, 0) < 3 THEN 'scr_driven'
      WHEN COALESCE(k.aki_stage_creat_t0, 0) = 3 AND COALESCE(k.aki_stage_uo_t0, 0) = 3 THEN 'mixed'
      ELSE 'unknown'
    END AS aki_pathway
  FROM cohort_base cb
  LEFT JOIN uo6h uo ON uo.stay_id = cb.stay_id
  LEFT JOIN kdigo_at_t0 k ON k.stay_id = cb.stay_id
)
SELECT * FROM final;

CREATE UNIQUE INDEX IF NOT EXISTS idx_subgroup_flags_v1_stay
  ON data_extract_crrt.subgroup_flags_v1 (stay_id);
CREATE INDEX IF NOT EXISTS idx_subgroup_flags_v1_oliguria
  ON data_extract_crrt.subgroup_flags_v1 (oliguria_3grp);
CREATE INDEX IF NOT EXISTS idx_subgroup_flags_v1_ne
  ON data_extract_crrt.subgroup_flags_v1 (ne_3grp);
CREATE INDEX IF NOT EXISTS idx_subgroup_flags_v1_lactate
  ON data_extract_crrt.subgroup_flags_v1 (lactate_2grp);
CREATE INDEX IF NOT EXISTS idx_subgroup_flags_v1_pf
  ON data_extract_crrt.subgroup_flags_v1 (pf_3grp);

ANALYZE data_extract_crrt.subgroup_flags_v1;

-- Navicat: run only the line below to display the table
SELECT * FROM data_extract_crrt.subgroup_flags_v1 ORDER BY stay_id;
