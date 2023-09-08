# TODO-barret; Rename methods for discoverability. Ex: `FOO_shinylive_assets` -> `assets_FOO`; Ex: Follow the python CLI pattern of `shinylive assets FOO` -> `assets_FOO`, `asset_download`
# TODO-barret; document
# TODO-barret; test
# * quarto_ext_call(c("base-deps", "--sw-dir", "asdfasfd"))
# * quarto_ext_call(c("package-deps"))
# * quarto_ext_call(c("codeblock-to-json-path"))
# TODO-barret; Update readme with local testing
# TOOD-barret; Move quarto extensions changes to `quarto-ext/shinylive`

download_shinylive <- function(
    # Note that this is the cache directory, which is the parent of the assets
    # directory. The tarball will have the assets directory as the top-level subdir.
    destdir = shinylive_cache_dir(),
    version = SHINYLIVE_ASSETS_VERSION,
    url = shinylive_bundle_url(version)) {
  tmp_targz <- tempfile(paste0("shinylive-", gsub(".", "_", version, fixed = TRUE), "-"), fileext = ".tar.gz")

  on.exit(
    {
      if (fs::file_exists(tmp_targz)) {
        message("Removing ", tmp_targz)
        fs::file_delete(tmp_targz)
      }
    },
    add = TRUE
  )

  message("Downloading shinylive v", version, "...")
  utils::download.file(url, destfile = tmp_targz, method = "auto")

  message("Unzipping to ", destdir, "/")
  fs::dir_create(destdir)
  archive::archive_extract(tmp_targz, destdir)
}


# Returns the URL for the Shinylive assets bundle.
shinylive_bundle_url <- function(version = SHINYLIVE_ASSETS_VERSION) {
  paste0(
    "https://github.com/rstudio/shinylive/releases/download/",
    paste0("v", version),
    "/",
    paste0("shinylive-", version, ".tar.gz")
  )
}


shinylive_cache_dir <- function() {
  # Must be normalized a `~` does not work with quarto
  normalizePath(rappdirs::user_cache_dir("shinylive"))
}

# Returns the directory used for caching Shinylive assets. This directory can
# contain multiple versions of Shinylive assets.
shinylive_cache_dir_exists <- function() {
  fs::dir_exists(shinylive_cache_dir())
}


# Returns the directory containing cached Shinylive assets, for a particular
# version of Shinylive.
shinylive_assets_dir <- function(version = SHINYLIVE_ASSETS_VERSION, ..., cache_dir = shinylive_cache_dir()) {
  shinylive_assets_dir_(cache_dir = shinylive_cache_dir(), version = version)
}
shinylive_prefix <- "shinylive-"
shinylive_assets_dir_ <- function(
    ...,
    cache_dir = shinylive_cache_dir(),
    version = SHINYLIVE_ASSETS_VERSION) {
  stopifnot(length(list(...)) == 0)
  fs::path(cache_dir, paste0(shinylive_prefix, version))
}


install_local_helper <- function(
    install_fn = fs::file_copy,
    assets_repo_dir,
    destdir = shinylive_cache_dir(),
    version = package_json_version(assets_repo_dir)) {
  stopifnot(fs::dir_exists(assets_repo_dir))
  repo_build_dir <- fs::path(assets_repo_dir, "build")
  if (!fs::dir_exists(repo_build_dir)) {
    stop("Assets repo build dir does not exist (`", repo_build_dir, "`).\nHave you called `make all` yet?")
  }
  target_dir <- shinylive_assets_dir_(cache_dir = destdir, version = version)

  unlink_path(target_dir)
  install_fn(repo_build_dir, target_dir)

  if (version != SHINYLIVE_ASSETS_VERSION) {
    message(
      "Warning: You are installing a local copy of shinylive that is not the same as the version used by the shinylive R package.",
      "\nWarning: Unexpected behavior may occur!",
      "\n\nNew version: ", version
    )
  }
}

copy_shinylive_local <- function(
    assets_repo_dir,
    destdir = shinylive_cache_dir(),
    version = package_json_version(assets_repo_dir)) {
  install_local_helper(
    install_fn = function(from, to) {
      fs::dir_create(to)
      fs::dir_copy(from, to, overwrite = TRUE)
    },
    assets_repo_dir = assets_repo_dir,
    destdir = destdir,
    version = version
  )
}

