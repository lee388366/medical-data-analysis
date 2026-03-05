#808 + 505 baseline
df_long <- dbGetQuery(con,"
SELECT *
FROM data_extract_crrt.ccw_clone_long_0_24h_1h_v2
")

df_baseline <- dbGetQuery(con,"
SELECT stay_id,
       weight_kg,
       ne_eq_baseline,
       mv_baseline
FROM data_extract_crrt.cohort_baseline_v1
")

df <- df_long %>%
  left_join(df_baseline, by="stay_id")
