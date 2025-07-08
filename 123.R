# 安装必要包（如未安装）
if (!require("table1")) install.packages("table1")
if (!require("tableone")) install.packages("tableone")

library(table1)
library(tableone)

# 设置工作目录到数据文件所在位置
setwd("/Users/liangmenglin/Desktop/126case/")

# 读取数据
aa <- read.csv("126case.csv")

# 批量转因子
for (i in names(aa)[c(1, 3, 4, 5, 6, 7, 8, 9, 10, 
                      11, 12, 13, 14, 15, 51)]) {
  aa[, i] <- as.factor(aa[, i])
}

# 批量转数值
vars_to_convert <- c("Age", "WBC", "NEPER", "LYMPH", "HGB", "PLT", "CRP", "PCT", "PT", "INR", "APTT", "TBIL", "BUN", "CREA", "NTproBNP",
                     "TNI", "Lac", "OIPaO2_FiO2", "SOFA", "GCS",
                     "HR", "RR", "BP", "T",
                     "CD3_PER", "CD3_CD4_PER", "CD3_CD8_PER",
                     "CD3_CD4__CD3_CD8", "CD3",
                     "CD3_CD4", "CD3_CD8", "CD3_CD16__CD56_PER",
                     "CD3_CD16__CD56", "BCD19PER",
                     "BCD19", "N_CT", "ORF1AB_CT")
aa[, vars_to_convert] <- apply(aa[, vars_to_convert], 2, as.numeric)

# 修改变量名称
aa$survive_die <- factor(aa$survive_die, levels=c(1,0), labels=c("Death", "Alive"))
aa$gender <- factor(aa$gender, levels=c(1,2), labels=c("Male", "Female"))
aa$HT <- factor(aa$HT, levels=c(1,0), labels=c("Yes", "No"))
aa$T2DM <- factor(aa$T2DM, levels=c(0,1), labels=c("No", "Yes"))
aa$PE <- factor(aa$PE, levels=c(0,1), labels=c("No", "Yes"))
aa$CI <- factor(aa$CI, levels=c(0,1), labels=c("No", "Yes"))
aa$MI <- factor(aa$MI, levels=c(0, 1), labels=c("No", "Yes"))
aa$HAEM <- factor(aa$HAEM, levels=c(0, 1), labels=c("No", "Yes"))
aa$HyperT <- factor(aa$HyperT, levels=c(0, 1), labels=c("No", "Yes"))
aa$CA <- factor(aa$CA, levels=c(0, 1), labels=c("No", "Yes"))
aa$LTUH <- factor(aa$LTUH, levels=c(0, 1), labels=c("No", "Yes"))
aa$CRD <- factor(aa$CRD, levels=c(0, 1), labels=c("No", "Yes"))
aa$CHF <- factor(aa$CHF, levels=c(0, 1), labels=c("No", "Yes"))
aa$CLD <- factor(aa$CLD, levels=c(0, 1), labels=c("No", "Yes"))
aa$CKD <- factor(aa$CKD, levels=c(0, 1), labels=c("No", "Yes"))

# 定义变量列表
vars <- c("gender", "Age", "HT", "T2DM", "PE", "CI", "MI", "HAEM", "HyperT", "CA", "LTUH", "CRD", "CHF", "CLD", "CKD",
          "WBC", "NEPER", "LYMPH", "HGB", "PLT", "CRP", "PCT", "PT", "INR", "APTT", "TBIL",
          "BUN", "CREA", "NTproBNP", "TNI", "Lac", "OIPaO2_FiO2", "SOFA", "GCS", 
          "HR", "RR", "T", "CD3_PER", "CD3_CD4_PER", "CD3_CD8_PER", "CD3_CD4__CD3_CD8", "CD3",
          "CD3_CD4", "CD3_CD8", "CD3_CD16__CD56_PER", "CD3_CD16__CD56", 
          "BCD19PER", "BCD19", "N_CT", "ORF1AB_CT")

# 定义分类变量
catVars <- c("gender", "HT", "T2DM", "PE", "CI", "MI", "HAEM", "HyperT", "CA", "LTUH", "CRD", "CHF", "CLD", "CKD")

# 创建tableone对象
tab1 <- CreateTableOne(vars = vars, strata = "survive_die", data = aa, factorVars = catVars)

# 打印结果
print(tab1, showAllLevels = TRUE, formatOptions = list(big.mark = ","))

# 转换为矩阵格式并保存为CSV
tab1_matrix <- print(tab1, showAllLevels = TRUE, formatOptions = list(big.mark = ","), 
                     printToggle = FALSE, noSpaces = TRUE)

# 保存为CSV
write.csv(tab1_matrix, file = "table1_result.csv", row.names = TRUE)
cat("三线表已保存为 table1_result.csv\n")

# 同时生成带P值的table1格式
# P值函数
pvalue <- function(x, ...) {
  y <- unlist(x)
  g <- factor(rep(1:length(x), times=sapply(x, length)))
  
  if (is.numeric(y)) {
    p <- tryCatch({
      shapiro_p <- shapiro.test(y)$p.value
      if (!is.na(shapiro_p) && shapiro_p > 0.05) {
        t.test(y ~ g)$p.value
      } else {
        wilcox.test(y ~ g, paired = FALSE)$p.value
      }
    }, error = function(e) NA)
  } else {
    p <- tryCatch(fisher.test(table(y, g))$p.value, error = function(e) NA)
  }
  
  if (is.na(p)) {
    c("", "")
  } else {
    c("", sub("<", "&lt;", format.pval(p, digits=3, eps=0.001)))
  }
}

# 生成table1格式的三线表
result <- table1(~ gender + Age + HT + T2DM + PE + CI + MI + HAEM + HyperT + CA + LTUH + CRD + CHF + CLD + CKD +
                   WBC + NEPER + LYMPH + HGB + PLT + CRP + PCT + PT + INR + APTT + TBIL +
                   BUN + CREA + NTproBNP + TNI + Lac + OIPaO2_FiO2 + SOFA + GCS + 
                   HR + RR + T + CD3_PER + CD3_CD4_PER + CD3_CD8_PER + CD3_CD4__CD3_CD8 + CD3 +
                   CD3_CD4 + CD3_CD8 + CD3_CD16__CD56_PER + CD3_CD16__CD56 + 
                   BCD19PER + BCD19 + N_CT + ORF1AB_CT | survive_die, 
                 data=aa, 
                 topclass="Rtable1-zebra", 
                 render.continuous=c(.="Mean ± SD"), 
                 overall=FALSE, 
                 extra.col=list(`P-value`=pvalue))

# 保存为HTML文件
cat(as.character(result), file="table1_result.html")
cat("三线表HTML版本已保存为 table1_result.html\n") 

