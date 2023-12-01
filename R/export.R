#' Export a Shiny app to a directory
#'
#' This function exports a Shiny app to a directory, which can then be served
#' using `httpuv`.
#'
#' @param appdir Directory containing the application.
#' @param destdir Destination directory.
#' @param subdir Subdirectory of `destdir` to write the app to.
#' @param verbose Print verbose output. Defaults to `TRUE` if running
#'    interactively.
#' @param ... Ignored
#' @export
#' @return Nothing. The app is exported to `destdir`. Instructions for serving
#' the directory are printed to stdout.
#' @importFrom rlang is_interactive
#' @examplesIf interactive()
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
    verbose = is_interactive()) {
  verbose_print <- if (verbose) message else list

  stopifnot(fs::is_dir(appdir))
  if (!(
    fs::file_exists(fs::path(appdir, "app.R")) ||
      fs::file_exists(fs::path(appdir, "server.R"))
  )) {
    stop("Directory ", appdir, " does not contain an app.R or server.R file.")
  }

  if (fs::is_absolute_path(subdir)) {
    stop(
      "export(subdir=) was supplied an absolute path (`", subdir, "`).",
      " Only relative paths are allowed."
    )
  }

  if (!fs::dir_exists(destdir)) {
    verbose_print("Creating ", destdir, "/")
    fs::dir_create(destdir)
  }


  cp_funcs <- create_copy_fn(overwrite = FALSE, verbose_print = verbose_print)
  mark_file <- cp_funcs$mark_file
  copy_files <- cp_funcs$copy_files

  assets_path <- assets_dir()

  # =========================================================================
  # Copy the base dependencies for shinylive/ distribution. This does not
  # include the R package files.
  # =========================================================================
  verbose_print(
    "Copying base Shinylive files from ", assets_path, "/ to ", destdir, "/"
  )
  # When exporting, we know it is only an R app. So remove python support
  base_files <- c(shinylive_common_files("base"), shinylive_common_files("r"))
  if (verbose) {
    p <- progress::progress_bar$new(
      format = "[:bar] :percent",
      total = length(base_files),
      clear = TRUE,
      # show_after = 0
    )
  }
  Map(
    file.path(assets_path, base_files),
    file.path(destdir, base_files),
    f = function(src_path, dest_path) {
      if (verbose) {
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
  # For each app, write the index.html, edit/index.html, and app.json in
  # destdir/subdir.
  # =========================================================================
  write_app_json(
    app_info,
    destdir,
    html_source_dir = fs::path(assets_path, "export_template"),
    verbose = verbose
  )

  verbose_print(
    "\nRun the following in an R session to serve the app:\n",
    "  httpuv::runStaticServer(\"", destdir, "\")\n"
  )

  invisible()
}
