# R 分析数据来源说明

## 结论：**R 为连库（直连 PostgreSQL），非导出文件**

- **01_prepare_ccw_dataset.R**：使用 `DBI` + `RPostgres::Postgres()` 连接数据库（`dbname = "mimic"`），通过 `dbGetQuery(con, "SELECT ...")` 从 `data_extract_crrt.ccw_clone_long_0_24h_1h_v2` 和 `data_extract_crrt.cohort_baseline_v1` 拉数，合并后得到分析用 long 数据。
- **02_compute_ipcw.R**：在 01 产出的数据上拟合删失模型、计算 IPCW（无读文件；需在 01 或 02 末尾将带权重的数据保存为 `analysis_data_ccw.rds`）。
- **03 / 04 / 05 / 06 / 07**：主数据来自 **readRDS("analysis_data_ccw.rds")**；其中 04/05/06/07 会再次 **连库** 用 `dbGetQuery(con, ...)` 查询 `data_extract_crrt.outcomes_28d_renal_v1` 等表做结局合并或作图。

因此：**R 端是连库模式**。需保证本机 R 能连上同一 PostgreSQL（database `mimic`，schema `data_extract_crrt`）；若需 host/port/user/password，在 `dbConnect()` 中按需填写。

## 01 与 SQL 表列名对应（cohort_baseline_v1）

05 脚本产出的 `cohort_baseline_v1` 列名与 01 中部分 SELECT 不一致，需在 01 里用下面列名（或 05 侧用 AS 别名）：

| 01 当前查询列名           | 05 实际产出列名 |
|--------------------------|-----------------|
| sex                      | **gender**      |
| charlson_comorbidity_index | **cci**      |
| pfratio                  | **pf_ratio**    |
| scr_baseline_win         | **scr**         |
| potassium                | **k**           |

01 已按上表改为 05 列名，并增加 `clone_id` 与 `saveRDS`，见 analysis_1/01_prepare_ccw_dataset.R。