link_shinylive_local <- function(
    assets_repo_dir,
    destdir = shinylive_cache_dir(),
    version = package_json_version(assets_repo_dir)) {
  install_local_helper(
    install_fn = function(from, to) {
      # Make sure parent folder exists
      fs::dir_create(fs::path_dir(to))
      # Link dir
      fs::link_create(from, to)
    },
    assets_repo_dir = assets_repo_dir,
    destdir = destdir,
    version = version
  )
}



# Ensure that there is a local copy of shinylive.
ensure_shinylive_assets <- function(
    destdir = shinylive_cache_dir(),
    version = SHINYLIVE_ASSETS_VERSION,
    url = shinylive_bundle_url(version)) {
  if (!fs::dir_exists(destdir)) {
    message("Creating directory ", destdir)
    fs::dir_create(destdir)
  }

  shinylive_bundle_dir <- shinylive_assets_dir(version)
  if (!fs::dir_exists(shinylive_bundle_dir)) {
    message(shinylive_bundle_dir, " does not exist")
    download_shinylive(url = url, version = version, destdir = destdir)
  }

  shinylive_bundle_dir
}



# """Removes local copies of shinylive web assets, except for the one used by the
# current version of the shinylive python package.

# Parameters
# ----------
# shinylive_dir
#     The directory where shinylive is stored. If None, the default directory will
#     be used.
# """
cleanup_shinylive_assets <- function(
    shinylive_dir = shinylive_cache_dir()) {
  # TODO-barret: Future - Sort descending by version numbers
  versions <- vapply(
    installed_shinylive_versions(shinylive_dir),
    function(ver_path) {
      sub(shinylive_prefix, "", basename(ver_path))
    },
    character(1)
  )
  if (SHINYLIVE_ASSETS_VERSION %in% versions) {
    message("Keeping version ", SHINYLIVE_ASSETS_VERSION)
    versions <- setdiff(versions, SHINYLIVE_ASSETS_VERSION)
  }

  remove_shinylive_assets(shinylive_dir, versions)
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
remove_shinylive_assets <- function(
    shinylive_dir,
    versions) {
  stopifnot(length(versions) > 0 && is.character(versions))

  lapply(versions, function(version) {
    target_dir <- shinylive_assets_dir_(cache_dir = shinylive_dir, version = version)
    if (fs::dir_exists(target_dir)) {
      message("Removing ", target_dir)
      unlink_path(target_dir)
    } else {
      message(target_dir, " does not exist")
    }
  })

  invisible()
}



installed_shinylive_versions <- function(
    shinylive_dir = shinylive_cache_dir()) {
  # fs::dir_ls(shinylive_dir, type = "directory", regexp = "^shinylive-")
  fs::path(
    shinylive_dir,
    # Using `dir()` to avoid the path expansion that `fs::dir_ls()` does.
    # `dir()` is 10x faster than `fs::dir_ls()`
    dir(shinylive_dir, full.names = FALSE, pattern = "^shinylive-")
  )
}





print_shinylive_local_info <- function() {
  installed_versions <- installed_shinylive_versions()
  if (length(installed_versions) == 0) {
    installed_versions <- "(None)"
  }

  cat(
    collapse(c(
      "Shinylive local info:",
      "",
      "    Local cached shinylive asset dir:",
      collapse("    ", shinylive_cache_dir()),
      "",
      if (shinylive_cache_dir_exists()) {
        collapse(c(
          "    Installed versions:",
          collapse("    ", installed_versions)
        ))
      } else {
        "    (Cache dir does not exist)"
      }
    )),
    sep = ""
  )
}


# """Checks if the URL for the Shinylive assets bundle is valid.

# Returns True if the URL is valid (with a 200 status code), False otherwise.

# The reason it has both the `version` and `url` parameters is so that it behaves the
# same as `download_shinylive()` and `ensure_shinylive_assets()`.
# """
check_assets_url <- function(
    version = SHINYLIVE_ASSETS_VERSION,
    url = shinylive_bundle_url(version)) {
  req <- httr::HEAD(url)
  req$status_code == 200
}
