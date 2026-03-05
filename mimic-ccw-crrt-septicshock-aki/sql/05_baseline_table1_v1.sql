-- ============================================================
-- 05) Baseline Table 1 dataset (t0-6h, t0]
-- Output: data_extract_crrt.cohort_baseline_v1
--
-- Notes:
--   Uses "last observation" (single latest charttime/endtime per table) in baseline window.
--   Performance: one LATERAL per table (one scan per cohort row) instead of many scalar subqueries.
--
-- 本地 MIMIC 表/列：
--   weight_durations; charlson; vitalsign; chemistry(bun，无 urea_nitrogen);
--   enzyme(ast,alt); bg(po2,fio2); coagulation; complete_blood_count;
--   ventilation; vasoactive_agent; norepinephrine_equivalent_dose(starttime,endtime，无 charttime);
--   sofa(sofa_24hours,endtime).
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

-- 索引：无索引时 LATERAL 会极慢；已建过可跳过
CREATE INDEX IF NOT EXISTS idx_mimic_derived_vitalsign_stay_chart
  ON mimiciv_derived.vitalsign (stay_id, charttime DESC);
CREATE INDEX IF NOT EXISTS idx_mimic_derived_chemistry_hadm_chart
  ON mimiciv_derived.chemistry (hadm_id, charttime DESC);
CREATE INDEX IF NOT EXISTS idx_mimic_derived_bg_hadm_chart
  ON mimiciv_derived.bg (hadm_id, charttime DESC);
CREATE INDEX IF NOT EXISTS idx_mimic_derived_enzyme_hadm_chart
  ON mimiciv_derived.enzyme (hadm_id, charttime DESC);
CREATE INDEX IF NOT EXISTS idx_mimic_derived_coagulation_hadm_chart
  ON mimiciv_derived.coagulation (hadm_id, charttime DESC);
CREATE INDEX IF NOT EXISTS idx_mimic_derived_cbc_hadm_chart
  ON mimiciv_derived.complete_blood_count (hadm_id, charttime DESC);
CREATE INDEX IF NOT EXISTS idx_mimic_derived_weight_stay
  ON mimiciv_derived.weight_durations (stay_id, starttime DESC);
CREATE INDEX IF NOT EXISTS idx_mimic_derived_sofa_stay_end
  ON mimiciv_derived.sofa (stay_id, endtime DESC);
CREATE INDEX IF NOT EXISTS idx_mimic_derived_ne_stay_end
  ON mimiciv_derived.norepinephrine_equivalent_dose (stay_id, endtime DESC);

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt.cohort_baseline_v1 CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt.cohort_baseline_v1 AS
WITH
cohort AS (
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
  FROM data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"
)
SELECT
  c.subject_id,
  c.hadm_id,
  c.stay_id,
  c.intime,
  c.outtime,
  c.t0_time,
  c.age,
  c.gender,
  c.race,
  c.insurance,
  w.weight_kg,
  cc.charlson_comorbidity_index AS cci,
  v.hr,
  v.sbp,
  v.dbp,
  v.map,
  v.rr,
  v.spo2,
  v.temp_c,
  cb.wbc,
  cb.hb,
  cb.plt,
  ch.na,
  ch.cl,
  ch.k,
  ch.hco3,
  ch.scr,
  ch.bun,
  enz.ast,
  enz.alt,
  b.ph,
  b.lactate,
  b.pao2,
  b.fio2,
  CASE WHEN b.pao2 IS NOT NULL AND b.fio2 IS NOT NULL AND b.fio2 > 0 THEN b.pao2 / b.fio2 ELSE NULL END AS pf_ratio,
  cg.inr,
  sp.mv_baseline,
  sp.vaso_baseline,
  sp.ne_eq_baseline,
  sf.sofa_baseline
