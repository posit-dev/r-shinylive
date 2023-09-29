HTML_DEP_ITEM_CLASS <- "shinylive_html_dep"
html_dep_obj <- function(
    ...,
    name,
    path,
    attribs = NULL) {
  stopifnot(length(list(...)) == 0)
  assert_nzchar_string(name)
  assert_nzchar_string(path)
  is.null(attribs) || assert_list(attribs)
  ret <- list(
    name = name,
    path = path
  )
  if (!is.null(attribs)) {
    ret$attribs <- attribs
  }
  structure(
    ret,
    class = c(HTML_DEP_ITEM_CLASS, "list")
  )
}

HTML_DEP_SERVICEWORKER_CLASS <- "shinylive_html_dep_serviceworker"
html_dep_serviceworker_obj <- function(
    ...,
    source,
    destination) {
  stopifnot(length(list(...)) == 0)
  assert_nzchar_string(source)
  assert_nzchar_string(destination)
  structure(
    list(
      source = source,
      destination = destination
    ),
    class = c(HTML_DEP_SERVICEWORKER_CLASS, "list")
  )
}

QUARTO_HTML_DEPENDENCY_CLASS <- "shinylive_quarto_html_dependency"
quarto_html_dependency_obj <- function(
    ...,
    name,
    version = NULL,
    scripts = NULL,
    stylesheets = NULL,
    resources = NULL,
    meta = NULL,
    head = NULL,
    serviceworkers = NULL) {
  stopifnot(length(list(...)) == 0)
  assert_nzchar_string(name)
  is.null(version) || assert_nzchar_string(version)
  is.null(scripts) || assert_list_items(scripts, HTML_DEP_ITEM_CLASS)
  is.null(stylesheets) || assert_list_items(stylesheets, HTML_DEP_ITEM_CLASS)
  is.null(resources) || assert_list_items(resources, HTML_DEP_ITEM_CLASS)
  is.null(meta) || assert_list(meta)
  is.null(head) || assert_nzchar_string(head)
  is.null(serviceworkers) ||
    assert_list_items(serviceworkers, HTML_DEP_SERVICEWORKER_CLASS)

  structure(
    list(
      name = name,
      version = version,
      scripts = scripts,
      stylesheets = stylesheets,
      resources = resources,
      meta = meta,
      head = head,
      serviceworkers = serviceworkers
    ),
    class = c(QUARTO_HTML_DEPENDENCY_CLASS, "list")
  )
}

shinylive_base_deps_htmldep <- function(sw_dir = NULL) {
  list(
    serviceworker_dep(sw_dir),
    shinylive_common_dep_htmldep("base")
  )
}
shinylive_r_resources <- function() {
  shinylive_common_dep_htmldep("r")$resources
}
# Not used in practice!
shinylive_python_resources <- function(sw_dir = NULL) {
  shinylive_common_dep_htmldep("python")$resources
}


serviceworker_dep <- function(sw_dir) {
  quarto_html_dependency_obj(
    name = "shinylive-serviceworker",
    version = SHINYLIVE_ASSETS_VERSION,
    serviceworkers = list(
      html_dep_serviceworker_obj(
        source = file.path(assets_dir(), "shinylive-sw.js"),
        destination = "/shinylive-sw.js"
      )
    ),
    meta =
      if (!is.null(sw_dir)) {
        # Add meta tag to tell load-shinylive-sw.js where to find
        # shinylive-sw.js.
        list("shinylive:serviceworker_dir" = sw_dir)
      } else {
        NULL
      }
  )
}


