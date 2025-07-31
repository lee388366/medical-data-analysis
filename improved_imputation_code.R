#### 改进版医学数据缺失值插补代码 ####
# 作者：改进版本
# 日期：2024年
# 说明：修正了原代码中多重插补方法的问题

#### 安装并加载必要包 ####
# install.packages(c("mice", "readr", "dplyr", "VIM", "pool"))
suppressMessages({
  library(readr)
  library(mice)
  library(dplyr)
  library(VIM)
  library(broom)  # 用于整理模型结果
})

#### 1. 读取数据（增加错误处理） ####
file_path <- "~/Desktop/通气数据.csv"
if (!file.exists(file_path)) {
  stop("数据文件不存在：", file_path)
}

df <- read_csv(file_path, locale = locale(encoding = "UTF-8"))
cat("数据维度：", dim(df), "\n")

#### 2. 清洗分类变量 ####
df <- df %>%
  mutate(
    FZ = case_when(
      FZ == "简易" ~ 1, 
      FZ == "10" ~ 2, 
      TRUE ~ as.numeric(FZ)
    ),
    ROSC = case_when(
      ROSC == "是" ~ 1, 
      ROSC == "否" ~ 0, 
      TRUE ~ as.numeric(ROSC)
    )
  )

#### 3. 增强的缺失数据分析 ####
missing_rate <- colMeans(is.na(df))
cat("缺失率概况：\n")
print(round(sort(missing_rate[missing_rate > 0], decreasing = TRUE), 3))

# 缺失模式可视化
md.pattern(df, plot = TRUE)

# 缺失值分布图
if (require(VIM, quietly = TRUE)) {
  aggr_plot <- aggr(df, col = c('navyblue', 'red'), 
                    numbers = TRUE, sortVars = TRUE)
}

#### 4. 智能变量选择 ####
# 排除不应插补的变量类型
exclude_vars <- c("date", "id", "patient_id")  # 可根据实际情况调整
exclude_pattern <- paste(exclude_vars, collapse = "|")

vars_for_impute <- names(df)[
  missing_rate > 0 & 
  missing_rate < 0.8 & 
  !grepl(exclude_pattern, names(df), ignore.case = TRUE)
]

cat("选择插补的变量数量：", length(vars_for_impute), "\n")
cat("变量列表：", paste(vars_for_impute, collapse = ", "), "\n")

df4imp <- df[, vars_for_impute]

#### 5. 改进的多重插补 ####
# 增加迭代次数，添加收敛检查
imp <- mice(df4imp, 
            m = 5,           # 插补数据集数量
            maxit = 20,      # 增加迭代次数
            seed = 42, 
            printFlag = TRUE,
            method = 'pmm')  # 使用预测均值匹配方法

# 检查收敛性
plot(imp, main = "MICE收敛性检查")

# 检查插补质量
densityplot(imp, main = "插补值密度分布")

#### 6. 定义非负变量（基于医学常识） ####
non_negative_vars <- c(
  "BCO2", "BIP1", "BIP2", "BNIP1", "BNIP2", "BNIP3", "BCI", "BPVPI", "BASO2",
  "VFAHCO3", "VFVPCO2", "VFVPO2", "VFVHCO3", "VFVSO2", "VFVHb", "VFVGlu", "VFVK",
  "CBP1", "CBP2", "CBP3", "CCVP", "CETCO2", "CIP1", "CIP2", "CAPH", "CAPCO2",
  "CAPO2", "CAHCO3", "CASO2", "CAHb", "CAGlu", "CAK", "CVPH", "CVPCO2", "CVPO2",
  "CVHCO3", "CVSO2", "CVHb", "CVGlu", "CVK", "VentBP1", "VentBP2", "VentBP3",
  "VentCVP", "VentIP1", "VentIP2", "Ventpeak", "VentPmean", "VentAPH",
  "VentAPCO2", "VentAPO2", "VentAHCO3", "VentASO2", "VentAHb", "VentAGlu", "VentAK",
  "VentVPH", "VentVPCO2", "VentVPO2", "VentVHCO3", "VentVSO2", "VentVHb", "VentVGlu",
  "VentVK", "dose", "ROSCBP1", "ROSCBP2", "ROSCBP3", "ROSCCVP", "ROSCETCO2",
  "ROSCIP1", "ROSCIP2", "ROSCIP3", "ROSCPpeak", "ROSCPmean", "ROSCCO", "ROSCCI",
  "ROSCPVPI", "ROSCSVRI", "ROSCAPH", "ROSCAPCO2", "ROSCAPO2", "ROSCHCO3", 
  "ROSCASO2", "ROSCAHb", "ROSCAGlu", "ROSCAK", "ROSCVPH", "ROSCVPCO2", 
  "ROSCVPO2", "ROSCVHCO3", "ROSCVSO2", "ROSCVHb", "ROSCVGlu", "ROSCVK"
)

