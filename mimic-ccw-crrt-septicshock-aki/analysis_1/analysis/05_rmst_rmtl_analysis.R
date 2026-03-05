library(dplyr)
library(DBI)
library(survRM2)

con <- dbConnect(RPostgres::Postgres(),
                 dbname = "mimic")

# 读取 survival 数据
df <- readRDS("analysis_data_ccw.rds")

# 读取 outcome
df_outcome <- dbGetQuery(con,"
SELECT stay_id,
       death_28d,
       deathtime,
       t0_time
FROM data_extract_crrt.outcomes_28d_renal_v1
")

df <- df %>%
  left_join(df_outcome, by="stay_id")

# time-to-event
df <- df %>%
  mutate(
    time = as.numeric(
      difftime(deathtime, t0_time, units="days")
    ),
    time = pmin(time, 28),
    event = ifelse(death_28d==1 & time<=28,1,0)
  )

# RMST / RMTL
rmst <- rmst2(
  time = df$time,
  status = df$event,
  arm = as.numeric(as.factor(df$strategy)),
  tau = 28,
  weight = df$ipcw_trunc
)

print(rmst)

# 保存结果
capture.output(
  rmst,
  file = "rmst_results.txt"
)
