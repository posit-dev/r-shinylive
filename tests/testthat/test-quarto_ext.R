test_that("quarto_ext errors on missing --sw-dir argument", {
  skip_if_assets_unavailable()
  expect_error(
    quarto_ext(c("extension", "base-htmldeps")),
    class = "rlang_error"
  )
})

test_that("quarto_ext errors on --sw-dir without value", {
  skip_if_assets_unavailable()
  expect_error(
    quarto_ext(c("extension", "base-htmldeps", "--sw-dir")),
    class = "rlang_error"
  )
})

test_that("quarto_ext errors on unknown extension type", {
  skip_if_assets_unavailable()
  expect_error(
    quarto_ext(c("extension", "nonexistent-type")),
    class = "rlang_error"
  )
})

test_that("quarto_ext handles `extension info`", {
  skip_if_assets_unavailable()

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
  expect_equal(
    info$scripts$`codeblock-to-json`,
    quarto_codeblock_to_json_path()
  )
})


test_that("quarto_ext handles `extension base-htmldeps`", {
  skip_if_assets_unavailable()

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
  expect_false(any(grepl(
    "webr",
    vapply(shinylive_resources, `[[`, character(1), "name"),
    fixed = TRUE
  )))
})
test_that("quarto_ext handles `extension language-resources`", {
  skip_if_assets_unavailable()

  assets_ensure()

  txt <- collapse(capture.output({
    quarto_ext(c("extension", "language-resources"))
  }))
  resources <- jsonlite::parse_json(txt)

  # Verify webr folder in path
  expect_true(any(grepl(
    "webr",
    vapply(resources, `[[`, character(1), "name"),
    fixed = TRUE
  )))
})


test_that("quarto_ext handles `extension app-resources`", {
  skip_if_assets_unavailable()

  assets_ensure()

  # Work in a temp folder that is removed on exit
  withr::local_dir(withr::local_tempdir())
  withr::local_envvar(QUARTO_PROJECT_DIR = ".")

  app_json <- '[{"name":"app.R","type":"text","content":"library(shiny)"}]'
  writeLines(app_json, "app.json")

  txt <- collapse(capture.output({
    quarto_ext(c("extension", "app-resources"), con = "app.json")
  }))
  resources <- jsonlite::parse_json(txt)

  # Package metadata included in resources
  expect_true(any(grepl(
    "metadata.rds",
    vapply(resources, `[[`, character(1), "name"),
    fixed = TRUE
  )))
})

test_that("quarto_ext handles `extension app-resources` with additional binary files", {
  skip_if_assets_unavailable()

  assets_ensure()

  # Work in a temp folder that is removed on exit
  withr::local_dir(withr::local_tempdir())
  withr::local_envvar(QUARTO_PROJECT_DIR = ".")

  # A binary file included in app.json should successfully be decoded while
  # building package metadata for app-resources.
  app_json <- '[{"name":"app.R","type":"text","content":"library(shiny)"},{"name":"image.png","type":"binary","content":"iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAQMAAABmvDolAAAAA1BMVEW10NBjBBbqAAAAH0lEQVRoge3BAQ0AAADCoPdPbQ43oAAAAAAAAAAAvg0hAAABmmDh1QAAAABJRU5ErkJggg=="}]'
  writeLines(app_json, "app.json")

  txt <- collapse(capture.output({
    quarto_ext(c("extension", "app-resources"), con = "app.json")
  }))
  resources <- jsonlite::parse_json(txt)

  # Package metadata included in resources
  expect_true(any(grepl(
    "metadata.rds",
    vapply(resources, `[[`, character(1), "name"),
    fixed = TRUE
  )))
})

local_app_resources_project <- function(env = parent.frame()) {
  projdir <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(
    QUARTO_PROJECT_DIR = projdir,
    SHINYLIVE_WASM_PACKAGES = "FALSE",
    .local_envir = env
  )
  projdir
}

app_json_with <- function(name, content = "x", type = "text") {
  jsonlite::toJSON(
    list(
      list(name = "app.R", content = "library(shiny)", type = "text"),
      list(name = name, content = content, type = type)
    ),
    auto_unbox = TRUE
  )
}

test_that("build_app_resources() checks app file paths", {
  projdir <- local_app_resources_project()
  appdir <- fs::path(projdir, ".quarto", "_webr", "appdir")

  bad_names <- c(
    "/abs.R",
    "../up.R",
    "a/../../up.R",
    "C:/x.R",
    "C:x.R",
    "~/x.R",
    "~",
    "~user/x.R"
  )
  for (bad in bad_names) {
    expect_error(
      build_app_resources(app_json_with(bad)),
      "must be relative",
      info = bad
    )
  }

  expect_no_error(build_app_resources(app_json_with("..foo.R")))
  expect_true(fs::file_exists(fs::path(appdir, "..foo.R")))
})

test_that("build_app_resources() errors on bad binary content", {
  local_app_resources_project()
  expect_error(
    build_app_resources(app_json_with(
      "img.png",
      "!!!notbase64%%%",
      type = "binary"
    )),
    "Could not decode"
  )
})
