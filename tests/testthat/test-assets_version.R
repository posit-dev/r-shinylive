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
  expect_equal(
    check_versions_info(read_versions_json(dir), now = now)$checked_at,
    now - 3600
  )

  local_mocked_bindings(fetch_latest_assets_version = function() "0.10.16")
  expect_equal(
    check_versions_info(
      read_versions_json(dir),
      force = TRUE,
      now = now
    )$checked_at,
    now
  )
})

test_that("an unchanged latest tag skips the release list", {
  dir <- withr::local_tempdir()
  write_versions_json(versions_info(25), dir)
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.10.16",
    fetch_assets_versions = function() stop("should not be called")
  )
  info <- check_versions_info(read_versions_json(dir), now = now)
  expect_equal(info$checked_at, now)
  expect_equal(info$versions, c("0.10.16", "0.10.15"))
  # The check alone saves nothing
  expect_equal(read_versions_json(dir)$checked_at, now - 25 * 3600)
})

test_that("a changed latest tag refreshes the release list", {
  dir <- withr::local_tempdir()
  write_versions_json(versions_info(25, error = "old failure"), dir)
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.11.0",
    fetch_assets_versions = function() c("0.11.0", "0.10.17", "0.10.16")
  )
  info <- check_versions_info(read_versions_json(dir), now = now)
  expect_equal(info$latest, "0.11.0")
  expect_equal(info$versions, c("0.11.0", "0.10.17", "0.10.16"))
  expect_null(info$error)
  expect_equal(read_versions_json(dir)$latest, "0.10.16")
})

test_that("a missing file fetches the release list", {
  dir <- withr::local_tempdir()
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.10.16",
    fetch_assets_versions = function() c("0.10.16", "0.10.15")
  )
  info <- check_versions_info(read_versions_json(dir), now = now)
  expect_equal(info$versions, c("0.10.16", "0.10.15"))
  expect_equal(info$latest, "0.10.16")
})

test_that("a failed latest check records the error and keeps old data", {
  dir <- withr::local_tempdir()
  write_versions_json(versions_info(25), dir)
  local_mocked_bindings(
    fetch_latest_assets_version = function() stop("Could not resolve host")
  )
  info <- check_versions_info(read_versions_json(dir), now = now)
  expect_match(info$error, "Could not resolve host")
  expect_equal(info$versions, c("0.10.16", "0.10.15"))
  expect_equal(info$latest, "0.10.16")
  # The check alone saves nothing
  expect_equal(read_versions_json(dir)$checked_at, now - 25 * 3600)
})

test_that("a failed release list keeps the old latest and versions", {
  dir <- withr::local_tempdir()
  write_versions_json(versions_info(25), dir)
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.11.0",
    fetch_assets_versions = function() stop("HTTP 403 rate limit exceeded")
  )
  info <- check_versions_info(read_versions_json(dir), now = now)
  expect_match(info$error, "403")
  expect_equal(info$latest, "0.10.16")
  # The newly seen latest tag is added to the known versions
  expect_equal(info$versions, c("0.11.0", "0.10.16", "0.10.15"))
})

test_that("a failed check with no file still records the error", {
  dir <- withr::local_tempdir()
  local_mocked_bindings(fetch_latest_assets_version = function() {
    stop("offline")
  })
  info <- check_versions_info(read_versions_json(dir), now = now)
  expect_equal(info$versions, character(0))
  expect_null(info$latest)
  expect_match(info$error, "offline")
  expect_null(read_versions_json(dir))
})

test_that("an invalid versions.json runs a new check", {
  dir <- withr::local_tempdir()
  writeLines("{not json", versions_json_path(dir))
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.10.16",
    fetch_assets_versions = function() "0.10.16"
  )
  info <- check_versions_info(read_versions_json(dir), now = now)
  expect_equal(info$versions, "0.10.16")
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

  expect_equal(
    resolve_assets_version("0.10.*", dir = dir, now = now),
    "0.10.17"
  )
  expect_equal(downloaded(), "0.10.17")
})

test_that("a downloaded version newer than the list is used", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir, c("0.10.16"))
  add_local_assets(dir, c("0.10.16", "0.10.18"))

  expect_equal(
    resolve_assets_version("0.10.*", dir = dir, now = now),
    "0.10.18"
  )
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
  local_resolve_env(dir, download = function(...) {
    stop("Could not resolve host")
  })

  expect_warning(
    expect_error(
      resolve_assets_version("0.10.*", dir = dir, now = now),
      "online"
    ),
    "may not be the newest"
  )
})

