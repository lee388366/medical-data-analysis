#安装和加载包
install.packages("tableone")
install.packages("table1")
install.packages("languageserver")
library(tableone) 
library(table1) 
#清理运行环境
rm(list = ls())
#路径
setwd("/Users/liangmenglin/Desktop/126case/")
#读入数据
aa <- read.csv("126case.csv")
#查看数据前6行
head(aa)
#查看数据性质
str(aa)
#批量转因子
for (i in names(aa)[c(1, 3, 4, 5, 6, 7, 8, 9, 10, 
                      11, 12, 13, 14, 15, 51)]) {aa[, i] <- as.factor(aa[, i])}
#批量转数值
vars_to_convert <- c("Age", "WBC", "NEPER", "LYMPH", "HGB", "PLT", "CRP", "PCT", "PT", "INR", "APTT", "TBIL", "BUN", "CREA", "NTproBNP",
                     "TNI", "Lac", "OIPaO2_FiO2", "SOFA", "GCS",
                     "HR", "RR", "BP", "T",
                     "CD3_PER", "CD3_CD4_PER", "CD3_CD8_PER",
                     "CD3_CD4__CD3_CD8", "CD3",
                     "CD3_CD4", "CD3_CD8", "CD3_CD16__CD56_PER",
                     "CD3_CD16__CD56", "BCD19PER",
                     "BCD19", "N_CT")
aa[, vars_to_convert] <- apply(aa[, vars_to_convert], 2, as.numeric)

shapiro.test(aa$Age)#W = 0.91332, p-value = 3.085e-05，P＜0.05不服从正态分布
shapiro.test(aa$WBC)#W = 0.723, p-value = 2.711e-11，P＜0.05不服从正态分布
shapiro.test(aa$NEPER)#W = 0.81078, p-value = 5.279e-09，P＜0.05不服从正态分布
shapiro.test(aa$LYMPH)#W = 0.60472, p-value = 1.067e-13，P＜0.05不服从正态分布
shapiro.test(aa$HGB)#P＜0.05不服从正态分布
shapiro.test(aa$PLT)#W = 0.36586, p-value < 2.2e-16，P＜0.05不服从正态分
shapiro.test(aa$CRP)#W = 0.924, p-value = 0.0001006，P＜0.05不服从正态分布
shapiro.test(aa$PCT)#W = 0.36586, p-value < 2.2e-16，P＜0.05不服从正态分布
shapiro.test(aa$PT)#W = 0.36586, p-value < 2.2e-16，P＜0.05不服从正态分布
shapiro.test(aa$INR)#P＜0.05不服从正态分布
shapiro.test(aa$APTT)#P＜0.05不服从正态分布
shapiro.test(aa$TBIL)#P＜0.05不服从正态分布
shapiro.test(aa$BUN)#P＜0.05不服从正态分布
shapiro.test(aa$CREA)#P＜0.05不服从正态分布
shapiro.test(aa$NTproBNP)#P＜0.05服从正态分布
shapiro.test(aa$TNI)#P＜0.05不服从正态分布
shapiro.test(aa$Lac)#P＜0.05不服从正态分布
shapiro.test(aa$OIPaO2_FiO2)#P＜0.05不服从正态分布
shapiro.test(aa$SOFA)#P＜0.05不服从正态分布
shapiro.test(aa$GCS)#P＜0.05不服从正态分布
shapiro.test(aa$HR)#P＜0.05不服从正态分布
shapiro.test(aa$RR)#P＜0.05不服从正态分布
shapiro.test(aa$BP)#P＞0.05服从正态分布################
shapiro.test(aa$T)#P＜0.05不服从正态分布
shapiro.test(aa$CD3_PER)#P＞0.05服从正态分布################
shapiro.test(aa$CD3_CD4_PER)#P＞0.05服从正态分布#############
shapiro.test(aa$CD3_CD8_PER)#P＜0.05不服从正态分布
shapiro.test(aa$CD3_CD4__CD3_CD8)#P＜0.05不服从正态分布
shapiro.test(aa$CD3)#P＜0.05不服从正态分布
shapiro.test(aa$CD3_CD4)#P＜0.05不服从正态分布
shapiro.test(aa$CD3_CD8)#P＜0.05不服从正态分布
shapiro.test(aa$CD3_CD16__CD56_PER)#P＜0.05不服从正态分布
shapiro.test(aa$CD3_CD16__CD56)#P＜0.05不服从正态分布
shapiro.test(aa$BCD19PER)#P＜0.05不服从正态分布
shapiro.test(aa$BCD19)#P＜0.05不服从正态分布
shapiro.test(aa$N_CT)#P＞0.05服从正态分布#################
shapiro.test(aa$ORF1AB_CT)#P＞0.05服从正态分布#################
#批量连续变量正态性检验
variables <- colnames(aa)
normality_results <- data.frame(Variable = character(), 
                                W_Value = numeric(), 
                                P_Value = numeric(), 
                                stringsAsFactors = FALSE)
