# Usage: Rscript real_data_fit.r <data_csv> <output_dir>

source("helpers.r")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Usage: Rscript real_data_fit.r <data_csv> <output_dir>")
data_csv   <- args[1]
output_dir <- args[2]

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

n_iter <- 30000
burnin <- 10000
tau2   <- 100
seed   <- 1

set.seed(seed)

df <- read.csv(data_csv)

if (nrow(df) > 10000) {
  df <- df[sample.int(nrow(df), 10000), ]
}

y <- df$default

covars <- c("loan_amnt", "int_rate", "log_income", "dti", "fico",
            "revol_util", "emp_length", "installment")
X_raw  <- as.matrix(df[, covars])
X_std  <- scale(X_raw)
X      <- cbind(intercept = 1, X_std)

p <- ncol(X)
init <- rep(0, p)

fit <- mh_logistic(X, y, n_iter = n_iter, burnin = burnin,
                   init = init, tau2 = tau2)

cat(sprintf("acceptance rate on real data: %.3f\n", fit$accept_rate))

param_names <- colnames(X)
post_mean   <- colMeans(fit$trace)
post_median <- apply(fit$trace, 2, median)
ci_lower    <- apply(fit$trace, 2, quantile, probs = 0.025)
ci_upper    <- apply(fit$trace, 2, quantile, probs = 0.975)

real_summary <- data.frame(
  parameter   = param_names,
  post_mean   = post_mean,
  post_median = post_median,
  ci_lower    = ci_lower,
  ci_upper    = ci_upper
)
cat("\nreal data posterior summaries\n")
print(real_summary, row.names = FALSE, digits = 4)
write.csv(real_summary, file.path(output_dir, "real_posterior_summary.csv"),
          row.names = FALSE)

pdf(file.path(output_dir, "real_trace_plots.pdf"), width = 10, height = 8)
par(mfrow = c(3, 3), mar = c(4, 4, 3, 1))
for (j in 1:p) {
  plot(fit$trace[, j], type = "l", col = "gray30",
       main = param_names[j], xlab = "iteration (post burn-in)",
       ylab = expression(beta[j]))
}
dev.off()

pdf(file.path(output_dir, "real_posterior_hist.pdf"), width = 10, height = 8)
par(mfrow = c(3, 3), mar = c(4, 4, 3, 1))
for (j in 1:p) {
  hist(fit$trace[, j], breaks = 40, col = "gray80", border = "white",
       main = param_names[j], xlab = expression(beta[j]))
  abline(v = post_mean[j], col = "red", lwd = 2)
  abline(v = c(ci_lower[j], ci_upper[j]), col = "blue", lty = 2)
}
dev.off()

saveRDS(list(
  trace       = fit$trace,
  accept_rate = fit$accept_rate,
  summary     = real_summary,
  param_names = param_names,
  n_obs       = nrow(X),
  n_iter      = n_iter,
  burnin      = burnin,
  tau2        = tau2,
  seed        = seed
), file.path(output_dir, "real_fit.rds"))

cat("\ndone. saved to", output_dir, "\n")