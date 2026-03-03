# MIMIC-IV: CCW for CRRT timing in Septic Shock ∩ AKI (KDIGO3-anchored)

## Project aim
Target trial emulation (TTE) + clone–censor–weight (CCW) to estimate the per-protocol effect of:
- Strategy A (early): initiate CRRT within 24 hours after t0
- Strategy B (no-early): do NOT initiate CRRT within 24 hours after t0

Population: Septic shock ∩ AKI (KDIGO stage 3 anchored) ICU cohort in MIMIC-IV.

## Key design
- Cohort: Sepsis-3 during ICU stay, adult, first ICU stay, ICU LOS ≥ 24h, exclude ESRD/renal transplant, require weight.
- t0 (time zero): max(ICU intime, first time reaching KDIGO stage 3 − 6h).
- Baseline window for Table 1: (t0 − 6h, t0]
- CCW window: [t0, t0 + 24h), sliced into 1-hour intervals
- Administrative censoring in CCW: death within 24h, ICU discharge before 24h
- Outcomes:
  - 28-day mortality (from t0)
  - Renal recovery at day 28: alive at 28d AND Scr_28d ≤ 1.5 × baseline Scr
    - baseline Scr proxy: MIN Scr in [admittime, t0]
    - Scr_28d: last Scr in (t0, t0+28d]

## Dependencies
Requires MIMIC-IV v3.1 with `mimiciv_derived` tables:
- icustay_detail, sepsis3, kdigo_stages, weight_durations, charlson
- vitalsign, bg, chemistry, coagulation
- ventilation, vasoactive_agent, norepinephrine_equivalent_dose
- rrt, crrt
- urine_output (table name may differ across derived builds)

## Project structure
```
mimic-ccw-crrt-septicshock-aki/
├── README.md
├── sql/                    # Pipeline scripts (run in order)
│   ├── 01_cohort_eligibility_ss.sql
│   ├── 02_define_t0_kdigo3_ss.sql
│   ├── 03_apply_septic_shock_and_exclude_rrt_pre_t0_ss.sql
│   ├── 05_baseline_table1_v1.sql
│   ├── 06_ccw_long_0_24h_dynamic_1h.sql
│   ├── 07_outcomes_28d_renal_recovery_scr.sql
│   ├── 08_ccw_clone_censor_1h_with_admin.sql
│   └── run_all.sql
└── docs/                   # Design and variable docs
    ├── 00_project_scope.md
    ├── 01_trial_protocol.md
    ├── 02_flow_attrition.md
    ├── 03_variable_dictionary.md
    ├── 04_ccw_design.md
    ├── 05_outcomes_definition.md
    └── 99_todo_next_session.md
```

## How to run
Run in order via `sql/run_all.sql` using psql (from repo root):
```bash
psql -f mimic-ccw-crrt-septicshock-aki/sql/run_all.sql