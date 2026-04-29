# Usage: Rscript run_file.r <seed> <output_dir>

source("helpers.r")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Usage: Rscript run_file.r <seed> <output_dir>")
seed       <- as.integer(args[1])
output_dir <- args[2]

n_obs    <- 10000
n_iter   <- 20000
burnin   <- 5000
tau2     <- 100

# pilot glm MLEs from the real data
beta_true <- c(-1.575, 0.6795, 0.518, -0.1467, 0.1489, -0.2624, -0.0804, -0.0389, -0.5068)

set.seed(seed)

X <- make_synthetic_X(n_obs)
y <- make_synthetic_y(X, beta_true)

init <- rep(0, length(beta_true))

fit <- mh_logistic(X, y, n_iter = n_iter, burnin = burnin,
                   init = init, tau2 = tau2)

out <- list(
  seed        = seed,
  beta_true   = beta_true,
  trace       = fit$trace,
  accept_rate = fit$accept_rate,
  n_obs       = n_obs,
  n_iter      = n_iter,
  burnin      = burnin,
  tau2        = tau2
)

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
fname <- file.path(output_dir, sprintf("trace_seed%04d.rds", seed))
saveRDS(out, fname)

cat(sprintf("seed %d done. accept_rate = %.3f. saved to %s\n",
            seed, fit$accept_rate, fname))