# Inverse Probability of Censoring Weights (IPCW)

This study uses a clone–censor–weight (CCW) target trial emulation
framework. Inverse probability of censoring weights (IPCW) are used
to account for informative censoring due to deviation from treatment
strategies.

## Censoring definition

At each hourly time slice, censoring occurs when a clone deviates from
its assigned strategy:

- Early CRRT strategy: no CRRT within 24 hours → censor at 24h
- No-early CRRT strategy: CRRT initiated within 24 hours → censor at CRRT time

Administrative censoring may also occur due to ICU discharge or death.

## Weight estimation

Weights are estimated using pooled logistic regression models predicting
the probability of censoring at each hourly time slice.

The stabilized weight is defined as:

SW = ∏ ( P(no censor | strategy, time) / P(no censor | history) )

where the denominator model includes baseline and time-varying covariates.

## Baseline covariates

- age
- sex
- weight_kg
- Charlson comorbidity index
- norepinephrine-equivalent dose (baseline)
- mechanical ventilation (baseline)
- PF ratio
- lactate
- pH or bicarbonate
- serum creatinine
- potassium

## Time-varying covariates

Measured at each hourly time slice:

- urine output (ml/kg/h, last 6h)
- mean arterial pressure (last 1h)
- vasopressor use (last 1h)
- norepinephrine-equivalent dose (last 1h)
- mechanical ventilation (last 1h)
- lactate (last 6h)
- pH (last 6h)
- potassium (last 6h)
- serum creatinine (last 6h)

## Time function

Time since t0 is modeled using:

- factor(hour_index)

## Stabilization

Stabilized weights are calculated using a numerator model including:

- treatment strategy
- time index

## Weight truncation

To reduce the influence of extreme weights, stabilized weights are truncated
at the 1st and 99th percentiles.

## Software

All weights are estimated in R using pooled logistic regression models.
