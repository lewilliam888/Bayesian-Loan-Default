rmvnorm_manual <- function(n, mu, Sigma) {
  p <- length(mu)
  L <- chol(Sigma)
  Z <- matrix(rnorm(n * p), nrow = n, ncol = p)
  Z %*% L + matrix(mu, nrow = n, ncol = p, byrow = TRUE)
}

dmvnorm_log <- function(x, mu, Sigma) {
  p <- length(mu)
  L <- chol(Sigma)
  log_det <- 2 * sum(log(diag(L)))
  z <- backsolve(L, x - mu, transpose = TRUE)
  -0.5 * (p * log(2 * pi) + log_det + sum(z^2))
}

log1pexp <- function(x) {
  ifelse(x > 0, x + log1p(exp(-x)), log1p(exp(x)))
}

log_lik_logistic <- function(beta, X, y) {
  eta <- as.vector(X %*% beta)
  sum(y * eta - log1pexp(eta))
}

log_prior <- function(beta, tau2) {
  p <- length(beta)
  -0.5 * (p * log(2 * pi * tau2) + sum(beta^2) / tau2)
}

log_post <- function(beta, X, y, tau2) {
  log_lik_logistic(beta, X, y) + log_prior(beta, tau2)
}

mh_logistic <- function(X, y, n_iter, burnin, init, tau2 = 100,
                        adapt_start = 200, adapt_window = 500,
                        adapt_scale = 2.4, eps = 1e-6) {
  p <- length(init)
  trace <- matrix(NA_real_, nrow = n_iter, ncol = p)
  trace[1, ] <- init
  current <- init
  current_lp <- log_post(current, X, y, tau2)
  accept <- 0
  
  prop_cov <- diag(0.01, p)
  
  for (t in 2:n_iter) {
    if (t > adapt_start && t %% 50 == 0) {
      lo <- max(1, t - adapt_window)
      recent <- trace[lo:(t - 1), , drop = FALSE]
      emp_cov <- cov(recent)
      prop_cov <- (adapt_scale^2 / p) * emp_cov + eps * diag(p)
    }
    
    prop <- as.vector(rmvnorm_manual(1, current, prop_cov))
    prop_lp <- log_post(prop, X, y, tau2)
    
    if (log(runif(1)) < prop_lp - current_lp) {
      current <- prop
      current_lp <- prop_lp
      accept <- accept + 1
    }
    trace[t, ] <- current
  }
  
  list(
    trace = trace[(burnin + 1):n_iter, , drop = FALSE],
    full_trace = trace,
    accept_rate = accept / (n_iter - 1),
    final_cov = prop_cov
  )
}

make_synthetic_X <- function(n) {
  loan_amnt   <- rgamma(n, shape = 4, rate = 4 / 15000)
  int_rate    <- rnorm(n, mean = 13, sd = 4.5)
  log_income  <- rnorm(n, mean = 11, sd = 0.6)
  dti         <- rnorm(n, mean = 18, sd = 8.5)
  fico        <- rnorm(n, mean = 695, sd = 32)
  revol_util  <- pmin(pmax(rnorm(n, mean = 53, sd = 24), 0), 100)
  emp_length  <- pmin(pmax(round(rnorm(n, mean = 6, sd = 3.5)), 0), 10)
  installment <- rgamma(n, shape = 4, rate = 4 / 440)
  
  raw <- cbind(loan_amnt, int_rate, log_income, dti, fico,
               revol_util, emp_length, installment)
  X_std <- scale(raw)
  cbind(intercept = 1, X_std)
}

make_synthetic_y <- function(X, beta_true) {
  eta <- as.vector(X %*% beta_true)
  p_i <- 1 / (1 + exp(-eta))
  rbinom(nrow(X), size = 1, prob = p_i)
}