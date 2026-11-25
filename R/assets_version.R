# Choosing which Shinylive assets version to use.
#
# A version input is one of:
# * an exact version, such as `"0.10.16"`
# * a series pattern, such as `"0.10.*"` (highest 0.10.x)
# * `"latest"` (the newest release, checked on GitHub once per R session)

parse_assets_version <- function(x, arg = rlang::caller_arg(x)) {
  is_string <- is.character(x) && length(x) == 1 && !is.na(x)
  if (is_string && identical(x, "latest")) {
    return(list(kind = "latest", value = x, prefix = integer(0)))
  }
  if (is_string && grepl("^[0-9]+(\\.[0-9]+)*$", x)) {
    return(list(kind = "exact", value = x, prefix = version_parts(x)))
  }
  if (is_string && grepl("^[0-9]+(\\.[0-9]+)*\\.\\*$", x)) {
    prefix <- version_parts(sub("\\.\\*$", "", x))
    return(list(kind = "pattern", value = x, prefix = prefix))
  }
  cli::cli_abort(c(
    "{.arg {arg}} must be a valid Shinylive assets version.",
    "i" = assets_version_hint,
    "x" = "Received: {.val {x}}"
  ))
}

assets_version_hint <- "Use an exact version ({.val 0.10.16}), a series ({.val 0.10.*}), or {.val latest}."

version_parts <- function(x) {
  as.integer(strsplit(x, ".", fixed = TRUE)[[1]])
}

safe_numeric_version <- function(x) {
  numeric_version(as.character(x), strict = FALSE)
}

# Returns a logical vector: which of `versions` match the parsed `spec`.
assets_version_matches <- function(versions, spec) {
  vapply(
    as.character(versions),
    FUN.VALUE = logical(1),
    USE.NAMES = FALSE,
    function(version) {
      if (is.na(safe_numeric_version(version))) {
        return(FALSE)
      }
      parts <- version_parts(version)
      switch(
        spec$kind,
        latest = TRUE,
        exact = identical(parts, spec$prefix),
        pattern = length(parts) > length(spec$prefix) &&
          identical(parts[seq_along(spec$prefix)], spec$prefix)
      )
    }
  )
}


# versions.json -----------------------------------------------------------
#
# Cached in the assets cache dir:
# {
#   "checked_at": "2026-11-20T17:03:00Z",
#   "latest": "0.11.0",
#   "versions": ["0.11.0", "0.10.17"],
#   "error": "<reason>"            # only when the last check failed
# }

VERSIONS_CHECK_HOURS <- 24
VERSIONS_RETRY_HOURS <- 1
VERSIONS_TIME_FORMAT <- "%Y-%m-%dT%H:%M:%SZ"

versions_json_path <- function(dir) {
  fs::path(dir, "versions.json")
}

read_versions_json <- function(dir) {
  path <- versions_json_path(dir)
  if (!fs::file_exists(path)) {
    return(NULL)
  }
  json <- tryCatch(
    jsonlite::read_json(path, simplifyVector = TRUE),
    error = function(e) NULL
  )
  if (!is.list(json) || !is.character(json$checked_at)) {
    return(NULL)
  }
  checked_at <- as.POSIXct(
    json$checked_at,
    format = VERSIONS_TIME_FORMAT,
    tz = "UTC"
  )
  if (length(checked_at) != 1 || is.na(checked_at)) {
    return(NULL)
  }
  info <- list(
    checked_at = checked_at,
    latest = if (is.character(json$latest)) json$latest,
    versions = if (is.character(json$versions)) json$versions else character(0)
  )
  info$error <- if (is.character(json$error)) json$error
  info
}

