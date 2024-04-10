.v8 <- new.env(parent = emptyenv())

check_v8_installed <- function() {
  rlang::check_installed("V8", "for shinylive url encoding and decoding.")
}

get_v8 <- function() {
  check_v8_installed()

  if (exists("context", envir = .v8)) {
    return(.v8$context)
  }

  context <- V8::v8()

  context$source(
    system.file("lz-string", "lz-string.min.js", package = "shinylive")
  )

  assign("context", context, envir = .v8)
  context
}

lzstring_compress_uri <- function(x) {
  x <- jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null")

  v8 <- get_v8()
  v8$call("LZString.compressToEncodedURIComponent", x)
}

lzstring_decompress_uri <- function(x) {
  v8 <- get_v8()

  x <- v8$call("LZString.decompressFromEncodedURIComponent", x)

  jsonlite::fromJSON(
    x,
    simplifyVector = TRUE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  )
}
