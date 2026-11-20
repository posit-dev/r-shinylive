test_that("deploy-app workflow's default assets version matches the package", {
  # The workflow is not part of the built package, so this only runs from a
  # source checkout (for example `devtools::test()`).
  workflow <- test_path("..", "..", ".github", "workflows", "deploy-app.yaml")
  skip_if_not(file.exists(workflow), "deploy-app.yaml is not available")

  lines <- readLines(workflow)
  input_line <- grep("^\\s+assets-version:\\s*$", lines)
  expect_length(input_line, 1)

  default_lines <- grep("^\\s+default:", lines)
  default_line <- lines[min(default_lines[default_lines > input_line])]
  default_value <- sub('^\\s+default:\\s*"?([^"]*)"?\\s*$', "\\1", default_line)

  expect_equal(default_value, SHINYLIVE_ASSETS_VERSION)
})
