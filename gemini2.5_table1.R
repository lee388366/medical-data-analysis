# Install and load the necessary packages if not already installed
if (!require(gtsummary)) {
  install.packages("gtsummary", repos = "http://cran.us.r-project.org")
}
library(gtsummary)
if (!require(dplyr)) {
  install.packages("dplyr", repos = "http://cran.us.r-project.org")
}
library(dplyr)
if (!require(gt)) {
  install.packages("gt", repos = "http://cran.us.r-project.org")
}
library(gt)

# Read the dataset
data <- read.csv("126case.csv")

# Create the three-line summary table
final_table <- data %>%
  # Convert gender and survive_die to factors for better labels
  mutate(
    gender = factor(gender, levels = c(1, 2), labels = c("Male", "Female")),
    survive_die = factor(survive_die, levels = c(0, 1), labels = c("Survived", "Died"))
  ) %>%
  # Create the summary table, including all columns
  tbl_summary(
    by = survive_die,
    statistic = list(
      all_continuous() ~ "{median} ({p25}, {p75})",
      all_categorical() ~ "{n} ({p}%)"
    ),
    digits = all_continuous() ~ 2,
    label = list(
        gender ~ "Gender",
        Age ~ "Age, years",
        HT ~ "Hypertension",
        T2DM ~ "Diabetes",
        PE ~ "Pulmonary embolism",
        CI ~ "Cerebral infarction",
        MI ~ "Myocardial infarction",
        HAEM ~ "Hemopathy",
        HyperT ~ "Thyroid dysfunction",
        CA ~ "Cancer",
        LTUH ~ "Long-term hormone use",
        CRD ~ "Chronic respiratory disease",
        CHF ~ "Chronic heart failure",
        CLD ~ "Chronic liver disease",
        CKD ~ "Chronic kidney disease",
        WBC ~ "WBC, ×10^9/L",
        NEPER ~ "Neutrophils, %",
        LYMPH ~ "Lymphocytes, ×10^9/L",
        HGB ~ "Hemoglobin, g/L",
        PLT ~ "Platelet, ×10^9/L",
        CRP ~ "CRP, mg/L",
        PCT ~ "PCT, ng/mL",
        PT ~ "PT, s",
        INR ~ "INR",
        APTT ~ "APTT, s",
        TBIL ~ "TBIL, mg/dL",
        BUN ~ "BUN, mg/dL",
        CREA ~ "CREA, mg/dL",
        NTproBNP ~ "NT-proBNP, pg/mL",
        TNI ~ "TNI, µg/L",
        Lac ~ "Lactate, mmol/L",
        OIPaO2_FiO2 ~ "PaO2/FiO2",
        SOFA ~ "SOFA Score",
        GCS ~ "GCS Score",
        HR ~ "Heart Rate, bpm",
        RR ~ "Respiratory Rate, rrm",
        BP ~ "Blood Pressure, mmHg",
        T ~ "Temperature, ℃",
        CD3_PER ~ "CD3 %",
        CD3_CD4_PER ~ "CD4 %",
        CD3_CD8_PER ~ "CD8 %",
        CD3_CD4__CD3_CD8 ~ "CD4/CD8 Ratio",
        CD3 ~ "CD3 Count",
        CD3_CD4 ~ "CD4 Count",
        CD3_CD8 ~ "CD8 Count",
        CD3_CD16__CD56_PER ~ "NK Cell %",
        CD3_CD16__CD56 ~ "NK Cell Count",
        BCD19PER ~ "B Cell %",
        BCD19 ~ "B Cell Count",
        N_CT ~ "N Gene CT Value",
        ORF1AB_CT ~ "ORF1ab Gene CT Value"
    )
  ) %>%
  # Add p-values to compare characteristics between groups
  add_p() %>%
  # Make the table more compact and publication-ready
  bold_labels() %>%
  bold_p(t = 0.05) %>%
  as_gt() # Convert to a gt object for better rendering

# Print the table to the console
print(final_table)

# Save the table to a Word document on the desktop
gtsave(final_table, filename = "/Users/liangmenglin/Desktop/123456789.docx")