test_that("no known match uses the fallback version", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir)

  expect_warning(
    v <- resolve_assets_version("0.10.*", dir = dir, now = now),
    "may not be the newest"
  )
  expect_equal(v, SHINYLIVE_ASSETS_VERSION_FALLBACK)
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
  expect_equal(assets_version_input("0.10.1"), "0.10.1")
  expect_equal(assets_version_input(NULL), SHINYLIVE_ASSETS_VERSION_DEFAULT)

  withr::local_envvar(SHINYLIVE_ASSETS_VERSION = "0.10.5")
  expect_equal(assets_version_input(NULL), "0.10.5")
  expect_equal(assets_version_input("0.10.1"), "0.10.1")
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

test_that("an empty SHINYLIVE_ASSETS_VERSION is treated as unset", {
  withr::local_envvar(SHINYLIVE_ASSETS_VERSION = "")
  expect_equal(
    assets_version_input(NULL),
    SHINYLIVE_ASSETS_VERSION_DEFAULT
  )
})

# Review fixes ------------------------------------------------------------

test_that("a read-only cache does not stop resolution", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir)
  add_local_assets(dir, "0.10.16")
  local_mocked_bindings(
    write_versions_json = function(...) stop("cannot open the connection")
  )

  expect_warning(
    v <- resolve_assets_version("0.10.*", dir = dir, now = now),
    "may not be the newest"
  )
  expect_equal(v, "0.10.16")
})

test_that("a newly seen latest tag is kept when the release list fails", {
  dir <- withr::local_tempdir()
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.10.17",
    fetch_assets_versions = function() stop("HTTP 403 rate limit exceeded")
  )
  info <- check_versions_info(read_versions_json(dir), now = now)
  expect_match(info$error, "403")
  expect_true("0.10.17" %in% info$versions)
  # Not stored as `latest`, so the next check fetches the full list
  expect_null(info$latest)
})

test_that("a failed download with nothing downloaded tries the fallback", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(
    dir,
    c("0.10.17", SHINYLIVE_ASSETS_VERSION_FALLBACK),
    download = function(version, dir) {
      if (version == "0.10.17") {
        stop("HTTP 404 Not Found")
      }
      fs::dir_create(fs::path(dir, paste0("shinylive-", version)))
    }
  )

  expect_warning(
    v <- resolve_assets_version("0.10.*", dir = dir, now = now),
    "0.10.17"
  )
  expect_equal(v, SHINYLIVE_ASSETS_VERSION_FALLBACK)
  expect_equal(downloaded(), c("0.10.17", SHINYLIVE_ASSETS_VERSION_FALLBACK))
})

test_that("a failed check with no listed match warns the pick may be old", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir)
  # The latest tag was seen, but the release list was rate limited
  write_versions_json(
    list(
      checked_at = now - 2 * 3600,
      latest = NULL,
      versions = "0.11.0",
      error = "HTTP 403 rate limit exceeded"
    ),
    dir
  )

  expect_warning(
    v <- resolve_assets_version("0.10.*", dir = dir, now = now),
    "may not be the newest"
  )
  expect_equal(v, SHINYLIVE_ASSETS_VERSION_FALLBACK)
})

test_that("a failed check with a listed match does not warn", {
  dir <- withr::local_tempdir()
  local_resolve_env(dir)
  write_versions_json(
    list(
      checked_at = now - 2 * 3600,
      latest = "0.10.17",
      versions = c("0.10.17", "0.10.16"),
      error = "Could not resolve host"
    ),
    dir
  )
  add_local_assets(dir, "0.10.17")

  expect_no_warning(
    expect_equal(
      resolve_assets_version("0.10.*", dir = dir, now = now),
      "0.10.17"
    )
  )
})

test_that("check = FALSE reads versions.json without the network", {
  dir <- withr::local_tempdir()
  local_resolve_env(dir, c("0.10.17", "0.10.16"), hours_ago = 48)
  local_mocked_bindings(
    fetch_latest_assets_version = function() stop("must not check")
  )

  expect_equal(
    resolve_assets_version(
      "0.10.*",
      dir = dir,
      now = now,
      download = FALSE,
      check = FALSE
    ),
    "0.10.17"
  )
})

