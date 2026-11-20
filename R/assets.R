#' Manage shinylive assets
#'
#' Helper methods for managing shinylive assets.
#'
#' @describeIn assets Downloads the shinylive assets bundle from GitHub and
#'    extracts it to the specified directory. The bundle will always be
#'    downloaded from GitHub, even if it already exists in the cache directory
#'    (`dir=`).
#' @param version The version of the assets: an exact version (`"0.10.16"`), a
#'    series (`"0.10.*"`), or `"latest"`. See [export()] for details. When not
#'    provided, the `SHINYLIVE_ASSETS_VERSION` environment variable is used if
#'    set.
#' @param ... Ignored.
#' @param dir The asset cache directory. Unless testing, the default behavior
#'    should be used.
#' @param url The URL to download the assets from. Unless testing, the default
#'    behavior should be used.
#' @export
#' @return
#' `assets_version()` returns the version of the currently supported Shinylive.
#'
#' `assets_download()` invisibly returns the cache directory and
#' `assets_ensure()` invisibly returns the assets directory for `version`.
#'
#' `assets_cleanup()` and `assets_remove()` return `invisible()`.
assets_download <- function(
  version = "0.10.*",
  ...,
  # Note that this is the cache directory, which is the parent of the assets
  # directory. The tarball will have the assets directory as the top-level
  # subdir.
  dir = assets_cache_dir(),
  url = assets_bundle_url(version)
) {
  version <- resolve_assets_version(
    assets_version_input(version, missing(version)),
    dir = dir,
    download = FALSE
  )
  tmp_targz <- tempfile(
    paste0("shinylive-", gsub(".", "_", version, fixed = TRUE), "-"),
    fileext = ".tar.gz"
  )

  on.exit(
    {
      if (fs::file_exists(tmp_targz)) {
        fs::file_delete(tmp_targz)
      }
    },
    add = TRUE
  )

  existed_before <- fs::dir_exists(assets_dir_impl(dir = dir, version = version))

  cli_progress_step("Downloading shinylive assets {.field v{version}}")
  req <- httr2::request(url)
  req <- httr2::req_progress(req)
  httr2::req_perform(req, path = tmp_targz)

  cli_progress_step("Unzipping shinylive assets to {.path {dir}}")
  fs::dir_create(dir)
  # Extract to a temp dir, then move into place, so a half-extracted folder is
  # never picked up as a version.
  tmp_dir <- tempfile("extract-", tmpdir = dir)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  archive::archive_extract(tmp_targz, tmp_dir)
  target_dir <- assets_dir_impl(dir = dir, version = version)
  if (fs::dir_exists(target_dir)) {
    if (existed_before) {
      # A re-download replaces the old folder
      unlink_path(target_dir)
    } else {
      # Another R process just finished the same download. Keep its folder,
      # which it may be reading from.
      cli_progress_done()
      return(invisible(dir))
    }
  }
  fs::file_move(fs::path(tmp_dir, basename(target_dir)), dir)

  cli_progress_done()
  invisible(dir)
}


# Returns the URL for the Shinylive assets bundle.
assets_bundle_url <- function(version = assets_version()) {
  paste0(
    "https://github.com/posit-dev/shinylive/releases/download/",
    paste0("v", version),
    "/",
    paste0("shinylive-", version, ".tar.gz")
  )
}


assets_cache_dir <- function() {
  if (cran_is_testing()) {
    stop("assets_cache_dir() must not be called during CRAN testing")
  }
  # Must be normalized as `~` does not work with quarto
  cache_dir <- rappdirs::user_cache_dir("shinylive")
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }
  normalizePath(cache_dir)
}

# Returns the directory containing cached Shinylive assets, for a particular
# version of Shinylive.
assets_dir <- function(
  version = assets_version(),
  ...,
  dir = assets_cache_dir()
) {
  assets_dir_impl(dir = dir, version = version)
}
shinylive_prefix <- "shinylive-"
# Returns the version from an assets folder path, like `0.10.16` from
# `<cache>/shinylive-0.10.16`
assets_path_version <- function(path) {
  sub(paste0("^", shinylive_prefix), "", basename(path))
}
assets_dir_impl <- function(
  ...,
  dir = assets_cache_dir(),
  version = assets_version()
) {
  rlang::check_dots_empty()
  fs::path(dir, paste0(shinylive_prefix, version))
}


