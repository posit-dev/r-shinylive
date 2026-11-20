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
