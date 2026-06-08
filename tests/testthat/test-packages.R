# Tests for Wasm package cache invalidation logic in R/packages.R.
#
# These exercise the cache-key handling that keeps a package's downloaded Wasm
# binary in sync with the version actually served by the Wasm binary repository
# (which can lag behind the locally installed version).

cran_desc <- function(version = "1.4.0") {
  list(Package = "scales", Version = version, Repository = "CRAN")
}

wasm_asset <- function(pkg = "scales", version = "1.4.0") {
  list(list(
    filename = glue::glue("{pkg}_{version}.tgz"),
    url = glue::glue("https://repo.r-wasm.org/.../{pkg}_{version}.tgz"),
    version = version
  ))
}

test_that("repo lag stores the downloaded version and keeps re-checking", {
  skip_on_cran()
  local_mocked_bindings(
    packageDescription = function(...) cran_desc("1.4.0"),
    .package = "utils"
  )
  # Repository lags behind local: it only serves scales 1.3.0
  local_mocked_bindings(
    get_wasm_assets = function(desc, repo) wasm_asset("scales", "1.3.0")
  )

  # First pass: no prior cache -> miss, stores the DOWNLOADED version as the ref
  m1 <- prepare_wasm_metadata("scales", list())
  expect_false(m1$cached)
  expect_equal(as.character(m1$ref), "scales@1.3.0")

  # The download loop would mark it cached; simulate the next render
  m1$cached <- TRUE
  m2 <- prepare_wasm_metadata("scales", m1)
  # desired (1.4.0) != stored (1.3.0) -> still a miss, repo still lagging
  expect_false(m2$cached)
  expect_equal(as.character(m2$ref), "scales@1.3.0")
})

test_that("cache self-heals once the repo catches up", {
  skip_on_cran()
  local_mocked_bindings(
    packageDescription = function(...) cran_desc("1.4.0"),
    .package = "utils"
  )
  # Repo now serves the desired version
  local_mocked_bindings(
    get_wasm_assets = function(desc, repo) wasm_asset("scales", "1.4.0")
  )

  prior <- list(
    name = "scales",
    version = "1.4.0",
    ref = "scales@1.3.0",
    cached = TRUE,
    type = "package"
  )
  m <- prepare_wasm_metadata("scales", prior)
  expect_false(m$cached) # re-download triggered
  expect_equal(as.character(m$ref), "scales@1.4.0")
})

test_that("stable cache hit when stored ref equals desired ref", {
  skip_on_cran()
  local_mocked_bindings(
    packageDescription = function(...) cran_desc("1.4.0"),
    .package = "utils"
  )
  # Must not hit the network on a cache hit
  local_mocked_bindings(
    get_wasm_assets = function(desc, repo) stop("should not re-download")
  )

  prior <- list(
    name = "scales",
    version = "1.4.0",
    ref = "scales@1.4.0",
    cached = TRUE,
    type = "package"
  )
  m <- prepare_wasm_metadata("scales", prior)
  expect_true(m$cached)
  expect_equal(as.character(m$ref), "scales@1.4.0")
})

test_that("a patch-level repo/local version mismatch never reaches a stable cache hit", {
  skip_on_cran()
  local_mocked_bindings(
    packageDescription = function(...) cran_desc("1.4.0"),
    .package = "utils"
  )
  # The repo serves a build whose version string differs only in patch from the
  # locally installed version (webR may patch packages at the repo). The stored
  # ref keys on the repo version, while the desired ref keys on the local one.
  local_mocked_bindings(
    get_wasm_assets = function(desc, repo) wasm_asset("scales", "1.4.0-1")
  )

  # First pass: miss, stores the repo's (patched) version as the ref.
  m1 <- prepare_wasm_metadata("scales", list())
  expect_false(m1$cached)
  expect_equal(as.character(m1$ref), "scales@1.4.0-1")

  # Next render: desired (local 1.4.0) still != stored (repo 1.4.0-1), so the
  # cache never stabilises to a hit even though the repo has not changed.
  m1$cached <- TRUE
  m2 <- prepare_wasm_metadata("scales", m1)
  expect_false(m2$cached)
  expect_equal(as.character(m2$ref), "scales@1.4.0-1")
})

