#sql/09_subgroup_flags_v1.sql
library(dplyr)
library(DBI)
library(broom)
library(ggplot2)

con <- dbConnect(RPostgres::Postgres(),
                 dbname = "mimic")

# 读取 survival dataset
df <- readRDS("analysis_data_ccw.rds")

# 读取 outcome
df_outcome <- dbGetQuery(con,"
SELECT stay_id,
       death_28d,
       deathtime,
       t0_time
FROM data_extract_crrt.outcomes_28d_renal_v1
")

# 读取 subgroup
df_subgroup <- dbGetQuery(con,"
SELECT *
FROM data_extract_crrt.subgroup_flags_v1
")

df <- df %>%
  left_join(df_outcome, by="stay_id") %>%
  left_join(df_subgroup, by="stay_id")

# time-to-event
df <- df %>%
  mutate(
    time = as.numeric(
      difftime(deathtime,t0_time,units="days")
    ),
    time = pmin(time,28),
    event = ifelse(death_28d==1 & time<=28,1,0)
  )

# 需要分析的亚组
subgroups <- c(
  "oliguria_3grp",
  "ne_3grp",
  "mv_2grp",
  "lactate_2grp",
  "pf_3grp"
)

results <- list()

for (sg in subgroups) {

  levels_sg <- unique(df[[sg]])

  for (lv in levels_sg) {

    data_sub <- df %>%
      filter(.data[[sg]] == lv)

    if(nrow(data_sub) < 50) next

    model <- coxph(
      Surv(time,event) ~ strategy,
      data = data_sub,
      weights = ipcw_trunc
    )

    est <- broom::tidy(model)

    est$subgroup <- sg
    est$level <- lv

    results[[paste0(sg,lv)]] <- est
  }
}

forest_data <- bind_rows(results)

# forest plot
ggplot(forest_data,
       aes(x = estimate,
           y = paste(subgroup,level))) +
  geom_point() +
  geom_errorbarh(
    aes(xmin = conf.low,
        xmax = conf.high),
    height = 0.2
  ) +
  geom_vline(xintercept = 1,
             linetype = "dashed") +
  theme_minimal() +
  labs(
    x = "Hazard Ratio",
    y = "Subgroup"
  )

ggsave("fig_subgroup_forest_plot.png",
       width = 6,
       height = 6)
fig_subgroup_forest_plot.png
