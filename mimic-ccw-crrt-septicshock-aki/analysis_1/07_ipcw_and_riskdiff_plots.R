library(dplyr)
library(tidyr)
library(ggplot2)
library(survival)
library(DBI)

# -----------------------------
# 0) Inputs
# -----------------------------
# Requires: analysis_data_ccw.rds created by 02_compute_ipcw_weights.R
df_long <- readRDS("analysis_data_ccw.rds")

# Optional: adjust DB connection if needed
con <- dbConnect(RPostgres::Postgres(), dbname = "mimic")

# Outcomes (07)
df_outcome <- dbGetQuery(con, "
SELECT stay_id,
       death_28d,
       deathtime,
       t0_time
FROM data_extract_crrt.outcomes_28d_renal_v1
")

# -----------------------------
# 1) IPCW distribution + truncation comparison
# -----------------------------
# Use one row per clone-hour; distribution diagnostics usually okay at this granularity.
# If you prefer per-clone summary weights at hour 24 only, see NOTE at bottom.

df_w <- df_long %>%
  select(ipcw, ipcw_trunc) %>%
  filter(!is.na(ipcw), !is.na(ipcw_trunc))

# 1.1 Histogram (truncated)
p_hist_trunc <- ggplot(df_w, aes(x = ipcw_trunc)) +
  geom_histogram(bins = 120) +
  theme_minimal() +
  labs(
    title = "Stabilized IPCW distribution (truncated)",
    x = "IPCW (truncated at 1%/99%)",
    y = "Count"
  )
ggsave("fig_ipcw_hist_truncated.png", p_hist_trunc, width = 7, height = 4.5)

# 1.2 Density comparison (raw vs truncated) on log scale (helps see tails)
df_w_long <- df_w %>%
  pivot_longer(cols = c(ipcw, ipcw_trunc),
               names_to = "type",
               values_to = "weight")

p_dens <- ggplot(df_w_long, aes(x = weight)) +
  geom_density() +
  scale_x_log10() +
  facet_wrap(~type, ncol = 1, scales = "free_y") +
  theme_minimal() +
  labs(
    title = "IPCW density (raw vs truncated, log scale)",
    x = "Weight (log10 scale)",
    y = "Density"
  )
ggsave("fig_ipcw_density_raw_vs_trunc_log.png", p_dens, width = 7, height = 6)

# 1.3 ECDF comparison (raw vs truncated)
p_ecdf <- ggplot(df_w_long, aes(x = weight)) +
  stat_ecdf() +
  scale_x_log10() +
  facet_wrap(~type, ncol = 1) +
  theme_minimal() +
  labs(
    title = "IPCW ECDF (raw vs truncated, log scale)",
    x = "Weight (log10 scale)",
    y = "ECDF"
  )
ggsave("fig_ipcw_ecdf_raw_vs_trunc_log.png", p_ecdf, width = 7, height = 6)

# 1.4 Quick numeric diagnostics
diag_tbl <- df_w %>%
  summarise(
    n = n(),
    mean_raw = mean(ipcw),
    sd_raw = sd(ipcw),
    p50_raw = quantile(ipcw, 0.50),
    p95_raw = quantile(ipcw, 0.95),
    p99_raw = quantile(ipcw, 0.99),
    max_raw = max(ipcw),
    mean_trunc = mean(ipcw_trunc),
    sd_trunc = sd(ipcw_trunc),
    p50_trunc = quantile(ipcw_trunc, 0.50),
    p95_trunc = quantile(ipcw_trunc, 0.95),
    p99_trunc = quantile(ipcw_trunc, 0.99),
    max_trunc = max(ipcw_trunc)
  )
write.csv(diag_tbl, "ipcw_weight_diagnostics_summary.csv", row.names = FALSE)

# -----------------------------
# 2) Risk difference plot (0–28d)
#    Using weighted Kaplan–Meier (by strategy) then derive:
#    risk(t) = 1 - S(t)
#    RD(t) = risk_A(t) - risk_B(t)
# -----------------------------
df_surv <- df_long %>%
  # reduce to one row per clone for survival analysis inputs
  # keep the last available weight in [0,24h] as the clone weight for survival estimators
  group_by(stay_id, strategy) %>%
  summarise(
    ipcw_trunc_last = last(ipcw_trunc),
    .groups = "drop"
  ) %>%
  left_join(df_outcome, by = "stay_id") %>%
  mutate(
    time = as.numeric(difftime(deathtime, t0_time, units = "days")),
    time = pmin(time, 28),
    event = ifelse(death_28d == 1 & time <= 28, 1, 0)
  )

# Weighted KM by strategy
fit <- survfit(
  Surv(time, event) ~ strategy,
  data = df_surv,
  weights = ipcw_trunc_last
)

# Evaluate on a time grid
time_grid <- seq(0, 28, by = 0.5)
sf <- summary(fit, times = time_grid)

# Tidy survival estimates
# sf$strata looks like "strategy=A" etc; adapt if your strategy labels differ.
surv_df <- data.frame(
  time = sf$time,
  surv = sf$surv,
  strata = sf$strata
) %>%
  mutate(
    strategy = sub(".*=", "", strata),
    risk = 1 - surv
  ) %>%
  select(time, strategy, risk)

# Wide then compute RD: risk(early) - risk(no_early)
# If your strategy labels are different, change the two names below.
wide <- surv_df %>%
  pivot_wider(names_from = strategy, values_from = risk)

# Try to auto-detect two arms (first two columns after time)
arm_cols <- setdiff(names(wide), "time")
if (length(arm_cols) < 2) stop("Could not detect two strategy arms from survfit strata.")
arm1 <- arm_cols[1]
arm2 <- arm_cols[2]

rd_df <- wide %>%
  mutate(
    rd = .data[[arm1]] - .data[[arm2]],
    arm_contrast = paste0(arm1, " - ", arm2)
  ) %>%
  select(time, rd, arm_contrast)

p_rd <- ggplot(rd_df, aes(x = time, y = rd)) +
  geom_line() +
  geom_hline(yintercept = 0, linetype = "dashed") +
  theme_minimal() +
  labs(
    title = paste0("Risk difference over time (", unique(rd_df$arm_contrast), ")"),
    x = "Days since t0",
    y = "Risk difference (cumulative mortality)"
  )
ggsave("fig_risk_difference_curve_0_28d.png", p_rd, width = 7, height = 4.5)

# Also write the RD curve values for tables/supplement
write.csv(rd_df, "risk_difference_curve_0_28d.csv", row.names = FALSE)

# -----------------------------
# NOTE (optional):
# If you want weight distributions at a specific hour (e.g., hour_index==23 only),
# replace df_w with:
# df_w <- df_long %>% filter(hour_index==23) %>% select(ipcw, ipcw_trunc) %>% drop_na()
# -----------------------------
