# Variable dictionary (baseline + time-varying)

## Windows
- Baseline: (t0−6h, t0]
- Dynamic for CCW (1h slices):
  - Urine output: sum in (t_end−6h, t_end] / weight / 6
  - MAP: last value in (t_end−1h, t_end]
  - Vasoactive/MV/NE-eq: interval overlap with (t_end−1h, t_end]
  - Labs: last value in (t_end−6h, t_end]

## Baseline variables (Table 1)
Demographics:
- age, sex, race, insurance, CCI

Comorbidities (Charlson components):
- DM, CHF, COPD, liver disease, malignancy

Severity/support:
- SOFA at t0 (derived.sofa endtime within baseline window)
- MV flag
- vasopressor flag
- norepi equivalent dose

Vitals:
- HR, SBP, DBP, MAP, RR, SpO2, Temp (derived.vitalsign)

Labs:
- CBC: WBC, Hb, PLT (derived.complete_blood_count, if exists)
- Chemistry: Na, Cl, K, HCO3, Cr, BUN, Glu, Alb, TBil, AST, ALT (derived.chemistry)
- Blood gas: pH, lactate, PaO2, PaCO2 (derived.bg)
- Coag: INR (derived.coagulation)

AKI detail:
- aki_stage_creat, aki_stage_uo, KDIGO3 driver (derived.kdigo_stages)

## Time-varying covariates (CCW)
- uo_mlkgph_last6h
- map_last1h
- vasopressor_flag_last1h
- norepi_equiv_last1h
- mv_flag_last1h
- lactate_last6h
- ph_last6h
- k_last6h
- hco3_last6h
- scr_last6h