test_that("package missing from the repo gets an NA ref and retries", {
  skip_on_cran()
  local_mocked_bindings(
    packageDescription = function(...) {
      list(Package = "ghost", Version = "1.0.0", Repository = "CRAN")
    },
    .package = "utils"
  )
  local_mocked_bindings(get_wasm_assets = function(desc, repo) list())

  m1 <- prepare_wasm_metadata("ghost", list())
  expect_length(m1$assets, 0)
  expect_true(is.na(m1$ref))

  # Next render: an NA stored ref must be treated as a miss (retry)
  m1$cached <- TRUE
  m2 <- prepare_wasm_metadata("ghost", m1)
  expect_false(m2$cached)
})

# Helpers for the download_wasm_packages() integration tests below.

seed_packages_dir <- function(destdir, stale_file, ref) {
  pkg_subdir <- fs::path(destdir, "shinylive", "webr", "packages", "scales")
  fs::dir_create(pkg_subdir, recurse = TRUE)
  fs::file_create(fs::path(pkg_subdir, stale_file))

  meta_file <- fs::path(
    destdir,
    "shinylive",
    "webr",
    "packages",
    "metadata.rds"
  )
  saveRDS(
    list(
      scales = list(
        name = "scales",
        version = "1.4.0",
        ref = ref,
        cached = TRUE,
        type = "package",
        path = glue::glue("packages/scales/{stale_file}")
      )
    ),
    meta_file
  )
  pkg_subdir
}

mock_download_env <- function(repo_version, downloaded) {
  local_mocked_bindings(
    packageDescription = function(...) cran_desc("1.4.0"),
    download.file = function(url, destfile, ...) {
      downloaded$called <- TRUE
      fs::file_create(destfile)
      invisible(0)
    },
    .package = "utils",
    .env = parent.frame()
  )
  local_mocked_bindings(
    dependencies = function(...) data.frame(Package = "scales"),
    .package = "renv",
    .env = parent.frame()
  )
  local_mocked_bindings(
    get_wasm_assets = function(desc, repo) {
      downloaded$queried <- TRUE
      wasm_asset("scales", repo_version)
    },
    resolve_dependencies = function(pkgs, local = TRUE) pkgs,
    .env = parent.frame()
  )
}

test_that("stale .tgz binaries are removed when the repo version changes", {
  skip_on_cran()
  withr::local_options(shinylive.quiet = TRUE)
  out <- withr::local_tempdir()
  pkg_subdir <- seed_packages_dir(out, "scales_1.3.0.tgz", "scales@1.3.0")

  downloaded <- new.env()
  mock_download_env(repo_version = "1.4.0", downloaded = downloaded)

  suppressMessages(download_wasm_packages(
    appdir = out,
    destdir = out,
    package_cache = TRUE,
    max_filesize = "100MB"
  ))

  files <- fs::path_file(fs::dir_ls(pkg_subdir, type = "file"))
  expect_false("scales_1.3.0.tgz" %in% files)
  expect_true("scales_1.4.0.tgz" %in% files)
  expect_true(isTRUE(downloaded$called))
})

test_that("matching binary is not re-downloaded while the repo lags", {
  skip_on_cran()
  withr::local_options(shinylive.quiet = TRUE)
  out <- withr::local_tempdir()
  pkg_subdir <- seed_packages_dir(out, "scales_1.3.0.tgz", "scales@1.3.0")

  downloaded <- new.env()
  # Repo still only serves 1.3.0, which is already on disk
  mock_download_env(repo_version = "1.3.0", downloaded = downloaded)

  suppressMessages(download_wasm_packages(
    appdir = out,
    destdir = out,
    package_cache = TRUE,
    max_filesize = "100MB"
  ))

  files <- fs::path_file(fs::dir_ls(pkg_subdir, type = "file"))
  expect_true("scales_1.3.0.tgz" %in% files)
  # The cheap repo re-query happened, but the binary was not re-downloaded
  expect_true(isTRUE(downloaded$queried))
  expect_false(isTRUE(downloaded$called))
})
