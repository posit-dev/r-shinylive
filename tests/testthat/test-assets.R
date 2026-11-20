test_that("assets_dirs() contains files", {
  skip_if_assets_unavailable()

  assets_ensure()

  # Make sure we have assets installed
  expect_true(length(assets_dirs()) > 0)
  expect_true(length(dir(assets_dirs()[1])) > 0)
})

test_that("assets_path_webr_r_version() reads the R version from the assets", {
  assets_path <- withr::local_tempdir()
  translations <- fs::path(
    assets_path,
    "shinylive/webr/vfs/usr/lib/R/library/translations"
  )
  fs::dir_create(translations)
  writeLines(
    c("Package: translations", "Version: 4.7.1", "Priority: base"),
    fs::path(translations, "DESCRIPTION")
  )

  expect_equal(assets_path_webr_r_version(assets_path), "4.7.1")
})

test_that("assets_path_webr_r_version() errors when the version is missing", {
  assets_path <- withr::local_tempdir()

  expect_error(
    assets_path_webr_r_version(assets_path),
    "Can't find the webR R version"
  )
})

test_that("the default assets use the expected webR R version", {
  skip_if_assets_unavailable()

  # Update this when a new default assets version changes the webR R version.
  # It catches an R version change that would otherwise go unnoticed.
  expect_equal(assets_webr_r_version(SHINYLIVE_ASSETS_VERSION), "4.6.0")
})