test_that("assets_bundle_url() resolves a series", {
  dir <- withr::local_tempdir()
  local_resolve_env(dir, c("0.10.17", "0.10.16"))

  expect_equal(
    assets_bundle_url("0.10.*", dir = dir),
    assets_bundle_url("0.10.17")
  )
})

test_that("'latest' warns when its check fails", {
  dir <- withr::local_tempdir()
  local_resolve_env(dir, c("0.10.17", "0.10.16"))
  add_local_assets(dir, "0.10.17")

  expect_warning(
    v <- resolve_assets_version("latest", dir = dir, now = now),
    "may not be the newest"
  )
  expect_equal(v, "0.10.17")
})

test_that("the check is skipped during CRAN checks", {
  dir <- withr::local_tempdir()
  withr::local_envvar(TESTTHAT = "true", NOT_CRAN = "false")
  local_mocked_bindings(
    fetch_latest_assets_version = function() stop("must not check")
  )

  expect_null(check_versions_info(
    read_versions_json(dir),
    force = TRUE,
    now = now
  ))
  expect_false(fs::file_exists(versions_json_path(dir)))
})

test_that("warn = FALSE skips the outside-default warning", {
  dir <- withr::local_tempdir()
  local_resolve_env(dir)

  expect_no_warning(resolve_assets_version("0.9.0", dir = dir, warn = FALSE))
})

test_that("assets_bundle_url() and check_assets_url() do not download", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir, c("0.10.17", "0.10.16"))
  local_mocked_bindings(assets_cache_dir = function() dir)
  local_mocked_bindings(
    req_perform = function(req, ...) {
      structure(list(status_code = 200L), class = "httr2_response")
    },
    resp_status = function(resp) 200L,
    .package = "httr2"
  )

  expect_equal(assets_bundle_url(), assets_bundle_url("0.10.17"))
  expect_true(check_assets_url())
  expect_equal(downloaded(), character(0))
})

test_that("quarto_ext info downloads the assets it reports", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir, c("0.10.17", "0.10.16"))
  local_mocked_bindings(assets_cache_dir = function() dir)

  txt <- paste(
    utils::capture.output(quarto_ext(c("extension", "info"))),
    collapse = ""
  )
  info <- jsonlite::parse_json(txt)
  expect_equal(info$assets_version, "0.10.17")
  expect_equal(
    info$scripts$`codeblock-to-json`,
    as.character(fs::path(
      dir,
      "shinylive-0.10.17",
      "scripts",
      "codeblock-to-json.js"
    ))
  )
  expect_equal(downloaded(), "0.10.17")
})

test_that("only quarto_ext info checks GitHub", {
  dir <- withr::local_tempdir()
  # Due for a check, and GitHub knows a newer release
  local_resolve_env(dir, c("0.10.16"), hours_ago = 48)
  add_local_assets(dir, c("0.10.16", "0.10.17"))
  local_mocked_bindings(assets_cache_dir = function() dir)
  calls <- 0
  local_mocked_bindings(
    fetch_latest_assets_version = function() {
      calls <<- calls + 1
      "0.10.17"
    },
    fetch_assets_versions = function() c("0.10.17", "0.10.16")
  )

  expect_equal(quarto_assets_version(), "0.10.17")
  expect_equal(calls, 0)

  # `info` checks and saves versions.json
  assets_version_reset()
  utils::capture.output(quarto_ext(c("extension", "info")))
  expect_equal(calls, 1)
  expect_equal(read_versions_json(dir)$versions, c("0.10.17", "0.10.16"))
})

# Saving versions.json only once the chosen version is downloaded ---------

test_that("the check is not saved until the chosen version is downloaded", {
  dir <- withr::local_tempdir()
  downloaded <- local_resolve_env(dir, c("0.10.16"), hours_ago = 48)
  add_local_assets(dir, "0.10.16")
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.10.17",
    fetch_assets_versions = function() c("0.10.17", "0.10.16")
  )

  # Not downloaded, so not saved
  expect_equal(
    resolve_assets_version("0.10.*", dir = dir, now = now, download = FALSE),
    "0.10.17"
  )
  expect_equal(read_versions_json(dir)$versions, "0.10.16")

  # Downloaded, so saved
  assets_version_reset()
  expect_equal(
    resolve_assets_version("0.10.*", dir = dir, now = now),
    "0.10.17"
  )
  expect_equal(downloaded(), "0.10.17")
  expect_equal(read_versions_json(dir)$versions, c("0.10.17", "0.10.16"))
  expect_equal(read_versions_json(dir)$checked_at, now)
})

