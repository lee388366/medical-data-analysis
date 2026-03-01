-- ============================================================
-- 06) CCW long dataset: 1-hour slices over [t0, t0+24h)
-- Output:
--   data_extract_crrt.ccw_long_0_24h_1h_v1
--
-- Contents:
--   - hour_index 0..23
--   - t_start, t_end
--   - crrt_start_time (first CRRT >= t0)
--   - time-varying covariates at each slice end:
--       uo_mlkgph_last6h, map_last1h, vaso_flag_last1h, ne_eq_last1h,
--       mv_flag_last1h, lactate_last6h, ph_last6h, k_last6h, hco3_last6h, scr_last6h
--
-- Notes:
-- - Urine table name varies. Here assumes mimiciv_derived.urine_output(stay_id, charttime, urineoutput)
-- - NE equivalent table varies. Here assumes mimiciv_derived.norepinephrine_equivalent_dose(stay_id, charttime, norepinephrine_equivalent_dose)
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt.ccw_long_0_24h_1h_v1 CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt.ccw_long_0_24h_1h_v1 AS
WITH
cohort AS (
  SELECT *
  FROM data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"
),

weight AS (
  SELECT
    c.stay_id,
    (SELECT wd.weight
     FROM mimiciv_derived.weight_durations wd
     WHERE wd.stay_id = c.stay_id
       AND wd.starttime <= c.t0_time
       AND COALESCE(wd.endtime, c.t0_time) >= c.t0_time
       AND wd.weight IS NOT NULL
     ORDER BY wd.starttime DESC
     LIMIT 1) AS weight_kg
  FROM cohort c
),

crrt_start AS (
  SELECT
    c.stay_id,
    MIN(x.charttime) AS crrt_start_time
  FROM cohort c
  JOIN mimiciv_derived.crrt x
    ON x.stay_id = c.stay_id
  WHERE
    x.charttime >= c.t0_time
    AND (COALESCE(x.system_active,0) = 1 OR x.crrt_mode IS NOT NULL)
  GROUP BY c.stay_id
),

hours AS (
  SELECT
    c.subject_id, c.hadm_id, c.stay_id,
    c.t0_time,
    gs AS hour_index,
    (c.t0_time + (gs || ' hour')::interval) AS t_start,
    (c.t0_time + ((gs+1) || ' hour')::interval) AS t_end
  FROM cohort c
  CROSS JOIN generate_series(0, 23) gs
),

uo AS (
  SELECT
    h.stay_id, h.hour_index,
    CASE
      WHEN w.weight_kg IS NULL OR w.weight_kg <= 0 THEN NULL
      ELSE
        (
          SELECT SUM(u.urineoutput)
          FROM mimiciv_derived.urine_output u
          WHERE u.stay_id = h.stay_id
            AND u.charttime >  h.t_end - interval '6 hour'
            AND u.charttime <= h.t_end
            AND u.urineoutput IS NOT NULL
        ) / w.weight_kg / 6.0
    END AS uo_mlkgph_last6h
  FROM hours h
  LEFT JOIN weight w ON w.stay_id=h.stay_id
),

map1h AS (
  SELECT
    h.stay_id, h.hour_index,
    (SELECT v.mbp
     FROM mimiciv_derived.vitalsign v
     WHERE v.stay_id=h.stay_id
       AND v.charttime>h.t_end-interval '1 hour'
       AND v.charttime<=h.t_end
       AND v.mbp IS NOT NULL
     ORDER BY v.charttime DESC
     LIMIT 1) AS map_last1h
  FROM hours h
),

vaso1h AS (
  SELECT
    h.stay_id, h.hour_index,
    CASE WHEN EXISTS (
      SELECT 1 FROM mimiciv_derived.vasoactive_agent va
      WHERE va.stay_id=h.stay_id
        AND va.starttime < h.t_end
        AND COALESCE(va.endtime, h.t_end) > h.t_end - interval '1 hour'
        AND (
          COALESCE(va.norepinephrine,0) > 0
          OR COALESCE(va.epinephrine,0) > 0
          OR COALESCE(va.phenylephrine,0) > 0
          OR COALESCE(va.vasopressin,0) > 0
          OR COALESCE(va.dopamine,0) > 0
        )
    ) THEN 1 ELSE 0 END AS vaso_flag_last1h
  FROM hours h
),