install_local_helper <- function(
  ...,
  assets_repo_dir,
  install_fn = fs::file_copy,
  dir = assets_cache_dir(),
  version = package_json_version(assets_repo_dir)
) {
  rlang::check_dots_empty()
  if (!fs::dir_exists(assets_repo_dir)) {
    cli::cli_abort(
      "Assets repo directory does not exist: {.path {assets_repo_dir}}"
    )
  }
  repo_build_dir <- fs::path(assets_repo_dir, "build")
  if (!fs::dir_exists(repo_build_dir)) {
    cli::cli_abort(c(
      "Assets repo build dir does not exist ({.path {repo_build_dir}}).",
      i = "Have you called {.code make all} yet?"
    ))
  }
  target_dir <- assets_dir_impl(dir = dir, version = version)

  unlink_path(target_dir)
  install_fn(repo_build_dir, target_dir)

  default <- parse_assets_version(SHINYLIVE_ASSETS_VERSION_DEFAULT)
  if (!assets_version_matches(version, default)) {
    cli::cli_warn(c(
      "You are installing a local copy of shinylive assets outside of the series used by the shinylive R package.",
      "Unexpected behavior may occur!",
      x = "New assets version: {version}",
      i = "Supported assets series: {SHINYLIVE_ASSETS_VERSION_DEFAULT}"
    ))
  }
}

#' Install shinylive assets from a local directory
#'
#' Helper methods for testing updates to shinylive assets.
#'
#' @describeIn install Copies all shinylive assets from a local shinylive
#'    repository (e.g.
#'    [`posit-dev/shinylive`](https://github.com/posit-dev/shinylive)). This
#'    must be repeated for any change in the assets.
#' @param assets_repo_dir The local repository directory for shinylive assets
#'    (e.g. [`posit-dev/shinylive`](https://github.com/posit-dev/shinylive))
#' @param version The version of the assets being installed.
#' @inheritParams assets_download
#' @seealso [`assets_download()`], [`assets_ensure()`], [`assets_cleanup()`]
#' @return All method return `invisible()`.
#' @export
assets_install_copy <- function(
  assets_repo_dir,
  ...,
  dir = assets_cache_dir(),
  version = package_json_version(assets_repo_dir)
) {
  install_local_helper(
    ...,
    install_fn = function(from, to) {
      fs::dir_create(to)
      fs::dir_copy(from, to, overwrite = TRUE)
    },
    assets_repo_dir = assets_repo_dir,
    dir = dir,
    version = version
  )

  invisible()
}

#' @describeIn install Creates a symlink of the local shinylive assets to the
#'    cached assets directory. After the first installation, the assets will be the
#'    same as the source due to the symlink.
#' @export
assets_install_link <- function(
  assets_repo_dir,
  ...,
  dir = assets_cache_dir(),
  version = package_json_version(assets_repo_dir)
) {
  install_local_helper(
    ...,
    install_fn = function(from, to) {
      # Make sure from is an absolute path
      if (!fs::is_absolute_path(from)) {
        from <- fs::path_wd(from)
      }
      # Make sure parent folder exists
      fs::dir_create(fs::path_dir(to))
      # Link dir
      fs::link_create(from, to)
    },
    assets_repo_dir = assets_repo_dir,
    dir = dir,
    version = version
  )

  invisible()
}


#' @describeIn assets Ensures a local copy of shinylive is installed. If a local
#'    copy of shinylive is not installed, it will be downloaded and installed.
#'    If a local copy of shinylive is installed, its path will be returned.
#' @export
assets_ensure <- function(
  version = "0.10.*",
  ...,
  dir = assets_cache_dir(),
  url = assets_bundle_url(version)
) {
  rlang::check_dots_empty()
  if (!fs::dir_exists(dir)) {
    cli_alert_info("Creating assets cache directory {.path {dir}}")
    fs::dir_create(dir)
  }
  version <- resolve_assets_version(
    assets_version_input(version, missing(version)),
    dir = dir
  )

  assets_path <- assets_dir(version, dir = dir)
  if (!fs::dir_exists(assets_path)) {
    cli_alert_warning("{.path {assets_path}} assets directory does not exist.")
    assets_download(url = url, version = version, dir = dir)
  }

  invisible(assets_path)
}


