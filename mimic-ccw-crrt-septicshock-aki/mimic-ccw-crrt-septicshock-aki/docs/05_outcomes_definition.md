# Outcomes definition

## 28-day mortality
death_28d = 1 if death_time in (t0, t0+28d], else 0.
alive_28d = 1 if death_time is NULL or > t0+28d.

## Baseline Scr (proxy)
scr_baseline = MIN(creatinine) measured in [admittime, t0] within same admission.

Notes:
- This is an in-hospital baseline proxy. Sensitivity analyses can restrict baseline window to [t0−7d, t0].

## Day-28 Scr
scr_28d = last creatinine in (t0, t0+28d].

## Renal recovery at day 28 (primary renal endpoint)
renal_recovery_28d_scr = 1 if alive_28d=1 AND scr_28d ≤ 1.5 × scr_baseline.