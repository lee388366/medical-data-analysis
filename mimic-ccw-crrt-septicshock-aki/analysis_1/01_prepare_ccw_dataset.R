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

# baseline variables (列名与 05 cohort_baseline_v1 一致：gender/cci/pf_ratio/scr/k)
df_baseline <- dbGetQuery(con, "
SELECT
    stay_id,
    age,
    gender,
    weight_kg,
    cci,
    ne_eq_baseline,
    mv_baseline,
    pf_ratio,
    lactate,
    ph,
    scr,
    k
FROM data_extract_crrt.cohort_baseline_v1
")

# merge baseline with long dataset
df <- df_clone %>%
  left_join(df_baseline, by = "stay_id")

# clone 标识（08 无 clone_id 列，R 里用 stay_id + strategy 生成）
df <- df %>%
  mutate(clone_id = paste(stay_id, strategy, sep = "_"))

# 供 02 及 IPCW 模型用：与 05 列名对齐
df <- df %>%
  rename(
    sex = gender,
    charlson_comorbidity_index = cci,
    pfratio = pf_ratio,
    scr_baseline_win = scr,
    potassium = k
  )

# keep only rows at risk
df <- df %>%
  filter(at_risk_after_k == 1)

# 保存供 03–07 使用（R 为连库，中间结果存为 RDS）
saveRDS(df, "analysis_data_ccw.rds")
