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
    get_wasm_assets = function(desc, repo, r_version) {
      wasm_asset("scales", "1.3.0")
    }
  )

  # First pass: no prior cache -> miss, stores the DOWNLOADED version as the ref
  m1 <- prepare_wasm_metadata("scales", list(), "4.6.0")
  expect_false(m1$cached)
  expect_equal(as.character(m1$ref), "scales@1.3.0")

  # The download loop would mark it cached; simulate the next render
  m1$cached <- TRUE
  m2 <- prepare_wasm_metadata("scales", m1, "4.6.0")
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
    get_wasm_assets = function(desc, repo, r_version) {
      wasm_asset("scales", "1.4.0")
    }
  )

  prior <- list(
    name = "scales",
    version = "1.4.0",
    ref = "scales@1.3.0",
    cached = TRUE,
    type = "package"
  )
  m <- prepare_wasm_metadata("scales", prior, "4.6.0")
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
    get_wasm_assets = function(desc, repo, r_version) {
      stop("should not re-download")
    }
  )

  prior <- list(
    name = "scales",
    version = "1.4.0",
    ref = "scales@1.4.0",
    cached = TRUE,
    type = "package"
  )
  m <- prepare_wasm_metadata("scales", prior, "4.6.0")
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
    get_wasm_assets = function(desc, repo, r_version) {
      wasm_asset("scales", "1.4.0-1")
    }
  )

  # First pass: miss, stores the repo's (patched) version as the ref.
  m1 <- prepare_wasm_metadata("scales", list(), "4.6.0")
  expect_false(m1$cached)
  expect_equal(as.character(m1$ref), "scales@1.4.0-1")

  # Next render: desired (local 1.4.0) still != stored (repo 1.4.0-1), so the
  # cache never stabilises to a hit even though the repo has not changed.
  m1$cached <- TRUE
  m2 <- prepare_wasm_metadata("scales", m1, "4.6.0")
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
  local_mocked_bindings(get_wasm_assets = function(desc, repo, r_version) {
    list()
  })

  m1 <- prepare_wasm_metadata("ghost", list(), "4.6.0")
  expect_length(m1$assets, 0)
  expect_true(is.na(m1$ref))

  # Next render: an NA stored ref must be treated as a miss (retry)
  m1$cached <- TRUE
  m2 <- prepare_wasm_metadata("ghost", m1, "4.6.0")
  expect_false(m2$cached)
})

# Helpers for the download_wasm_packages() integration tests below.

seed_packages_dir <- function(destdir, stale_file, ref, r_version = "4.6.0") {
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
        path = glue::glue("packages/scales/{stale_file}"),
        "_webr_r_version" = r_version
      )
    ),
    meta_file
  )
  pkg_subdir
}

mock_download_env <- function(
  repo_version,
  downloaded,
  env = parent.frame()
) {
  local_mocked_bindings(
    packageDescription = function(...) cran_desc("1.4.0"),
    download.file = function(url, destfile, ...) {
      downloaded$called <- TRUE
      fs::file_create(destfile)
      invisible(0)
    },
    .package = "utils",
    .env = env
  )
  local_mocked_bindings(
    dependencies = function(...) data.frame(Package = "scales"),
    .package = "renv",
    .env = env
  )
  local_mocked_bindings(
    get_wasm_assets = function(desc, repo, r_version) {
      downloaded$queried <- TRUE
      wasm_asset("scales", repo_version)
    },
    resolve_dependencies = function(pkgs, local = TRUE) pkgs,
    .env = env
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
    max_filesize = "100MB",
    r_version = "4.6.0"
  ))

  files <- fs::path_file(fs::dir_ls(pkg_subdir, type = "file"))
  expect_false("scales_1.3.0.tgz" %in% files)
  expect_true("scales_1.4.0.tgz" %in% files)
  expect_true(isTRUE(downloaded$called))
})

