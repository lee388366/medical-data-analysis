-- ============================================================
-- 01) Core cohort: Sepsis-3 ICU patients with basic eligibility
-- Output:
--   data_extract_crrt."101_patients_core_cohort_sepsis"
--
-- Notes:
-- - Uses mimiciv_derived.icustay_detail + sepsis3 + weight_durations
-- - Excludes ESRD / renal transplant via ICD9/10 codes (approx).
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt."101_patients_core_cohort_sepsis" CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt."101_patients_core_cohort_sepsis" AS
WITH
icud AS (
  SELECT
    stay_id, subject_id, hadm_id,
    intime, outtime,
    anchor_age AS age,
    gender,
    race,
    insurance,
    icu_intime, icu_outtime,
    los_icu
  FROM mimiciv_derived.icustay_detail
),

first_icu AS (
  SELECT
    i.*,
    ROW_NUMBER() OVER (PARTITION BY subject_id ORDER BY intime) AS rn
  FROM icud i
),

sepsis AS (
  SELECT
    stay_id,
    sepsis3,
    suspected_infection_time
  FROM mimiciv_derived.sepsis3
),

-- Weight availability: take the nearest/overlapping weight record at ICU time (we use existence only here)
wt AS (
  SELECT DISTINCT stay_id
  FROM mimiciv_derived.weight_durations
  WHERE weight IS NOT NULL
),

-- ESRD / renal transplant exclusion (ICD9/10 common codes)
esrd_tx_hadm AS (
  SELECT DISTINCT d.hadm_id
  FROM mimiciv_hosp.diagnoses_icd d
  WHERE
    -- ICD10 ESRD N18.6; dialysis dependence Z99.2
    (d.icd_version = 10 AND (d.icd_code IN ('N186','Z992')))
    OR
    -- ICD9 ESRD 585.6; V45.1 (renal dialysis); V42.0 (kidney transplant status)
    (d.icd_version = 9 AND (d.icd_code IN ('5856','V451','V420')))
    OR
    -- ICD10 kidney transplant status Z94.0
    (d.icd_version = 10 AND (d.icd_code IN ('Z940')))
)

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
  AND f.los_icu >= 1.0  -- ICU LOS >= 24h
  AND s.sepsis3 IS TRUE
  AND s.suspected_infection_time IS NOT NULL
  AND s.suspected_infection_time >= f.intime
  AND s.suspected_infection_time <= f.outtime
  AND x.hadm_id IS NULL
;

CREATE INDEX IF NOT EXISTS idx_101_core_stay
  ON data_extract_crrt."101_patients_core_cohort_sepsis"(stay_id);

CREATE INDEX IF NOT EXISTS idx_101_core_hadm
  ON data_extract_crrt."101_patients_core_cohort_sepsis"(hadm_id);

ANALYZE data_extract_crrt."101_patients_core_cohort_sepsis";