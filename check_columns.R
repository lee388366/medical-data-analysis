# 定义所有可用的列名
available_columns <- c(
  "gender", "Age", "HT", "T2DM", "PE", "CI", "MI", "HAEM", "HyperT",
  "CA", "LTUH", "CRD", "CHF", "CLD", "CKD", "WBC", "NEPER", "LYMPH",
  "HGB", "PLT", "CRP", "PCT", "PT", "INR", "APTT", "TBIL", "BUN",
  "CREA", "NTproBNP", "TNI", "Lac", "PaO2_FiO2", "SOFA", "GCS",
  "HR", "RR", "BP", "T", "CD3_PER", "CD3_CD4_PER", "CD3_CD8_PER",
  "CD3_CD4__CD3_CD8", "CD3", "CD3_CD4", "CD3_CD8", "CD3_CD16__CD56_PER",
  "CD3_CD16__CD56", "BCD19PER", "BCD19", "N_CT", "ORF1AB_CT"
)

# 示例：设置响应变量（可以根据需要修改）
response_var <- "SOFA"  # 例如使用SOFA评分作为响应变量

# 假设train_data已经加载，这里是检查代码
# 检查响应变量是否存在于训练集中
if (!response_var %in% colnames(train_data)) {
  stop(paste("响应变量", response_var, "不存在于训练数据中"))
} else {
  cat("响应变量", response_var, "存在于训练数据中\n")
}

# 额外的检查：确保所有预期的列都存在
check_columns <- function(data, required_cols) {
  missing_cols <- setdiff(required_cols, colnames(data))
  if (length(missing_cols) > 0) {
    warning(paste("以下列缺失:", paste(missing_cols, collapse = ", ")))
    return(FALSE)
  }
  return(TRUE)
}

# 使用示例
# check_columns(train_data, available_columns)

# 打印数据集中实际存在的列
print("训练数据中的列名:")
print(colnames(train_data))

# 检查多个可能的响应变量
potential_response_vars <- c("SOFA", "GCS", "Lac", "CRP")
for (var in potential_response_vars) {
  if (var %in% colnames(train_data)) {
    cat(var, "可以作为响应变量\n")
  }
} 