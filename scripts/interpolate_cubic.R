# Piecewise cubic Hermite interpolation (PCHIP).
# Interior derivatives: Fritsch & Butland (1984), doi:10.1137/0905021.
# One-sided endpoint derivatives: Moler (2004), as in SciPy PchipInterpolator.
# This is not stats::splinefun(method = "fmm") (Forsythe–Malcolm–Moler).
# Cubic estimates are evaluated at every finite target time, including gaps.
# Outside the measured range the first/last cubic polynomial is extended.
# Shape preservation applies INSIDE the measured range, not to extrapolation.
pchip_fritsch_butland <- function(x, y, target) {
  stopifnot(length(x) == length(y), length(x) >= 2L,
            all(is.finite(x)), all(is.finite(y)), all(diff(x) > 0))
  n <- length(x)
  h <- diff(x)
  delta <- diff(y) / h
  slopes <- numeric(n)
  endpoint <- function(h1, h2, d1, d2) {
    d <- ((2 * h1 + h2) * d1 - h1 * d2) / (h1 + h2)
    if (sign(d) != sign(d1)) return(0)
    if (sign(d1) != sign(d2) && abs(d) > abs(3 * d1)) return(3 * d1)
    d
  }
  if (n == 2L) {
    slopes[] <- delta[1]
  } else {
    for (k in 2:(n - 1L)) {
      left <- delta[k - 1L]
      right <- delta[k]
      if (left != 0 && right != 0 && sign(left) == sign(right)) {
        w1 <- 2 * h[k] + h[k - 1L]
        w2 <- h[k] + 2 * h[k - 1L]
        slopes[k] <- (w1 + w2) / (w1 / left + w2 / right)
      }
    }
    slopes[1] <- endpoint(h[1], h[2], delta[1], delta[2])
    slopes[n] <- endpoint(h[n - 1L], h[n - 2L], delta[n - 1L], delta[n - 2L])
  }
  result <- rep(NA_real_, length(target))
  valid <- is.finite(target)
  i <- findInterval(target[valid], x, all.inside = TRUE)
  t <- (target[valid] - x[i]) / h[i]
  result[valid] <- (2*t^3 - 3*t^2 + 1) * y[i] +
    (t^3 - 2*t^2 + t) * h[i] * slopes[i] +
    (-2*t^3 + 3*t^2) * y[i + 1L] +
    (t^3 - t^2) * h[i] * slopes[i + 1L]
  result
}

# Preserve PAROLE's minimum of four usable observations and averaging of ties.
# No 0.1-second cutoff, silence mask, or linear interpolation is introduced.
interpolate_spline <- function(time, values, new_times) {
  stopifnot(length(time) == length(values))
  valid <- is.finite(time) & is.finite(values)
  if (sum(valid) < 4L) return(rep(NA_real_, length(new_times)))
  data <- aggregate(values[valid], list(time = time[valid]), mean)
  if (nrow(data) < 2L) return(rep(NA_real_, length(new_times)))
  pchip_fritsch_butland(data$time, data$x, new_times)
}
