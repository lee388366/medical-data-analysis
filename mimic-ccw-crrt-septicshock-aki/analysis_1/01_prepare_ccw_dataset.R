library(DBI)
library(dplyr)

# database connection
con <- dbConnect(RPostgres::Postgres(),
                 dbname = "mimic")

# clone–censor dataset
df_clone <- dbGetQuery(con, "
SELECT *
FROM data_extract_crrt.ccw_clone_long_0_24h_1h_v2
")

# baseline variables
df_baseline <- dbGetQuery(con, "
SELECT
    stay_id,
    age,
    sex,
    weight_kg,
    charlson_comorbidity_index,
    ne_eq_baseline,
    mv_baseline,
    pfratio,
    lactate,
    ph,
    scr_baseline_win,
    potassium
FROM data_extract_crrt.cohort_baseline_v1
")

# merge baseline with long dataset
df <- df_clone %>%
  left_join(df_baseline, by = "stay_id")

# keep only rows at risk
df <- df %>%
  filter(at_risk_after_k == 1)