write_versions_json <- function(info, dir) {
  fs::dir_create(dir)
  json <- list(
    checked_at = format(info$checked_at, VERSIONS_TIME_FORMAT, tz = "UTC"),
    latest = jsonlite::unbox(info$latest),
    versions = I(as.character(info$versions))
  )
  if (!is.null(info$error)) {
    json$error <- jsonlite::unbox(info$error)
  }
  json$checked_at <- jsonlite::unbox(json$checked_at)
  # Write to a temp file and rename, so other R processes never read a
  # half-written file.
  tmp <- tempfile("versions-", tmpdir = dir, fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  jsonlite::write_json(json, tmp, pretty = TRUE, null = "null")
  file.rename(tmp, versions_json_path(dir))
  invisible(versions_json_path(dir))
}

versions_check_due <- function(info, now = Sys.time()) {
  if (is.null(info)) {
    return(TRUE)
  }
  hours <- as.numeric(difftime(now, info$checked_at, units = "hours"))
  if (hours < 0) {
    # The clock changed
    return(TRUE)
  }
  wait <- if (is.null(info$error)) {
    VERSIONS_CHECK_HOURS
  } else {
    VERSIONS_RETRY_HOURS
  }
  hours >= wait
}

# Runs the GitHub check when due (or when `force = TRUE`) and returns the new
# versions info, or `info` itself when no check is due. A failed check records
# `error` but keeps the old versions. Nothing is saved; see
# `save_versions_json()`.
check_versions_info <- function(info, force = FALSE, now = Sys.time()) {
  # No network during CRAN checks
  if (cran_is_testing() || (!force && !versions_check_due(info, now))) {
    return(info)
  }

  latest <- NULL
  new_info <- tryCatch(
    {
      latest <- fetch_latest_assets_version()
      versions <- info$versions
      # Fetch the full list only when the latest tag changes. This assumes
      # releases only move forward: an older series gets no new patch release
      # after a newer series is out.
      if (!identical(latest, info$latest) || length(versions) == 0) {
        versions <- fetch_assets_versions()
      }
      list(checked_at = now, latest = latest, versions = versions)
    },
    error = function(e) {
      list(
        checked_at = now,
        # Keep the old `latest`, so the next check fetches the full list
        latest = info$latest,
        # A newly seen latest tag is still a known release
        versions = unique(c(latest, info$versions, character(0))),
        error = conditionMessage(e)
      )
    }
  )
  new_info
}

# Saves `versions.json`, ignoring a read-only cache (such as in a Docker
# image), which must not stop the export. Later commands then read the old
# file. Since it too only names downloaded versions, they still choose a
# downloaded version.
save_versions_json <- function(info, dir) {
  suppressWarnings(try(write_versions_json(info, dir), silent = TRUE))
  invisible()
}

# Returns `info` without the releases matching `spec` that are newer than
# `chosen`, as after they failed to download. `latest` is cleared, so the next
# check (in `VERSIONS_RETRY_HOURS`, since `error` is set) fetches the full
# list again.
drop_versions_newer_than <- function(info, spec, chosen, error, now) {
  versions <- info$versions
  newer <- assets_version_matches(versions, spec) &
    safe_numeric_version(versions) > safe_numeric_version(chosen)
  list(
    checked_at = now,
    latest = NULL,
    versions = versions[!newer %in% TRUE],
    error = error
  )
}

assets_releases_url <- "https://github.com/posit-dev/shinylive/releases"

check_network_allowed <- function(call = rlang::caller_env()) {
  if (cran_is_testing()) {
    cli::cli_abort(
      "Can't check Shinylive assets versions during CRAN checks.",
      call = call
    )
  }
}

# Returns the newest release version, read from where
# `<releases>/latest` redirects to. This is not the GitHub API, so it has no
# rate limit.
fetch_latest_assets_version <- function() {
  check_network_allowed()
  req <- httr2::request(paste0(assets_releases_url, "/latest"))
  req <- httr2::req_method(req, "HEAD")
  req <- httr2::req_timeout(req, 3)
  req <- httr2::req_options(req, connecttimeout = 1)
  resp <- httr2::req_perform(req)
  latest_tag_version(httr2::resp_url(resp))
}

latest_tag_version <- function(url) {
  if (!grepl("/releases/tag/v[0-9]+(\\.[0-9]+)*$", url)) {
    cli::cli_abort(
      "Can't find the latest Shinylive assets version in {.url {url}}."
    )
  }
  sub("^.*/releases/tag/v", "", url)
}

# Returns all published (not draft, not prerelease) release versions.
fetch_assets_versions <- function() {
  check_network_allowed()
  releases <- gh::gh(
    "/repos/posit-dev/shinylive/releases",
    .limit = Inf,
    .timeout = 10,
    .progress = FALSE
  )
  keep <- vapply(
    releases,
    function(r) !isTRUE(r$draft) && !isTRUE(r$prerelease),
    logical(1)
  )
  tags <- vapply(releases[keep], function(r) r$tag_name, character(1))
  versions <- sub("^v", "", tags)
  versions[!is.na(safe_numeric_version(versions))]
}


# Resolving a version -----------------------------------------------------

assets_version_memo <- new.env(parent = emptyenv())

assets_version_reset <- function() {
  rm(
    list = ls(assets_version_memo, all.names = TRUE),
    envir = assets_version_memo
  )
}

# Returns the version input to use: a non-`NULL` value wins, then the
# `SHINYLIVE_ASSETS_VERSION` env var, then the package default.
assets_version_input <- function(version = NULL) {
  if (!is.null(version)) {
    return(version)
  }
  env <- Sys.getenv("SHINYLIVE_ASSETS_VERSION")
  if (!nzchar(env)) {
    return(SHINYLIVE_ASSETS_VERSION_DEFAULT)
  }
  # Check it here, so the error says where the bad value came from
  tryCatch(
    parse_assets_version(env),
    error = function(e) {
      cli::cli_abort(
        c(
          "Bad {.envvar SHINYLIVE_ASSETS_VERSION} environment variable.",
          "i" = assets_version_hint,
          "x" = "Received: {.val {env}}"
        ),
        call = NULL
      )
    }
  )
  env
}

# Versions of the downloaded assets in `dir`
local_assets_versions <- function(dir) {
  assets_path_version(assets_dirs(dir = dir))
}

max_version <- function(versions) {
  as.character(max(numeric_version(versions)))
}

# Returns an exact assets version for an exact version, a series pattern, or
# `"latest"`. When `download = TRUE`, the chosen version is downloaded if
# needed; if that fails, the highest downloaded match is used instead. When
# `check = FALSE`, only the saved `versions.json` is read (no network), and it
# is never written. Otherwise, a new check is saved only when the chosen
# version is downloaded; if it fails to download, the newer matching releases
# are left out of the saved list. When `warn = FALSE`, an exact version
# outside the default series does not warn.
resolve_assets_version <- function(
  version,
  dir = assets_cache_dir(),
  now = Sys.time(),
  download = TRUE,
  check = TRUE,
  warn = TRUE
) {
  spec <- parse_assets_version(version)

  if (spec$kind == "exact") {
    if (warn) {
      warn_outside_default(spec$value)
    }
    return(spec$value)
  }

  key <- paste(spec$value, dir, download, check)
  if (!is.null(assets_version_memo[[key]])) {
    return(assets_version_memo[[key]])
  }

  saved_info <- read_versions_json(dir)
  info <- if (check) {
    check_versions_info(saved_info, force = spec$kind == "latest", now = now)
  } else {
    saved_info
  }
  local <- local_assets_versions(dir)
  local_matches <- local[assets_version_matches(local, spec)]
  known <- unique(c(info$versions, local))
  matches <- known[assets_version_matches(known, spec)]
  # The check (or the download after it) failed and no known release matches,
  # so the result may be old. Every known release matches `"latest"`, so any
  # failed check makes it old.
  stale <- check &&
    !is.null(info$error) &&
    (spec$kind == "latest" ||
      !any(assets_version_matches(info$versions, spec)))

  if (length(matches) == 0) {
    fallback <- SHINYLIVE_ASSETS_VERSION_FALLBACK
    if (!assets_version_matches(fallback, spec)) {
      cli::cli_abort(c(
        "No Shinylive assets version matches {.val {spec$value}}.",
        "i" = "Known versions: {.val {known}}",
        "i" = "Pass an exact version instead, such as {.val {fallback}}."
      ))
    }
    matches <- fallback
  }
  chosen <- max_version(matches)

  # This warns in every R process until the next check, on purpose: each
  # process may use an old version.
  if (stale) {
    checked_at <- format(info$checked_at, VERSIONS_TIME_FORMAT, tz = "UTC")
    retry_at <- format(
      info$checked_at + VERSIONS_RETRY_HOURS * 3600,
      VERSIONS_TIME_FORMAT,
      tz = "UTC"
    )
    cli::cli_warn(c(
      "The check for new Shinylive assets releases at {checked_at} failed: {info$error}",
      "i" = "Using {.field v{chosen}}, which may not be the newest {.val {spec$value}} release. GitHub is checked again after {retry_at}.",
      "i" = "Set {.envvar GITHUB_PAT} if GitHub is limiting requests, or pass an exact version."
    ))
  }

  if (download && !chosen %in% local) {
    chosen <- tryCatch(
      {
        assets_download(chosen, dir = dir)
        chosen
      },
      error = function(e) {
        failed <- chosen
        fallback <- SHINYLIVE_ASSETS_VERSION_FALLBACK
        fallback_error <- NULL
        if (
          length(local_matches) == 0 &&
            chosen != fallback &&
            assets_version_matches(fallback, spec)
        ) {
          fallback_error <- tryCatch(
            {
              assets_download(fallback, dir = dir)
              local_matches <- fallback
              NULL
            },
            error = function(e2) conditionMessage(e2)
          )
        }
        if (length(local_matches) == 0) {
          cli::cli_abort(
            c(
              "Can't download Shinylive assets {.field v{chosen}}.",
              "x" = if (!is.null(fallback_error)) {
                "The fallback {.field v{fallback}} also failed: {fallback_error}"
              },
              "i" = "Shinylive assets must be downloaded once while online.",
              "i" = "Or pass the exact version of downloaded assets."
            ),
            parent = e
          )
        }
        fallback <- max_version(local_matches)
        cli::cli_warn(c(
          "Can't download Shinylive assets {.field v{failed}}. Using downloaded {.field v{fallback}} instead.",
          "x" = "{conditionMessage(e)}"
        ))
        if (check && !is.null(info)) {
          info <<- drop_versions_newer_than(
            info,
            spec,
            fallback,
            error = paste0(
              "Can't download Shinylive assets v",
              failed,
              ": ",
              conditionMessage(e)
            ),
            now = now
          )
        }
        fallback
      }
    )
  }

  # Save only once the chosen version is downloaded. Later commands that only
  # read `versions.json` (like the Quarto ones, here or in py-shinylive) then
  # choose this downloaded version, and never one they would have to download.
  if (
    check &&
      !is.null(info) &&
      !identical(info, saved_info) &&
      chosen %in% local_assets_versions(dir)
  ) {
    save_versions_json(info, dir)
  }

  assets_version_memo[[key]] <- chosen
  chosen
}

warn_outside_default <- function(version) {
  key <- paste("warned", version)
  default <- parse_assets_version(SHINYLIVE_ASSETS_VERSION_DEFAULT)
  if (
    assets_version_matches(version, default) ||
      isTRUE(assets_version_memo[[key]])
  ) {
    return(invisible())
  }
  assets_version_memo[[key]] <- TRUE
  cli::cli_warn(c(
    "Shinylive assets {.field v{version}} are outside the default {.val {SHINYLIVE_ASSETS_VERSION_DEFAULT}} series for this version of {.pkg shinylive}.",
    "i" = "Unexpected behavior may occur."
  ))
}