ne1h AS (
  SELECT
    h.stay_id, h.hour_index,
    (SELECT MAX(ne.norepinephrine_equivalent_dose)
     FROM mimiciv_derived.norepinephrine_equivalent_dose ne
     WHERE ne.stay_id=h.stay_id
       AND ne.charttime>h.t_end-interval '1 hour'
       AND ne.charttime<=h.t_end
       AND ne.norepinephrine_equivalent_dose IS NOT NULL
    ) AS ne_eq_last1h
  FROM hours h
),

mv1h AS (
  SELECT
    h.stay_id, h.hour_index,
    CASE WHEN EXISTS (
      SELECT 1 FROM mimiciv_derived.ventilation v
      WHERE v.stay_id=h.stay_id
        AND v.starttime < h.t_end
        AND COALESCE(v.endtime, h.t_end) > h.t_end - interval '1 hour'
    ) THEN 1 ELSE 0 END AS mv_flag_last1h
  FROM hours h
),

lab6h AS (
  SELECT
    h.stay_id, h.hour_index,

    (SELECT b.lactate FROM mimiciv_derived.bg b
     WHERE b.hadm_id=h.hadm_id
       AND b.charttime>h.t_end-interval '6 hour'
       AND b.charttime<=h.t_end
       AND b.lactate IS NOT NULL
     ORDER BY b.charttime DESC LIMIT 1) AS lactate_last6h,

    (SELECT b.ph FROM mimiciv_derived.bg b
     WHERE b.hadm_id=h.hadm_id
       AND b.charttime>h.t_end-interval '6 hour'
       AND b.charttime<=h.t_end
       AND b.ph IS NOT NULL
     ORDER BY b.charttime DESC LIMIT 1) AS ph_last6h,

    (SELECT ch.potassium FROM mimiciv_derived.chemistry ch
     WHERE ch.hadm_id=h.hadm_id
       AND ch.charttime>h.t_end-interval '6 hour'
       AND ch.charttime<=h.t_end
       AND ch.potassium IS NOT NULL
     ORDER BY ch.charttime DESC LIMIT 1) AS k_last6h,

    (SELECT ch.bicarbonate FROM mimiciv_derived.chemistry ch
     WHERE ch.hadm_id=h.hadm_id
       AND ch.charttime>h.t_end-interval '6 hour'
       AND ch.charttime<=h.t_end
       AND ch.bicarbonate IS NOT NULL
     ORDER BY ch.charttime DESC LIMIT 1) AS hco3_last6h,

    (SELECT ch.creatinine FROM mimiciv_derived.chemistry ch
     WHERE ch.hadm_id=h.hadm_id
       AND ch.charttime>h.t_end-interval '6 hour'
       AND ch.charttime<=h.t_end
       AND ch.creatinine IS NOT NULL
     ORDER BY ch.charttime DESC LIMIT 1) AS scr_last6h

  FROM hours h
)

SELECT
  h.subject_id, h.hadm_id, h.stay_id,
  h.t0_time,
  h.hour_index,
  h.t_start,
  h.t_end,
  cs.crrt_start_time,

  uo.uo_mlkgph_last6h,
  mp.map_last1h,
  vs.vaso_flag_last1h,
  ne.ne_eq_last1h,
  mv.mv_flag_last1h,

  lb.lactate_last6h,
  lb.ph_last6h,
  lb.k_last6h,
  lb.hco3_last6h,
  lb.scr_last6h

FROM hours h
LEFT JOIN crrt_start cs ON cs.stay_id=h.stay_id
LEFT JOIN uo   ON uo.stay_id=h.stay_id AND uo.hour_index=h.hour_index
LEFT JOIN map1h mp ON mp.stay_id=h.stay_id AND mp.hour_index=h.hour_index
LEFT JOIN vaso1h vs ON vs.stay_id=h.stay_id AND vs.hour_index=h.hour_index
LEFT JOIN ne1h ne   ON ne.stay_id=h.stay_id AND ne.hour_index=h.hour_index
LEFT JOIN mv1h mv   ON mv.stay_id=h.stay_id AND mv.hour_index=h.hour_index
LEFT JOIN lab6h lb  ON lb.stay_id=h.stay_id AND lb.hour_index=h.hour_index
;

CREATE INDEX IF NOT EXISTS idx_ccw_long_stay_hour
  ON data_extract_crrt.ccw_long_0_24h_1h_v1(stay_id, hour_index);

ANALYZE data_extract_crrt.ccw_long_0_24h_1h_v1;