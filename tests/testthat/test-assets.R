test_that("assets_dirs() contains files", {
  skip_if_assets_unavailable()

  assets_ensure()

  # Make sure we have assets installed
  expect_true(length(assets_dirs()) > 0)
  expect_true(length(dir(assets_dirs()[1])) > 0)
})
