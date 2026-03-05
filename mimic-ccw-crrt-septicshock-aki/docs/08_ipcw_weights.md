# Inverse probability of censoring weights (IPCW)

Weights were estimated using pooled logistic regression models
predicting the probability of censoring at each hourly time slice.

The denominator model included:

- baseline covariates
- time-varying clinical variables
- treatment strategy
- time index

Stabilized weights were computed as the ratio between the marginal
probability of remaining uncensored and the conditional probability.

Weights were truncated at the 1st and 99th percentiles to reduce the
influence of extreme values.