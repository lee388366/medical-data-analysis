-- ============================================================
-- 01) Core cohort: Sepsis-3 ICU patients with basic eligibility
-- Output:
--   data_extract_crrt."101_patients_core_cohort_sepsis"
--
-- Notes:
-- - Uses mimiciv_derived.icustay_detail + sepsis3 + weight_durations
-- - Excludes ESRD / renal transplant via ICD9/10 (mimiciv_hosp.diagnoses_icd, codes without dots).
-- - intime/outtime from icu_intime/icu_outtime; age from admission_age; insurance from admissions.
-- - Qualified column names (i./a.) to avoid ambiguity.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt."101_patients_core_cohort_sepsis" CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt."101_patients_core_cohort_sepsis" AS
WITH
icud AS (
  SELECT
    i.stay_id,
    i.subject_id,
    i.hadm_id,
    i.icu_intime AS intime,
    i.icu_outtime AS outtime,
    i.admission_age AS age,
    i.gender,
    i.race,
    a.insurance,
    i.icu_intime,
    i.icu_outtime,
    i.los_icu
  FROM mimiciv_derived.icustay_detail i
  LEFT JOIN mimiciv_hosp.admissions a ON a.hadm_id = i.hadm_id
),

first_icu AS (
  SELECT
    i.*,
    ROW_NUMBER() OVER (PARTITION BY i.subject_id ORDER BY i.intime) AS rn
  FROM icud i
),

sepsis AS (
  SELECT
    stay_id,
    sepsis3,
    suspected_infection_time
  FROM mimiciv_derived.sepsis3
),

wt AS (
  SELECT DISTINCT stay_id
  FROM mimiciv_derived.weight_durations
  WHERE weight IS NOT NULL
),

esrd_tx_hadm AS (
  SELECT DISTINCT d.hadm_id
  FROM mimiciv_hosp.diagnoses_icd d
  WHERE
    (d.icd_version = 10 AND (d.icd_code IN ('N186','Z992','Z940')))
    OR
    (d.icd_version = 9  AND (d.icd_code IN ('5856','V451','V420')))
),

core AS (
  SELECT
    f.stay_id, f.subject_id, f.hadm_id,
    f.intime, f.outtime,
    f.age, f.gender, f.race, f.insurance,
    f.los_icu
  FROM first_icu f
  JOIN sepsis s
    ON s.stay_id = f.stay_id
  JOIN wt
    ON wt.stay_id = f.stay_id
  LEFT JOIN esrd_tx_hadm x
    ON x.hadm_id = f.hadm_id
  WHERE
    f.rn = 1
    AND f.age >= 18
    AND f.los_icu >= 1.0
    AND s.sepsis3 IS TRUE
    AND s.suspected_infection_time IS NOT NULL
    AND s.suspected_infection_time >= f.intime
    AND s.suspected_infection_time <= f.outtime
    AND x.hadm_id IS NULL
)
SELECT * FROM core;

CREATE INDEX IF NOT EXISTS idx_101_core_stay
  ON data_extract_crrt."101_patients_core_cohort_sepsis"(stay_id);

CREATE INDEX IF NOT EXISTS idx_101_core_hadm
  ON data_extract_crrt."101_patients_core_cohort_sepsis"(hadm_id);

ANALYZE data_extract_crrt."101_patients_core_cohort_sepsis";

-- 输出前 500 行，便于在 Navicat 结果窗口看到表格
SELECT * FROM data_extract_crrt."101_patients_core_cohort_sepsis" LIMIT 500;
