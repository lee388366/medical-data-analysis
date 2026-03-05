-- ============================================================
-- 06b) CCW long 敏感性：12h / 36h 宽限期（与 606 同结构，仅小时数不同）
-- Output:
--   data_extract_crrt.ccw_long_0_12h_1h_v1  （hour_index 0..11）
--   data_extract_crrt.ccw_long_0_36h_1h_v1  （hour_index 0..35）
-- Input: 301。依赖 606 已建 derived 索引，本脚本不再建。
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt.ccw_long_0_12h_1h_v1 CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt.ccw_long_0_12h_1h_v1 AS
WITH
cohort AS (
  SELECT stay_id, subject_id, hadm_id, t0_time
  FROM data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"
),
weight AS (
  SELECT c.stay_id,
    (SELECT wd.weight FROM mimiciv_derived.weight_durations wd
     WHERE wd.stay_id = c.stay_id AND wd.starttime <= c.t0_time
       AND COALESCE(wd.endtime, c.t0_time) >= c.t0_time AND wd.weight IS NOT NULL
     ORDER BY wd.starttime DESC LIMIT 1) AS weight_kg
  FROM cohort c
),
crrt_start AS (
  SELECT c.stay_id, MIN(x.charttime) AS crrt_start_time
  FROM cohort c
  JOIN mimiciv_derived.crrt x ON x.stay_id = c.stay_id
  WHERE x.charttime >= c.t0_time AND (COALESCE(x.system_active, 0) = 1 OR x.crrt_mode IS NOT NULL)
  GROUP BY c.stay_id
),
hours AS (
  SELECT c.subject_id, c.hadm_id, c.stay_id, c.t0_time,
    gs AS hour_index,
    (c.t0_time + (gs || ' hour')::interval) AS t_start,
    (c.t0_time + ((gs + 1) || ' hour')::interval) AS t_end
  FROM cohort c
  CROSS JOIN generate_series(0, 11) AS gs
)
SELECT h.subject_id, h.hadm_id, h.stay_id, h.t0_time, h.hour_index, h.t_start, h.t_end,
  cs.crrt_start_time, uo.uo_mlkgph_last6h, mp.map_last1h, vs.vaso_flag_last1h, ne.ne_eq_last1h,
  mv.mv_flag_last1h, lb_bg.lactate_last6h, lb_bg.ph_last6h, lb_chem.k_last6h, lb_chem.hco3_last6h, lb_chem.scr_last6h
