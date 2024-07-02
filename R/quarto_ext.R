#' Quarto extension for shinylive
#'
#' Integration with https://github.com/quarto-ext/shinylive
#'
#' @param args Command line arguments passed by the extension. See details for more information.
#' @param ... Ignored.
#' @param pretty Whether to pretty print the JSON output.
#' @param con File from which to take input. Default: `"stdin"`.
#' @return Nothing. Values are printed to stdout.
#' @section Command arguments:
#'
#' The first argument must be `"extension"`. This is done to match
#' `py-shinylive` so that it can nest other sub-commands under the `extension`
#' argument to minimize the api clutter the user can see.
#'
#' ### CLI Interface
#' * `extension info`
#'   * Prints information about the extension including:
#'     * `version`: The version of the R package
#'     * `assets_version`: The version of the web assets
#'     * `scripts`: A list of paths scripts that are used by the extension,
#'      mainly `codeblock-to-json`
#'   * Example
#'     ```
#'     {
#'       "version": "0.1.0",
#'       "assets_version": "0.2.0",
#'       "scripts": {
#'         "codeblock-to-json": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/scripts/codeblock-to-json.js"
#'       }
#'     }
#'     ```
#' * `extension base-htmldeps`
#'   * Prints the language agnostic quarto html dependencies as a JSON array.
#'     * The first html dependency is the `shinylive` service workers.
#'     * The second html dependency is the `shinylive` base dependencies. This
#'       dependency will contain the core `shinylive` asset scripts (JS files
#'       automatically sourced), stylesheets (CSS files that are automatically
#'       included), and resources (additional files that the JS and CSS files can
#'       source).
#'   * Example
#'     ```
#'     [
#'       {
#'         "name": "shinylive-serviceworker",
#'         "version": "0.2.0",
#'         "meta": { "shinylive:serviceworker_dir": "." },
#'         "serviceworkers": [
#'           {
#'             "source": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive-sw.js",
#'             "destination": "/shinylive-sw.js"
#'           }
#'         ]
#'       },
#'       {
#'         "name": "shinylive",
#'         "version": "0.2.0",
#'         "scripts": [{
#'           "name": "shinylive/load-shinylive-sw.js",
#'           "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/load-shinylive-sw.js",
#'             "attribs": { "type": "module" }
#'         }],
#'         "stylesheets": [{
#'           "name": "shinylive/shinylive.css",
#'           "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/shinylive.css"
#'         }],
#'         "resources": [
#'           {
#'             "name": "shinylive/shinylive.js",
#'             "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/shinylive.js"
#'           },
#'           ... # [ truncated ]
#'         ]
#'       }
#'     ]
#'     ```
#' * `extension language-resources`
#'   * Prints the language-specific resource files as JSON that should be added to the quarto html dependency.
#'     * For r-shinylive, this includes the webr resource files
#'     * For py-shinylive, this includes the pyodide and pyright resource files.
#'   * Example
#'     ```
#'     [
#'       {
#'         "name": "shinylive/webr/esbuild.d.ts",
#'         "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/webr/esbuild.d.ts"
#'       },
#'       {
#'         "name": "shinylive/webr/libRblas.so",
#'         "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/webr/libRblas.so"
#'       },
#'       ... # [ truncated ]
#'     ]
#' * `extension app-resources`
#'   * Prints app-specific resource files as JSON that should be added to the `"shinylive"` quarto html dependency.
#'   * Currently, r-shinylive does not return any resource files.
#'   * Example
#'     ```
#'     [
#'       {
#'         "name": "shinylive/pyodide/anyio-3.7.0-py3-none-any.whl",
#'         "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/pyodide/anyio-3.7.0-py3-none-any.whl"
#'       },
#'       {
#'         "name": "shinylive/pyodide/appdirs-1.4.4-py2.py3-none-any.whl",
#'         "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/pyodide/appdirs-1.4.4-py2.py3-none-any.whl"
#'       },
#'       ... # [ truncated ]
#'     ]
#'     ```
#'
quarto_ext <- function(
  args = commandArgs(trailingOnly = TRUE),
  ...,
  pretty = is_interactive(),
  con = "stdin"
) {
  stopifnot(length(list(...)) == 0)
  # This method should not print anything to stdout. Instead, it should return a JSON string that will be printed by the extension.
  stopifnot(length(args) >= 1)

  followup_statement <- function() {
    c(
      i = "Please update your {.href [quarto-ext/shinylive](https://github.com/quarto-ext/shinylive)} Quarto extension for the latest integration.",
      i = "To update the shinylive extension, run this command in your Quarto project:",
      "\t{.code quarto add quarto-ext/shinylive}",
      "",
      "R shinylive package version: {.field {SHINYLIVE_R_VERSION}}",
      "Supported assets version: {.field {assets_version()}}"
    )
  }

  # --version support
  if (args[1] == "--version") {
    cat(SHINYLIVE_R_VERSION, "\n")
    return(invisible())
  }

  if (args[1] != "extension") {
    cli::cli_abort(c(
      "Unknown command: {.strong {args[1]}}. Expected {.var extension} as first argument",
      "",
      followup_statement()
    ))
  }

  methods <- list(
    "info" = "Package, version, asset version, and script paths information",
    "base-htmldeps" = "Quarto html dependencies for the base shinylive integration",
    "language-resources" = "R's resource files for the quarto html dependency named `shinylive`",
    "app-resources" = "App-specific resource files for the quarto html dependency named `shinylive`"
  )

  not_enough_args <- length(args) < 2
  invalid_arg <- length(args) >= 2 && !(args[2] %in% names(methods))

  if (not_enough_args || invalid_arg) {
    msg_stop <- 
      if (not_enough_args) {
        "Missing {.var extension} subcommand"
      } else if (invalid_arg) {
        "Unknown {.var extension} subcommand {.strong {args[2]}}"
      }
    
    msg_methods <- c()
    for (method in names(methods)) {
      method_desc <- methods[[method]]
      msg_methods <- c(msg_methods, paste(cli::style_bold(method), "-", method_desc))
    }

    cli::cli_abort(c(
      msg_stop,
      "",
      cli::style_underline("Available methods"),
      msg_methods,
      "",
      followup_statement()
    ))
  }
  stopifnot(length(args) >= 2)

  ret <- switch(
    args[2],
    "info" = {
      list(
        "version" = SHINYLIVE_R_VERSION,
        "assets_version" = assets_version(),
        "scripts" = list(
          "codeblock-to-json" = quarto_codeblock_to_json_path()
        )
      )
    },
    "base-htmldeps" = {
      sw_dir_pos <- which(args == "--sw-dir")
      if (length(sw_dir_pos) == 1) {
        if (sw_dir_pos == length(args)) {
          stop("expected `--sw-dir` argument value")
        }
        sw_dir <- args[sw_dir_pos + 1]
      } else {
        stop("expected `--sw-dir` argument")
      }
      # Language agnostic files
      shinylive_base_deps_htmldep(sw_dir)
    },
    "language-resources" = {
      shinylive_r_resources()
      # shinylive_python_resources()
    },
    "app-resources" = {
      app_json <- readLines(con, warn = FALSE)
      build_app_resources(app_json)
    },
    {
      stop("Not implemented `extension` type: ", args[2])
    }
  )
  ret_null_free <- drop_nulls_rec(ret)
  ret_json <- jsonlite::toJSON(ret_null_free, pretty = pretty, auto_unbox = TRUE)
  # Make sure the json is printed to stdout.
  # Do not rely on Rscript to print the last value.
  print(ret_json)

  # Return invisibly, so that nothing is printed
  invisible()
}

