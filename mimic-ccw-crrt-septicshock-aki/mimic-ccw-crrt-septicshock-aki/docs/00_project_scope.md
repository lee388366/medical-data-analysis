# Scope & decisions (frozen)

## Main question
Among ICU patients with septic shock ∩ AKI (KDIGO stage 3 anchored), what is the per-protocol effect of early CRRT initiation (≤24h after t0) vs no-early initiation (no CRRT within 24h)?

## Core design choices
- TTE + CCW (per-protocol estimand)
- t0 anchored to KDIGO stage 3 onset (minus 6h, capped at ICU admission)
- Baseline window: (t0-6h, t0]
- CCW grace period: 24h
- CCW time-slice: 1h

## Primary outcomes
- 28-day mortality (from t0)
- 28-day renal recovery: alive at 28d AND Scr_28d ≤ 1.5 × baseline Scr