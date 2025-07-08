# 强制指定CRAN镜像，避免交互式选择
options(repos = c(CRAN = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/"))

# 自动安装iml和DALEX（如未安装）
if (!requireNamespace("iml", quietly = TRUE)) {
  install.packages("iml", repos = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/")
}
if (!requireNamespace("DALEX", quietly = TRUE)) {
  install.packages("DALEX", repos = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/")
}
if (!requireNamespace("randomForest", quietly = TRUE)) {
  install.packages("randomForest")
}
if (!requireNamespace("pROC", quietly = TRUE)) {
  install.packages("pROC")
}
if (!requireNamespace("ggbeeswarm", quietly = TRUE)) install.packages("ggbeeswarm")
if (!requireNamespace("patchwork", quietly = TRUE)) install.packages("patchwork")

library(iml)
library(DALEX)
library(randomForest)
library(pROC)

# 读入数据
case_data <- read.csv("/Users/liangmenglin/Desktop/126case/126case.csv", header = TRUE, stringsAsFactors = FALSE)

# 数据分割
set.seed(123)
n <- nrow(case_data)
train_index <- sample(seq_len(n), size = round(0.7 * n))
train_data <- case_data[train_index, ]
test_data  <- case_data[-train_index, ]

# 响应变量处理
response_var <- "survive_die"
train_data[[response_var]] <- factor(train_data[[response_var]], levels = c("0", "1"), labels = c("survive", "die"))
test_data[[response_var]]  <- factor(test_data[[response_var]],  levels = c("0", "1"), labels = c("survive", "die"))

# 特征矩阵
X_train <- train_data[, setdiff(names(train_data), response_var)]
X_test  <- test_data[, setdiff(names(test_data), response_var)]
y_train <- train_data[[response_var]]
y_test  <- test_data[[response_var]]

# 全部特征转为数值型
X_train[] <- lapply(X_train, function(x) {
  if (is.factor(x) || is.character(x)) as.numeric(as.factor(x)) else x
})
X_test[] <- lapply(X_test, function(x) {
  if (is.factor(x) || is.character(x)) as.numeric(as.factor(x)) else x
})

# 去除X和y中有NA的行
na_rows <- complete.cases(X_train, y_train)
X_train_noNA <- X_train[na_rows, ]
y_train_noNA <- y_train[na_rows]

cat("X_train_noNA行数：", nrow(X_train_noNA), "，y_train_noNA长度：", length(y_train_noNA), "\n")
cat("X_train_noNA是否有NA：", anyNA(X_train_noNA), "\n")
cat("y_train_noNA是否有NA：", anyNA(y_train_noNA), "\n")

# 训练 randomForest 模型
rf_model <- randomForest(x = X_train_noNA, y = y_train_noNA)

# 评估AUC
rf_pred <- predict(rf_model, newdata = X_test, type = "prob")[, "survive"]
auc_rf <- roc(y_test, rf_pred, levels = c("survive", "die"), direction = "<")$auc
cat("RF模型AUC:", auc_rf, "\n")

# iml SHAP解释
predictor_rf <- Predictor$new(
  model = rf_model,
  data = X_train_noNA,
  y = y_train_noNA,
  type = "prob",
  class = "survive"
)
shap_rf <- Shapley$new(predictor_rf, x.interest = X_train_noNA[1, ])
plot(shap_rf)

# 全局特征重要性
imp_rf <- FeatureImp$new(predictor_rf, loss = "ce")
plot(imp_rf)

# DALEXtra SHAP解释
# 安装并加载 DALEXtra
if (!requireNamespace("DALEXtra", quietly = TRUE)) {
  install.packages("DALEXtra", repos = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/")
}
library(DALEXtra)

explainer_rf <- DALEX::explain(
  model = rf_model,
  data = X_train_noNA,
  y = y_train_noNA,
  label = "RF",
  predict_function = function(m, d) predict(m, d, type = "prob")[, "survive"]
)
shap_rf_dalex <- predict_parts(explainer_rf, new_observation = X_train_noNA[1, ], type = "shap")
plot(shap_rf_dalex)

# 计算全局特征重要性（iml）
imp_rf <- FeatureImp$new(predictor_rf, loss = "ce")
imp_df <- imp_rf$results

# 按重要性排序
imp_df <- imp_df[order(imp_df$importance, decreasing = TRUE), ]

# 直接在R里显示柱状图
ggplot(imp_df, aes(x = reorder(feature, importance), y = importance)) +
  geom_bar(stat = "identity", fill = "#4682B4") +
  coord_flip() +
  geom_text(aes(label = round(importance, 3)), hjust = -0.1, size = 3.5) +
  labs(
    title = "Feature Importance (Mean Absolute SHAP)",
    subtitle = "Average impact magnitude of each feature on model predictions",
    x = "Feature",
    y = "Mean |SHAP value|",
    caption = "Bar height indicates feature importance, with value showing mean absolute SHAP"
  ) +
  theme_minimal(base_size = 14)

# 计算前 N 个样本的 SHAP 值
N <- min(50, nrow(X_train_noNA))  # 你可以改成更大
shap_long <- do.call(rbind, lapply(1:N, function(i) {
  s <- Shapley$new(predictor_rf, x.interest = X_train_noNA[i, ])
  data.frame(
    feature = s$results$feature,
    phi = s$results$phi,
    value = as.numeric(X_train_noNA[i, s$results$feature]),
    obs = i
  )
}))

# 直接在R里显示蜂群图
ggplot(shap_long, aes(x = phi, y = feature, color = value)) +
  ggbeeswarm::geom_quasirandom(groupOnY = TRUE, alpha = 0.7) +
  scale_color_gradient(low = "blue", high = "red") +
  labs(
    title = "SHAP Value Distribution (Bee Swarm)",
    subtitle = "Each point represents one sample, color indicates feature value",
    x = "SHAP value (impact on model output)",
    y = "Feature",
    caption = "Red: high feature values | Blue: low feature values | Horizontal spread: direction of effect"
  ) +
  theme_minimal(base_size = 14)

# 选取前6个重要特征
top_features <- head(imp_df$feature, 6)

# 保存为PDF，每页一个dependence plot
plots <- lapply(top_features, function(f) {
  ggplot(shap_long[shap_long$feature == f, ], aes(x = value, y = phi)) +
    geom_point(alpha = 0.7, color = "#4682B4") +
    labs(
      title = paste("Dependence plot:", f),
      x = paste(f, "(feature value)"),
      y = "SHAP value"
    ) +
    theme_minimal(base_size = 14)
})

pdf("4_SHAP_Feature_Dependence.pdf", width=14, height=8)
wrap_plots(plots, nrow = 2, ncol = 3)
dev.off()








