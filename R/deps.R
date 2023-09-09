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
  structure(
    list(
      name = name,
      path = path,
      attribs = attribs
    ),
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
    serviceworkers = NULL) {
  stopifnot(length(list(...)) == 0)
  assert_nzchar_string(name)
  is.null(version) || assert_nzchar_string(version)
  is.null(scripts) || assert_list_items(scripts, HTML_DEP_ITEM_CLASS)
  is.null(stylesheets) || assert_list_items(stylesheets, HTML_DEP_ITEM_CLASS)
  is.null(resources) || assert_list_items(resources, HTML_DEP_ITEM_CLASS)
  is.null(meta) || assert_list(meta)
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
      serviceworkers = serviceworkers
    ),
    class = c(QUARTO_HTML_DEPENDENCY_CLASS, "list")
  )
}

shinylive_base_deps_htmldep <- function(sw_dir = NULL) {
  list(
    serviceworker_dep(sw_dir),
    shinylive_common_dep_htmldep()
  )
}

serviceworker_dep <- function(sw_dir) {
  quarto_html_dependency_obj(
    name = "shinylive-serviceworker",
    version = SHINYLIVE_ASSETS_VERSION,
    serviceworkers = list(
      html_dep_serviceworker_obj(
        source = file.path(assets_dir(), "shinylive-sw.js"),
        destination = "/shinylive-sw.js"
      ),
      html_dep_serviceworker_obj(
        source = file.path(assets_dir(), "shinylive", "webr", "webr-serviceworker.js"),
        destination = "/webr-serviceworker.js"
      ),
      html_dep_serviceworker_obj(
        source = file.path(assets_dir(), "shinylive", "webr", "webr-worker.js"),
        destination = "/webr-worker.js"
      )
    ),
    meta =
      if (!is.null(sw_dir)) {
        # Add meta tag to tell load-shinylive-sw.js where to find shinylive-sw.js.
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
shinylive_common_dep_htmldep <- function() {
  assets_path <- assets_dir()
  base_files <- shinylive_common_files()

  scripts <- list()
  stylesheets <- list()
  resources <- list()

  add_item <- function(
      type = c("script", "stylesheet", "resource"),
      name,
      path,
      attribs = NULL) {
    dep_item <- html_dep_obj(name = name, path = path, attribs = attribs)
    switch(match.arg(type),
      "script" = {
        scripts[[length(scripts) + 1]] <<- dep_item
      },
      "stylesheet" = {
        stylesheets[[length(stylesheets) + 1]] <<- dep_item
      },
      "resource" = {
        resources[[length(resources) + 1]] <<- dep_item
      },
      {
        stop("unknown type: ", type)
      }
    )
  }

  lapply(base_files, function(base_file) {
    base_file_basename <- basename(base_file)
    if (
      base_file_basename == "load-shinylive-sw.js" ||
        base_file_basename == "run-python-blocks.js"
    ) {
      add_item(
        type = "script",
        name = base_file,
        path = file.path(assets_path, base_file),
        attribs = list(type = "module")
      )
    } else if (base_file_basename == "shinylive.css") {
      add_item(
        type = "stylesheet",
        name = base_file,
        path = file.path(assets_path, base_file)
      )
    } else {
      add_item(
        type = "resource",
        name = base_file,
        path = file.path(assets_path, base_file)
      )
    }
  })


  # # Add base python packages as resources
  # resources.extend(base_package_deps_htmldepitems())

  # Sort scripts so that load-serviceworker.js is first, and
  # run-python-blocks.js is last.
  scripts_names <- vapply(scripts, `[[`, character(1), "name")
  scripts <- c(
    scripts[scripts_names == "load-serviceworker.js"],
    scripts[scripts_names != "load-serviceworker.js"]
  )
  scripts_names <- vapply(scripts, `[[`, character(1), "name")
  scripts <- c(
    scripts[scripts_names != "run-python-blocks.js"],
    scripts[scripts_names == "run-python-blocks.js"]
  )

  quarto_html_dependency_obj(
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
shinylive_common_files <- function() {
  assets_ensure()

  assets_dir <- assets_dir()
  # `dir()` is 10x faster than `fs::dir_ls()`
  common_files <- dir(assets_dir, recursive = TRUE)

  # TODO-barret-future: Remove these files for lighter deployments.
  # common_files <- common_files[!grepl("^shinylive/pyodide/", common_files)]
  # common_files <- common_files[!grepl("^shinylive/pyright/", common_files)]
  common_files <- common_files[!grepl("^scripts/", common_files)]
  common_files <- common_files[!grepl("^export_template/", common_files)]
  common_files <- setdiff(common_files, "shinylive/examples.json")

  # Return relative path to the assets_dir
  fs::path(common_files)
}








# Also implement `package_deps_htmldepitems`? Return empty list?
