# mimic-ccw-crrt-septicshock-aki

Target trial emulation (TTE) + clone–censor–weight (CCW) study in **MIMIC-IV v3.1**:
Effect of **early CRRT (≤24h after t0)** vs **no-early (no CRRT within 24h)** among ICU patients with:
**septic shock proxy ∩ AKI (KDIGO stage 3 anchored)**.

---

## 1. Study design (frozen decisions)

### Population
ICU patients (adult, first ICU stay, ICU LOS ≥ 24h) with:
- Sepsis-3 during ICU stay
- AKI reaches KDIGO stage 3 in ICU (anchored to first KDIGO3 time)
- Septic shock proxy around t0: vasopressor overlap in (t0−6h, t0]
- Weight available (for urine output normalization)
- Exclude: ESRD/renal transplant history; any RRT/CRRT before t0

### Time zero (t0)
`t0 = max(ICU intime, first KDIGO stage 3 time − 6h)`

### Strategies (grace period 24h)
- **A (early):** start CRRT within 24h after t0
- **B (no-early):** do NOT start CRRT within 24h after t0

### Follow-up
- CCW adherence window: `[t0, t0+24h)` with **1-hour slices**
- Main outcomes evaluated at 28d from t0

### Primary outcomes
- 28-day mortality from t0
- 28-day renal recovery (Scr-based):
  `alive at 28d AND Scr_28d ≤ 1.5 × baseline_Scr`

Baseline Scr proxy:
- `baseline_Scr = MIN Scr in [admittime, t0]`
Scr_28d:
- last Scr in `(t0, t0+28d]`

---

## 2. Repository structure