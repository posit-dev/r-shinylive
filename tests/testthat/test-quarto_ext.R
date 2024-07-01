test_that("quarto_ext handles `extension info`", {
  maybe_skip_test()

  assets_ensure()

  txt <- collapse(capture.output({
    quarto_ext(c("extension", "info"))
  }))
  info <- jsonlite::parse_json(txt)
  expect_equal(info$version, as.character(utils::packageVersion("shinylive")))
  expect_equal(info$assets_version, assets_version())

  expect_true(
    is.list(info$scripts) &&
      length(info$scripts) == 1 &&
      nzchar(info$scripts$`codeblock-to-json`)
  )
  expect_equal(info$scripts$`codeblock-to-json`, quarto_codeblock_to_json_path())
})


test_that("quarto_ext handles `extension base-htmldeps`", {
  maybe_skip_test()

  assets_ensure()

  txt <- collapse(capture.output({
    quarto_ext(c("extension", "base-htmldeps", "--sw-dir", "TEST_PATH_SW_DIR"))
  }))
  items <- jsonlite::parse_json(txt)
  expect_length(items, 2)

  worker_item <- items[[1]]
  expect_equal(
    worker_item$meta[["shinylive:serviceworker_dir"]],
    "TEST_PATH_SW_DIR"
  )

  shinylive_item <- items[[2]]
  # Verify there is a quarto html dependency with name `"shinylive"`
  expect_equal(shinylive_item$name, "shinylive")
  # Verify webr can NOT be found in resources
  shinylive_resources <- shinylive_item$resources
  expect_false(any(grepl("webr", vapply(shinylive_resources, `[[`, character(1), "name"), fixed = TRUE)))
})
test_that("quarto_ext handles `extension language-resources`", {
  maybe_skip_test()

  assets_ensure()

  txt <- collapse(capture.output({
    quarto_ext(c("extension", "language-resources"))
  }))
  resources <- jsonlite::parse_json(txt)

  # Verify webr folder in path
  expect_true(any(grepl("webr", vapply(resources, `[[`, character(1), "name"), fixed = TRUE)))
})


test_that("quarto_ext handles `extension app-resources`", {
  maybe_skip_test()

  assets_ensure()

  # Clean-up on exit
  tmpdir <- tempdir()
  wd <- setwd(tmpdir)
  on.exit({
    setwd(wd)
    fs::dir_delete(tmpdir)
  })

  app_json <- '[{"name":"app.R","type":"text","content":"library(shiny)"}]'
  writeLines(app_json, "app.json")

  txt <- collapse(capture.output({
    quarto_ext(c("extension", "app-resources"), con = "app.json")
  }))
  resources <- jsonlite::parse_json(txt)

  # Package metadata included in resources
  expect_true(any(grepl("metadata.rds", vapply(resources, `[[`, character(1), "name"), fixed = TRUE)))
})

test_that("quarto_ext handles `extension app-resources` with additional binary files", {
  maybe_skip_test()

  assets_ensure()

  # Clean-up on exit
  tmpdir <- tempdir()
  wd <- setwd(tmpdir)
  on.exit({
    setwd(wd)
    fs::dir_delete(tmpdir)
  })

  # A binary file included in app.json should successfully be decoded while
  # building package metadata for app-resources.
  app_json <- '[{"name":"app.R","type":"text","content":"library(shiny)"},{"name":"image.png","type":"binary","content":"iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAQMAAABmvDolAAAAA1BMVEW10NBjBBbqAAAAH0lEQVRoge3BAQ0AAADCoPdPbQ43oAAAAAAAAAAAvg0hAAABmmDh1QAAAABJRU5ErkJggg=="}]'
  writeLines(app_json, "app.json")

  txt <- collapse(capture.output({
    quarto_ext(c("extension", "app-resources"), con = "app.json")
  }))
  resources <- jsonlite::parse_json(txt)

  # Package metadata included in resources
  expect_true(any(grepl("metadata.rds", vapply(resources, `[[`, character(1), "name"), fixed = TRUE)))
})
