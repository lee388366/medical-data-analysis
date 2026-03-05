library(dplyr)
library(survival)
library(survminer)
library(DBI)

con <- dbConnect(RPostgres::Postgres(),
                 dbname="mimic")

# 读取权重数据
df_long <- readRDS("analysis_data_ccw.rds")

# 读取 outcome
df_outcome <- dbGetQuery(con,"
SELECT stay_id,
       death_28d,
       deathtime,
       t0_time
FROM data_extract_crrt.outcomes_28d_renal_v1
")

df <- df_long %>%
  left_join(df_outcome, by="stay_id")

# 计算 time-to-event
df <- df %>%
  mutate(
    time = as.numeric(
      difftime(deathtime, t0_time, units="days")
    ),
    time = pmin(time, 28),
    event = ifelse(death_28d==1 & time<=28,1,0)
  )

# -----------------------------
# 1 Weighted Kaplan-Meier
# -----------------------------

fit <- survfit(
  Surv(time,event) ~ strategy,
  data=df,
  weights=ipcw_trunc
)

ggsurvplot(
  fit,
  conf.int = TRUE,
  risk.table = TRUE
)

ggsave("fig_weighted_survival_curve.png",
       width=6,height=5)

# -----------------------------
# 2 Risk difference at 28 days
# -----------------------------

surv_28 <- summary(fit, times=28)

risk <- 1 - surv_28$surv

risk_diff <- risk[1] - risk[2]

print(risk_diff)

# -----------------------------
# 3 Weighted Cox model
# -----------------------------

cox_model <- coxph(
  Surv(time,event) ~ strategy,
  data=df,
  weights=ipcw_trunc
)

summary(cox_model)

write.csv(
  broom::tidy(cox_model),
  "cox_results.csv",
  row.names=FALSE
)