numeric_variables <- c("Age", "WBC", "NEPER", "LYMPH", "HGB", "PLT", "CRP", "PCT", 
                       "PT", "INR", "APTT", "TBIL", "BUN", "CREA", "NTproBNP",
                       "TNI", "Lac", "OIPaO2_FiO2", "SOFA", "GCS",
                       "HR", "RR", "BP", "T",
                       "CD3_PER", "CD3_CD4_PER", "CD3_CD8_PER",
                       "CD3_CD4__CD3_CD8", "CD3",
                       "CD3_CD4", "CD3_CD8", "CD3_CD16__CD56_PER",
                       "CD3_CD16__CD56", "BCD19PER",
                       "BCD19", "N_CT","ORF1AB_CT")
aa[, numeric_variables] <- apply(aa[, numeric_variables], 2, function(x) as.numeric(as.character(x)))
for (variable in variables) {
  if (is.numeric(aa[[variable]])) {
    result <- shapiro.test(aa[[variable]])
    normality_results <- rbind(normality_results, c(Variable = variable, 
                                                    W_Value = result$statistic, 
                                                    P_Value = result$p.value))
  }
}
print(normality_results)
# 修改变量名称
aa$survive_die <- factor(aa$survive_die, levels=c(1,0),labels=c("Death", "Alive"))
aa$gender <- factor(aa$gender, levels=c(1,2),labels=c("Male", "Female"))
aa$HT <- factor(aa$HT, levels=c(1,0),labels=c("Yes", "No"))
aa$T2DM <- factor(aa$T2DM, levels=c(0,1),labels=c("No", "Yes"))
aa$PE <- factor(aa$PE, levels=c(0,1),labels=c("No", "Yes"))
aa$CI <-factor(aa$CI, levels=c(0,1),labels=c("No", "Yes"))
aa$MI <- factor(aa$MI, levels=c(0, 1), labels=c("No", "Yes"))
aa$HAEM <- factor(aa$HAEM, levels=c(0, 1), labels=c("No", "Yes"))
aa$HyperT <- factor(aa$HyperT, levels=c(0, 1), labels=c("No", "Yes"))
aa$CA <- factor(aa$CA, levels=c(0, 1), labels=c("No", "Yes"))
aa$LTUH <- factor(aa$LTUH, levels=c(0, 1), labels=c("No", "Yes"))
aa$CRD <- factor(aa$CRD, levels=c(0, 1), labels=c("No", "Yes"))
aa$CHF <- factor(aa$CHF, levels=c(0, 1), labels=c("No", "Yes"))
aa$CLD <- factor(aa$CLD, levels=c(0, 1), labels=c("No", "Yes"))
aa$CKD <- factor(aa$CKD, levels=c(0, 1), labels=c("No", "Yes"))
#查看数据性质
str(aa)
# label()添加标签
label(aa$gender)           <- "Gender"
label(aa$Age)              <- "Age"
label(aa$HT)               <- "Hypertension"
label(aa$T2DM)             <- "Diabetes"
label(aa$PE)               <- "Pulmonary embolism"
label(aa$CI)               <- "Cerebral infarction"
label(aa$MI)               <- "Myocardial infarction"
label(aa$HAEM)             <- "Hemopathy"
label(aa$HyperT)           <- "Thyroid dysfunction"
label(aa$CA)               <- "Cancer"
label(aa$LTUH)             <- "Long-term hormone use"
label(aa$CRD)              <- "Chronic respiratory disease"
label(aa$CHF)              <- "Chronic heart failure"
label(aa$CLD)              <- "Chronic liver disease"
label(aa$CKD)              <- "Chronic kidney disease"
label(aa$NEPER)            <- "Neutrophils"
label(aa$LYMPH)            <- "Lymphocytes"
label(aa$HGB)              <- "Hemoglobin"
label(aa$PLT)              <- "Platelet"
label(aa$OIPaO2_FiO2)      <- "PaO2/FiO2"
# units()添加单位
units(aa$Age)              <- "years"
units(aa$WBC)              <- "×10^9/L"
units(aa$NEPER)            <- "%"
units(aa$LYMPH)            <- "×10^9/L"
units(aa$HGB)              <- "g/L"
units(aa$PLT)              <- "×10^9/L"
units(aa$CRP)              <- "mg/L"
units(aa$PCT)              <- "ng/mL"
units(aa$PT)               <- "s"
units(aa$CRP)              <- "mg/L"
units(aa$APTT)             <- "s"
units(aa$TBIL)             <-"mg/dL"
units(aa$BUN)              <-"mg/dL"
units(aa$CREA)             <-"mg/dL"
units(aa$NTproBNP)         <-"pg/mL"
units(aa$TNI)              <-"µg/L"
units(aa$Lac)              <-"mmol/L"
units(aa$HR)               <-"bpm"
units(aa$RR)               <-"rrm"
units(aa$BP)               <-"mmHg"
units(aa$T)                <-"℃"
units(aa$OIPaO2_FiO2)      <-"%"
#基线中出现的变量

