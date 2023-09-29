#' Quarto extension for shinylive
#'
#' @param args Command line arguments passed by the extension. The first
#'    argument can be one of:
#'
#'    - `codeblock-to-json-path`: Prints the path to the `codeblock-to-json.js` script.
#'    - `base-deps`: Prints the base dependencies as a JSON array.
#'    - `package-deps`: Prints the package dependencies as a JSON array.
#'      Currently, this returns an empty array as `webr` is handling the package
#'      dependencies.
#' @noRd
quarto_ext <- function(args = commandArgs(trailingOnly = TRUE)) {
  # This method should not print anything to stdout. Instead, it should return a JSON string that will be printed by the extension.
  stopifnot(length(args) >= 1)

  followup_statement <- function() {
    paste0(
      "Please update your `quarto-ext/shinylive` quarto extension for the latest integration.\n",
      "\n",
      paste0("shinylive R package version:  ", SHINYLIVE_R_VERSION), "\n",
      paste0("shinylive web assets version: ", assets_version())
    )
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
      "Expected one of:\n",
      paste0(
        "    ",
        c(
          "info",
          "base-htmldeps",
          "language-resources",
          "app-resources"
        ),
        collapse = "\n"
      ),
      "\n\n",
      "Please update your `quarto-ext/shinylive` quarto extension for the latest integration.\n",
      "\n",
      paste0("shinylive R package version:  ", SHINYLIVE_R_VERSION), "\n",
      paste0("shinylive web assets version: ", assets_version())
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
      stopifnot(length(args) >= 3)
      sw_dir_pos <- which(args == "--sw-dir")
      if (length(sw_dir_pos) == 1) {
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
  ret_json <- jsonlite::toJSON(ret_null_free, pretty = TRUE, auto_unbox = TRUE)
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