test_that("`webr` is never downloaded, whether used directly or as a dependency", {
  skip_on_cran()
  withr::local_options(shinylive.quiet = TRUE)
  # Even when listed here, the built-in `webr` must not be swapped for CRAN's
  withr::local_envvar(SHINYLIVE_DOWNLOAD_WASM_CORE_PACKAGES = "webr")
  out <- withr::local_tempdir()

  downloaded <- new.env()
  mock_download_env(repo_version = "1.4.0", downloaded = downloaded)
  # The app calls `webr::install()`, and `scales` resolves to also need `webr`
  local_mocked_bindings(
    dependencies = function(...) data.frame(Package = c("scales", "webr")),
    .package = "renv"
  )
  local_mocked_bindings(
    resolve_dependencies = function(pkgs, local = TRUE) {
      if ("scales" %in% pkgs) unique(c(pkgs, "webr")) else pkgs
    }
  )

  suppressMessages(download_wasm_packages(
    appdir = out,
    destdir = out,
    package_cache = TRUE,
    max_filesize = "100MB",
    r_version = "4.6.0"
  ))

  pkg_dir <- fs::path(out, "shinylive", "webr", "packages")
  metadata <- readRDS(fs::path(pkg_dir, "metadata.rds"))
  expect_equal(names(metadata), "scales")
  expect_false(fs::dir_exists(fs::path(pkg_dir, "webr")))
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
    max_filesize = "100MB",
    r_version = "4.6.0"
  ))

  files <- fs::path_file(fs::dir_ls(pkg_subdir, type = "file"))
  expect_true("scales_1.3.0.tgz" %in% files)
  # The cheap repo re-query happened, but the binary was not re-downloaded
  expect_true(isTRUE(downloaded$queried))
  expect_false(isTRUE(downloaded$called))
})

test_that("binaries from another R version are deleted and re-downloaded", {
  skip_on_cran()
  withr::local_options(shinylive.quiet = TRUE)
  out <- withr::local_tempdir()
  # Same file name, but built for R 4.5
  pkg_subdir <- seed_packages_dir(
    out,
    "scales_1.4.0.tgz",
    "scales@1.4.0",
    r_version = "4.5.0"
  )

  downloaded <- new.env()
  mock_download_env(repo_version = "1.4.0", downloaded = downloaded)

  suppressMessages(download_wasm_packages(
    appdir = out,
    destdir = out,
    package_cache = TRUE,
    max_filesize = "100MB",
    r_version = "4.6.0"
  ))

  expect_true(isTRUE(downloaded$called))
  expect_true(fs::file_exists(fs::path(pkg_subdir, "scales_1.4.0.tgz")))
  metadata <- readRDS(fs::path(
    out,
    "shinylive",
    "webr",
    "packages",
    "metadata.rds"
  ))
  expect_equal(metadata$scales[["_webr_r_version"]], "4.6.0")
})

test_that("old metadata without an R version is not reused", {
  skip_on_cran()
  withr::local_options(shinylive.quiet = TRUE)
  out <- withr::local_tempdir()
  seed_packages_dir(out, "scales_1.4.0.tgz", "scales@1.4.0", r_version = NULL)

  downloaded <- new.env()
  mock_download_env(repo_version = "1.4.0", downloaded = downloaded)

  suppressMessages(download_wasm_packages(
    appdir = out,
    destdir = out,
    package_cache = TRUE,
    max_filesize = "100MB",
    r_version = "4.6.0"
  ))

  expect_true(isTRUE(downloaded$called))
})

test_that("the Wasm repo URL follows the given R version", {
  expect_equal(
    as.character(wasm_contrib_url("https://repo.r-wasm.org", "4.7.1")),
    "https://repo.r-wasm.org/bin/emscripten/contrib/4.7"
  )
})

test_that("prepare_wasm_metadata() passes the R version to the repo lookup", {
  skip_on_cran()
  local_mocked_bindings(
    packageDescription = function(...) cran_desc("1.4.0"),
    .package = "utils"
  )
  seen <- NULL
  local_mocked_bindings(
    get_wasm_assets = function(desc, repo, r_version) {
      seen <<- r_version
      wasm_asset("scales", "1.4.0")
    }
  )

  prepare_wasm_metadata("scales", list(), "4.7.0")
  expect_equal(seen, "4.7.0")
})

test_that("parse_max_filesize() turns the limit off for NA, Inf, and negatives", {
  for (x in list(
    NA,
    NA_character_,
    Inf,
    -1,
    "NA",
    "Inf",
    "inf",
    "-1",
    " -1 "
  )) {
    expect_equal(as.numeric(parse_max_filesize(x)), Inf, info = format(x))
  }
})

