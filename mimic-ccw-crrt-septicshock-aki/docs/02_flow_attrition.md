# Flow / attrition diagram counts

Counts are generated automatically by:
- sql/00_attrition_counts_flow.sql
Output: data_extract_crrt.attrition_counts_v1

Suggested flow structure:
1) Core cohort (101): adult + first ICU + LOS≥24h + exclude ESRD/Tx + Sepsis3-in-ICU + weight
2) Define t0 (201): KDIGO stage 3 exists; t0 defined as KDIGO3-6h (cap at ICU intime)
3) Final cohort (301): sepsis time ≤ t0 + vasopressor overlap + exclude pre-t0 RRT/CRRT

Reasons for exclusion (201 → 301) are reported as not mutually exclusive unless explicitly made sequential.