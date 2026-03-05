model_denom <- glm(
  censor_k_total ~
  strategy +
  age + sex +
  ne_eq_baseline +
  mv_baseline +
  uo_mlkgph_last6h +
  map_last1h +
  vaso_flag_last1h +
  ne_eq_last1h +
  mv_flag_last1h +
  lactate_last6h +
  ph_last6h +
  factor(hour_index),
  family = binomial(),
  data=df
)

p_denom <- predict(model_denom,type="response")

df$w_denom <- 1/(1-p_denom)

df <- df %>%
  group_by(stay_id,clone_id) %>%
  mutate(
    ipcw = cumprod(w_denom)
  )