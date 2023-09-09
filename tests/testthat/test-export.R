

test_that("export", {
  skip_on_cran()

  assets_ensure()

  # Create a temporary directory
  app_file <- file.path(tempfile(), "app.R")
  app_dir <- dirname(app_file)
  dir.create(app_dir, recursive = TRUE)
  on.exit(unlink_path(app_dir))
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

})