# Returns the R version that the assets' webR was built with, such as "4.6.0".
# WebAssembly package binaries must be built for this same R version.
assets_webr_r_version <- function(version = assets_version()) {
  assets_path <- assets_ensure(version = version)
  assets_path_webr_r_version(assets_path)
}

assets_path_webr_r_version <- function(assets_path) {
  # The `translations` base package ships with webR and its `Version` is the R
  # version. Found in assets 0.8.0 and later.
  desc_file <- fs::path(
    assets_path,
    "shinylive/webr/vfs/usr/lib/R/library/translations/DESCRIPTION"
  )
  r_version <- if (fs::file_exists(desc_file)) {
    unname(read.dcf(desc_file, fields = "Version")[1, 1])
  } else {
    NA_character_
  }

  if (is.na(r_version)) {
    cli::cli_abort(c(
      "Can't find the webR R version in the Shinylive assets.",
      "x" = "Missing or invalid file: {.path {desc_file}}",
      "i" = "The assets may be incomplete. Delete {.path {assets_path}} so they are downloaded again."
    ))
  }

  r_version
}


# """Removes local copies of shinylive web assets, except for the one used by the
# current version of the shinylive python package.

# Parameters
# ----------
# dir
#     The directory where shinylive is stored. If None, the default directory will
#     be used.
# """

#' @describeIn assets Removes local copies of shinylive web assets, except for
#'    the newest version of each series (such as `0.10.*`).
#' @export
assets_cleanup <- function(
  ...,
  dir = assets_cache_dir()
) {
  rlang::check_dots_empty()
  versions <- local_assets_versions(dir)
  # `assets_dirs()` sorts newest first, so keep the first of each series
  series <- vapply(
    versions,
    function(v) paste(version_parts(v)[1:2], collapse = "."),
    character(1)
  )
  keep <- versions[!duplicated(series)]
  # Also keep an exact version pinned with `SHINYLIVE_ASSETS_VERSION`
  pinned <- parse_assets_version(assets_version_input(NULL, TRUE))
  if (pinned$kind == "exact") {
    keep <- union(keep, intersect(versions, pinned$value))
  }
  for (v in keep) {
    cli_alert_info("Keeping version {v}")
  }
  versions <- setdiff(versions, keep)

  if (length(versions) > 0) {
    assets_remove(versions, dir = dir)
  }

  invisible()
}


# """Removes local copy of shinylive.

# Parameters
# ----------
# shinylive_dir
#     The directory where shinylive is stored. If None, the default directory will
#     be used.

# version
#     If a version is specified, only that version will be removed.
#     If None, all local versions except the version specified by SHINYLIVE_ASSETS_VERSION will be removed.
# """

#' @describeIn assets Removes a local copies of shinylive web assets.
#' @param versions The assets versions to remove.
#' @export
assets_remove <- function(
  versions,
  ...,
  dir = assets_cache_dir()
) {
  rlang::check_dots_empty()
  if (!is.character(versions) || length(versions) == 0) {
    cli::cli_abort("{.arg versions} must be a non-empty character vector.")
  }

  lapply(versions, function(version) {
    target_dir <- assets_dir_impl(dir = dir, version = version)
    if (fs::dir_exists(target_dir)) {
      cli_progress_step("Removing {.path {target_dir}}")
      unlink_path(target_dir)
    } else {
      cli_alert_warning("{.path {target_dir}} folder does not exist")
    }
  })

  invisible()
}


