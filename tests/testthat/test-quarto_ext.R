

test_that("quarto_ext handles codeblock-to-json-path", {
  skip_on_cran()

  assets_ensure()

  txt <- collapse(capture.output({
    quarto_ext(c("codeblock-to-json-path"))
  }))
  expect_true(grepl("/scripts/codeblock-to-json\\.js$", txt))
})


test_that("quarto_ext handles base-deps", {
  skip_on_cran()

  assets_ensure()

  txt <- collapse(capture.output({
    quarto_ext(c("base-deps", "--sw-dir", "TEST_PATH_SW_DIR"))
  }))
  items <- jsonlite::parse_json(txt)
  worker_items <- Filter(items, f = function(item) {
    item$name == "shinylive-serviceworker"
  })

  expect_length(worker_items, 1)
  worker_item <- worker_items[[1]]
  expect_equal(worker_item$meta[["shinylive:serviceworker_dir"]], "TEST_PATH_SW_DIR")
})


test_that("quarto_ext handles package-deps", {
  skip_on_cran()

  assets_ensure()

  txt <- collapse(capture.output({
    quarto_ext(c("package-deps"))
  }))
  obj <- jsonlite::parse_json(txt)
  expect_equal(obj, list())
})
