# CCW design details

## Strategies
A: early ≤24h after t0
B: no-early within 24h after t0

## Cloning
Each eligible stay_id is duplicated into A and B.

## Protocol censoring
A: if CRRT not started by t0+24h -> censor at t0+24h
B: if CRRT starts within 24h -> censor at CRRT start time

## Administrative censoring (within 24h)
- death_time (admissions.deathtime) if within 24h
- ICU discharge (icu_outtime) if within 24h

## Discrete-time representation
1-hour slices, censor event occurs in (t_start, t_end].

## IPCW
Stabilized weights:
- numerator: baseline + time
- denominator: baseline + time + time-varying covariates