test_that("parse_max_filesize() parses sizes and warns on bad values", {
  expect_equal(parse_max_filesize("100MB"), fs::fs_bytes("100MB"))
  expect_equal(parse_max_filesize(" 1K "), fs::fs_bytes("1K"))
  expect_equal(parse_max_filesize(2048), fs::fs_bytes(2048))
  for (x in c("", "+1GB", "abc")) {
    expect_warning(
      out <- parse_max_filesize(x),
      "Could not parse",
      info = x
    )
    expect_equal(out, fs::fs_bytes(SHINYLIVE_DEFAULT_MAX_FILESIZE))
  }
})

test_that("parse_max_filesize() needs a single value", {
  for (x in list(c(1, 2), character(0), list("1MB"))) {
    expect_error(
      parse_max_filesize(x),
      "must be a single number or string",
      info = format(x)
    )
  }
})

local_size_limit_env <- function(downloaded, env = parent.frame()) {
  withr::local_options(shinylive.quiet = TRUE, .local_envir = env)
  withr::local_envvar(SHINYLIVE_DEFAULT_MAX_FILESIZE = NA, .local_envir = env)
  mock_download_env(repo_version = "1.4.0", downloaded = downloaded, env = env)
  # Every downloaded binary is 101 bytes. `writeBin()` avoids the extra byte
  # that `writeLines()` adds on Windows (CRLF).
  local_mocked_bindings(
    download.file = function(url, destfile, ...) {
      downloaded$called <- TRUE
      writeBin(charToRaw(strrep("x", 101)), destfile)
      invisible(0)
    },
    .package = "utils",
    .env = env
  )
}

download_scales <- function(out, max_filesize) {
  download_wasm_packages(
    appdir = out,
    destdir = out,
    package_cache = TRUE,
    max_filesize = max_filesize,
    r_version = "4.6.0"
  )
  readRDS(fs::path(out, "shinylive", "webr", "packages", "metadata.rds"))$scales
}

test_that("a package dropped for its size is only tried again once it fits", {
  skip_on_cran()
  out <- withr::local_tempdir()
  downloaded <- new.env()
  local_size_limit_env(downloaded)
  local_mocked_bindings(SHINYLIVE_DEFAULT_MAX_FILESIZE = "10B")
  binary <- fs::path(out, "shinylive", "webr", "packages", "scales")

  expect_warning(meta <- download_scales(out, NULL), "larger than the maximum")
  expect_true(meta$cached)
  expect_equal(meta$dropped_size, 101)
  expect_length(meta$assets, 0)

  # The same limit: no download, but the warning shows again
  downloaded$called <- FALSE
  expect_warning(meta <- download_scales(out, NULL), "larger than the maximum")
  expect_false(downloaded$called)
  expect_equal(meta$dropped_size, 101)

  # A larger limit downloads it
  meta <- download_scales(out, "1MB")
  expect_true(downloaded$called)
  expect_true(meta$cached)
  expect_null(meta$dropped_size)
  expect_equal(as.character(meta$path), "packages/scales/scales_1.4.0.tgz")
  expect_true(fs::file_exists(fs::path(binary, "scales_1.4.0.tgz")))
})

test_that("a cached package over a smaller limit is dropped", {
  skip_on_cran()
  out <- withr::local_tempdir()
  downloaded <- new.env()
  local_size_limit_env(downloaded)
  binary <- fs::path(out, "shinylive", "webr", "packages", "scales")
  download_scales(out, "1MB")

  # A limit you set yourself is an error, and nothing changes on disk
  downloaded$called <- FALSE
  expect_error(download_scales(out, "50B"), "larger than the maximum")
  expect_false(downloaded$called)
  expect_true(fs::file_exists(fs::path(binary, "scales_1.4.0.tgz")))
  meta_file <- fs::path(out, "shinylive", "webr", "packages", "metadata.rds")
  expect_length(readRDS(meta_file)$scales$assets, 1)

  # The default limit warns and drops it
  local_mocked_bindings(SHINYLIVE_DEFAULT_MAX_FILESIZE = "50B")
  expect_warning(meta <- download_scales(out, NULL), "larger than the maximum")
  expect_false(downloaded$called)
  expect_false(fs::dir_exists(binary))
  expect_length(meta$assets, 0)
  expect_null(meta$path)
  expect_equal(meta$dropped_size, 101)
})
