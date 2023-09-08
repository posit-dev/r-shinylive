quarto_ext_call <- function(args = commandArgs(trailingOnly = TRUE)) {
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
  ret_null_free <- drop_nulls(ret)
  ret_json <- jsonlite::toJSON(ret_null_free, pretty = TRUE, auto_unbox = TRUE)
  print(ret_json)
}

drop_nulls <- function(x) {
  if (is.list(x)) {
    # Recurse
    x <- lapply(x, drop_nulls)
    is_null <- vapply(x, is.null, logical(1))
    x[!is_null]
  } else {
    # Return as is. Let parent list handle it
    x
  }
}

quarto_codeblock_to_json_path <- function() {
  file.path(shinylive_assets_dir(), "scripts", "codeblock-to-json.js")
}

# def package_deps(json_file: Optional[str]) -> None:
#     json_content: str | None = None
#     if json_file is None:
#         json_content = sys.stdin.read()

#     deps = _deps.package_deps_htmldepitems(json_file, json_content)
#     print(json.dumps(deps, indent=2))
