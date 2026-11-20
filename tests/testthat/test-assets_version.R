test_that("parse_assets_version() handles each kind", {
  expect_equal(parse_assets_version("0.10.16")$kind, "exact")
  expect_equal(parse_assets_version("0.10.16")$prefix, c(0L, 10L, 16L))
  expect_equal(parse_assets_version("0.10.*")$kind, "pattern")
  expect_equal(parse_assets_version("0.10.*")$prefix, c(0L, 10L))
  expect_equal(parse_assets_version("0.*")$prefix, 0L)
  expect_equal(parse_assets_version("latest")$kind, "latest")
  expect_equal(parse_assets_version("latest")$prefix, integer(0))
})

test_that("parse_assets_version() rejects invalid input", {
  bad <- c("", "0.10.x", "*", "0.*.1", "0.10.**", "v0.10.16", "latest*")
  for (x in bad) {
    expect_error(parse_assets_version(x), "assets version")
  }
  expect_error(parse_assets_version(c("0.10.16", "0.10.17")), "assets version")
  expect_error(parse_assets_version(NA_character_), "assets version")
  expect_error(parse_assets_version(NULL), "assets version")
})

test_that("assets_version_matches() matches patterns by series", {
  versions <- c("0.9.0", "0.10.1", "0.10.16", "0.11.0", "1.0.0", "dev")
  expect_equal(
    assets_version_matches(versions, parse_assets_version("0.10.*")),
    c(FALSE, TRUE, TRUE, FALSE, FALSE, FALSE)
  )
  expect_equal(
    assets_version_matches(versions, parse_assets_version("0.*")),
    c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE)
  )
  expect_equal(
    assets_version_matches(versions, parse_assets_version("latest")),
    c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE)
  )
  expect_equal(
    assets_version_matches(versions, parse_assets_version("0.10.16")),
    c(FALSE, FALSE, TRUE, FALSE, FALSE, FALSE)
  )
  expect_equal(
    assets_version_matches(character(0), parse_assets_version("0.*")),
    logical(0)
  )
})

test_that("assets_version_matches() does not match a shorter version", {
  # "0.10" has no third part, so it isn't in the "0.10.1.*" series
  expect_false(
    assets_version_matches("0.10", parse_assets_version("0.10.1.*"))
  )
})

# versions.json -----------------------------------------------------------

now <- as.POSIXct("2026-11-20 12:00:00", tz = "UTC")

versions_info <- function(hours_ago, ..., error = NULL) {
  info <- list(
    checked_at = now - hours_ago * 3600,
    latest = "0.10.16",
    versions = c("0.10.16", "0.10.15")
  )
  info$error <- error
  utils::modifyList(info, list(...))
}

test_that("write/read versions.json round-trips without leftover files", {
  dir <- withr::local_tempdir()
  write_versions_json(versions_info(0), dir)

  info <- read_versions_json(dir)
  expect_equal(info$versions, c("0.10.16", "0.10.15"))
  expect_equal(info$latest, "0.10.16")
  expect_equal(info$checked_at, now)
  expect_null(info$error)
  expect_equal(basename(fs::dir_ls(dir)), "versions.json")
})

test_that("a single release is stored as a list, not a string", {
  dir <- withr::local_tempdir()
  write_versions_json(versions_info(0, versions = "0.10.16"), dir)
  expect_match(
    paste(readLines(versions_json_path(dir)), collapse = ""),
    '"versions": \\["0.10.16"\\]'
  )
  expect_equal(read_versions_json(dir)$versions, "0.10.16")
})

test_that("missing or invalid versions.json reads as NULL", {
  dir <- withr::local_tempdir()
  expect_null(read_versions_json(dir))

  writeLines("{not json", versions_json_path(dir))
  expect_null(read_versions_json(dir))

  writeLines('{"checked_at": "yesterday"}', versions_json_path(dir))
  expect_null(read_versions_json(dir))
})