FROM hours h
LEFT JOIN weight w ON w.stay_id = h.stay_id
LEFT JOIN crrt_start cs ON cs.stay_id = h.stay_id
LEFT JOIN LATERAL (SELECT CASE WHEN w.weight_kg IS NULL OR w.weight_kg <= 0 THEN NULL ELSE (SELECT COALESCE(SUM(u.urineoutput), 0) FROM mimiciv_derived.urine_output u WHERE u.stay_id = h.stay_id AND u.charttime > h.t_end - interval '6 hour' AND u.charttime <= h.t_end AND u.urineoutput IS NOT NULL) / w.weight_kg / 6.0 END AS uo_mlkgph_last6h) uo ON true
LEFT JOIN LATERAL (SELECT v.mbp AS map_last1h FROM mimiciv_derived.vitalsign v WHERE v.stay_id = h.stay_id AND v.charttime > h.t_end - interval '1 hour' AND v.charttime <= h.t_end AND v.mbp IS NOT NULL ORDER BY v.charttime DESC LIMIT 1) mp ON true
LEFT JOIN LATERAL (SELECT CASE WHEN EXISTS (SELECT 1 FROM mimiciv_derived.vasoactive_agent va WHERE va.stay_id = h.stay_id AND va.starttime < h.t_end AND COALESCE(va.endtime, h.t_end) > h.t_end - interval '1 hour' AND (COALESCE(va.norepinephrine,0)>0 OR COALESCE(va.epinephrine,0)>0 OR COALESCE(va.phenylephrine,0)>0 OR COALESCE(va.vasopressin,0)>0 OR COALESCE(va.dopamine,0)>0)) THEN 1 ELSE 0 END AS vaso_flag_last1h FROM (SELECT 1) _) vs ON true
LEFT JOIN LATERAL (SELECT MAX(ne.norepinephrine_equivalent_dose) AS ne_eq_last1h FROM mimiciv_derived.norepinephrine_equivalent_dose ne WHERE ne.stay_id = h.stay_id AND ne.starttime < h.t_end AND COALESCE(ne.endtime, h.t_end) > h.t_end - interval '1 hour' AND ne.norepinephrine_equivalent_dose IS NOT NULL) ne ON true
LEFT JOIN LATERAL (SELECT CASE WHEN EXISTS (SELECT 1 FROM mimiciv_derived.ventilation v WHERE v.stay_id = h.stay_id AND v.starttime < h.t_end AND COALESCE(v.endtime, h.t_end) > h.t_end - interval '1 hour') THEN 1 ELSE 0 END AS mv_flag_last1h FROM (SELECT 1) _) mv ON true
LEFT JOIN LATERAL (SELECT b.lactate AS lactate_last6h, b.ph AS ph_last6h FROM mimiciv_derived.bg b WHERE b.hadm_id = h.hadm_id AND b.charttime > h.t_end - interval '6 hour' AND b.charttime <= h.t_end ORDER BY b.charttime DESC LIMIT 1) lb_bg ON true
LEFT JOIN LATERAL (SELECT ch.potassium AS k_last6h, ch.bicarbonate AS hco3_last6h, ch.creatinine AS scr_last6h FROM mimiciv_derived.chemistry ch WHERE ch.hadm_id = h.hadm_id AND ch.charttime > h.t_end - interval '6 hour' AND ch.charttime <= h.t_end ORDER BY ch.charttime DESC LIMIT 1) lb_chem ON true;

CREATE INDEX IF NOT EXISTS idx_ccw_long_12h_stay_hour ON data_extract_crrt.ccw_long_0_12h_1h_v1 (stay_id, hour_index);
ANALYZE data_extract_crrt.ccw_long_0_12h_1h_v1;

-- ---------- 36h ----------
DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt.ccw_long_0_36h_1h_v1 CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt.ccw_long_0_36h_1h_v1 AS
WITH
cohort AS (
  SELECT stay_id, subject_id, hadm_id, t0_time
  FROM data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"
),
weight AS (
  SELECT c.stay_id,
    (SELECT wd.weight FROM mimiciv_derived.weight_durations wd
     WHERE wd.stay_id = c.stay_id AND wd.starttime <= c.t0_time
       AND COALESCE(wd.endtime, c.t0_time) >= c.t0_time AND wd.weight IS NOT NULL
     ORDER BY wd.starttime DESC LIMIT 1) AS weight_kg
  FROM cohort c
),
crrt_start AS (
  SELECT c.stay_id, MIN(x.charttime) AS crrt_start_time
  FROM cohort c
  JOIN mimiciv_derived.crrt x ON x.stay_id = c.stay_id
  WHERE x.charttime >= c.t0_time AND (COALESCE(x.system_active, 0) = 1 OR x.crrt_mode IS NOT NULL)
  GROUP BY c.stay_id
),
hours AS (
  SELECT c.subject_id, c.hadm_id, c.stay_id, c.t0_time,
    gs AS hour_index,
    (c.t0_time + (gs || ' hour')::interval) AS t_start,
    (c.t0_time + ((gs + 1) || ' hour')::interval) AS t_end
  FROM cohort c
  CROSS JOIN generate_series(0, 35) AS gs
)
SELECT h.subject_id, h.hadm_id, h.stay_id, h.t0_time, h.hour_index, h.t_start, h.t_end,
  cs.crrt_start_time, uo.uo_mlkgph_last6h, mp.map_last1h, vs.vaso_flag_last1h, ne.ne_eq_last1h,
  mv.mv_flag_last1h, lb_bg.lactate_last6h, lb_bg.ph_last6h, lb_chem.k_last6h, lb_chem.hco3_last6h, lb_chem.scr_last6h
