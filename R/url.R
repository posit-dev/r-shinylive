url_encode_dir <- function(
    dir,
    language = c("auto", "r", "py"),
    mode = c("editor", "app"),
    hide_header = FALSE,
    exclude = "rsconnect/"
) {

  stopifnot(fs::dir_exists(dir))

  language <- rlang::arg_match(language)
  mode <- rlang::arg_match(mode)
  hide_header <- hide_header && mode == "app"

  files <- fs::dir_ls(dir, recurse = TRUE, type = "file", regexp = exclude, invert = TRUE)
  files <- fs::path_abs(files)
  files <- files[!grepl("^(\\.|_)", fs::path_file(files))]

  rgx_app <- switch(
    language,
    r = "(^app|(ui|server)).*\\.[Rr])",
    py = "^app.+\\.py$",
    auto = "^app|((ui|server)\\.[Rr])"
  )

  idx_app <- which(grepl(rgx_app, fs::path_file(files)))
  if (length(idx_app) == 0) {
    stop(
      switch(
        language,
        r = "No app.R, ui.R or server.R found in ",
        py = "No app.py found in ",
        auto = "No app.R, app.py or ui/server.R found in "
      ),
      dir
    )
  }

  idx_app <- idx_app[1]
  path_root <- fs::path_dir(files[idx_app])
  files <- c(files[idx_app], files[-idx_app])

  if (language == "auto") {
    language <- tolower(fs::path_ext(files[1]))
  }

  names <- fs::path_rel(files, path_root)
  bundle <- unname(Map(as_file_list, files, names))
  bundle <- jsonlite::toJSON(bundle, auto_unbox = TRUE, null = "null", na = "null")
  URI <- lzstring::compressToEncodedURIComponent(bundle)
  URI <- gsub("/", "-", URI)
  sprintf(
    "https://%s/%s/%s/#%scode=%s",
    getOption("shinylive.host", "shinylive.io"),
    language,
    mode,
    if (hide_header) "h=0&" else "",
    URI
  )
}

url_decode <- function(encoded_url, dir = NULL, json = FALSE) {
  url_in <- strsplit(encoded_url, "code=")[[1]][2]
  sl_app <- lzstring::decompressFromEncodedURIComponent(url_in)
  sl_app <- jsonlite::fromJSON(sl_app, simplifyVector = FALSE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE)
  if (json) {
    sl_app <- jsonlite::toJSON(sl_app)
    return(sl_app)
  }
  if (!is.null(dir)) {
    write_files(sl_app, dir)
  } else {
    print(sl_app)
  }
}

write_files <- function(sl_app, dest) {
  if (!fs::dir_exists(dest)) {
    fs::dir_create(dest)
  }
  for (file in sl_app) {
    if ("type" %in% names(file) && file[["type"]] == "binary") {
      file_content <- base64enc::base64decode(file[["content"]])
      writeBin(file_content, file.path(dest, file[["name"]]))
    } else {
      file_content <- iconv(file[["content"]], "UTF-8", "UTF-8", sub = "")
      writeLines(file_content, file.path(dest, file[["name"]]))
    }
  }
  return(dest)
}

as_file_list <- function(path, name = fs::path_file(path), type = NULL) {
  if (is.null(type)) {
    ext <- tolower(fs::path_ext(path))
    type <- if (ext %in% text_file_extensions()) "text" else "binary"
  } else {
    rlang::arg_match(type, c("text", "binary"))
  }

  content <-
    if (type == "text") {
      read_utf8(path)
    } else {
      rlang::check_installed("base64enc", "for binary file encoding.")
      base64enc::base64encode(read_raw(path))
    }

  ret <- list(name = name, content = content)
  if (type == "binary") ret$type <- "binary"

  ret
}

text_file_extensions <- function() {
  c(
    "r", "rmd", "rnw", "rpres", "rhtml", "qmd",
    "py", "ipynb", "js", "ts", "jl",
    "html", "css", "scss", "less", "sass",
    "tex", "txt", "md", "markdown", "html", "htm",
    "json", "yml", "yaml", "xml", "svg",
    "sh", "bash", "zsh", "fish", "bat", "cmd",
    "sql", "csv", "tsv", "tab",
    "log", "dcf", "ini", "cfg", "conf", "properties", "env", "envrc",
    "gitignore", "gitattributes", "gitmodules", "gitconfig", "gitkeep",
    "htaccess", "htpasswd", "htgroups", "htdigest"
  )
}
