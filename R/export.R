# from __future__ import annotations

# import os
# import sys
# from pathlib import Path

# from . import _deps, _utils
# from ._app_json import AppInfo, read_app_files, write_app_json
# from ._assets import shinylive_assets_dir


export <- function(
    appdir,
    destdir,
    ...,
    subdir = "",
    verbose = FALSE
    # full_shinylive = FALSE
) {
  verbose_print <- if (verbose) message else list

  if (!fs::file_exists(fs::path(appdir, "app.R"))) {
    stop("Directory ", appdir, " does not contain an app.R file.")
  }

  if (fs::is_absolute_path(subdir)) {
    stop(
      "export(subdir=) was supplied an absolute path (`", subdir, "`).",
      " Only relative paths are allowed."
    )
  }

  if (!fs::dir_exists(destdir)) {
    message("Creating ", destdir, "/")
    fs::dir_create(destdir)
  }


  copy_fn = create_copy_fn(overwrite=FALSE, verbose_print=verbose_print)

  assets_dir = shinylive_assets_dir()

  # =========================================================================
  # Copy the base dependencies for shinylive/ distribution. This does not
  # include the R package files.
  # =========================================================================
  message(
    "Copying base Shinylive files from ", assets_dir, "/ to ", destdir, "/"
  )
  base_files <- shinylive_common_files()
  p <- progress::progress_bar$new(
    format = "[:bar] :percent",
    total = length(base_files),
    clear = TRUE,
    # show_after = 0
  )
  lapply(base_files, function(base_file) {
    src_path <- fs::path(assets_dir, base_file)
    dest_path <- fs::path(destdir, base_file)
    p$tick()

    copy_fn(src_path, dest_path)
  })

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
  #     package_files = _utils.listdir_recursive(assets_dir / "shinylive" / "pyodide")
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
  #         f"Copying imported packages from {assets_dir}/shinylive/pyodide/ to {destdir}/shinylive/pyodide/",
  #         file=sys.stderr,
  #     )
  #     verbose_print(" ", ", ".join(package_files))

  # for filename in package_files:
  #     src_path = assets_dir / "shinylive" / "pyodide" / filename
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
    html_source_dir = fs::path(assets_dir, "export_template")
  )

  message(
    "\nRun the following in an R session to serve the app:\n",
    "  httpuv::runStaticServer(\"", destdir, "\", port=8008)\n"
  )
}
