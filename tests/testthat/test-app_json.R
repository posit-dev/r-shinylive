test_that("read_app_files() stores text that is not UTF-8 as binary", {
  appdir <- withr::local_tempdir()
  writeLines("library(shiny)", fs::path(appdir, "app.R"))
  writeBin(
    as.raw(c(0x63, 0x61, 0x66, 0xe9, 0x0a)),
    fs::path(appdir, "latin1.txt")
  )

  files <- read_app_files(appdir, withr::local_tempdir())
  types <- vapply(files, `[[`, character(1), "type")
  names(types) <- vapply(files, `[[`, character(1), "name")
  expect_equal(types[["app.R"]], "text")
  expect_equal(types[["latin1.txt"]], "binary")

  json <- jsonlite::toJSON(files, auto_unbox = TRUE)
  expect_true(jsonlite::validate(json))
})

local_app <- function(dir) {
  fs::dir_create(dir)
  writeLines("library(shiny)", fs::path(dir, "app.R"))
  dir
}

app_file_names <- function(files) {
  vapply(files, `[[`, character(1), "name")
}

test_that("read_app_files() reads an app that is inside destdir", {
  root <- withr::local_tempdir()
  appdir <- local_app(fs::path(root, "myapp"))
  expect_equal(app_file_names(read_app_files(appdir, root)), "app.R")
})

test_that("read_app_files() reads an app folder with an excluded name", {
  root <- withr::local_tempdir()
  appdir <- local_app(fs::path(root, "venv"))
  fs::dir_create(fs::path(appdir, "rsconnect"))
  writeLines("x", fs::path(appdir, "rsconnect", "x.dcf"))
  expect_equal(
    app_file_names(read_app_files(appdir, withr::local_tempdir())),
    "app.R"
  )
})

test_that("read_app_files() skips destdir given as a relative path", {
  root <- withr::local_tempdir()
  appdir <- local_app(fs::path(root, "myapp"))
  fs::dir_create(fs::path(appdir, "site"))
  writeLines("x", fs::path(appdir, "site", "index.html"))

  withr::with_dir(appdir, {
    expect_equal(app_file_names(read_app_files(appdir, "site")), "app.R")
  })
  withr::with_dir(root, {
    expect_equal(
      app_file_names(read_app_files("myapp", fs::path(appdir, "site"))),
      "app.R"
    )
  })
})

test_that("export() errors when destdir is appdir", {
  appdir <- local_app(withr::local_tempdir())
  expect_error(export(appdir, appdir), "different folder")
})

test_that("write_app_json() can write over a custom template's other files", {
  template_dir <- withr::local_tempdir()
  writeLines("<title>{{title}}</title>", fs::path(template_dir, "index.html"))
  writeLines("body {}", fs::path(template_dir, "extra.css"))

  destdir <- withr::local_tempdir()
  app_info <- app_info_obj(
    "app",
    "",
    list(file_content_obj("app.R", "library(shiny)"))
  )
  write_app_json(app_info, destdir, template_dir = template_dir, quiet = TRUE)
  expect_no_error(
    write_app_json(app_info, destdir, template_dir = template_dir, quiet = TRUE)
  )
  expect_true(fs::file_exists(fs::path(destdir, "extra.css")))
})
