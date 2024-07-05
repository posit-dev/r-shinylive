#' Export a Shiny app to a directory
#'
#' This function exports a Shiny app to a directory, which can then be served
#' using `httpuv`.
#'
#' @param appdir Directory containing the application.
#' @param destdir Destination directory.
#' @param subdir Subdirectory of `destdir` to write the app to.
#' @param quiet Suppress console output during export. Follows the global
#'   `shinylive.quiet` option or defaults to `FALSE` in interactive sessions if
#'   not set.
#' @param verbose Deprecated, please use `quiet` instead.
#' @param wasm_packages Download and include binary WebAssembly packages as
#'   part of the output app's static assets. Defaults to `TRUE`.
#' @param package_cache Cache downloaded binary WebAssembly packages. Defaults
#'   to `TRUE`.
#' @param assets_version The version of the Shinylive assets to use in the
#'   exported app. Defaults to [assets_version()]. Note, not all custom assets
#'   versions may work with this release of \pkg{shinylive}. Please visit the
#'   [shinylive asset releases](https://github.com/posit-dev/shinylive/releases)
#'   website to learn more information about the available `assets_version`
#'   values.
#' @param template_dir Path to a custom template directory to use when exporting
#'   the shinylive app. The template can be copied from the shinylive assets
#'   using: `fs::path(shinylive:::assets_dir(), "export_template")`.
#' @param template_params A list of parameters to pass to the template. The
#'   supported parameters depends on the template being used. Custom templates
#'   may support additional parameters (see `template_dir` for instructions on
#'   creating a custom template or to find the current shinylive assets' 
#'   templates).
#'   
#'   With shinylive assets > 0.4.1, the default export template supports the
#'   following parameters:
#' 
#'   1. `title`: The title of the app. Defaults to `"Shiny app"`.
#'   2. `include_in_head`, `include_before_body`, `include_after_body`: Raw
#'      HTML to be included in the `<head>`, just after the opening `<body>`,
#'      or just before the closing `</body>` tag, respectively.
#' @param ... Ignored
#' @export
#' @return Nothing. The app is exported to `destdir`. Instructions for serving
#' the directory are printed to stdout.
#' @examplesIf rlang::is_interactive()
#' app_dir <- system.file("examples", "01_hello", package = "shiny")
#' out_dir <- tempfile("shinylive-export")
#'
#' # Export the app to a directory
#' export(app_dir, out_dir)
#'
#' # Serve the exported directory
#' if (require(httpuv)) {
#'   httpuv::runStaticServer(out_dir)
#' }
export <- function(
  appdir,
  destdir,
  ...,
  subdir = "",
  quiet = getOption("shinylive.quiet", !is_interactive()),
  wasm_packages = TRUE,
  package_cache = TRUE,
  assets_version = NULL,
  template_dir = NULL,
  template_params = list(),
  verbose = NULL
) {
  if (!is.null(verbose)) {
    rlang::warn("The {.var verbose} argument is deprecated. Use {.var quiet} instead.")
    if (missing(quiet)) {
      quiet <- !verbose
    }
  }

  local_quiet(quiet)
  cli_alert_info("Exporting Shiny app from: {.path {appdir}}")
  cli_alert("Destination: {.path {destdir}}")

  if (is.null(assets_version)) {
    assets_version <- assets_version()
  }

  if (!fs::is_dir(appdir)) {
    cli::cli_abort("{.var appdir} must be a directory, but was provided {.path {appdir}}.")
  }
  if (!(
    fs::file_exists(fs::path(appdir, "app.R")) ||
      fs::file_exists(fs::path(appdir, "server.R"))
  )) {
    cli::cli_abort("Directory {.path {appdir}} does not contain an app.R or server.R file.")
  }

  if (fs::is_absolute_path(subdir)) {
    cli::cli_abort(
      "{.var subdir} was supplied an absolute path ({.path {subdir}}), but only relative paths are allowed."
    )
  }

  if (!fs::dir_exists(destdir)) {
    fs::dir_create(destdir)
  }


  cp_funcs <- create_copy_fn(overwrite = FALSE)
  mark_file <- cp_funcs$mark_file
  copy_files <- cp_funcs$copy_files

  assets_path <- assets_dir(version = assets_version)

  # =========================================================================
  # Copy the base dependencies for shinylive/ distribution. This does not
  # include the R package files.
  # =========================================================================
  cli_progress_step("Copying base Shinylive files")

  # When exporting, we know it is only an R app. So remove python support
  base_files <- c(
    shinylive_common_files("base", version = assets_version),
    shinylive_common_files("r", version = assets_version)
  )

  if (!is_quiet()) {
    p <- progress::progress_bar$new(
      format = "[:bar] :percent\n",
      total = length(base_files),
      clear = FALSE,
      show_after = 0
    )
  }
  Map(
    file.path(assets_path, base_files),
    file.path(destdir, base_files),
    f = function(src_path, dest_path) {
      if (!is_quiet()) {
        p$tick()
      }
      mark_file(src_path, dest_path)
    }
  )
  # lapply(base_files, function(base_file) {
  #   src_path <- fs::path(assets_path, base_file)
  #   dest_path <- fs::path(destdir, base_file)
  #   if (verbose) {
  #     p$tick()
  #   }

  #   # Add file to copy list
  #   copy_fn(src_path, dest_path)
  # })
  # Copy all files in one call
  copy_files()
  cli_progress_done()

  # =========================================================================
  # Load each app's contents into a list[FileContentJson]
  # =========================================================================
  app_info <- app_info_obj(
    appdir,
    subdir,
    read_app_files(appdir, destdir)
  )

  # # =========================================================================
  # # Copy dependencies from shinylive/pyodide/
  # # =========================================================================
  # if full_shinylive:
  #     package_files = _utils.listdir_recursive(assets_path / "shinylive" / "pyodide")
  #     # Some of the files in this dir are base files; don't copy them.
  #     package_files = [
  #         file
  #         for file in package_files
  #         if os.path.join("shinylive", "pyodide", file) not in base_files
  #     ]

  # else:
  #     deps = _deps.base_package_deps() + _deps.find_package_deps(app_info["files"])

  #     package_files: list[str] = [dep["file_name"] for dep in deps]

  #     print(
  #         f"Copying imported packages from {assets_path}/shinylive/pyodide/ to {destdir}/shinylive/pyodide/",
  #         file=sys.stderr,
  #     )
  #     verbose_print(" ", ", ".join(package_files))

  # for filename in package_files:
  #     src_path = assets_path / "shinylive" / "pyodide" / filename
  #     dest_path = destdir / "shinylive" / "pyodide" / filename
  #     if not dest_path.parent.exists():
  #         os.makedirs(dest_path.parent)

  #     copy_fn(src_path, dest_path)

  # =========================================================================
  # Copy app package dependencies as Wasm binaries
  # =========================================================================
  if (wasm_packages) {
    download_wasm_packages(appdir, destdir, package_cache)
  }

  # =========================================================================
  # For each app, write the index.html, edit/index.html, and app.json in
  # destdir/subdir.
  # =========================================================================
  write_app_json(
    app_info,
    destdir,
    template_dir = template_dir %||% fs::path(assets_path, "export_template"),
    quiet = quiet,
    template_params = template_params
  )

  # Escape backslashes in destdir because Windows
  destdir_esc <- gsub("\\\\", "\\\\\\\\", destdir)

  cli_alert_success("Shinylive app export complete.")
  cli_alert_info("Run the following in an R session to serve the app:")
  cli_text('{.run httpuv::runStaticServer("{destdir_esc}")}')

  invisible(destdir)
}
