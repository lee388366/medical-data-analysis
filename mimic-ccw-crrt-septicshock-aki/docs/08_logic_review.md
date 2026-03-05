# SQL / Docs / R 逻辑梳理与问题清单

基于 [mimic-ccw-crrt-septicshock-aki](https://github.com/lee388366/medical-data-analysis/tree/main/mimic-ccw-crrt-septicshock-aki) 全量 SQL、docs、analysis_1 的梳理结果。

---

## 一、执行顺序（run_all.sql）

当前顺序：

1. 01 → 02 → 03（队列：101 → 201 → 301）
2. 05 → **09** → 06 → 08 → 07
3. 00（attrition，最后）

---

## 二、严重问题（会导致跑不通或结果错）

### 1. 06 不建 24h long，08 会报错

- **08** 依赖 `data_extract_crrt.ccw_long_0_24h_1h_v1`（见 08 第 27 行 `FROM … ccw_long_0_24h_1h_v1 l`）。
- **06_ccw_long_0_24h_dynamic_1h.sql** 实际只创建：
  - `ccw_long_0_12h_1h_v1`（0..11h）
  - `ccw_long_0_36h_1h_v1`（0..35h）
- **没有**创建 `ccw_long_0_24h_1h_v1`，因此按 run_all 跑完 06 再跑 08 会报错：**relation "ccw_long_0_24h_1h_v1" does not exist**。

**结论**：06 文件名和 README 写的是 “24h dynamic”，但内容是 12h/36h 敏感性；主分析用的 24h long 缺失，必须补上（见下方修复建议）。

---

### 2. 09 与 05 重复，且未建 subgroup_flags_v1

- **09_subgroup_flags_v1.sql** 的注释和文件名都指向 “subgroup flags”，但脚本里：
  - `DROP/CREATE MATERIALIZED VIEW … cohort_baseline_v1`
  - 输出表为 **cohort_baseline_v1**，与 **05** 完全重复。
- 因此：
  - 运行 05 再运行 09 会**用 09 覆盖 05 的 baseline**（逻辑重复、易混淆）。
  - **data_extract_crrt.subgroup_flags_v1** 从未被创建，而 **docs/06_subgroup_analysis.md** 和 **docs/07_survival_analysis.md** 均假设存在 `subgroup_flags_v1`（09 产出）。

**结论**：09 应改为真正建 `subgroup_flags_v1`（基线亚组：oliguria、NE、MV、lactate、PF、aki_pathway 等），而不是再建一次 cohort_baseline_v1。

---

## 三、其他逻辑与一致性问题

### 3. run_all 未包含 00

- **00_attrition_counts_flow.sql** 依赖 101、201、301，用于做纳入排除流程图。
- run_all 里 00 在**最后**执行，顺序正确；但 README 的 “Project structure” 未列出 `00_attrition_counts_flow.sql`，容易让人以为没有 attrition 步骤。建议在 README 中补上 00。

### 4. README 与当前 sql 不一致

- README 中列出的 sql 为：01, 02, 03, 05, 06, 07, 08, run_all，未提 **09** 和 **00**。
- 实际仓库有：00, 01, 02, 03, 05, 06, 07, 08, 09, run_all。建议 README 与 run_all 一致，并区分“主流程”与“可选/敏感性”。

### 5. 07 产出表名与文档

- 07 产出：`data_extract_crrt.outcomes_28d_renal_v1`（含 death_7d/28d、renal_recovery_28d_scr 等）。
- docs/07_survival_analysis.md 写的是 “08 clone–censor dataset + 07 outcomes table”，未写具体表名；若在 R 里写死表名，需与 07 一致（outcomes_28d_renal_v1）。

### 6. R 脚本尚未实现

- **analysis_1/** 下已有 R 脚本：01_prepare_ccw_dataset.R、02_compute_ipcw.R、03_survival_analysis.R、04__survival_analysis.R、05_rmst_rmtl_analysis.R、06_subgroup_forest_plot.R、07_ipcw_and_riskdiff_plots.R 等，依赖 08/07/05/09 产出的表（ccw_clone_long_0_24h_1h_v2、outcomes_28d_renal_v1、cohort_baseline_v1、subgroup_flags_v1）。08 无 clone_id 列，R 里需用 stay_id + strategy 生成克隆标识。

### 7. 03 与 00 的 RRT 判定

- 03 排除 pre-t0 RRT 使用：`(r.dialysis_present = 1 OR r.dialysis_active = 1)`（未包 COALESCE）。
- 00 中为：`(COALESCE(r.dialysis_present, 0) = 1 OR COALESCE(r.dialysis_active, 0) = 1)`。
- 若 MIMIC 中 NULL 表示“未记录”，建议 03 与 00 统一用 COALESCE，避免口径不一致。

---

## 四、修复建议汇总

| 优先级 | 问题 | 建议 |
|--------|------|------|
| P0 | 06 不建 24h long，08 报错 | 在 06 中增加创建 **ccw_long_0_24h_1h_v1**（generate_series 0..23，与 12h/36h 同结构）；或将 06 拆成 06_main（24h）+ 06_grace（12h/36h），run_all 先跑 06_main 再 08。 |
| P0 | 09 建的是 baseline 不是 subgroup_flags | 用真正的 subgroup_flags 逻辑重写 09：读 301 + cohort_baseline_v1 + urine_output + kdigo_stages，产出 **subgroup_flags_v1**（oliguria_3grp, ne_3grp, mv_2grp, lactate_2grp, pf_3grp, aki_pathway 等）。 |
| P1 | README 未列 00、09 | 更新 README 的 Project structure，列出 00_attrition、09_subgroup_flags，并注明 06 主产出为 24h long、12h/36h 为敏感性。 |
| P2 | 03 的 RRT 条件 | 03 中 r.dialysis_present / r.dialysis_active 建议加 COALESCE(..., 0)，与 00 一致。 |

---

## 五、当前无 R 文件

- analysis_1 下已有 R 脚本（01–07 等），与 SQL 表名一致；README 列出计划/实际脚本对应关系。
- 若要在本仓实现 01–05 的 R 流程，需从 08/07/505/909 导出 CSV 或连库，并约定：outcomes 表名 = outcomes_28d_renal_v1；clone 标识 = (stay_id, strategy)；IPCW 协变量见 docs_IPCW_covariate_checklist（若已同步到本仓）。

上述逻辑问题修好后，run_all 可完整跑通，且与 README、docs 及后续 R 分析一致。