test_that("versions_check_due() follows the 24 hour and 1 hour rules", {
  expect_true(versions_check_due(NULL, now))
  expect_false(versions_check_due(versions_info(23), now))
  expect_true(versions_check_due(versions_info(25), now))
  expect_false(versions_check_due(versions_info(0.5, error = "offline"), now))
  expect_true(versions_check_due(versions_info(2, error = "offline"), now))
  # A check time in the future means the clock changed
  expect_true(versions_check_due(versions_info(-1), now))
})

test_that("a fresh check skips the network unless forced", {
  dir <- withr::local_tempdir()
  write_versions_json(versions_info(1), dir)
  local_mocked_bindings(
    fetch_latest_assets_version = function() stop("network used"),
    fetch_assets_versions = function() stop("network used")
  )
  expect_equal(update_versions_info(dir, now = now)$checked_at, now - 3600)

  local_mocked_bindings(fetch_latest_assets_version = function() "0.10.16")
  expect_equal(update_versions_info(dir, force = TRUE, now = now)$checked_at, now)
})

test_that("an unchanged latest tag skips the release list", {
  dir <- withr::local_tempdir()
  write_versions_json(versions_info(25), dir)
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.10.16",
    fetch_assets_versions = function() stop("should not be called")
  )
  info <- update_versions_info(dir, now = now)
  expect_equal(info$checked_at, now)
  expect_equal(info$versions, c("0.10.16", "0.10.15"))
  expect_equal(read_versions_json(dir)$checked_at, now)
})

test_that("a changed latest tag refreshes the release list", {
  dir <- withr::local_tempdir()
  write_versions_json(versions_info(25, error = "old failure"), dir)
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.11.0",
    fetch_assets_versions = function() c("0.11.0", "0.10.17", "0.10.16")
  )
  info <- update_versions_info(dir, now = now)
  expect_equal(info$latest, "0.11.0")
  expect_equal(info$versions, c("0.11.0", "0.10.17", "0.10.16"))
  expect_null(info$error)
  expect_equal(read_versions_json(dir), info)
})

test_that("a missing file fetches the release list", {
  dir <- withr::local_tempdir()
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.10.16",
    fetch_assets_versions = function() c("0.10.16", "0.10.15")
  )
  info <- update_versions_info(dir, now = now)
  expect_equal(info$versions, c("0.10.16", "0.10.15"))
  expect_equal(info$latest, "0.10.16")
})

test_that("a failed latest check records the error and keeps old data", {
  dir <- withr::local_tempdir()
  write_versions_json(versions_info(25), dir)
  local_mocked_bindings(
    fetch_latest_assets_version = function() stop("Could not resolve host")
  )
  info <- update_versions_info(dir, now = now)
  expect_match(info$error, "Could not resolve host")
  expect_equal(info$versions, c("0.10.16", "0.10.15"))
  expect_equal(info$latest, "0.10.16")
  expect_equal(read_versions_json(dir)$checked_at, now)
})

test_that("a failed release list keeps the old latest and versions", {
  dir <- withr::local_tempdir()
  write_versions_json(versions_info(25), dir)
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.11.0",
    fetch_assets_versions = function() stop("HTTP 403 rate limit exceeded")
  )
  info <- update_versions_info(dir, now = now)
  expect_match(info$error, "403")
  expect_equal(info$latest, "0.10.16")
  expect_equal(info$versions, c("0.10.16", "0.10.15"))
})

test_that("a failed check with no file still records the error", {
  dir <- withr::local_tempdir()
  local_mocked_bindings(fetch_latest_assets_version = function() stop("offline"))
  info <- update_versions_info(dir, now = now)
  expect_equal(info$versions, character(0))
  expect_null(info$latest)
  expect_match(read_versions_json(dir)$error, "offline")
})

test_that("an invalid versions.json is rewritten", {
  dir <- withr::local_tempdir()
  writeLines("{not json", versions_json_path(dir))
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.10.16",
    fetch_assets_versions = function() "0.10.16"
  )
  update_versions_info(dir, now = now)
  expect_equal(read_versions_json(dir)$versions, "0.10.16")
})