FROM hours h
LEFT JOIN weight w ON w.stay_id = h.stay_id
LEFT JOIN crrt_start cs ON cs.stay_id = h.stay_id
LEFT JOIN LATERAL (SELECT CASE WHEN w.weight_kg IS NULL OR w.weight_kg <= 0 THEN NULL ELSE (SELECT COALESCE(SUM(u.urineoutput), 0) FROM mimiciv_derived.urine_output u WHERE u.stay_id = h.stay_id AND u.charttime > h.t_end - interval '6 hour' AND u.charttime <= h.t_end AND u.urineoutput IS NOT NULL) / w.weight_kg / 6.0 END AS uo_mlkgph_last6h) uo ON true
LEFT JOIN LATERAL (SELECT v.mbp AS map_last1h FROM mimiciv_derived.vitalsign v WHERE v.stay_id = h.stay_id AND v.charttime > h.t_end - interval '1 hour' AND v.charttime <= h.t_end AND v.mbp IS NOT NULL ORDER BY v.charttime DESC LIMIT 1) mp ON true
LEFT JOIN LATERAL (SELECT CASE WHEN EXISTS (SELECT 1 FROM mimiciv_derived.vasoactive_agent va WHERE va.stay_id = h.stay_id AND va.starttime < h.t_end AND COALESCE(va.endtime, h.t_end) > h.t_end - interval '1 hour' AND (COALESCE(va.norepinephrine,0)>0 OR COALESCE(va.epinephrine,0)>0 OR COALESCE(va.phenylephrine,0)>0 OR COALESCE(va.vasopressin,0)>0 OR COALESCE(va.dopamine,0)>0)) THEN 1 ELSE 0 END AS vaso_flag_last1h FROM (SELECT 1) _) vs ON true
LEFT JOIN LATERAL (SELECT MAX(ne.norepinephrine_equivalent_dose) AS ne_eq_last1h FROM mimiciv_derived.norepinephrine_equivalent_dose ne WHERE ne.stay_id = h.stay_id AND ne.starttime < h.t_end AND COALESCE(ne.endtime, h.t_end) > h.t_end - interval '1 hour' AND ne.norepinephrine_equivalent_dose IS NOT NULL) ne ON true
LEFT JOIN LATERAL (SELECT CASE WHEN EXISTS (SELECT 1 FROM mimiciv_derived.ventilation v WHERE v.stay_id = h.stay_id AND v.starttime < h.t_end AND COALESCE(v.endtime, h.t_end) > h.t_end - interval '1 hour') THEN 1 ELSE 0 END AS mv_flag_last1h FROM (SELECT 1) _) mv ON true
LEFT JOIN LATERAL (SELECT b.lactate AS lactate_last6h, b.ph AS ph_last6h FROM mimiciv_derived.bg b WHERE b.hadm_id = h.hadm_id AND b.charttime > h.t_end - interval '6 hour' AND b.charttime <= h.t_end ORDER BY b.charttime DESC LIMIT 1) lb_bg ON true
LEFT JOIN LATERAL (SELECT ch.potassium AS k_last6h, ch.bicarbonate AS hco3_last6h, ch.creatinine AS scr_last6h FROM mimiciv_derived.chemistry ch WHERE ch.hadm_id = h.hadm_id AND ch.charttime > h.t_end - interval '6 hour' AND ch.charttime <= h.t_end ORDER BY ch.charttime DESC LIMIT 1) lb_chem ON true;

CREATE INDEX IF NOT EXISTS idx_ccw_long_36h_stay_hour ON data_extract_crrt.ccw_long_0_36h_1h_v1 (stay_id, hour_index);
ANALYZE data_extract_crrt.ccw_long_0_36h_1h_v1;

-- 在 Navicat 显示（先跑 606 建索引，再跑本脚本）
SELECT * FROM data_extract_crrt.ccw_long_0_12h_1h_v1 ORDER BY stay_id, hour_index LIMIT 300;
-- SELECT * FROM data_extract_crrt.ccw_long_0_36h_1h_v1 ORDER BY stay_id, hour_index LIMIT 500;
