#### 改进版医学数据缺失值插补代码 ####
# 可直接复制到R中运行

#### 安装并加载必要包 ####
# 如果包未安装，请先运行下面的安装命令
# install.packages(c("mice", "readr", "dplyr", "VIM"))

suppressWarnings(suppressMessages({
  library(readr)
  library(mice)
  library(dplyr)
  library(VIM)
}))

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

#### 3. 缺失数据分析 ####
missing_rate <- colMeans(is.na(df))
cat("缺失率概况：\n")
print(round(sort(missing_rate[missing_rate > 0], decreasing = TRUE), 3))

# 缺失模式可视化
md.pattern(df, plot = TRUE)

#### 4. 选择要插补的变量 ####
exclude_vars <- c("date", "id", "patient_id")
exclude_pattern <- paste(exclude_vars, collapse = "|")

vars_for_impute <- names(df)[
  missing_rate > 0 & 
  missing_rate < 0.8 & 
  !grepl(exclude_pattern, names(df), ignore.case = TRUE)
]

cat("选择插补的变量数量：", length(vars_for_impute), "\n")
df4imp <- df[, vars_for_impute]

#### 5. 多重插补（改进版） ####
imp <- mice(df4imp, 
            m = 5,           # 插补数据集数量
            maxit = 20,      # 增加迭代次数
            seed = 42, 
            printFlag = FALSE,  # 减少输出
            method = 'pmm')     # 预测均值匹配方法

# 检查收敛性
plot(imp, main = "MICE收敛性检查")

#### 6. 定义非负变量 ####
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

#### 7. 改进的数据集选择方法 ####
# 获取所有插补数据集并应用约束
complete_datasets <- lapply(1:5, function(i) {
  dataset <- complete(imp, i)
  
  # 应用非负约束
  for (col in intersect(non_negative_vars, names(dataset))) {
    dataset[[col]] <- pmax(dataset[[col]], 0)
  }
  
  return(dataset)
})

# 使用更合理的选择标准：选择方差最接近中位数的数据集
var_scores <- sapply(complete_datasets, function(df) {
  numeric_vars <- sapply(df, is.numeric)
  if (sum(numeric_vars) > 0) {
    sum(sapply(df[numeric_vars], var, na.rm = TRUE), na.rm = TRUE)
  } else {
    0
  }
})

median_var <- median(var_scores)
best_idx <- which.min(abs(var_scores - median_var))
best_dataset <- complete_datasets[[best_idx]]

cat("选择的数据集编号：", best_idx, "\n")
cat("各数据集方差分数：", round(var_scores, 2), "\n")

#### 8. 数据质量检查 ####
cat("\n=== 插补后数据质量检查 ===\n")
cat("- 数据维度：", dim(best_dataset), "\n")
cat("- 缺失值数量：", sum(is.na(best_dataset)), "\n")

# 检查是否还有负值
neg_check <- sapply(intersect(non_negative_vars, names(best_dataset)), function(col) {
  sum(best_dataset[[col]] < 0, na.rm = TRUE)
})
if (any(neg_check > 0)) {
  cat("- 警告：仍有负值的变量：\n")
  print(neg_check[neg_check > 0])
} else {
  cat("- ✓ 所有应为非负的变量都已处理\n")
}

#### 9. 导出数据 ####
output_path <- "~/Desktop/插补后通气数据_改进版.csv"
write.csv(best_dataset, output_path, 
          row.names = FALSE, 
          fileEncoding = "UTF-8")

cat("数据已保存至：", output_path, "\n")

#### 10. 生成简要报告 ####
cat("\n=== 插补报告 ===\n")
cat("原始数据变量数：", ncol(df), "\n")
cat("插补变量数：", length(vars_for_impute), "\n")
cat("插补方法：MICE (PMM)\n")
cat("插补数据集数：5\n")
cat("迭代次数：20\n")
cat("应用非负约束的变量数：", length(intersect(non_negative_vars, names(best_dataset))), "\n")

# 显示前几个变量的统计摘要
cat("\n前5个变量的统计摘要：\n")
print(summary(best_dataset[1:min(5, ncol(best_dataset))]))

cat("\n✓ 插补过程完成！\n")

#### 可选：如果需要正确的多重插补分析，使用以下代码 ####
# 注释：如果您要进行统计分析（如回归），应该使用下面的池化方法

# # 示例：对所有插补数据集进行回归分析并池化结果
# # 假设要分析ROSC作为结果变量
# if("ROSC" %in% names(df) && require(broom, quietly = TRUE)) {
#   
#   # 为池化分析创建插补对象（包含所有变量）
#   df_all <- df
#   for (col in intersect(non_negative_vars, names(df_all))) {
#     df_all[[col]] <- pmax(df_all[[col]], 0, na.rm = TRUE)
#   }
#   
#   imp_all <- mice(df_all[vars_for_impute], m = 5, maxit = 20, seed = 42, printFlag = FALSE)
#   
#   # 示例分析：简单回归
#   fit <- with(imp_all, glm(ROSC ~ ., family = binomial))
#   pooled_results <- pool(fit)
#   
#   cat("\n池化回归分析结果（示例）：\n")
#   print(summary(pooled_results))
# }