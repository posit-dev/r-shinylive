SHINYLIVE_DEFAULT_MAX_FILESIZE <- "100MB"
SHINYLIVE_WASM_PACKAGES <- TRUE

# Sys env maximum filesize for asset bundling
sys_env_max_filesize <- function() {
  max_fs_env <- Sys.getenv("SHINYLIVE_DEFAULT_MAX_FILESIZE")
  if (max_fs_env == "") NULL else max_fs_env
}

sys_env_wasm_packages <- function() {
  pkgs_env <- Sys.getenv("SHINYLIVE_WASM_PACKAGES", SHINYLIVE_WASM_PACKAGES)
  pkgs_env <- switch(pkgs_env, "1" = TRUE, "0" = FALSE, pkgs_env)
  wasm_packages <- as.logical(pkgs_env)
  if (is.na(wasm_packages)) {
    cli::cli_abort("Could not parse `wasm_packages` value: {.code {pkgs_env}}")
  }
  wasm_packages
}

# Resolve package list, dependencies listed in Depends and Imports
resolve_dependencies <- function(pkgs, local = TRUE) {
  pkg_refs <- if (local) {
    refs <- find.package(pkgs, lib.loc = NULL, quiet = FALSE, !is_quiet())
    glue::glue("local::{refs}")
  } else {
    pkgs
  }
  wasm_config <- list(
    platforms = "source",
    dependencies = list(c("Depends", "Imports"), c("Depends", "Imports"))
  )
  inst <- pkgdepends::new_pkg_deps(pkg_refs, config = wasm_config)
  inst$resolve()
  unique(inst$get_resolution()$package)
}

check_repo_pkg_version <- function(desc, ver, pkg) {
  # Show a warning if packages major.minor versions differ
  # We don't worry too much about patch, since webR versions of packages may be
  # patched at the repo for compatibility with Emscripten
  inst_ver <- package_version(desc$Version)
  repo_ver <- package_version(ver)
  if (inst_ver$major != repo_ver$major || inst_ver$minor != repo_ver$minor) {
    cli::cli_warn(c(
      "Package version mismatch for {.pkg {pkg}}, ensure the versions below are compatible.",
      "!" = "Installed version: {desc$Version}, WebAssembly version: {ver}.",
      "i" = "Install a package version matching the WebAssembly version to silence this error."
    ))
  }
}

get_wasm_assets <- function(desc, repo) {
  pkg <- desc$Package
  r_short <- gsub("\\.[^.]+$", "", WEBR_R_VERSION)
  contrib <- glue::glue("{repo}/bin/emscripten/contrib/{r_short}")

  info <- utils::available.packages(contriburl = contrib)
  if (!pkg %in% rownames(info)) {
    cli::cli_warn("Can't find {.pkg {pkg}} in Wasm binary repository: {.url {repo}}")
    return(list())
  }

  ver <- info[pkg, "Version", drop = TRUE]
  check_repo_pkg_version(desc, ver, pkg)

  list(
    list(
      filename = glue::glue("{pkg}_{ver}.tgz"),
      url = glue::glue("{contrib}/{pkg}_{ver}.tgz")
    )
  )
}

get_github_wasm_assets <- function(desc) {
  pkg <- desc$Package
  user <- desc$RemoteUsername
  repo <- desc$RemoteRepo
  ref <- desc$RemoteRef

  # Find a release for installed package's RemoteRef
  tags <- tryCatch(
    gh::gh(
      "/repos/{user}/{repo}/releases/tags/{ref}",
      user = user,
      repo = repo,
      ref = ref
    ),
    error = function(err) {
      cli::cli_abort(
        c(
          "Can't find GitHub release for github::{user}/{repo}@{ref}",
          "!" = "Ensure a GitHub release exists for the package repository reference: {.val {ref}}.",
          "i" = "Alternatively, install a CRAN version of this package to use the default Wasm binary repository."
        ),
        parent = err
      )
    }
  )

  # Find GH release asset URLs for R library VFS image
  library_data <- Filter(function(item) {
    grepl("library.data", item$name, fixed = TRUE)
  }, tags$assets)
  library_metadata <- Filter(function(item) {
    item$name == "library.js.metadata"
  }, tags$assets)

  if (length(library_data) == 0 || length(library_metadata) == 0) {
    # We are stricter here than with CRAN-like repositories, the asset bundle
    # `RemoteRef` must match exactly. This allows for the use of development
    # versions of packages through the GitHub pre-releases feature.
    cli::cli_abort(c(
      "Can't find WebAssembly binary assets for github::{user}/{repo}@{ref}",
      "!" = "Ensure WebAssembly binary assets are associated with the GitHub release {.val {ref}}.",
      "i" = "WebAssembly binary assets can be built on release using GitHub Actions: {.url https://github.com/r-wasm/actions}",
      "i" = "Alternatively, install a CRAN version of this package to use the default Wasm binary repository."
    ))
  }

  list(
    list(
      filename = library_data[[1]]$name,
      url = library_data[[1]]$browser_download_url
    ),
    list(
      filename = library_metadata[[1]]$name,
      url = library_metadata[[1]]$browser_download_url
    )
  )
}

