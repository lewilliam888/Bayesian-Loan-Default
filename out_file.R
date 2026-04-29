# Usage: Rscript out_file.r <traces_dir> <figures_dir>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Usage: Rscript out_file.r <traces_dir> <figures_dir>")
traces_dir  <- args[1]
figures_dir <- args[2]

if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)

files <- list.files(traces_dir, pattern = "^trace_seed.*\\.rds$", full.names = TRUE)
if (length(files) == 0) stop("no trace files found in ", traces_dir)
cat(sprintf("found %d trace files\n", length(files)))

param_names <- c("intercept", "loan_amnt", "int_rate", "log_income", "dti",
                 "fico", "revol_util", "emp_length", "installment")
p <- length(param_names)

N <- length(files)
post_mean   <- matrix(NA_real_, nrow = N, ncol = p)
post_median <- matrix(NA_real_, nrow = N, ncol = p)
ci_lower    <- matrix(NA_real_, nrow = N, ncol = p)
ci_upper    <- matrix(NA_real_, nrow = N, ncol = p)
accept_rates <- numeric(N)
beta_true   <- NULL

for (i in seq_along(files)) {
  out <- readRDS(files[i])
  if (is.null(beta_true)) beta_true <- out$beta_true
  trace <- out$trace
  post_mean[i, ]   <- colMeans(trace)
  post_median[i, ] <- apply(trace, 2, median)
  ci_lower[i, ]    <- apply(trace, 2, quantile, probs = 0.025)
  ci_upper[i, ]    <- apply(trace, 2, quantile, probs = 0.975)
  accept_rates[i]  <- out$accept_rate
}

covered <- (matrix(beta_true, nrow = N, ncol = p, byrow = TRUE) >= ci_lower) &
  (matrix(beta_true, nrow = N, ncol = p, byrow = TRUE) <= ci_upper)
coverage <- colMeans(covered)
mc_se    <- sqrt(coverage * (1 - coverage) / N)

cov_table <- data.frame(
  parameter = param_names,
  beta_true = beta_true,
  mean_of_post_means = colMeans(post_mean),
  bias = colMeans(post_mean) - beta_true,
  coverage_95 = coverage,
  mc_se = mc_se
)
cat("\ncoverage table\n")
print(cov_table, row.names = FALSE, digits = 4)
write.csv(cov_table, file.path(figures_dir, "coverage_table.csv"), row.names = FALSE)

pdf(file.path(figures_dir, "sampling_dist_post_means.pdf"), width = 10, height = 8)
par(mfrow = c(3, 3), mar = c(4, 4, 3, 1))
for (j in 1:p) {
  hist(post_mean[, j], breaks = 25,
       main = param_names[j],
       xlab = "posterior mean across replicates",
       col = "gray80", border = "white")
  abline(v = beta_true[j], col = "red", lwd = 2)
}
dev.off()

pdf(file.path(figures_dir, "sampling_dist_post_medians.pdf"), width = 10, height = 8)
par(mfrow = c(3, 3), mar = c(4, 4, 3, 1))
for (j in 1:p) {
  hist(post_median[, j], breaks = 25,
       main = param_names[j],
       xlab = "posterior median across replicates",
       col = "gray80", border = "white")
  abline(v = beta_true[j], col = "red", lwd = 2)
}
dev.off()

pdf(file.path(figures_dir, "coverage_plot.pdf"), width = 8, height = 5)
par(mar = c(7, 4, 3, 1))
bp <- barplot(coverage, names.arg = param_names, las = 2,
              ylim = c(0, 1), col = "gray80", border = "white",
              ylab = "empirical coverage of 95% CI",
              main = sprintf("coverage from N = %d replicates", N))
abline(h = 0.95, col = "red", lwd = 2, lty = 2)
arrows(bp, coverage - 1.96 * mc_se, bp, coverage + 1.96 * mc_se,
       length = 0.04, angle = 90, code = 3)
dev.off()

cat(sprintf("\nacceptance rate: mean = %.3f, sd = %.3f, range = [%.3f, %.3f]\n",
            mean(accept_rates), sd(accept_rates),
            min(accept_rates), max(accept_rates)))

saveRDS(list(
  N = N,
  beta_true = beta_true,
  post_mean = post_mean,
  post_median = post_median,
  ci_lower = ci_lower,
  ci_upper = ci_upper,
  coverage = coverage,
  mc_se = mc_se,
  accept_rates = accept_rates,
  cov_table = cov_table
), file.path(figures_dir, "sim_study_results.rds"))

cat("\ndone. saved to", figures_dir, "\n")