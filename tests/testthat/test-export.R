

test_that("export", {
  skip_on_cran()

  assets_ensure()

  # Create a temporary directory
  app_file <- file.path(tempfile(), "app.R")
  app_dir <- dirname(app_file)
  dir.create(app_dir, recursive = TRUE)
  on.exit(unlink_path(app_dir), add = TRUE)
  cat(
    file = app_file,
    collapse(c(
      "library(shiny)",
      "shinyApp(",
      "    fluidPage(",
      "        sliderInput(\"n\", \"N\", 0, 100, 40),",
      "        verbatimTextOutput(\"txt\", placeholder = TRUE),",
      "    ),",
      "    function(input, output) {",
      "        output$txt <- renderText({",
      "            paste0(\"The value of n*2 is \", 2 * input$n)",
      "        })",
      "    }",
      ")",
      ""
    ))
  )

  # Create a temporary directory
  out_dir <- file.path(tempfile(), "out")

  expect_silent({
    export(app_dir, out_dir)
  })

  asset_root_files <- c("shinylive", "shinylive-sw.js")
  asset_app_files <- c("app.json", "edit", "index.html")
  asset_edit_files <- c("index.html")

  expect_setequal(
    dir(out_dir),
    c(asset_root_files, asset_app_files)
  )
  expect_setequal(dir(file.path(out_dir, "edit")), asset_edit_files)

  expect_silent({
    export(app_dir, out_dir, subdir = "test_subdir")
  })

  expect_setequal(
    dir(out_dir),
    c(asset_root_files, asset_app_files, "test_subdir")
  )
  expect_setequal(
    dir(file.path(out_dir, "test_subdir")),
    asset_app_files
  )
  expect_setequal(dir(file.path(out_dir, "test_subdir", "edit")), asset_edit_files)
})