myVars <- c("gender", 
            "Age", 
            "HT", "T2DM", "PE", "CI", "MI", "HAEM", "HyperT", "CA",
            "LTUH", "CRD", "CHF", "CLD", "CKD", 
            "WBC", "NEPER", "LYMPH", "HGB", "PLT", "CRP", "PCT", "PT", "INR", "APTT", "TBIL", "BUN", "CREA", "NTproBNP", 
            "TNI", "Lac", "OIPaO2_FiO2", 
            "SOFA", "GCS", 
            "HR", "RR", "BP", "T",
            "CD3_PER", "CD3_CD4_PER",
            "CD3_CD8_PER", 
            "CD3_CD4__CD3_CD8", "CD3", 
            "CD3_CD4", "CD3_CD8", "CD3_CD16__CD56_PER", 
            "CD3_CD16__CD56", "BCD19PER", 
            "BCD19","N_CT", "ORF1AB_CT", "survive_die" )

#基线中出现的分类变量

catvars <- c("gender", 
             "HT", "T2DM", "PE", "CI", "MI", "HAEM", 
             "HyperT", "LTUH", "CRD", "CHF", "CLD", "CKD",
             "survive_die")  

#指定哪些是非正态分布数据

nonvar <-  c("gender", 
             "Age", 
             "gender", "HT", "T2DM", "PE", "CI", "MI", "HAEM", "HyperT", "CA", "LTUH", "CRD", "CHF", "CLD", "CKD","survive_die",
             
             "WBC", "NEPER", "LYMPH", "HGB", "PLT", "CRP", "PCT", "PT", "INR", "APTT", "TBIL", "BUN", "CREA", "NTproBNP", 
             "TNI", "Lac", "OIPaO2_FiO2", 
             "SOFA", "GCS", 
             "HR", "RR", "T",
             
             "CD3_CD8_PER", 
             "CD3_CD4__CD3_CD8", "CD3", 
             "CD3_CD4", "CD3_CD8", "CD3_CD16__CD56_PER", 
             "CD3_CD16__CD56", "BCD19PER", 
             "survive_die")

#连续自变量

x1 <- c("Age", "WBC", "NEPER", "LYMPH", "HGB", "CRP", "PCT", 
        "PT", "INR", "APTT", "TBIL", "BUN", "CREA", 
        "NTproBNP", "TNI", "Lac", "OIPaO2_FiO2", "SOFA", "GCS", 
        "HR", "RR","BP", "T", "CD3_CD8_PER", "CD3_CD4__CD3_CD8", 
        "CD3", "CD3_CD4", "CD3_CD8", "CD3_CD16__CD56_PER", 
        "CD3_CD16__CD56", "BCD19PER", 
        "BCD19",
        "PLT", "CD3_PER", "CD3_CD4_PER", "N_CT", "ORF1AB_CT")

#分类自变量

x2 <- c("gender", "HT", "T2DM", "PE", "CI", "MI", "HAEM", "HyperT", "CA", "LTUH", "CRD", "CHF", "CLD", "CKD","survive_die")

