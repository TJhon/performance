#' Check model for homogeneity of variances
#'
#' Check model for homogeneity of variances between groups described
#' by independent variables in a model.
#'
#' @param x A linear model or an ANOVA object.
#' @param method Name of the method (underlying test) that should be performend
#' to check the homogeneity of variances. May either be \code{"bartlett"} for
#' the Bartlett test (assuming normal distributed samples or groups),
#' \code{"fligner"} for the Fligner-Killeen test (rank-based, non-parametric test),
#' or \code{"auto"}. In the latter case, Bartlett test is used if the model response
#' is normal distributed, else Fligner-Killeen test is used.
#' @param ... Currently not used.
#'
#' @return Invisibly returns the p-value of the test statistics. A p-value
#' < 0.05 indicates a significant difference in the variance between the groups.
#'
#' @examples
#' model <- lm(len ~ supp + dose, data = ToothGrowth)
#' check_homogeneity(model)
#'
#' # plot results
#' result <- check_homogeneity(model)
#' plot(result)
#'
#' @importFrom stats fligner.test bartlett.test shapiro.test
#' @importFrom insight find_response find_predictors get_data get_response
#' @export
check_homogeneity <- function(x, method = c("bartlett", "fligner", "auto"), ...) {
  UseMethod("check_homogeneity")
}


#' @export
check_homogeneity.default <- function(x, method = c("bartlett", "fligner", "auto"), ...) {
  method <- match.arg(method)

  resp <- insight::find_response(x)
  pred <- insight::find_predictors(x, component = "conditional", flatten = TRUE)

  if (length(pred) > 1) {
    pred <- paste0("interaction(", paste0(pred, collapse = ", "), ")", collapse = "")
  }

  f <- stats::as.formula(sprintf("%s ~ %s", resp, pred))

  if (method == "auto") {
    check <- tryCatch(
      {stats::shapiro.test(insight::get_response(x))$p.value},
      error = function(e) { NULL }
    )

    if (is.null(check)) {
      insight::print_color("'check_homogeneity()' cannot perform check for normality. Please specify the 'method'-argument for the test of equal variances.\n", "red")
      return(NULL)
    }

    method <- ifelse(check < 0.05, "fligner", "bartlett")
  }

  if (method == "fligner") {
    r <- stats::fligner.test(f, data = insight::get_data(x))
  } else if (method == "bartlett") {
    r <- stats::bartlett.test(f, data = insight::get_data(x))
  }


  p.val <- r$p.value

  method.string <- switch(
    method,
    "bartlett" = "Bartlett Test",
    "fligner" = "Fligner-Killeen Test"
  )

  if (p.val < 0.05) {
    insight::print_color(sprintf("Warning: Variances differ between groups (%s, p = %.3f).\n", method.string, p.val), "red")
  } else {
    insight::print_color(sprintf("OK: Variances in each of the groups are the same (%s, p = %.3f).\n", method.string, p.val), "green")
  }

  attr(p.val, "object_name") <- deparse(substitute(x), width.cutoff = 500)
  attr(p.val, "method") <- method.string
  class(p.val) <- unique(c("check_homogeneity", "see_check_homogeneity", class(p.val)))

  invisible(p.val)
}