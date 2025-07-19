# Install and load the necessary package if not already installed
if (!require(gtsummary)) {
  install.packages("gtsummary", repos = "http://cran.us.r-project.org")
}
library(gtsummary)
if (!require(dplyr)) {
  install.packages("dplyr", repos = "http://cran.us.r-project.org")
}
library(dplyr)


# Read the dataset
data <- read.csv("126case.csv")

# Create the three-line summary table
# We'''ll select a few key variables for demonstration purposes
# and stratify by the '''survive_die''' outcome variable.
# A three-line table typically summarizes baseline characteristics by outcome.

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
      all_continuous() ~ "{mean} ({sd})",
      all_categorical() ~ "{n} / {N} ({p}%)"
    ),
    digits = all_continuous() ~ 2
  ) %>%
  # Add a spanning header to the statistics columns
  # Add p-values to compare characteristics between groups
  add_p() %>%
  # Make the table more compact and publication-ready
  bold_labels() %>%
  bold_p(t = 0.05) %>%
  as_gt() # Convert to a gt object for better rendering

# Print the table to the console
print(final_table)

# To save the table to a file, you can use gtsave()
# For example, to save as a Word document:
# gtsave(final_table, filename = "demographics_table.docx")
# Or as a PNG image:
# gtsave(final_table, filename = "demographics_table.png")