# Lookup URL and metadata for Wasm binary package
prepare_wasm_metadata <- function(pkg, metadata) {
  desc <- utils::packageDescription(pkg)
  repo <- desc$Repository
  prev_ref <- metadata$ref
  prev_cached <- metadata$cached
  metadata$name <- pkg
  metadata$version <- desc$Version

  # Skip base R packages
  if (!is.null(desc$Priority) && desc$Priority == "base") {
    metadata$ref <- glue::glue("{metadata$name}@{metadata$version}")
    metadata$type <- "base"
    metadata$cached <- prev_cached <- TRUE
    cli_alert("Skipping base R package: {metadata$ref}")
    return(metadata)
  }

  # Set a package ref for caching
  if (!is.null(desc$RemoteType) && desc$RemoteType == "github") {
    user <- desc$RemoteUsername
    repo <- desc$RemoteRepo
    sha <- desc$RemoteSha
    metadata$ref <- glue::glue("github::{user}/{repo}@{sha}")
  } else if (is.null(repo) || repo == "CRAN") {
    repo <- "CRAN"
    metadata$ref <- glue::glue("{metadata$name}@{metadata$version}")
  } else if (grepl("Bioconductor", repo)) {
    metadata$ref <- glue::glue("bioc::{metadata$name}@{metadata$version}")
  } else if (grepl("r-universe\\.dev$", repo)) {
    metadata$ref <- glue::glue("{repo}::{metadata$name}@{desc$RemoteSha}")
  } else {
    metadata$ref <- glue::glue("{metadata$name}@{metadata$version}")
  }

  # If not cached, discover Wasm binary URLs
  if (is.null(prev_cached) || !prev_cached || prev_ref != metadata$ref) {
    metadata$cached <- FALSE
    if (!is.null(desc$RemoteType) && desc$RemoteType == "github") {
      metadata$assets <- get_github_wasm_assets(desc)
      metadata$type <- "library"
    } else if (grepl("r-universe\\.dev$", repo)) {
      metadata$assets <- get_wasm_assets(desc, repo = desc$Repository)
      metadata$type <- "package"
    } else if (grepl("Bioconductor", repo)) {
      # Use r-universe for Bioconductor packages
      metadata$assets <- get_wasm_assets(desc, repo = "https://bioc.r-universe.dev")
      metadata$type <- "package"
    } else {
      # Fallback to repo.r-wasm.org lookup for CRAN and anything else
      metadata$assets <- get_wasm_assets(desc, repo = "http://repo.r-wasm.org")
      metadata$type <- "package"
    }
  } else {
    cli_alert("Skipping cached Wasm binary: {metadata$ref}")
  }

  metadata
}

# Dev usage:
# withr::with_envvar(list(SHINYLIVE_DOWNLOAD_WASM_CORE_PACKAGES = "bslib"), {CODE})
env_download_wasm_core_packages <- function() {
  pkgs <- Sys.getenv("SHINYLIVE_DOWNLOAD_WASM_CORE_PACKAGES", "")

  if (!nzchar(pkgs)) {
    return()
  }

  strsplit(pkgs, "\\s*[ ,\n]\\s*")[[1]]
}

