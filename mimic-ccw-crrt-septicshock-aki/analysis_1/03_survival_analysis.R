library(dplyr)
library(ggplot2)

# 读取权重数据
df <- readRDS("analysis_data_ccw.rds")

# -----------------------------
# 1 权重分布
# -----------------------------

summary(df$ipcw)
summary(df$ipcw_trunc)

ggplot(df, aes(x = ipcw_trunc)) +
  geom_histogram(bins = 100) +
  theme_minimal() +
  labs(
    title = "Distribution of stabilized IPCW",
    x = "IPCW (truncated)",
    y = "Count"
  )

ggsave("fig_weight_distribution.png", width = 6, height = 4)

# -----------------------------
# 2 权重截断前后对比
# -----------------------------

df_long <- df %>%
  select(ipcw, ipcw_trunc) %>%
  tidyr::pivot_longer(cols = everything(),
                      names_to = "type",
                      values_to = "weight")

ggplot(df_long, aes(x = weight)) +
  geom_histogram(bins = 100) +
  facet_wrap(~type, scales = "free") +
  theme_minimal()

ggsave("fig_weight_truncation.png", width = 8, height = 4)

# -----------------------------
# 3 每小时删失概率
# -----------------------------

censor_by_hour <- df %>%
  group_by(hour_index) %>%
  summarise(
    censor_rate = mean(censor_k_total, na.rm = TRUE),
    n = n()
  )

ggplot(censor_by_hour,
       aes(x = hour_index, y = censor_rate)) +
  geom_line() +
  geom_point() +
  theme_minimal() +
  labs(
    title = "Censoring probability by hour",
    x = "Hour since t0",
    y = "Censoring probability"
  )

ggsave("fig_censor_probability_by_hour.png", width = 6, height = 4)

# -----------------------------
# 4 strategy 分层删失概率
# -----------------------------

censor_strategy <- df %>%
  group_by(hour_index, strategy) %>%
  summarise(
    censor_rate = mean(censor_k_total, na.rm = TRUE)
  )

ggplot(censor_strategy,
       aes(x = hour_index,
           y = censor_rate,
           color = strategy)) +
  geom_line() +
  theme_minimal() +
  labs(
    title = "Censor probability by strategy",
    x = "Hour",
    y = "Censor probability"
  )

ggsave("fig_censor_by_strategy.png", width = 6, height = 4)
