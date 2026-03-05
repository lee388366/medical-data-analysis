library(dplyr)

# denominator model
model_denom <- glm(
  censor_k_total ~
    strategy +
    age +
    sex +
    weight_kg +
    charlson_comorbidity_index +
    ne_eq_baseline +
    mv_baseline +
    pfratio +
    lactate +
    ph +
    scr_baseline_win +
    potassium +
    uo_mlkgph_last6h +
    map_last1h +
    vaso_flag_last1h +
    ne_eq_last1h +
    mv_flag_last1h +
    lactate_last6h +
    ph_last6h +
    k_last6h +
    scr_last6h +
    factor(hour_index),

  family = binomial(),
  data = df
)

p_denom <- predict(model_denom, type = "response")

# numerator model (stabilization)
model_num <- glm(
  censor_k_total ~ strategy + factor(hour_index),
  family = binomial(),
  data = df
)

p_num <- predict(model_num, type = "response")

df <- df %>%
  mutate(
    w_denom = 1/(1 - p_denom),
    w_num = 1/(1 - p_num),
    w_slice = w_num / w_denom
  )

# cumulative stabilized weight
df <- df %>%
  group_by(stay_id, clone_id) %>%
  mutate(
    ipcw = cumprod(w_slice)
  )

# weight truncation
lower <- quantile(df$ipcw, 0.01, na.rm = TRUE)
upper <- quantile(df$ipcw, 0.99, na.rm = TRUE)

df <- df %>%
  mutate(
    ipcw_trunc = pmin(pmax(ipcw, lower), upper)
  )

summary(df$ipcw_trunc)