download_wasm_packages <- function(appdir, destdir, package_cache, max_filesize) {
  max_filesize_missing <- is.null(sys_env_max_filesize()) && is.null(max_filesize)
  max_filesize_cli_fn <- if (max_filesize_missing) cli::cli_warn else cli::cli_abort

  max_filesize <- max_filesize %||% sys_env_max_filesize() %||% SHINYLIVE_DEFAULT_MAX_FILESIZE
  max_filesize <- if (is.na(max_filesize) || (max_filesize < 0)) Inf else max_filesize
  max_filesize_val <- max_filesize
  max_filesize <- fs::fs_bytes(max_filesize)
  if (is.na(max_filesize)) {
    cli::cli_warn(c(
      "!" = "Could not parse `max_filesize` value: {.code {max_filesize_val}}",
      "i" = "Setting to {.code {SHINYLIVE_DEFAULT_MAX_FILESIZE}}"
    ))
    max_filesize <- fs::fs_bytes(SHINYLIVE_DEFAULT_MAX_FILESIZE)
  }

  # Core packages in base webR image that we don't need to download
  shiny_pkgs <- c("shiny", "bslib", "renv")
  shiny_pkgs <- resolve_dependencies(shiny_pkgs, local = FALSE)

  # If a package appears in the download core allow list,
  # we remove it from the internal list of packages to skip downloading
  pkgs_download_core <- env_download_wasm_core_packages()
  if (length(pkgs_download_core) > 0) {
    shiny_pkgs <- setdiff(shiny_pkgs, pkgs_download_core)
  }

  # App dependencies, ignoring base webR + shiny packages
  pkgs_app <- unique(renv::dependencies(appdir, quiet = is_quiet())$Package)
  pkgs_app <- setdiff(pkgs_app, shiny_pkgs)

  # Create empty R packages directory in app assets if not already there
  pkg_dir <- fs::path(destdir, "shinylive", "webr", "packages")
  fs::dir_create(pkg_dir, recurse = TRUE)

  cli_progress_step(
    "Downloading WebAssembly R package binaries to {.path {pkg_dir}}"
  )

  # Load existing metadata from disk, from a previously deployed app
  metadata_file <- fs::path(destdir, "shinylive", "webr", "packages", "metadata.rds")
  prev_metadata <- if (package_cache && fs::file_exists(metadata_file)) {
    readRDS(metadata_file)
  } else {
    list()
  }

  if (length(pkgs_app) > 0) {
    pkgs_app <- resolve_dependencies(pkgs_app)
    pkgs_app <- setdiff(pkgs_app, shiny_pkgs)
    names(pkgs_app) <- pkgs_app
  }

  if (!is_quiet()) {
    p <- progress::progress_bar$new(
      format = "[:bar] :percent\n",
      total = length(pkgs_app),
      clear = TRUE,
      show_after = 0
    )
  }

  # Loop over packages and download them if not cached
  cur_metadata <- lapply(pkgs_app, function(pkg) {
    if (!is_quiet()) p$tick()

    pkg_subdir <- fs::path(pkg_dir, pkg)
    fs::dir_create(pkg_subdir, recurse = TRUE)

    prev_meta <- if (pkg %in% names(prev_metadata)) {
      prev_metadata[[pkg]]
    } else {
      list()
    }
    # Create package ref and lookup download URLs
    meta <- prepare_wasm_metadata(pkg, prev_meta)

    if (!meta$cached) {
      # Download Wasm binaries and copy to static assets dir
      for (file in meta$assets) {
        path <- fs::path(pkg_subdir, file$filename)
        utils::download.file(file$url, path, mode = "wb")

        # Disallow this package if an asset is too large
        if (fs::file_size(path) > max_filesize) {
          fs::dir_delete(pkg_subdir)
          meta$assets = list()
          max_filesize_cli_fn(c(
            "!" = "The file size of package {.pkg {pkg}} is larger than the maximum allowed file size of {.strong {max_filesize}}.",
            "!" = "This package will not be included as part of the WebAssembly asset bundle.",
            "i" = "Set the maximum allowed size to {.code -1}, {.code Inf}, or {.code NA} to disable this check.",
            "i" = if (max_filesize_missing) "Explicitly set the maximum allowed size to treat this as an error." else NULL
          ))
          break
        }
      }

      meta$cached <- TRUE
      meta$path <- NULL
      if (length(meta$assets) > 0) {
        meta$path <- glue::glue("packages/{pkg}/{meta$assets[[1]]$filename}")
      }
    }
    meta
  })

  # Merge metadata to protect previous cache
  pkgs <- unique(c(names(prev_metadata), names(cur_metadata)))
  metadata <- Map(
    function(a, b) if (is.null(b)) a else b,
    prev_metadata[pkgs],
    cur_metadata[pkgs]
  )
  names(metadata) <- pkgs

  # Remove base packages from caching and metadata
  metadata <- Filter(function(item) item$type != "base", metadata)

  cli_progress_step("Writing app metadata to {.path {metadata_file}}")
  saveRDS(metadata, metadata_file)
  cli_progress_done()
  cli_alert_info("Wrote {.path {metadata_file}} ({fs::file_info(metadata_file)$size[1]} bytes)")

  invisible(metadata_file)
}
