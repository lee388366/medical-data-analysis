# Trial protocol (TTE + CCW)

## Eligibility
- Adult (age ≥ 18)
- First ICU stay per subject
- ICU LOS ≥ 24h
- Sepsis-3 during ICU stay (suspected infection time within ICU stay)
- AKI reaches KDIGO stage 3 within ICU stay
- Septic shock proxy around t0: vasopressor overlap in (t0−6h, t0]
- Weight available (for urine output normalization)

## Exclusion
- ESRD / chronic dialysis dependence / renal transplant history (ICD-based)
- Any RRT/CRRT before t0 (derived.rrt + derived.crrt)

## Time zero (t0)
t0 = max(ICU intime, first time reaching KDIGO stage 3 − 6 hours)

## Treatment strategies (grace period 24h)
- Strategy A (early): initiate CRRT within 24h after t0
- Strategy B (no-early): do not initiate CRRT within 24h after t0

## Follow-up
- Outcomes: from t0 to 28 days.
- CCW adherence window: [t0, t0+24h).

## Estimand
Per-protocol effect (as if patients adhered to each strategy).

## CCW approach
- Clone each eligible patient into two copies (A and B).
- Censor for protocol deviation:
  - A: if no CRRT by 24h -> censor at 24h
  - B: if CRRT starts within 24h -> censor at start time
- Administrative censor within 24h:
  - death_time if within 24h
  - ICU discharge (outtime) if < 24h
- Use stabilized IPCW with pooled logistic hazard model over 1h slices.

## Baseline covariates (Table 1)
All baseline covariates extracted from (t0−6h, t0], using last observation within window.

## Time-varying covariates (for IPCW)
Computed per 1h slice using only information up to slice end:
- urine output rate over last 6h (ml/kg/h)
- MAP (last 1h)
- vasopressor flag (overlap last 1h)
- norepinephrine equivalent dose (overlap last 1h)
- MV flag (overlap last 1h)
- lactate, pH (last 6h)
- K, HCO3, Scr (last 6h)