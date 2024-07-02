#' Manage shinylive assets
#'
#' Helper methods for managing shinylive assets.
#'
#' @describeIn assets Downloads the shinylive assets bundle from GitHub and
#'    extracts it to the specified directory. The bundle will always be
#'    downloaded from GitHub, even if it already exists in the cache directory
#'    (`dir=`).
#' @param version The version of the assets to download.
#' @param ... Ignored.
#' @param dir The asset cache directory. Unless testing, the default behavior
#'    should be used.
#' @param url The URL to download the assets from. Unless testing, the default
#'    behavior should be used.
#' @export
#' @return
#' `assets_version()` returns the version of the currently supported Shinylive.
#'
#' All other methods return `invisible()`.
assets_download <- function(
  version = assets_version(),
  ...,
  # Note that this is the cache directory, which is the parent of the assets
  # directory. The tarball will have the assets directory as the top-level
  # subdir.
  dir = assets_cache_dir(),
  url = assets_bundle_url(version)
) {
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

  cli_progress_step("Downloading shinylive assets {.field v{version}}")
  req <- httr2::request(url)
  req <- httr2::req_progress(req)
  httr2::req_perform(req, path = tmp_targz)
  
  cli_progress_step("Unzipping shinylive assets to {.path {dir}}")
  fs::dir_create(dir)
  archive::archive_extract(tmp_targz, dir)
  
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
  # Must be normalized as `~` does not work with quarto
  cache_dir <- rappdirs::user_cache_dir("shinylive")
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }
  normalizePath(cache_dir)
}

# Returns the directory used for caching Shinylive assets. This directory can
# contain multiple versions of Shinylive assets.
assets_cache_dir_exists <- function() {
  fs::dir_exists(assets_cache_dir())
}


# Returns the directory containing cached Shinylive assets, for a particular
# version of Shinylive.
assets_dir <- function(version = assets_version(), ..., dir = assets_cache_dir()) {
  assets_dir_impl(dir = assets_cache_dir(), version = version)
}
shinylive_prefix <- "shinylive-"
assets_dir_impl <- function(
  ...,
  dir = assets_cache_dir(),
  version = assets_version()
) {
  stopifnot(length(list(...)) == 0)
  fs::path(dir, paste0(shinylive_prefix, version))
}


install_local_helper <- function(
  ...,
  assets_repo_dir,
  install_fn = fs::file_copy,
  dir = assets_cache_dir(),
  version = package_json_version(assets_repo_dir)
) {
  stopifnot(length(list(...)) == 0)
  stopifnot(fs::dir_exists(assets_repo_dir))
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

  if (version != assets_version()) {
    cli::cli_warn(c(
      "You are installing a local copy of shinylive assets that is not the same as the version used by the shinylive R package.",
      "Unexpected behavior may occur!",
      x = "New assets version: {version}",
      i = "Supported assets version: {assets_version()}"
    ))
  }
}

#' Install shinylive assets from from a local directory
#'
#' Helper methods for testing updates to shinylive assets.
#'
#' @describeIn install Copies all shinylive assets from a local shinylive
#'    repository (e.g.
#'    [`posit-dev/shinylive`](https://github.com/posit-dev/py-shinylive)). This
#'    must be repeated for any change in the assets.
#' @param assets_repo_dir The local repository directory for shinylive assets
#'    (e.g. [`posit-dev/shinylive`](https://github.com/posit-dev/py-shinylive))
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
#'    cached assets directory. After the first installation, the assets will the
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
  version = assets_version(),
  ...,
  dir = assets_cache_dir(),
  url = assets_bundle_url(version)
) {
  stopifnot(length(list(...)) == 0)
  if (!fs::dir_exists(dir)) {
    cli_alert_info("Creating assets cache directory ", dir)
    fs::dir_create(dir)
  }

  assets_path <- assets_dir(version, dir = dir)
  if (!fs::dir_exists(assets_path)) {
    cli_alert_warning("{.path {assets_path}} assets directory does not exist.")
    assets_download(url = url, version = version, dir = dir)
  }

  invisible(assets_path)
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
#'    the one used by the current version of \pkg{shinylive}.
#' @export
assets_cleanup <- function(
  ...,
  dir = assets_cache_dir()
) {
  stopifnot(length(list(...)) == 0)
  versions <- vapply(
    assets_dirs(dir = dir),
    function(ver_path) {
      sub(shinylive_prefix, "", basename(ver_path))
    },
    character(1)
  )
  if (assets_version() %in% versions) {
    cli_alert_info("Keeping version {assets_version()}")
    versions <- setdiff(versions, assets_version())
  }

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
  stopifnot(length(list(...)) == 0)
  stopifnot(length(versions) > 0 && is.character(versions))

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
  stopifnot(length(list(...)) == 0)
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

  # Sort descending by version numbers
  path_versions_str <- sub(shinylive_prefix, "", path_basenames)
  path_versions <- as.character(
    sort(numeric_version(path_versions_str), decreasing = TRUE)
  )

  # Return full path to the versions
  fs::path(dir, paste0(shinylive_prefix, path_versions))
}




#' @describeIn assets Prints information about the local shinylive assets that
#'   have been installed. Invisibly returns a table of installed asset versions
#'   and their associated paths.
#' @param quiet In `assets_info()`, if `quiet = TRUE`, the function will not
#'   print the assets information to the console.
#' @export
assets_info <- function(quiet = FALSE) {
  installed_versions <- assets_dirs()
  if (length(installed_versions) == 0) {
    installed_versions <- "(None)"
  }

  local_quiet(quiet)

  cli_text("shinylive R package version: {.field {SHINYLIVE_R_VERSION}}")
  cli_text("shinylive web assets version: {.field {assets_version()}}")
  cli_text("")
  cli_text("Local cached shinylive asset dir:")
  cli_bullets(c(">" = "{.path {assets_cache_dir()}}"))
  cli_text("")
  cli_text("Installed assets:")
  if (assets_cache_dir_exists()) {
    cli_installed <- c()
    for (i in seq_along(installed_versions)) {
      cli_installed <- c(cli_installed, c("*" = sprintf("{.path {installed_versions[%s]}}", i)))
    }
    cli_bullets(cli_installed)
  } else {
    cli_bullets("(Cache dir does not exist)")
  }

  versions <- vapply(
    strsplit(installed_versions, "shinylive-", fixed = TRUE),
    FUN.VALUE = character(1),
    function(x) x[[2]]
  )

  data <- data.frame(
    version = versions,
    path = installed_versions,
    is_assets_version = versions == assets_version()
  )

  class(data) <- c("tbl_df", "tbl", "data.frame")

  if (is_quiet()) data else invisible(data)
}



#' @describeIn assets Returns the version of the currently supported Shinylive
#'    assets version. If the `SHINYLIVE_ASSETS_VERSION` environment variable is set,
#'    that value will be used.
#' @export
assets_version <- function() {
  Sys.getenv("SHINYLIVE_ASSETS_VERSION", SHINYLIVE_ASSETS_VERSION)
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
  resp <- httr2::req_perform(req)
  resp$status_code == 200
}
