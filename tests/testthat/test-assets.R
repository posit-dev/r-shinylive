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

test_that("assets_dir() uses `dir`", {
  dir <- withr::local_tempdir()
  expect_equal(
    assets_dir("1.2.3", dir = dir),
    fs::path(dir, "shinylive-1.2.3")
  )
})

test_that("assets_ensure() downloads to and returns a path in `dir`", {
  dir <- withr::local_tempdir()
  local_mocked_bindings(
    assets_download = function(version, ..., dir, url) {
      fs::dir_create(fs::path(dir, paste0("shinylive-", version)))
      invisible(dir)
    }
  )
  path <- assets_ensure("1.2.3", dir = dir)
  expect_equal(path, fs::path(dir, "shinylive-1.2.3"))
  expect_true(fs::dir_exists(path))
})

test_that("assets_dirs() skips entries that are not version folders", {
  dir <- withr::local_tempdir()
  fs::dir_create(fs::path(dir, c("shinylive-0.9.0", "shinylive-0.10.1")))
  fs::dir_create(fs::path(dir, "shinylive-dev"))
  fs::file_create(fs::path(dir, "shinylive-1.0.0.tar.gz"))

  expect_equal(
    assets_dirs(dir = dir),
    fs::path(dir, c("shinylive-0.10.1", "shinylive-0.9.0"))
  )
})

test_that("assets_info() works when no assets are installed", {
  dir <- withr::local_tempdir()
  local_mocked_bindings(assets_cache_dir = function() dir)

  info <- assets_info(quiet = TRUE)
  expect_equal(nrow(info), 0)
  expect_named(info, c("version", "path", "is_assets_version"))

  fs::dir_create(fs::path(dir, "shinylive-0.9.0"))
  info <- assets_info(quiet = TRUE)
  expect_equal(info$version, "0.9.0")
  expect_equal(info$path, as.character(fs::path(dir, "shinylive-0.9.0")))
})

test_that("assets_ensure() shows the cache folder it creates", {
  dir <- fs::path(withr::local_tempdir(), "cache")
  local_mocked_bindings(
    assets_download = function(version, ..., dir, url) {
      fs::dir_create(fs::path(dir, paste0("shinylive-", version)))
      invisible(dir)
    }
  )
  withr::local_options(shinylive.quiet = FALSE)
  expect_message(
    assets_ensure("1.2.3", dir = dir),
    "Creating assets cache directory .*cache"
  )
})