#### 7. 正确的多重插补处理方法 ####
# 方法A：如果需要进行统计分析，应该使用池化方法
# 示例：假设我们要做回归分析
pool_analysis_example <- function(imp_object, outcome_var) {
  # 对每个插补数据集拟合模型
  fit <- with(imp_object, lm(get(outcome_var) ~ .))
  # 池化结果
  pooled <- pool(fit)
  return(summary(pooled))
}

# 方法B：如果必须输出单一数据集（不推荐但有时必要）
# 使用更合理的选择标准：最小化插补方差
if (TRUE) {  # 设置为TRUE如果需要单一数据集
  
  # 获取所有插补数据集
  complete_datasets <- lapply(1:5, function(i) {
    dataset <- complete(imp, i)
    
    # 对每个数据集应用非负约束
    for (col in intersect(non_negative_vars, names(dataset))) {
      dataset[[col]] <- pmax(dataset[[col]], 0)
    }
    
    return(dataset)
  })
  
  # 计算每个变量在所有插补中的方差
  var_scores <- sapply(complete_datasets, function(df) {
    # 计算数值变量的总方差
    numeric_vars <- sapply(df, is.numeric)
    if (sum(numeric_vars) > 0) {
      sum(sapply(df[numeric_vars], var, na.rm = TRUE), na.rm = TRUE)
    } else {
      0
    }
  })
  
  # 选择方差最接近中位数的数据集（更稳健的选择）
  median_var <- median(var_scores)
  best_dataset <- complete_datasets[[which.min(abs(var_scores - median_var))]]
  
  cat("选择的数据集编号：", which.min(abs(var_scores - median_var)), "\n")
  cat("各数据集方差分数：", round(var_scores, 2), "\n")
}

#### 8. 数据质量检查 ####
cat("插补后数据质量检查：\n")
cat("- 数据维度：", dim(best_dataset), "\n")
cat("- 缺失值数量：", sum(is.na(best_dataset)), "\n")
cat("- 负值检查（应为0）：\n")

for (col in intersect(non_negative_vars, names(best_dataset))) {
  neg_count <- sum(best_dataset[[col]] < 0, na.rm = TRUE)
  if (neg_count > 0) {
    cat("  ", col, ":", neg_count, "个负值\n")
  }
}

#### 9. 导出数据 ####
output_path <- "~/Desktop/插补后通气数据_改进版.csv"
write.csv(best_dataset, output_path, 
          row.names = FALSE, 
          fileEncoding = "UTF-8")

cat("数据已保存至：", output_path, "\n")

#### 10. 生成插补报告 ####
cat("\n=== 插补报告 ===\n")
cat("原始数据变量数：", ncol(df), "\n")
cat("插补变量数：", length(vars_for_impute), "\n")
cat("插补方法：MICE (PMM)\n")
cat("插补数据集数：5\n")
cat("迭代次数：20\n")
cat("约束处理：", length(intersect(non_negative_vars, names(best_dataset))), "个变量应用非负约束\n")

# 简要统计摘要
summary(best_dataset[1:min(10, ncol(best_dataset))])  # 显示前10个变量的摘要

#### 11. 可选：保存所有插补数据集（推荐用于敏感性分析） ####
save_all_datasets <- FALSE  # 设置为TRUE如果需要
if (save_all_datasets) {
  for (i in 1:5) {
    dataset_i <- complete_datasets[[i]]
    write.csv(dataset_i, 
              paste0("~/Desktop/插补数据集_", i, ".csv"),
              row.names = FALSE, 
              fileEncoding = "UTF-8")
  }
  cat("所有5个插补数据集已保存\n")
}

cat("\n插补过程完成！\n")