test_that("the fetchers refuse to use the network during CRAN checks", {
  withr::local_envvar(TESTTHAT = "true", NOT_CRAN = "false")
  expect_error(fetch_latest_assets_version(), "CRAN")
  expect_error(fetch_assets_versions(), "CRAN")
})

test_that("latest_tag_version() reads the version from a release URL", {
  expect_equal(
    latest_tag_version(
      "https://github.com/posit-dev/shinylive/releases/tag/v0.10.16"
    ),
    "0.10.16"
  )
  expect_error(
    latest_tag_version("https://github.com/posit-dev/shinylive/releases"),
    "latest"
  )
})

# Resolving a version -----------------------------------------------------

local_resolve_env <- function(
  dir,
  versions = NULL,
  hours_ago = 1,
  download = function(version, ..., dir) {
    fs::dir_create(fs::path(dir, paste0("shinylive-", version)))
  },
  env = parent.frame()
) {
  withr::local_envvar(SHINYLIVE_ASSETS_VERSION = NA, .local_envir = env)
  assets_version_reset()
  withr::defer(assets_version_reset(), envir = env)
  if (!is.null(versions)) {
    write_versions_json(
      list(
        checked_at = now - hours_ago * 3600,
        latest = versions[1],
        versions = versions
      ),
      dir
    )
  }
  downloaded <- character(0)
  local_mocked_bindings(
    fetch_latest_assets_version = function() stop("offline"),
    fetch_assets_versions = function() stop("offline"),
    assets_download = function(version, ..., dir) {
      downloaded <<- c(downloaded, version)
      download(version, dir = dir)
      invisible(dir)
    },
    .env = env
  )
  function() downloaded
}

add_local_assets <- function(dir, versions) {
  fs::dir_create(fs::path(dir, paste0("shinylive-", versions)))
}

test_that("exported formals use SHINYLIVE_ASSETS_VERSION_DEFAULT", {
  expect_equal(
    formals(export)$assets_version,
    SHINYLIVE_ASSETS_VERSION_DEFAULT
  )
  expect_equal(
    formals(assets_download)$version,
    SHINYLIVE_ASSETS_VERSION_DEFAULT
  )
  expect_equal(formals(assets_ensure)$version, SHINYLIVE_ASSETS_VERSION_DEFAULT)
})

test_that("the default and fallback versions agree", {
  expect_true(assets_version_matches(
    SHINYLIVE_ASSETS_VERSION_FALLBACK,
    parse_assets_version(SHINYLIVE_ASSETS_VERSION_DEFAULT)
  ))
})

test_that("a pattern resolves to the highest matching release and downloads it", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir, c("0.11.0", "0.10.17", "0.10.16"))
  add_local_assets(dir, "0.10.16")

  expect_equal(resolve_assets_version("0.10.*", dir = dir, now = now), "0.10.17")
  expect_equal(downloaded(), "0.10.17")
})

test_that("a downloaded version newer than the list is used", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir, c("0.10.16"))
  add_local_assets(dir, c("0.10.16", "0.10.18"))

  expect_equal(resolve_assets_version("0.10.*", dir = dir, now = now), "0.10.18")
  expect_equal(downloaded(), character(0))
})

test_that("offline with a newer release not downloaded uses the downloaded one", {
  dir <- withr::local_tempdir()
  local_resolve_env(
    dir,
    c("0.10.17", "0.10.16"),
    download = function(...) stop("Could not resolve host")
  )
  add_local_assets(dir, "0.10.16")

  expect_warning(
    v <- resolve_assets_version("0.10.*", dir = dir, now = now),
    "0.10.16"
  )
  expect_equal(v, "0.10.16")
})

test_that("offline with nothing downloaded errors clearly", {
  dir <- withr::local_tempdir()
  local_resolve_env(dir, download = function(...) stop("Could not resolve host"))

  expect_error(
    resolve_assets_version("0.10.*", dir = dir, now = now),
    "online"
  )
})

