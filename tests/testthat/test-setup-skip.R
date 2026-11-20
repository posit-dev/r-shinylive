test_that("TEST_ASSETS accepts 1 and true", {
  for (value in c("1", "true", "TRUE")) {
    withr::with_envvar(c(TEST_ASSETS = value), expect_true(can_test_assets()))
  }
  for (value in c("0", "false", "")) {
    withr::with_envvar(c(TEST_ASSETS = value), expect_false(can_test_assets()))
  }
})
