# Choosing which Shinylive assets version to use.
#
# A version input is one of:
# * an exact version, such as `"0.10.16"`
# * a series pattern, such as `"0.10.*"` (highest 0.10.x)
# * `"latest"` (the newest release, checked on GitHub right away)

parse_assets_version <- function(x, arg = rlang::caller_arg(x)) {
  is_string <- is.character(x) && length(x) == 1 && !is.na(x)
  if (is_string && identical(x, "latest")) {
    return(list(kind = "latest", value = x, prefix = integer(0)))
  }
  if (is_string && grepl("^[0-9]+(\\.[0-9]+)*$", x)) {
    return(list(kind = "exact", value = x, prefix = version_parts(x)))
  }
  if (is_string && grepl("^[0-9]+(\\.[0-9]+)*\\.\\*$", x)) {
    prefix <- version_parts(sub("\\.\\*$", "", x))
    return(list(kind = "pattern", value = x, prefix = prefix))
  }
  cli::cli_abort(c(
    "{.arg {arg}} must be a valid Shinylive assets version.",
    "i" = "Use an exact version ({.val 0.10.16}), a series ({.val 0.10.*}), or {.val latest}.",
    "x" = "Received: {.val {x}}"
  ))
}

version_parts <- function(x) {
  as.integer(strsplit(x, ".", fixed = TRUE)[[1]])
}

safe_numeric_version <- function(x) {
  numeric_version(as.character(x), strict = FALSE)
}

# Returns a logical vector: which of `versions` match the parsed `spec`.
assets_version_matches <- function(versions, spec) {
  vapply(
    as.character(versions),
    FUN.VALUE = logical(1),
    USE.NAMES = FALSE,
    function(version) {
      if (is.na(safe_numeric_version(version))) {
        return(FALSE)
      }
      parts <- version_parts(version)
      switch(
        spec$kind,
        latest = TRUE,
        exact = identical(parts, spec$prefix),
        pattern = length(parts) > length(spec$prefix) &&
          identical(parts[seq_along(spec$prefix)], spec$prefix)
      )
    }
  )
}