test_that("a new check is saved when the chosen version is already local", {
  dir <- withr::local_tempdir()
  local_resolve_env(dir, c("0.10.16"), hours_ago = 48)
  add_local_assets(dir, c("0.10.16", "0.10.17"))
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.10.17",
    fetch_assets_versions = function() c("0.10.17", "0.10.16")
  )

  resolve_assets_version("0.10.*", dir = dir, now = now, download = FALSE)
  expect_equal(read_versions_json(dir)$latest, "0.10.17")
})

test_that("a failed download saves the list without the newer matches", {
  dir <- withr::local_tempdir()
  local_resolve_env(
    dir,
    c("0.10.16"),
    hours_ago = 48,
    download = function(...) stop("HTTP 404 Not Found")
  )
  add_local_assets(dir, "0.10.16")
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.11.1",
    fetch_assets_versions = function() {
      c("0.11.1", "0.11.0", "0.10.18", "0.10.17", "0.10.16", "0.9.0")
    }
  )

  expect_warning(
    v <- resolve_assets_version("0.10.*", dir = dir, now = now),
    "0.10.18"
  )
  expect_equal(v, "0.10.16")

  info <- read_versions_json(dir)
  # Other series are kept
  expect_equal(info$versions, c("0.11.1", "0.11.0", "0.10.16", "0.9.0"))
  expect_null(info$latest)
  expect_match(info$error, "v0.10.18.*404")
  expect_equal(info$checked_at, now)
  # A failed download is retried within the hour, not the day
  expect_false(versions_check_due(info, now + 0.5 * 3600))
  expect_true(versions_check_due(info, now + 1 * 3600))
})

test_that("after a failed download, later Quarto commands keep the downloaded version", {
  dir <- withr::local_tempdir()
  online <- FALSE
  downloaded <- local_resolve_env(
    dir,
    c("0.10.16"),
    hours_ago = 48,
    download = function(version, dir) {
      if (!online) {
        stop("HTTP 503")
      }
      fs::dir_create(fs::path(dir, paste0("shinylive-", version)))
    }
  )
  add_local_assets(dir, "0.10.16")
  local_mocked_bindings(assets_cache_dir = function() dir)
  local_mocked_bindings(
    fetch_latest_assets_version = function() "0.10.17",
    fetch_assets_versions = function() c("0.10.17", "0.10.16")
  )

  # `info` checks GitHub, but can't download v0.10.17
  expect_warning(
    txt <- utils::capture.output(quarto_ext(c("extension", "info"))),
    "0.10.17"
  )
  expect_equal(
    jsonlite::parse_json(paste(txt, collapse = ""))$assets_version,
    "0.10.16"
  )

  # The download works now, but the later commands (`check = FALSE`) still
  # choose the downloaded version, so the render uses one version
  online <- TRUE
  assets_version_reset()
  expect_equal(quarto_assets_version(), "0.10.16")
  expect_equal(downloaded(), "0.10.17")
})

test_that("check = FALSE never writes versions.json", {
  dir <- withr::local_tempdir()
  local_resolve_env(dir)
  add_local_assets(dir, "0.10.16")

  resolve_assets_version(
    "0.10.*",
    dir = dir,
    now = now,
    download = FALSE,
    check = FALSE
  )
  expect_false(fs::file_exists(versions_json_path(dir)))
})

test_that("drop_versions_newer_than() keeps other series and older matches", {
  info <- list(
    checked_at = now - 3600,
    latest = "0.11.0",
    versions = c("0.11.0", "0.10.18", "0.10.17", "0.10.16")
  )
  out <- drop_versions_newer_than(
    info,
    parse_assets_version("0.10.*"),
    "0.10.17",
    error = "boom",
    now = now
  )
  expect_equal(out$versions, c("0.11.0", "0.10.17", "0.10.16"))
  expect_null(out$latest)
  expect_equal(out$error, "boom")
  expect_equal(out$checked_at, now)
})