#构建Table函数

tableone <- CreateTableOne(vars = c(x1,x2),data = aa,
                           factorVars = x2,strata = "survive_die",addOverall = TRUE)
results1 <- print(tableone, showAllLevels = TRUE)
write.csv(results1,"results1.csv")

#非参数检验(秩和检验、卡方检验)

library(tableone)
table2 <- CreateTableOne(vars = c(x1,x2),data = aa,
                         factorVars = x2, 
                         strata = "survive_die",
                         
                         addOverall = TRUE)
                         render.continuous=c(.="Mean (CV%)", 
                                             .="Median [Q1, Q3]",
                                             
                                             "Geo. mean (Geo. CV%)"="GMEAN (GCV%)")
results2 <- print(table2,
                  showAllLevels = TRUE, 
                  nonnormal = nonvar)#指定非参数检验的变量
                                     #exact选项可以指定确切概率检验的变量,这里忽略
write.csv(results2,"results2.csv")
table1(~ gender + 
         Age + 
         HT + T2DM + PE + CI + MI + HAEM + HyperT +CA + LTUH + CRD + CHF + 
         WBC + NEPER + LYMPH + HGB + PLT + CRP  + PCT + 
         PT + INR  + APTT  + TBIL +
         BUN + CREA + NTproBNP  + TNI + Lac + OIPaO2_FiO2 + SOFA + GCS + 
         HR + RR  + T  + CD3_CD8_PER + CD3_CD4__CD3_CD8 + CD3 +
         CD3_CD4 + CD3_CD8 + CD3_CD16__CD56_PER + CD3_CD16__CD56 + 
         BCD19PER + BCD19  | survive_die, data=aa, 
        render.continuous=c(.="Mean ± SD", 
                            .="Median [Q1, Q3]")) 
###################################
# 改变外观
table1(~ Age + gender | survive_die, data=aa, topclass="Rtable1-zebra")
table1(~ Age + gender | survive_die, data=aa, topclass="Rtable1-grid")
table1(~ Age + gender | survive_die, data=aa, 
       topclass="Rtable1-grid Rtable1-shade Rtable1-times")
###################################
# 添加 p

pvalue <- function(x, ...) {
  # Construct vectors of data y, and groups (strata) g
  y <- unlist(x)
  g <- factor(rep(1:length(x), times=sapply(x, length)))
  
  if (is.numeric(y)) {
    # Check if the numeric variable follows a normal distribution
    is_normal <- shapiro.test(y)$p.value > 0.05
    
    if (is_normal) {
      # For numeric variables following normal distribution, perform a t-test
      p <- t.test(y ~ g)$p.value
    } else {
      # For numeric variables not following normal distribution, perform a Mann-Whitney U test
      p <- wilcox.test(y ~ g, paired = FALSE)$p.value
    }
  } else {
    # For categorical variables, perform a chi-squared/fisher test of independence
    p <- fisher.test(table(y, g))$p.value
  }
  
  # Format the p-value, using an HTML entity for the less-than sign.
  # The initial empty string places the output on the line below the variable label.
  c("", sub("<", "&lt;", format.pval(p, digits=3, eps=0.001)))
}



table1(~ gender + 
         Age + 
         HT + T2DM + PE + CI + MI + HAEM + 
         HyperT + CA + LTUH + CRD + CHF + CLD + CKD +
         WBC + NEPER + LYMPH + HGB + PLT + CRP  + PCT + 
         PT + INR  + APTT  + TBIL +
         BUN + CREA + NTproBNP  + TNI + Lac + OIPaO2_FiO2 + SOFA + GCS + 
         HR + RR + BP + T + 
         CD3_PER + CD3_CD4_PER + CD3_CD8_PER + CD3_CD4__CD3_CD8 + CD3 +
         CD3_CD4 + CD3_CD8 + CD3_CD16__CD56_PER + CD3_CD16__CD56 + 
         BCD19PER + BCD19 + N_CT + ORF1AB_CT  | survive_die, 
       data=aa, 
       nonormal = nonvar,
       topclass="Rtable1-zebra", 
       render.continuous=c(.="Mean ± SD", 
                           .="Median [Q1, Q3]"), overall=F, extra.col=list(`P-value`=pvalue))
install.packages("nortest")  # 如果没有安装
library(nortest)