FROM cohort c
LEFT JOIN LATERAL (
  SELECT wd.weight AS weight_kg
  FROM mimiciv_derived.weight_durations wd
  WHERE wd.stay_id = c.stay_id
    AND wd.starttime <= c.t0_time
    AND COALESCE(wd.endtime, c.t0_time) >= c.t0_time
    AND wd.weight IS NOT NULL
  ORDER BY wd.starttime DESC
  LIMIT 1
) w ON true
LEFT JOIN mimiciv_derived.charlson cc ON cc.hadm_id = c.hadm_id
LEFT JOIN LATERAL (
  SELECT v.heart_rate AS hr, v.sbp, v.dbp, v.mbp AS map, v.resp_rate AS rr, v.spo2, v.temperature AS temp_c
  FROM mimiciv_derived.vitalsign v
  WHERE v.stay_id = c.stay_id
    AND v.charttime > c.t0_time - interval '6 hour'
    AND v.charttime <= c.t0_time
  ORDER BY v.charttime DESC
  LIMIT 1
) v ON true
LEFT JOIN LATERAL (
  SELECT ch.sodium AS na, ch.chloride AS cl, ch.potassium AS k, ch.bicarbonate AS hco3, ch.creatinine AS scr, ch.bun
  FROM mimiciv_derived.chemistry ch
  WHERE ch.hadm_id = c.hadm_id
    AND ch.charttime > c.t0_time - interval '6 hour'
    AND ch.charttime <= c.t0_time
  ORDER BY ch.charttime DESC
  LIMIT 1
) ch ON true
LEFT JOIN LATERAL (
  SELECT b.ph, b.lactate, b.po2 AS pao2, b.fio2
  FROM mimiciv_derived.bg b
  WHERE b.hadm_id = c.hadm_id
    AND b.charttime > c.t0_time - interval '6 hour'
    AND b.charttime <= c.t0_time
  ORDER BY b.charttime DESC
  LIMIT 1
) b ON true
LEFT JOIN LATERAL (
  SELECT e.ast, e.alt
  FROM mimiciv_derived.enzyme e
  WHERE e.hadm_id = c.hadm_id
    AND e.charttime > c.t0_time - interval '6 hour'
    AND e.charttime <= c.t0_time
  ORDER BY e.charttime DESC
  LIMIT 1
) enz ON true
LEFT JOIN LATERAL (
  SELECT cg.inr
  FROM mimiciv_derived.coagulation cg
  WHERE cg.hadm_id = c.hadm_id
    AND cg.charttime > c.t0_time - interval '6 hour'
    AND cg.charttime <= c.t0_time
  ORDER BY cg.charttime DESC
  LIMIT 1
) cg ON true
LEFT JOIN LATERAL (
  SELECT cb.wbc, cb.hemoglobin AS hb, cb.platelet AS plt
  FROM mimiciv_derived.complete_blood_count cb
  WHERE cb.hadm_id = c.hadm_id
    AND cb.charttime > c.t0_time - interval '6 hour'
    AND cb.charttime <= c.t0_time
  ORDER BY cb.charttime DESC
  LIMIT 1
) cb ON true
LEFT JOIN LATERAL (
  SELECT
    CASE WHEN EXISTS (
      SELECT 1 FROM mimiciv_derived.ventilation v
      WHERE v.stay_id = c.stay_id
        AND v.starttime < c.t0_time
        AND COALESCE(v.endtime, c.t0_time) > c.t0_time - interval '6 hour'
    ) THEN 1 ELSE 0 END AS mv_baseline,
    CASE WHEN EXISTS (
      SELECT 1 FROM mimiciv_derived.vasoactive_agent va
      WHERE va.stay_id = c.stay_id
        AND va.starttime < c.t0_time
        AND COALESCE(va.endtime, c.t0_time) > c.t0_time - interval '6 hour'
        AND (COALESCE(va.norepinephrine, 0) > 0 OR COALESCE(va.epinephrine, 0) > 0
             OR COALESCE(va.phenylephrine, 0) > 0 OR COALESCE(va.vasopressin, 0) > 0 OR COALESCE(va.dopamine, 0) > 0)
    ) THEN 1 ELSE 0 END AS vaso_baseline,
    (SELECT ne.norepinephrine_equivalent_dose
     FROM mimiciv_derived.norepinephrine_equivalent_dose ne
     WHERE ne.stay_id = c.stay_id
       AND ne.starttime < c.t0_time
       AND COALESCE(ne.endtime, c.t0_time) > c.t0_time - interval '6 hour'
       AND ne.norepinephrine_equivalent_dose IS NOT NULL
     ORDER BY ne.endtime DESC
     LIMIT 1) AS ne_eq_baseline
  FROM (SELECT 1) _
) sp ON true
LEFT JOIN LATERAL (
  SELECT s.sofa_24hours AS sofa_baseline
  FROM mimiciv_derived.sofa s
  WHERE s.stay_id = c.stay_id
    AND s.endtime > c.t0_time - interval '6 hour'
    AND s.endtime <= c.t0_time
    AND s.sofa_24hours IS NOT NULL
  ORDER BY s.endtime DESC
  LIMIT 1
) sf ON true;

CREATE INDEX IF NOT EXISTS idx_baseline_stay
  ON data_extract_crrt.cohort_baseline_v1 (stay_id);
CREATE INDEX IF NOT EXISTS idx_baseline_hadm
  ON data_extract_crrt.cohort_baseline_v1 (hadm_id);
CREATE INDEX IF NOT EXISTS idx_baseline_subject
  ON data_extract_crrt.cohort_baseline_v1 (subject_id);

ANALYZE data_extract_crrt.cohort_baseline_v1;

-- Navicat：仅选中下面一行执行以显示表格
SELECT * FROM data_extract_crrt.cohort_baseline_v1;
