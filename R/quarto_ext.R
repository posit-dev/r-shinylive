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

  ret <- switch(args[1],
    "codeblock-to-json-path" = {
      ret <- quarto_codeblock_to_json_path()
      cat(ret, "\n", sep = "")
      return(invisible())
    },
    "base-deps" = {
      sw_dir_pos <- which(args == "--sw-dir")
      if (length(sw_dir_pos) == 1) {
        sw_dir <- args[sw_dir_pos + 1]
      } else {
        stop("expected `--sw-dir` argument")
      }
      shinylive_base_deps_htmldep(sw_dir)
    },
    "package-deps" = {
      list()
    },
    {
      stop("unknown command: ", args[1])
    }
  )
  ret_null_free <- drop_nulls_rec(ret)
  ret_json <- jsonlite::toJSON(ret_null_free, pretty = TRUE, auto_unbox = TRUE)
  print(ret_json)

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
