can_test_assets <- function() {
  isTRUE(as.logical(Sys.getenv("TEST_ASSETS", "false")))
}
is_interative_or_on_ci <- function() {
  interactive() || can_test_assets()
}
maybe_skip_test <- function() {
  skip_on_cran()
  skip_if(!is_interative_or_on_ci(), "Skipping test on non-interactive session. To run this test, set environment variable TEST_ASSETS=1.")
}