test_that("no known match uses the fallback version", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir)

  expect_equal(
    resolve_assets_version("0.10.*", dir = dir, now = now),
    SHINYLIVE_ASSETS_VERSION_FALLBACK
  )
  expect_equal(downloaded(), SHINYLIVE_ASSETS_VERSION_FALLBACK)
})

test_that("no match and no matching fallback errors with the known versions", {
  dir <- withr::local_tempdir()
  local_resolve_env(dir, c("0.10.17", "0.10.16"))

  expect_error(
    resolve_assets_version("0.12.*", dir = dir, now = now),
    "0.10.17"
  )
})

test_that("'latest' checks GitHub even when the list is fresh", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir, c("0.10.16"))
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.11.0",
    fetch_assets_versions = function() c("0.11.0", "0.10.16")
  )

  expect_equal(resolve_assets_version("latest", dir = dir, now = now), "0.11.0")
  expect_equal(downloaded(), "0.11.0")
})

test_that("resolution is remembered for the R session", {
  dir <- withr::local_tempdir()
  local_resolve_env(dir, c("0.10.16"))
  calls <- 0
  local_mocked_bindings(
    fetch_latest_assets_version = function() {
      calls <<- calls + 1
      "0.10.16"
    }
  )

  resolve_assets_version("latest", dir = dir, now = now)
  resolve_assets_version("latest", dir = dir, now = now)
  expect_equal(calls, 1)

  assets_version_reset()
  resolve_assets_version("latest", dir = dir, now = now)
  expect_equal(calls, 2)
})

test_that("resolution can skip the download", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir, c("0.10.17", "0.10.16"))

  expect_equal(
    resolve_assets_version("0.10.*", dir = dir, now = now, download = FALSE),
    "0.10.17"
  )
  expect_equal(downloaded(), character(0))
})

test_that("exact versions are returned as is and warn outside the default", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir)

  expect_equal(resolve_assets_version("0.10.16", dir = dir), "0.10.16")
  expect_warning(resolve_assets_version("0.9.0", dir = dir), "0\\.10\\.\\*")
  # Only once per session
  expect_no_warning(resolve_assets_version("0.9.0", dir = dir))
  expect_equal(downloaded(), character(0))
})

test_that("assets_version_input() prefers explicit, then env var, then default", {
  withr::local_envvar(SHINYLIVE_ASSETS_VERSION = NA)
  expect_equal(assets_version_input("0.10.1", FALSE), "0.10.1")
  expect_equal(assets_version_input(NULL, FALSE), SHINYLIVE_ASSETS_VERSION_DEFAULT)
  expect_equal(
    assets_version_input("0.10.*", TRUE),
    SHINYLIVE_ASSETS_VERSION_DEFAULT
  )

  withr::local_envvar(SHINYLIVE_ASSETS_VERSION = "0.10.5")
  expect_equal(assets_version_input("0.10.*", TRUE), "0.10.5")
  expect_equal(assets_version_input(NULL, FALSE), "0.10.5")
  expect_equal(assets_version_input("0.10.1", FALSE), "0.10.1")
})

test_that("assets_version() resolves the default in the cache dir", {
  dir <- withr::local_tempdir()
  local_resolve_env(dir, c("0.10.17", "0.10.16"))
  local_mocked_bindings(assets_cache_dir = function() dir)

  expect_equal(assets_version(), "0.10.17")

  assets_version_reset()
  withr::local_envvar(SHINYLIVE_ASSETS_VERSION = "0.10.16")
  expect_equal(assets_version(), "0.10.16")
})

test_that("assets_ensure() resolves a pattern before downloading", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir, c("0.10.17", "0.10.16"))

  path <- assets_ensure(dir = dir)
  expect_equal(path, fs::path(dir, "shinylive-0.10.17"))
  expect_equal(downloaded(), "0.10.17")
})
