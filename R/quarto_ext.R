#' Quarto extension for shinylive
#'
#' Integration with https://github.com/quarto-ext/shinylive
#'
#' @param args Command line arguments passed by the extension. See details for more information.
#' @param ... Ignored.
#' @param pretty Whether to pretty print the JSON output.
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
#' @importFrom rlang is_interactive
quarto_ext <- function(
    args = commandArgs(trailingOnly = TRUE),
    ...,
    pretty = is_interactive()) {
  stopifnot(length(list(...)) == 0)
  # This method should not print anything to stdout. Instead, it should return a JSON string that will be printed by the extension.
  stopifnot(length(args) >= 1)

  followup_statement <- function() {
    paste0(
      "Please update your `quarto-ext/shinylive` Quarto extension for the latest integration.\n",
      "To update the shinylive extension, run this command in your Quarto project:\n",
      "\tquarto add quarto-ext/shinylive\n",
      "\n",
      paste0("R shinylive package version:  ", SHINYLIVE_R_VERSION), "\n",
      paste0("Supported assets version: ", assets_version())
    )
  }

  # --version support
  if (args[1] == "--version") {
    cat(SHINYLIVE_R_VERSION, "\n")
    return(invisible())
  }

  if (args[1] != "extension") {
    stop(
      "Unknown command: '", args[1], "'\n",
      "Expected `extension` as first argument\n",
      "\n",
      followup_statement()
    )
  }


  if (
    (not_enough_args <- length(args) < 2) ||
      (invalid_arg <- !(args[2] %in% c(
        "info",
        "base-htmldeps",
        "language-resources",
        "app-resources"
      )))
  ) {
    stop(
      if (not_enough_args) {
        "Missing `extension` subcommand\n"
      } else if (invalid_arg) {
        paste0("Unknown `extension` subcommand: '", args[2], "'\n")
      },
      "Known methods:\n",
      paste0(
        "    ",
        c(
          "info               - Package, version, asset version, and script paths information",
          "base-htmldeps      - Quarto html dependencies for the base shinylive integration",
          "language-resources - R's resource files for the quarto html dependency named `shinylive`",
          "app-resources      - App-specific resource files for the quarto html dependency named `shinylive`"
        ),
        collapse = "\n"
      ),
      "\n\n",
      followup_statement()
    )
  }
  stopifnot(length(args) >= 2)

  ret <- switch(args[2],
    "info" = {
      list(
        "version" = SHINYLIVE_R_VERSION,
        "assets_version" = SHINYLIVE_ASSETS_VERSION,
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
      list()
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


quarto_codeblock_to_json_path <- function() {
  file.path(assets_dir(), "scripts", "codeblock-to-json.js")
}

# def package_deps(json_file: Optional[str]) -> None:
#     json_content: str | None = None
#     if json_file is None:
#         json_content = sys.stdin.read()

#     deps = _deps.package_deps_htmldepitems(json_file, json_content)
#     print(json.dumps(deps, indent=2))
