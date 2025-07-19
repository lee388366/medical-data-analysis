# h2o+shapviz多模型SHAP解释全流程示例

# 0. 自动检查并安装依赖包
required_packages <- c("RCurl", "jsonlite", "h2o", "tidymodels", "shapviz", "caret")
for(pkg in required_packages){
  if(!requireNamespace(pkg, quietly = TRUE)){
    if(pkg == "h2o"){
      install.packages("h2o", repos = "https://h2o-release.s3.amazonaws.com/h2o/latest_stable_R")
    } else {
      install.packages(pkg)
    }
  }
}

# 1. 加载必要R包
library(h2o)
library(shapviz)
library(caret)
library(tidymodels)

# 2. 读取数据
# 假设126case.csv与脚本同目录
# 注意：如有中文路径或特殊字符，建议用file.choose()交互选择

data <- read.csv("126case.csv", header = TRUE, check.names = FALSE)

# 3. 变量类型处理
# 目标变量survive_die转为factor
# 部分特征如gender等也建议转为factor
cat_vars <- c("gender", "HT", "T2DM", "PE", "CI", "MI", "HAEM", "HyperT", "CA", "LTUH", "CRD", "CHF", "CLD", "CKD")
data[cat_vars] <- lapply(data[cat_vars], as.factor)
data$survive_die <- as.factor(data$survive_die)

# 4. 划分训练集和测试集
set.seed(123)
inTrain <- createDataPartition(y = data$survive_die, p = 0.7, list = FALSE)
traindata <- data[inTrain, ]
testdata <- data[-inTrain, ]

# 5. 用recipe+step_dummy处理哑变量，转换为h2o数据框
rec <- recipe(survive_die ~ ., data = traindata) %>%
  step_dummy(all_nominal_predictors()) %>%
  prep()
traindata_env <- bake(rec, new_data = NULL) %>% as.h2o()
testdata_env <- bake(rec, new_data = testdata) %>% as.h2o()

# 6. 启动h2o
h2o.init()

# 7. 训练h2o随机森林模型
xvars <- setdiff(colnames(traindata_env), "survive_die")
fit_rf <- h2o.randomForest(x = xvars, y = "survive_die", training_frame = traindata_env, nfolds = 5, seed = 123)

# 8. shapviz解释（训练集）
shp_rf <- shapviz(fit_rf, X_pred = as.data.frame(traindata_env))
# 变量重要性
sv_importance(shp_rf, show_numbers = TRUE)
# 偏相关依赖图（以Age为例）
sv_dependence(shp_rf, v = "Age")
# 单样本力图
sv_force(shp_rf, row_id = 1)
# 单样本waterfall图
sv_waterfall(shp_rf, row_id = 1)

# 9. h2o自动建模（AutoML）
auto_fit <- h2o.automl(y = "survive_die", training_frame = traindata_env, max_models = 10, seed = 123)
# 查看前6模型
h2o.get_leaderboard(auto_fit)
# 选取最优模型
best <- h2o.get_best_model(auto_fit)
# 模型表现
perf <- h2o.performance(best, newdata = testdata_env)
perf
# 绘制ROC曲线
plot(perf, type = "roc")
# 变量重要性
h2o.varimp_plot(best)
# 基于排列的变量重要性
if("h2o.permutation_importance_plot" %in% ls("package:h2o")){
  h2o.permutation_importance_plot(best, traindata_env)
}

# 10. SHAP解释（AutoML最优模型）
shp_best <- shapviz(best, X_pred = as.data.frame(traindata_env))
sv_importance(shp_best, show_numbers = TRUE)
sv_dependence(shp_best, v = "Age")
sv_force(shp_best, row_id = 1)
sv_waterfall(shp_best, row_id = 1)

# 11. 结束h2o
h2o.shutdown(prompt = FALSE)

# 脚本结束 



