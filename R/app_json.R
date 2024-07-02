# This is the same as the FileContentJson type in TypeScript.
FILE_CONTENT_CLASS <- "shinylive_file_content"
file_content_obj <- function(name, content, type = c("text", "binary")) {
  structure(
    list(
      name = name,
      content = content,
      type = match.arg(type)
    ),
    class = c(FILE_CONTENT_CLASS, "list")
  )
}

APP_INFO_CLASS <- "shinylive_app_info"
app_info_obj <- function(appdir, subdir, files) {
  stopifnot(inherits(files, "list"))
  lapply(files, function(file) {
    stopifnot(inherits(file, FILE_CONTENT_CLASS))
  })
  structure(
    list(
      appdir = appdir,
      subdir = subdir,
      files = files
    ),
    class = APP_INFO_CLASS
  )
}


# =============================================================================
# """
# Load files for a Shiny application.
#
# Parameters
# ----------
# appdir : str
#     Directory containing the application.
#
# destdir : str
#     Destination directory. This is used only to avoid adding shinylive assets when
#     they are in a subdir of the application.
# """
read_app_files <- function(
  appdir,
  destdir
) {
  exclude_names <- c("__pycache__", "venv", ".venv", "rsconnect")
  # exclude_names_map <- setNames(rep(TRUE, length(exclude_names)), exclude_names)
  is_excluded <- function(name) {
    name %in% exclude_names
  }
  # Recursively iterate over files in app directory, and collect the files into
  # app_files data structure.

  # Returned from this function
  app_files <- list()
  # Add an app file entry from anywhere in `read_app_files` to avoid handling data from the bottom up
  add_file <- function(name, content, type) {
    app_files[[length(app_files) + 1]] <<-
      file_content_obj(
        name = name,
        content = content,
        type = type
      )
  }

  inspect_dir <- function(curdur) {
    stopifnot(fs::is_dir(curdur))

    # Check for excluded dirs
    curdur_basename <- basename(curdur)
    if (is_excluded(curdur_basename)) {
      return(NULL)
    }

    # If the current directory is inside of the destdir, then do not inspect
    if (fs::path_has_parent(curdur, destdir)) {
      return(NULL)
    }

    # Do not need to worry about names that start with `.` as
    # they are not returned by `fs::dir_walk(all = FALSE)`.
    # `dir()` is 10x faster than `fs::dir_ls()`
    cur_paths <- dir(curdur, full.names = TRUE)
    # Stable sort
    cur_paths <- sort(cur_paths, method = "radix")

    cur_paths_basename <- basename(cur_paths)
    # Move `app.R`, `ui.R`, `server.R` to first in list
    first_files <- c("app.R", "ui.R", "server.R")
    # print(list(cur_paths, has_first_files, has_first_files))
    has_first_files <- first_files %in% cur_paths_basename
    is_first_file <- cur_paths_basename %in% first_files
    if (any(is_first_file)) {
      cur_paths <- c(
        # Only first files found
        cur_paths[is_first_file],
        # Other files without first files
        cur_paths[!is_first_file]
      )
    }

    # For each file/dir in this directory...
    Map(
      cur_paths,
      f = function(cur_path) {
        if (fs::is_dir(cur_path)) {
          # Recurse
          inspect_dir(cur_path)
          return(NULL)
        }

        # cur_path is a file!

        cur_basename <- basename(cur_path)
        if (cur_basename == "shinylive.js") {
          cli::cli_warn(c(
            "Warning: Found {.path shinylive.js} in source directory {.path {curdur}}.",
            i = "Are you including a shinylive distribution in your app?"
          ))
        }

        # Get file content
        file_content <- try(brio::read_file(cur_path), silent = TRUE)
        if (!inherits(file_content, "try-error")) {
          file_type <- "text"
        } else {
          # Try reading as binary
          file_content <- brio::read_file_raw(cur_path)
          file_type <- "binary"
        }

        add_file(
          name = fs::path_rel(cur_path, appdir),
          content = file_content,
          type = file_type
        )
      }
    )
    invisible()
  }

  inspect_dir(appdir)

  app_files
}




# """
# Write index.html, edit/index.html, and app.json for an application in the destdir.
# """
write_app_json <- function(
  app_info,
  destdir,
  template_dir,
  template_params = list(),
  quiet = getOption("shinylive.quiet", FALSE)
) {
  local_quiet(quiet)

  stopifnot(inherits(app_info, APP_INFO_CLASS))
  # stopifnot(fs::dir_exists(destdir))
  stopifnot(fs::dir_exists(template_dir))

  app_destdir <- fs::path(destdir, app_info$subdir)

  # For a subdir like a/b/c, this will be ../../../
  subdir_inverse <- paste0(rep("..", length(fs::path_split(app_info$subdir)[[1]])), collapse = "/")
  if (subdir_inverse != "") {
    # Add trailing slash
    subdir_inverse <- paste0(subdir_inverse, "/")
  }

  # Then iterate over the HTML files in the template directory and interpolate
  # the template parameters.
  template_files <- fs::dir_ls(template_dir, recurse = TRUE, type = "file")

  template_params <- rlang::dots_list(
    # Forced parameters
    REL_PATH = subdir_inverse,
    APP_ENGINE = "r",
    # User parameters
    !!!template_params,
    # Default parameters
    title = "Shiny App",
    .homonyms = "first"
  )

  for (template_file in template_files) {
    dest_file <- fs::path(app_destdir, fs::path_rel(template_file, template_dir))
    fs::dir_create(fs::path_dir(dest_file))

    if (fs::path_ext(template_file) == "html") {
      file_content <- whisker::whisker.render(
        template = brio::read_file(template_file), 
        data = template_params
      )
      brio::write_file(file_content, dest_file)
    } else {
      fs::file_copy(template_file, dest_file)
    }
  }

  app_json_output_file <- fs::path(app_destdir, "app.json")

  cli_progress_step("Writing {.path {app_json_output_file}}")
  jsonlite::write_json(
    app_info$files,
    path = app_json_output_file,
    auto_unbox = TRUE,
    pretty = FALSE
  )
  cli_progress_done()
  cli_alert_info("Wrote {.path {app_json_output_file}} ({fs::file_info(app_json_output_file)$size[1]} bytes)")
  
  invisible(app_json_output_file)
}
