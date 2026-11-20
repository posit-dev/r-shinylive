can_test_assets <- function() {
  value <- Sys.getenv("TEST_ASSETS", "false")
  identical(value, "1") || isTRUE(as.logical(value))
}
is_interactive_or_test_assets <- function() {
  interactive() || can_test_assets()
}
skip_if_assets_unavailable <- function() {
  skip_on_cran()
  skip_if(
    !is_interactive_or_test_assets(),
    "Skipping test on non-interactive session. To run this test, set environment variable TEST_ASSETS=1."
  )
}
