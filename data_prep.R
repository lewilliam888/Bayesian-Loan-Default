# Usage: Rscript data_prep.r <raw_csv> <output_csv>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Usage: Rscript data_prep.r <raw_csv> <output_csv>")
raw_csv    <- args[1]
output_csv <- args[2]

raw <- read.csv(raw_csv, stringsAsFactors = FALSE)
cat("raw rows:", nrow(raw), "\n")

# only loans with a final outcome
keep_status <- c("Fully Paid", "Charged Off", "Default")
df <- raw[raw$loan_status %in% keep_status, ]

df$default <- as.integer(df$loan_status %in% c("Charged Off", "Default"))

# int_rate comes in as "13.49%"
if (is.character(df$int_rate)) {
  df$int_rate <- as.numeric(sub("%", "", df$int_rate))
}
if (is.character(df$revol_util)) {
  df$revol_util <- as.numeric(sub("%", "", df$revol_util))
}

# emp_length: "10+ years", "< 1 year", "n/a", etc.
parse_emp <- function(x) {
  x <- trimws(x)
  out <- rep(NA_real_, length(x))
  out[x == "< 1 year"] <- 0
  out[x == "10+ years"] <- 10
  yrs <- suppressWarnings(as.numeric(sub(" years?", "", x)))
  out[is.na(out) & !is.na(yrs)] <- yrs[is.na(out) & !is.na(yrs)]
  out
}
df$emp_length <- parse_emp(df$emp_length)

# fico from low/high range columns
df$fico <- (df$fico_range_low + df$fico_range_high) / 2

df$log_income <- log(df$annual_inc + 1)

keep_cols <- c("default", "loan_amnt", "int_rate", "log_income", "dti",
               "fico", "revol_util", "emp_length", "installment")
df <- df[, keep_cols]

df <- df[complete.cases(df), ]

# trim impossible values
df <- df[df$dti >= 0 & df$dti < 100, ]
df <- df[df$log_income > 0, ]
df <- df[df$revol_util >= 0 & df$revol_util <= 100, ]

cat("clean rows:", nrow(df), "\n")
cat("default rate:", round(mean(df$default), 4), "\n")

write.csv(df, output_csv, row.names = FALSE)
cat("saved cleaned data to", output_csv, "\n")

# pilot glm to set beta_true for the simulation study
covars <- c("loan_amnt", "int_rate", "log_income", "dti", "fico",
            "revol_util", "emp_length", "installment")
X_std <- scale(as.matrix(df[, covars]))
fit_df <- data.frame(default = df$default, X_std)
pilot <- glm(default ~ ., data = fit_df, family = binomial)

cat("\npilot glm coefficients (use these as beta_true in run_file.r):\n")
print(round(coef(pilot), 4))

cat("\nformatted for run_file.r:\n")
cat("beta_true <- c(",
    paste(round(coef(pilot), 4), collapse = ", "),
    ")\n", sep = "")