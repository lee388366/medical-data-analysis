-- ============================================================
-- 09 Subgroup flags (baseline-defined) for effect modification & forest plot
-- Output: data_extract_crrt.subgroup_flags_v1
--
-- Windows / rules:
-- - All subgroup variables defined at baseline: (t0 - 6h, t0]
-- - "last observation" for labs/vitals, and 6h urine rate for oliguria subgroup
-- - NE equiv unit: ug/kg/min (mcg/kg/min)
--
-- Depends on:
-- - data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"
-- - data_extract_crrt.cohort_baseline_v1
-- - mimiciv_derived.urine_output (or adjust if name differs)
-- - mimiciv_derived.kdigo_stages (optional; for AKI pathway)
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt.subgroup_flags_v1 CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt.subgroup_flags_v1 AS
WITH
cohort AS (
  SELECT
    subject_id, hadm_id, stay_id,
    t0_time
  FROM data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"
  WHERE t0_time IS NOT NULL
),

base AS (
  SELECT
    b.*
  FROM data_extract_crrt.cohort_baseline_v1 b
  JOIN cohort c
    ON c.stay_id = b.stay_id
),

-- unified weight (support either weight_kg or weight)
w AS (
  SELECT
    c.stay_id,
    COALESCE(b.weight_kg, b.weight) AS weight_kg
  FROM cohort c
  LEFT JOIN base b
    ON b.stay_id = c.stay_id
),

-- 6h urine output rate in (t0-6h, t0] => ml/kg/h
uo6h AS (
  SELECT
    c.stay_id,
    CASE
      WHEN w.weight_kg IS NULL OR w.weight_kg <= 0 THEN NULL
      ELSE
        (
          SELECT SUM(u.urineoutput)
          FROM mimiciv_derived.urine_output u
          WHERE u.stay_id = c.stay_id
            AND u.charttime >  c.t0_time - interval '6 hour'
            AND u.charttime <= c.t0_time
            AND u.urineoutput IS NOT NULL
        ) / w.weight_kg / 6.0
    END AS uo_mlkgph_t0_last6h
  FROM cohort c
  LEFT JOIN w
    ON w.stay_id = c.stay_id
),

-- AKI pathway at/just before t0:
-- prefer record with charttime <= t0 and closest to t0
kdigo_at_t0 AS (
  SELECT
    c.stay_id,
    (
      SELECT k.aki_stage_uo
      FROM mimiciv_derived.kdigo_stages k
      WHERE k.stay_id = c.stay_id
        AND k.charttime <= c.t0_time
      ORDER BY k.charttime DESC
      LIMIT 1
    ) AS aki_stage_uo_t0,
    (
      SELECT k.aki_stage_creat
      FROM mimiciv_derived.kdigo_stages k
      WHERE k.stay_id = c.stay_id
        AND k.charttime <= c.t0_time
      ORDER BY k.charttime DESC
      LIMIT 1
    ) AS aki_stage_creat_t0
  FROM cohort c
),

-- baseline NE equivalent: accept different possible column names from cohort_baseline_v1
ne_base AS (
  SELECT
    c.stay_id,
    COALESCE(
      b.ne_eq_baseline,          -- version A
      b.norepi_equiv,            -- version B
      b.ne_equiv,                -- version C (fallback)
      NULL
    ) AS ne_ugkgmin
  FROM cohort c
  LEFT JOIN base b
    ON b.stay_id = c.stay_id
),

mv_base AS (
  SELECT
    c.stay_id,
    COALESCE(
      b.mv_baseline,
      b.mv_flag,
      0
    )::int AS mv_flag
  FROM cohort c
  LEFT JOIN base b
    ON b.stay_id = c.stay_id
),

lac_base AS (
  SELECT
    c.stay_id,
    COALESCE(
      b.lactate,
      b.lactate_last6h,
      NULL
    ) AS lactate_mmol
  FROM cohort c
  LEFT JOIN base b
    ON b.stay_id = c.stay_id
),

