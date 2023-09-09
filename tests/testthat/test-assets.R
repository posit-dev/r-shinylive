test_that("assets_versions() contains files", {
  maybe_skip_test()

  expect_true(length(dir(assets_versions()[1])) > 0)
})
