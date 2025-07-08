# 112233.R
# 本脚本用于绘制科研成果分类维恩图的示例脚本

# 设置工作目录为项目根目录
setwd("/Users/liangmenglin/Cursor")

# 检查并安装所需包
pkgs <- c("ragg", "officer", "magrittr", "table1", "stringr", "Hmisc")
for (p in pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  library(p, character.only = TRUE)
}

# 确保输出文件夹存在
if (!dir.exists("output_directory")) dir.create("output_directory")

# 保存图片
png_file <- "output_directory/table1_output.png"
agg_png(filename = png_file, width = 1400, height = 1200, res = 150)

type_names <- c(
  rep("人工智能与预测模型研究", 3),
  rep("感染病因与流行病学分析", 3),
  rep("脓毒症及代谢机制研究", 3),
  "重症治疗及临床技术研究",
  rep("一氧化碳中毒及神经病理机制", 2)
)

articles <- c(
  "浅析人工智能时代急诊医师胜任力",
  "Machine learning-based mortality risk prediction model in patients with sepsis",
  "基于LASSO-Logistic回归及列线图模型预测Covid-19合并脓毒症患者短期死亡风险",
  "红细胞分布宽度与血小板分布宽度可以辅助预测流感合并下呼吸道感染患者预后",
  "老年急诊病房急性感染序贯治疗患者的致病菌流行病学分析",
  "快速Pitt菌血症评分联合乳酸预测急性下呼吸道感染患者的死亡风险",
  "Hyperosmolarity and Hyperosmolar Hyperglycemic State Increase New-Onset Atrial Fibrillation Risk in Sepsis",
  "Relationship between lymphocyte changes and disease severity in patients with COVID-19 and treatment progress",
  "micro RNA-132对FoxO3的调控在脓毒症心肌病(SCM)线粒体自噬中的作用及其机制研究",
  "Extracorporeal Membrane Oxygenation (ECMO) in Critically Ill Patients with Coronavirus Disease 2019 (COVID-19) Pneumonia and Acute Respiratory Distress Syndrome (ARDS)",
  "表观扩散系数联合C-反应蛋白对一氧化碳中毒迟发性脑病的相关性分析",
  "急性一氧化碳中毒迟发性脑病发病机制研究进展"
)

df <- data.frame(
  分类 = factor(type_names, levels = unique(type_names)),
  文章标题 = str_wrap(articles, width = 35)
)

label(df$分类) <- "文章分类"
label(df$文章标题) <- "文章标题"

table1(~ 文章标题 | 分类, data = df, overall = FALSE,
       caption = "基于PICOS分类的文章分类与标题对照表")
dev.off()

# 创建 Word 文档并插入图片
doc <- read_docx()
doc <- doc %>%
  body_add_par("基于PICOS分类的文章分类与标题对照表", style = "heading 1") %>%
  body_add_img(src = png_file, width = 6, height = 5) %>%
  body_add_par("图片来源：R语言 table1 包生成", style = "Normal")

# 保存 Word 文档
print(doc, target = "/Users/liangmenglin/Desktop/126case/table1_report.docx")

# 请在此处添加你的R代码 

getwd()

