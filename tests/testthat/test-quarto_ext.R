test_that("quarto_ext handles `extension info`", {
  maybe_skip_test()

  assets_ensure()

  txt <- collapse(capture.output({
    quarto_ext(c("extension", "info"))
  }))
  info <- jsonlite::parse_json(txt)
  expect_equal(info$version, as.character(utils::packageVersion("shinylive")))
  expect_equal(info$assets_version, SHINYLIVE_ASSETS_VERSION)

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

  txt <- collapse(capture.output({
    quarto_ext(c("extension", "app-resources"))
  }))
  obj <- jsonlite::parse_json(txt)
  expect_equal(obj, list())
})
