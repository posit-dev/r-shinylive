test_that("read_app_files() stores text that is not UTF-8 as binary", {
  appdir <- withr::local_tempdir()
  writeLines("library(shiny)", fs::path(appdir, "app.R"))
  writeBin(as.raw(c(0x63, 0x61, 0x66, 0xe9, 0x0a)), fs::path(appdir, "latin1.txt"))

  files <- read_app_files(appdir, withr::local_tempdir())
  types <- vapply(files, `[[`, character(1), "type")
  names(types) <- vapply(files, `[[`, character(1), "name")
  expect_equal(types[["app.R"]], "text")
  expect_equal(types[["latin1.txt"]], "binary")

  json <- jsonlite::toJSON(files, auto_unbox = TRUE)
  expect_true(jsonlite::validate(json))
})