# """
# Return an HTML dependency object consisting of files that are base
# dependencies; in other words, the files that are always included in a
# Shinylive deployment.
# """
shinylive_common_dep_htmldep <- function(dep_type = c("base", "python", "r")) {
  assets_path <- assets_dir()
  # In quarto ext, keep support for python engine
  rel_common_files <- shinylive_common_files(dep_type = dep_type)
  abs_common_files <- file.path(assets_path, rel_common_files)

  # `NULL` values can be inserted into;
  # Ex: `a <- NULL; a[[1]] <- 4; stopifnot(identical(a, list(4)))`
  scripts <- NULL
  stylesheets <- NULL
  resources <- NULL

  switch(dep_type,
    "python" = ,
    "r" = {
      # Language specific files are all resources
      # For speed / simplicity, create deps directly
      resources <- Map(
        USE.NAMES = FALSE,
        rel_common_files,
        abs_common_files,
        f = function(rel_common_file, abs_common_file) {
          html_dep_obj(
            name = rel_common_file,
            path = abs_common_file
          )
        }
      )
    },
    "base" = {
      # Placeholder for load-shinylive-sw.js; (Existance is validated later)
      load_shinylive_dep <- NULL
      # Placeholder for run-python-blocks.js; Appended to end of scripts
      run_python_blocks_dep <- NULL

      Map(
        rel_common_files,
        abs_common_files,
        basename(rel_common_files),
        f = function(rel_common_file, abs_common_file, common_file_basename) {
          switch(common_file_basename,
            "run-python-blocks.js" = {
              run_python_blocks_dep <<-
                html_dep_obj(
                  name = rel_common_file,
                  path = abs_common_file,
                  attribs = list(type = "module")
                )
            },
            "load-shinylive-sw.js" = {
              load_shinylive_dep <<-
                html_dep_obj(
                  name = rel_common_file,
                  path = abs_common_file,
                  attribs = list(type = "module")
                )
            },
            "shinylive.css" = {
              stylesheets[[length(stylesheets) + 1]] <<-
                html_dep_obj(
                  name = rel_common_file,
                  path = abs_common_file
                )
            },
            {
              # Resource file
              resources[[length(resources) + 1]] <<-
                html_dep_obj(
                  name = rel_common_file,
                  path = abs_common_file
                )
            }
          )
          # Do not return anything
          NULL
        }
      )


      # Put load-shinylive-sw.js in the scripts first
      if (is.null(load_shinylive_dep)) {
        stop("load-shinylive-sw.js not found in assets")
      }
      scripts <- c(list(load_shinylive_dep), scripts)

      # Append run_python_blocks_dep if it exists
      if (!is.null(run_python_blocks_dep)) {
        scripts[[length(scripts) + 1]] <- run_python_blocks_dep
      }
    },
    {
      stop("unknown dep_type: ", dep_type)
    }
  )

  # # Add base python packages as resources
  # python: `resources.extend(base_package_deps_htmldepitems())`

  quarto_html_dependency_obj(
    # MUST be called `"shinylive"` to match quarto ext name
    name = "shinylive",
    version = SHINYLIVE_ASSETS_VERSION,
    scripts = scripts,
    stylesheets = stylesheets,
    resources = resources
  )
}


# """
# Return a list of files that are base dependencies; in other words, the files
# that are always included in a Shinylive deployment.
# """
shinylive_common_files <- function(dep_type = c("base", "python", "r")) {
  dep_type <- match.arg(dep_type)
  assets_ensure()

  assets_folder <- assets_dir()
  # # `dir()` is 10x faster than `fs::dir_ls()`
  # common_files <- dir(assets_folder, recursive = TRUE)

  asset_files_in_folder <- function(assets_sub_path, recurse) {
    folder <-
      if (is.null(assets_sub_path)) {
        assets_folder
      } else {
        file.path(assets_folder, assets_sub_path)
      }
    files <- dir(folder, recursive = recurse, full.names = FALSE)
    rel_files <-
      if (is.null(assets_sub_path)) {
        files
      } else {
        file.path(assets_sub_path, files)
      }
    if (recurse) {
      # Does not contain dirs by definition
      # Return as is
      rel_files
    } else {
      # Remove directories
      rel_files[!file.info(file.path(folder, files))$isdir]
    }
  }

  common_files <-
    switch(dep_type,
      "base" = {
        # Do copy any "top-level" python files as they are minimal
        c(
          # Do not include `./scripts` or `./export_template` in base deps
          asset_files_in_folder(NULL, recurse = FALSE),
          # Do not include `./shinylive/examples.json` in base deps
          setdiff(asset_files_in_folder("shinylive", recurse = FALSE), "shinylive/examples.json")
        )
      },
      "r" = {
        c(
          asset_files_in_folder(file.path("shinylive", "webr"), recurse = TRUE)
        )
      },
      "python" = {
        c(
          asset_files_in_folder(file.path("shinylive", "pyodide"), recurse = TRUE),
          asset_files_in_folder(file.path("shinylive", "pyright"), recurse = TRUE)
        )
      },
      {
        stop("unknown dep_type: ", dep_type)
      }
    )

  # Return relative path to the assets in `assets_dir()`
  common_files
}
