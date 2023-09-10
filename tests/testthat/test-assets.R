test_that("assets_versions() contains files", {
  maybe_skip_test()

  assets_ensure()

  # Make sure we have assets installed
  expect_true(length(assets_versions()) > 0)
  expect_true(length(dir(assets_versions()[1])) > 0)
})
