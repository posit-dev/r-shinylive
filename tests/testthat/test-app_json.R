test_that("glue_template() returns empty string if template param is not defined", {
  expect_equal(
    glue_template("{{ not_defined }}", list(), "export_template/index.html"),
    glue::glue("")
  )
})

test_that("glue_template() ignores unused parameters", {
  expect_equal(
    glue_template("{{ x }}", list(x = "a", y = "b"), "export_template/index.html"),
    glue::glue("a")
  )

  expect_equal(
    glue_template("{{ a }}{{ b }}", list(a = NULL, b = NA), "export_template/index.html"),
    glue::glue("")
  )
})