build_app_resources <- function(app_json) {
  appdir <- fs::path(".quarto", "_webr", "appdir")
  destdir <- fs::path(".quarto", "_webr", "destdir")

  # Build app directory, removing any previous app expanded there
  if (fs::dir_exists(appdir)) {
    fs::dir_delete(appdir)
  }
  fs::dir_create(appdir, recurse = TRUE)

  # Convert app.json into files on disk, so we can use `renv::dependencies()`
  app <- jsonlite::fromJSON(
    app_json,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  )
  lapply(app, function(file) {
    file_path <- fs::path(appdir, file$name)
    if (file$type == "text") {
      writeLines(file$content, file_path)
    } else {
      try({
        raw_content <- jsonlite::base64_dec(file$content)
        writeBin(raw_content, file_path, useBytes = TRUE)
      })
    }
  })

  # Download wasm binaries ready to embed into Quarto deps
  withr::with_options(
    list(shinylive.quiet = TRUE),
    download_wasm_packages(appdir, destdir, package_cache = TRUE)
  )

  # Enumerate R package Wasm binaries and prepare the VFS images as html deps
  webr_dir <- fs::path(destdir, "shinylive", "webr")
  packages_files <- dir(webr_dir, recursive = TRUE, full.names = FALSE)
  packages_paths <- file.path("shinylive", "webr", packages_files)
  packages_abs <- file.path(fs::path_abs(webr_dir), packages_files)

  Map(
    USE.NAMES = FALSE,
    packages_paths,
    packages_abs,
    f = function(rel_common_file, abs_common_file) {
      html_dep_obj(
        name = rel_common_file,
        path = abs_common_file
      )
    }
  )
}

quarto_codeblock_to_json_path <- function() {
  file.path(assets_dir(), "scripts", "codeblock-to-json.js")
}

# def package_deps(json_file: Optional[str]) -> None:
#     json_content: str | None = None
#     if json_file is None:
#         json_content = sys.stdin.read()

#     deps = _deps.package_deps_htmldepitems(json_file, json_content)
#     print(json.dumps(deps, indent=2))
