-- ============================================================
-- 05) Baseline Table 1 dataset (t0-6h, t0]
-- Output:
--   data_extract_crrt.cohort_baseline_v1
-- Notes:
-- - Uses "last observation" within baseline window for vitals/labs
-- - SOFA uses derived.sofa (if available); otherwise remove that block.
-- - CBC table name may differ across derived builds.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt.cohort_baseline_v1 CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt.cohort_baseline_v1 AS
WITH
cohort AS (
  SELECT *
  FROM data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"
),

w_at_t0 AS (
  SELECT
    c.stay_id,
    -- weight closest to t0 within +/- 12h window (fallback to any)
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

cci AS (
  SELECT
    ch.hadm_id,
    ch.charlson_comorbidity_index AS cci
  FROM mimiciv_derived.charlson ch
),

-- helper: last value in window for a given table/column
vitals AS (
  SELECT
    c.stay_id,
    -- last values (t0-6h, t0]
    (SELECT v.heart_rate FROM mimiciv_derived.vitalsign v
      WHERE v.stay_id=c.stay_id AND v.charttime>c.t0_time-interval '6 hour' AND v.charttime<=c.t0_time
        AND v.heart_rate IS NOT NULL
      ORDER BY v.charttime DESC LIMIT 1) AS hr,
    (SELECT v.sbp FROM mimiciv_derived.vitalsign v
      WHERE v.stay_id=c.stay_id AND v.charttime>c.t0_time-interval '6 hour' AND v.charttime<=c.t0_time
        AND v.sbp IS NOT NULL
      ORDER BY v.charttime DESC LIMIT 1) AS sbp,
    (SELECT v.dbp FROM mimiciv_derived.vitalsign v
      WHERE v.stay_id=c.stay_id AND v.charttime>c.t0_time-interval '6 hour' AND v.charttime<=c.t0_time
        AND v.dbp IS NOT NULL
      ORDER BY v.charttime DESC LIMIT 1) AS dbp,
    (SELECT v.mbp FROM mimiciv_derived.vitalsign v
      WHERE v.stay_id=c.stay_id AND v.charttime>c.t0_time-interval '6 hour' AND v.charttime<=c.t0_time
        AND v.mbp IS NOT NULL
      ORDER BY v.charttime DESC LIMIT 1) AS map,
    (SELECT v.resp_rate FROM mimiciv_derived.vitalsign v
      WHERE v.stay_id=c.stay_id AND v.charttime>c.t0_time-interval '6 hour' AND v.charttime<=c.t0_time
        AND v.resp_rate IS NOT NULL
      ORDER BY v.charttime DESC LIMIT 1) AS rr,
    (SELECT v.spo2 FROM mimiciv_derived.vitalsign v
      WHERE v.stay_id=c.stay_id AND v.charttime>c.t0_time-interval '6 hour' AND v.charttime<=c.t0_time
        AND v.spo2 IS NOT NULL
      ORDER BY v.charttime DESC LIMIT 1) AS spo2,
    (SELECT v.temperature FROM mimiciv_derived.vitalsign v
      WHERE v.stay_id=c.stay_id AND v.charttime>c.t0_time-interval '6 hour' AND v.charttime<=c.t0_time
        AND v.temperature IS NOT NULL
      ORDER BY v.charttime DESC LIMIT 1) AS temp_c
  FROM cohort c
),

chem AS (
  SELECT
    c.stay_id,
    (SELECT ch.creatinine FROM mimiciv_derived.chemistry ch
      WHERE ch.hadm_id=c.hadm_id AND ch.charttime>c.t0_time-interval '6 hour' AND ch.charttime<=c.t0_time
        AND ch.creatinine IS NOT NULL
      ORDER BY ch.charttime DESC LIMIT 1) AS scr,
    (SELECT ch.urea_nitrogen FROM mimiciv_derived.chemistry ch
      WHERE ch.hadm_id=c.hadm_id AND ch.charttime>c.t0_time-interval '6 hour' AND ch.charttime<=c.t0_time
        AND ch.urea_nitrogen IS NOT NULL
      ORDER BY ch.charttime DESC LIMIT 1) AS bun,
    (SELECT ch.sodium FROM mimiciv_derived.chemistry ch
      WHERE ch.hadm_id=c.hadm_id AND ch.charttime>c.t0_time-interval '6 hour' AND ch.charttime<=c.t0_time
        AND ch.sodium IS NOT NULL
      ORDER BY ch.charttime DESC LIMIT 1) AS na,
    (SELECT ch.chloride FROM mimiciv_derived.chemistry ch
      WHERE ch.hadm_id=c.hadm_id AND ch.charttime>c.t0_time-interval '6 hour' AND ch.charttime<=c.t0_time
        AND ch.chloride IS NOT NULL
      ORDER BY ch.charttime DESC LIMIT 1) AS cl,
    (SELECT ch.potassium FROM mimiciv_derived.chemistry ch
      WHERE ch.hadm_id=c.hadm_id AND ch.charttime>c.t0_time-interval '6 hour' AND ch.charttime<=c.t0_time
        AND ch.potassium IS NOT NULL
      ORDER BY ch.charttime DESC LIMIT 1) AS k,
    (SELECT ch.bicarbonate FROM mimiciv_derived.chemistry ch
      WHERE ch.hadm_id=c.hadm_id AND ch.charttime>c.t0_time-interval '6 hour' AND ch.charttime<=c.t0_time
        AND ch.bicarbonate IS NOT NULL
      ORDER BY ch.charttime DESC LIMIT 1) AS hco3,
    (SELECT ch.ast FROM mimiciv_derived.chemistry ch
      WHERE ch.hadm_id=c.hadm_id AND ch.charttime>c.t0_time-interval '6 hour' AND ch.charttime<=c.t0_time
        AND ch.ast IS NOT NULL
      ORDER BY ch.charttime DESC LIMIT 1) AS ast,
    (SELECT ch.alt FROM mimiciv_derived.chemistry ch
      WHERE ch.hadm_id=c.hadm_id AND ch.charttime>c.t0_time-interval '6 hour' AND ch.charttime<=c.t0_time
        AND ch.alt IS NOT NULL
      ORDER BY ch.charttime DESC LIMIT 1) AS alt
  FROM cohort c
),

bg AS (
  SELECT
    c.stay_id,
    (SELECT b.ph FROM mimiciv_derived.bg b
      WHERE b.hadm_id=c.hadm_id AND b.charttime>c.t0_time-interval '6 hour' AND b.charttime<=c.t0_time
        AND b.ph IS NOT NULL
      ORDER BY b.charttime DESC LIMIT 1) AS ph,
    (SELECT b.lactate FROM mimiciv_derived.bg b
      WHERE b.hadm_id=c.hadm_id AND b.charttime>c.t0_time-interval '6 hour' AND b.charttime<=c.t0_time
        AND b.lactate IS NOT NULL
      ORDER BY b.charttime DESC LIMIT 1) AS lactate,
    (SELECT b.pao2 FROM mimiciv_derived.bg b
      WHERE b.hadm_id=c.hadm_id AND b.charttime>c.t0_time-interval '6 hour' AND b.charttime<=c.t0_time
        AND b.pao2 IS NOT NULL
      ORDER BY b.charttime DESC LIMIT 1) AS pao2,
    (SELECT b.fio2 FROM mimiciv_derived.bg b
      WHERE b.hadm_id=c.hadm_id AND b.charttime>c.t0_time-interval '6 hour' AND b.charttime<=c.t0_time
        AND b.fio2 IS NOT NULL
      ORDER BY b.charttime DESC LIMIT 1) AS fio2
  FROM cohort c
),

coag AS (
  SELECT
    c.stay_id,
    (SELECT cg.inr FROM mimiciv_derived.coagulation cg
      WHERE cg.hadm_id=c.hadm_id AND cg.charttime>c.t0_time-interval '6 hour' AND cg.charttime<=c.t0_time
        AND cg.inr IS NOT NULL
      ORDER BY cg.charttime DESC LIMIT 1) AS inr
  FROM cohort c
),

-- CBC (table name may vary; if missing, replace via labevents mapping)
cbc AS (
  SELECT
    c.stay_id,
    (SELECT cb.wbc FROM mimiciv_derived.complete_blood_count cb
      WHERE cb.hadm_id=c.hadm_id AND cb.charttime>c.t0_time-interval '6 hour' AND cb.charttime<=c.t0_time
        AND cb.wbc IS NOT NULL
      ORDER BY cb.charttime DESC LIMIT 1) AS wbc,
    (SELECT cb.hemoglobin FROM mimiciv_derived.complete_blood_count cb
      WHERE cb.hadm_id=c.hadm_id AND cb.charttime>c.t0_time-interval '6 hour' AND cb.charttime<=c.t0_time
        AND cb.hemoglobin IS NOT NULL
      ORDER BY cb.charttime DESC LIMIT 1) AS hb,
    (SELECT cb.platelet FROM mimiciv_derived.complete_blood_count cb
      WHERE cb.hadm_id=c.hadm_id AND cb.charttime>c.t0_time-interval '6 hour' AND cb.charttime<=c.t0_time
        AND cb.platelet IS NOT NULL
      ORDER BY cb.charttime DESC LIMIT 1) AS plt
  FROM cohort c
),

support AS (
  SELECT
    c.stay_id,
    -- MV overlap in baseline window
    CASE WHEN EXISTS (
      SELECT 1 FROM mimiciv_derived.ventilation v
      WHERE v.stay_id=c.stay_id
        AND v.starttime < c.t0_time
        AND COALESCE(v.endtime, c.t0_time) > c.t0_time - interval '6 hour'
    ) THEN 1 ELSE 0 END AS mv_baseline,

    -- vasopressor overlap in baseline window
    CASE WHEN EXISTS (
      SELECT 1 FROM mimiciv_derived.vasoactive_agent va
      WHERE va.stay_id=c.stay_id
        AND va.starttime < c.t0_time
        AND COALESCE(va.endtime, c.t0_time) > c.t0_time - interval '6 hour'
        AND (
          COALESCE(va.norepinephrine,0) > 0
          OR COALESCE(va.epinephrine,0) > 0
          OR COALESCE(va.phenylephrine,0) > 0
          OR COALESCE(va.vasopressin,0) > 0
          OR COALESCE(va.dopamine,0) > 0
        )
    ) THEN 1 ELSE 0 END AS vaso_baseline,

    -- NE equivalent dose baseline (take last in window; may vary across derived builds)
    (SELECT ne.norepinephrine_equivalent_dose
     FROM mimiciv_derived.norepinephrine_equivalent_dose ne
     WHERE ne.stay_id=c.stay_id
       AND ne.charttime>c.t0_time-interval '6 hour'
       AND ne.charttime<=c.t0_time
       AND ne.norepinephrine_equivalent_dose IS NOT NULL
     ORDER BY ne.charttime DESC
     LIMIT 1) AS ne_eq_baseline
  FROM cohort c
),

sofa AS (
  SELECT
    c.stay_id,
    (SELECT s.sofa
     FROM mimiciv_derived.sofa s
     WHERE s.stay_id=c.stay_id
       AND s.endtime>c.t0_time-interval '6 hour'
       AND s.endtime<=c.t0_time
       AND s.sofa IS NOT NULL
     ORDER BY s.endtime DESC
     LIMIT 1) AS sofa_baseline
  FROM cohort c
)

SELECT
  c.subject_id, c.hadm_id, c.stay_id,
  c.intime, c.outtime, c.t0_time,
  c.age, c.gender, c.race, c.insurance,
  w.weight_kg,
  cc.cci,

  v.hr, v.sbp, v.dbp, v.map, v.rr, v.spo2, v.temp_c,

  cb.wbc, cb.hb, cb.plt,

  ch.na, ch.cl, ch.k, ch.hco3,
  ch.scr, ch.bun,
  ch.ast, ch.alt,

  b.ph, b.lactate,
  b.pao2, b.fio2,
  CASE WHEN b.pao2 IS NOT NULL AND b.fio2 IS NOT NULL AND b.fio2 > 0
       THEN b.pao2 / b.fio2
       ELSE NULL END AS pf_ratio,

  cg.inr,

  sp.mv_baseline,
  sp.vaso_baseline,
  sp.ne_eq_baseline,

  sf.sofa_baseline
FROM cohort c
LEFT JOIN w_at_t0 w ON w.stay_id=c.stay_id
LEFT JOIN cci cc    ON cc.hadm_id=c.hadm_id
LEFT JOIN vitals v  ON v.stay_id=c.stay_id
LEFT JOIN cbc cb    ON cb.stay_id=c.stay_id
LEFT JOIN chem ch   ON ch.stay_id=c.stay_id
LEFT JOIN bg b      ON b.stay_id=c.stay_id
LEFT JOIN coag cg   ON cg.stay_id=c.stay_id
LEFT JOIN support sp ON sp.stay_id=c.stay_id
LEFT JOIN sofa sf   ON sf.stay_id=c.stay_id
;

CREATE INDEX IF NOT EXISTS idx_baseline_stay
  ON data_extract_crrt.cohort_baseline_v1(stay_id);

ANALYZE data_extract_crrt.cohort_baseline_v1;