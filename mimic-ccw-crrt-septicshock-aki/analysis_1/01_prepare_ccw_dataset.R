#### 1）Run in RStudio: open project at repo root; 优先读 data_dir 下 CSV，否则连库####
config_path <- NULL
if (file.exists("analysis_1/config.R")) config_path <- "analysis_1/config.R"
if (is.null(config_path) && file.exists("config.R")) config_path <- "config.R"
if (is.null(config_path) && file.exists("../analysis_1/config.R")) config_path <- "../analysis_1/config.R"  # wd 在 sql 时
if (is.null(config_path)) {
  for (root in c("/Users/liangmenglin/Desktop/new-test",
                 "/Users/liangmenglin/Cursor/medical-data-analysis/mimic-ccw-crrt-septicshock-aki")) {
    p <- file.path(root, "analysis_1", "config.R")
    if (file.exists(p)) { config_path <- p; break }
  }
}
if (is.null(config_path)) stop("Cannot find config.R. Set wd to project root or analysis_1.")
source(config_path)
library(dplyr)

# CSV 路径：优先 data_dir 下默认名，其次 proj_root/sql 下带日期导出
path_clone   <- file.path(data_dir, "ccw_clone_long_0_24h_1h_v2.csv")
path_baseline <- file.path(data_dir, "cohort_baseline_v1.csv")
if (!file.exists(path_clone)) path_clone <- file.path(proj_root, "sql", "08_ccw_clone_censor_1h_with_admin.csv")
if (!file.exists(path_baseline)) path_baseline <- file.path(proj_root, "sql", "05_baseline_table1_v1_20260305.csv")

if (file.exists(path_clone) && file.exists(path_baseline)) {
  # 优先：从 CSV 拼表，不连库
  df_clone   <- read.csv(path_clone, stringsAsFactors = FALSE)
  df_baseline <- read.csv(path_baseline, stringsAsFactors = FALSE)
  df_baseline <- df_baseline %>%
    select(stay_id, age, gender, weight_kg, cci, ne_eq_baseline, mv_baseline,
           pf_ratio, lactate, ph, scr, k)
} else {
  # 否则：连库（需 .Renviron 里 MIMIC_USER、MIMIC_PASSWORD）；失败则提示放 CSV
  if (!file.exists(path_clone)) message("未找到: ", path_clone)
  if (!file.exists(path_baseline)) message("未找到: ", path_baseline)
  library(DBI)
  con <- tryCatch(get_con(), error = function(e) {
    stop("连库失败 (未提供密码?)。请二选一：\n",
         "  1) 把 ccw_clone_long_0_24h_1h_v2.csv 与 cohort_baseline_v1.csv 放到\n      ", data_dir, "\n",
         "  2) 在 ~/.Renviron 或项目根目录 .Renviron 中设置 MIMIC_USER=... 和 MIMIC_PASSWORD=...，然后 Session -> Restart R\n",
         "原错误: ", conditionMessage(e), call. = FALSE)
  })
  df_clone <- dbGetQuery(con, "SELECT * FROM data_extract_crrt.ccw_clone_long_0_24h_1h_v2")
  df_baseline <- dbGetQuery(con, "
    SELECT stay_id, age, gender, weight_kg, cci, ne_eq_baseline, mv_baseline,
           pf_ratio, lactate, ph, scr, k
    FROM data_extract_crrt.cohort_baseline_v1
  ")
}

# 拼表
df <- df_clone %>%
  left_join(df_baseline, by = "stay_id") %>%
  mutate(clone_id = paste(stay_id, strategy, sep = "_")) %>%
  rename(
    sex = gender,
    charlson_comorbidity_index = cci,
    pfratio = pf_ratio,
    scr_baseline_win = scr,
    potassium = k
  ) %>%
  filter(at_risk_after_k == 1)

saveRDS(df, path_rds)
#### 2）读取df####
df <- readRDS("/Users/liangmenglin/Desktop/new-test/analysis_1/data/analysis_data_ccw.rds")
# 行数、列数
nrow(df)
ncol(df)

# 列名
names(df)

# 前几行
head(df)

# 用 View 在 RStudio 里像表格一样看（RStudio 里才有）
View(df)