assets_dirs <- function(
  ...,
  dir = assets_cache_dir()
) {
  rlang::check_dots_empty()
  if (!fs::dir_exists(dir)) {
    return(character(0))
  }
  # fs::dir_ls(shinylive_dir, type = "directory", regexp = "^shinylive-")

  path_basenames <-
    # Using `dir()` to avoid the path expansion that `fs::dir_ls()` does.
    # `dir()` is 10x faster than `fs::dir_ls()`
    base::dir(
      dir,
      full.names = FALSE,
      pattern = paste0("^", shinylive_prefix)
    )
  if (length(path_basenames) == 0) {
    return(character(0))
  }

  # Skip files and folders whose suffix is not a version, like `shinylive-dev`
  path_versions_str <- assets_path_version(path_basenames)
  path_versions <- numeric_version(path_versions_str, strict = FALSE)
  is_version_dir <- !is.na(path_versions) &
    dir.exists(file.path(dir, path_basenames))
  path_basenames <- path_basenames[is_version_dir]
  path_versions <- path_versions[is_version_dir]

  # Sort descending by version numbers
  path_basenames <- path_basenames[order(path_versions, decreasing = TRUE)]

  # Return full path to the versions
  fs::path(dir, path_basenames)
}


#' @describeIn assets Prints information about the local shinylive assets that
#'   have been installed. Returns a table of installed asset versions and their
#'   associated paths, invisibly unless `quiet = TRUE`.
#' @param quiet In `assets_info()`, if `quiet = TRUE`, the function will not
#'   print the assets information to the console.
#' @export
assets_info <- function(quiet = FALSE) {
  installed_versions <- assets_dirs()
  # Report only: never download here
  resolved <- resolve_assets_version(
    assets_version_input(NULL, TRUE),
    download = FALSE
  )

  local_quiet(quiet)

  cli_text("shinylive R package version: {.field {SHINYLIVE_R_VERSION}}")
  cli_text("shinylive web assets version: {.field {resolved}}")
  cli_text("Default assets series: {.field {SHINYLIVE_ASSETS_VERSION_DEFAULT}}")
  check <- read_versions_json(assets_cache_dir())
  if (!is.null(check)) {
    checked_at <- format(check$checked_at, VERSIONS_TIME_FORMAT, tz = "UTC")
    cli_text("Last checked for new assets: {.field {checked_at}}")
    if (!is.null(check$error)) {
      cli_text("Last check failed: {check$error}")
    }
  }
  cli_text("")
  cli_text("Local cached shinylive asset dir:")
  cli_bullets(c(">" = "{.path {assets_cache_dir()}}"))
  cli_text("")
  cli_text("Installed assets:")
  if (length(installed_versions) == 0) {
    cli_bullets(c("*" = "(None)"))
  } else {
    cli_installed <- c()
    for (i in seq_along(installed_versions)) {
      cli_installed <- c(
        cli_installed,
        c("*" = sprintf("{.path {installed_versions[%s]}}", i))
      )
    }
    cli_bullets(cli_installed)
  }

  versions <- assets_path_version(installed_versions)

  data <- data.frame(
    version = as.character(versions),
    path = as.character(installed_versions),
    is_assets_version = versions == resolved
  )

  class(data) <- c("tbl_df", "tbl", "data.frame")

  if (is_quiet()) data else invisible(data)
}


#' @describeIn assets Returns the exact Shinylive assets version to use. It is
#'    the newest release in the default series (`"0.10.*"`), checked on GitHub
#'    at most once a day, or the highest downloaded version when offline. If
#'    the `SHINYLIVE_ASSETS_VERSION` environment variable is set, it is used
#'    instead (an exact version, a series, or `"latest"`). The result is
#'    remembered for the R session and may download the assets.
#' @export
assets_version <- function() {
  resolve_assets_version(assets_version_input(NULL, TRUE))
}

# """Checks if the URL for the Shinylive assets bundle is valid.

# Returns True if the URL is valid (with a 200 status code), False otherwise.

# The reason it has both the `version` and `url` parameters is so that it behaves the
# same as `assets_download()` and `assets_ensure()`.
# """
check_assets_url <- function(
  version = assets_version(),
  url = assets_bundle_url(version)
) {
  req <- httr2::request(url)
  req <- httr2::req_method(req, "HEAD")
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- httr2::req_perform(req)
  httr2::resp_status(resp) == 200
}