pf_base AS (
  SELECT
    c.stay_id,
    COALESCE(
      b.pf_ratio,
      b.pfratio,
      b.pf,
      NULL
    ) AS pf_ratio
  FROM cohort c
  LEFT JOIN base b
    ON b.stay_id = c.stay_id
),

final AS (
  SELECT
    c.subject_id, c.hadm_id, c.stay_id,
    c.t0_time,

    uo.uo_mlkgph_t0_last6h,
    ne.ne_ugkgmin,
    mv.mv_flag,
    lac.lactate_mmol,
    pf.pf_ratio,

    k.aki_stage_uo_t0,
    k.aki_stage_creat_t0,

    -- oliguria 3 groups: <0.3 / 0.3-0.5 / >=0.5
    CASE
      WHEN uo.uo_mlkgph_t0_last6h IS NULL THEN 'missing'
      WHEN uo.uo_mlkgph_t0_last6h < 0.3 THEN 'oliguria_<0.3'
      WHEN uo.uo_mlkgph_t0_last6h < 0.5 THEN 'oliguria_0.3-0.5'
      ELSE 'non_oliguric_>=0.5'
    END AS oliguria_3grp,

    -- NE 3 groups (ug/kg/min)
    CASE
      WHEN ne.ne_ugkgmin IS NULL THEN 'missing'
      WHEN ne.ne_ugkgmin < 0.1 THEN 'NE_<0.1'
      WHEN ne.ne_ugkgmin < 0.3 THEN 'NE_0.1-0.3'
      ELSE 'NE_>=0.3'
    END AS ne_3grp,

    CASE
      WHEN mv.mv_flag = 1 THEN 'MV'
      ELSE 'no_MV'
    END AS mv_2grp,

    CASE
      WHEN lac.lactate_mmol IS NULL THEN 'missing'
      WHEN lac.lactate_mmol >= 4 THEN 'lactate_>=4'
      ELSE 'lactate_<4'
    END AS lactate_2grp,

    CASE
      WHEN pf.pf_ratio IS NULL THEN 'missing'
      WHEN pf.pf_ratio < 100 THEN 'PF_<100'
      WHEN pf.pf_ratio < 200 THEN 'PF_100-200'
      ELSE 'PF_>=200'
    END AS pf_3grp,

    -- AKI pathway (based on stage 3 driver around t0, if available)
    CASE
      WHEN k.aki_stage_uo_t0 IS NULL AND k.aki_stage_creat_t0 IS NULL THEN 'unknown'
      WHEN COALESCE(k.aki_stage_uo_t0, 0) = 3 AND COALESCE(k.aki_stage_creat_t0, 0) < 3 THEN 'uo_driven'
      WHEN COALESCE(k.aki_stage_creat_t0, 0) = 3 AND COALESCE(k.aki_stage_uo_t0, 0) < 3 THEN 'scr_driven'
      WHEN COALESCE(k.aki_stage_creat_t0, 0) = 3 AND COALESCE(k.aki_stage_uo_t0, 0) = 3 THEN 'mixed'
      ELSE 'unknown'
    END AS aki_pathway

  FROM cohort c
  LEFT JOIN uo6h uo ON uo.stay_id = c.stay_id
  LEFT JOIN ne_base ne ON ne.stay_id = c.stay_id
  LEFT JOIN mv_base mv ON mv.stay_id = c.stay_id
  LEFT JOIN lac_base lac ON lac.stay_id = c.stay_id
  LEFT JOIN pf_base pf ON pf.stay_id = c.stay_id
  LEFT JOIN kdigo_at_t0 k ON k.stay_id = c.stay_id
)

SELECT * FROM final
;

CREATE UNIQUE INDEX IF NOT EXISTS idx_subgroup_flags_v1_stay
  ON data_extract_crrt.subgroup_flags_v1(stay_id);

CREATE INDEX IF NOT EXISTS idx_subgroup_flags_v1_oliguria
  ON data_extract_crrt.subgroup_flags_v1(oliguria_3grp);

CREATE INDEX IF NOT EXISTS idx_subgroup_flags_v1_ne
  ON data_extract_crrt.subgroup_flags_v1(ne_3grp);

ANALYZE data_extract_crrt.subgroup_flags_v1;