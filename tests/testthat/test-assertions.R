# -- utils.R assert helpers --

test_that("assert_nzchar_string rejects non-string input", {
  expect_error(assert_nzchar_string(123), class = "rlang_error")
  expect_error(assert_nzchar_string(NULL), class = "rlang_error")
  expect_error(assert_nzchar_string(TRUE), class = "rlang_error")
})

test_that("assert_nzchar_string rejects empty string", {
  expect_error(assert_nzchar_string(""), class = "rlang_error")
})

test_that("assert_nzchar_string accepts valid string", {
  expect_no_error(assert_nzchar_string("hello"))
})

test_that("assert_list rejects non-list input", {
  expect_error(assert_list(1), class = "rlang_error")
  expect_error(assert_list("a"), class = "rlang_error")
  expect_error(assert_list(NULL), class = "rlang_error")
})

test_that("assert_list accepts list", {
  expect_true(assert_list(list()))
  expect_true(assert_list(list(1, 2)))
})

test_that("assert_list_items rejects non-list", {
  expect_error(assert_list_items(1, "foo"), class = "rlang_error")
})

test_that("assert_list_items rejects list with wrong class", {
  bad <- list(structure(list(), class = "wrong"))
  expect_error(assert_list_items(bad, "expected_class"), class = "rlang_error")
})

test_that("assert_list_items accepts list with correct class", {
  good <- list(
    structure(list(), class = c("myclass", "list")),
    structure(list(), class = c("myclass", "list"))
  )
  expect_true(assert_list_items(good, "myclass"))
})

# -- app_json.R --

test_that("app_info_obj rejects non-list files", {
  expect_error(
    app_info_obj("dir", "sub", files = "not_a_list"),
    class = "rlang_error"
  )
})

test_that("app_info_obj rejects files with wrong class", {
  bad_files <- list(list(name = "a", content = "b", type = "text"))
  expect_error(
    app_info_obj("dir", "sub", files = bad_files),
    class = "rlang_error"
  )
})

test_that("app_info_obj accepts valid files", {
  good_files <- list(file_content_obj("app.R", "content", "text"))
  result <- app_info_obj("dir", "sub", files = good_files)
  expect_s3_class(result, APP_INFO_CLASS)
})

test_that("write_app_json rejects non-app_info object", {
  expect_error(
    write_app_json("not_app_info", tempdir(), tempdir()),
    class = "rlang_error"
  )
})

test_that("write_app_json rejects non-existent template_dir", {
  good_files <- list(file_content_obj("app.R", "content", "text"))
  app <- app_info_obj("dir", "", files = good_files)
  expect_error(
    write_app_json(app, tempdir(), "/nonexistent/path"),
    class = "rlang_error"
  )
})

# -- deps.R check_dots_empty --

test_that("html_dep_obj rejects extra dots args", {
  expect_error(
    html_dep_obj(extra = "bad", name = "n", path = "p"),
    class = "rlib_error_dots"
  )
})

test_that("html_dep_serviceworker_obj rejects extra dots args", {
  expect_error(
    html_dep_serviceworker_obj(extra = "bad", source = "s", destination = "d"),
    class = "rlib_error_dots"
  )
})

test_that("quarto_html_dependency_obj rejects extra dots args", {
  expect_error(
    quarto_html_dependency_obj(extra = "bad", name = "n"),
    class = "rlib_error_dots"
  )
})

# -- utils.R CRAN guard --

test_that("cran_is_testing() is TRUE when TESTTHAT=true and NOT_CRAN is unset", {
  withr::with_envvar(list("TESTTHAT" = "true", "NOT_CRAN" = NA), {
    expect_true(cran_is_testing())
  })
})

test_that("cran_is_testing() is TRUE when TESTTHAT=true and NOT_CRAN!=true", {
  withr::with_envvar(list("TESTTHAT" = "true", "NOT_CRAN" = "false"), {
    expect_true(cran_is_testing())
  })
})

test_that("cran_is_testing() is FALSE when NOT_CRAN=true", {
  withr::with_envvar(list("TESTTHAT" = "true", "NOT_CRAN" = "true"), {
    expect_false(cran_is_testing())
  })
})

test_that("cran_is_testing() is FALSE when TESTTHAT is unset", {
  withr::with_envvar(list("TESTTHAT" = NA, "NOT_CRAN" = NA), {
    expect_false(cran_is_testing())
  })
})

test_that("assets_cache_dir() errors during CRAN testing", {
  withr::with_envvar(list("TESTTHAT" = "true", "NOT_CRAN" = NA), {
    expect_error(assets_cache_dir(), "must not be called during CRAN testing")
  })
})

# -- assets.R --

test_that("assets_remove rejects non-character versions", {
  skip_if_assets_unavailable()
  expect_error(assets_remove(123), class = "rlang_error")
})

test_that("assets_remove rejects empty versions", {
  skip_if_assets_unavailable()
  expect_error(assets_remove(character(0)), class = "rlang_error")
})

test_that("assets_dirs rejects extra dots args", {
  skip_if_assets_unavailable()
  expect_error(assets_dirs(extra = "bad"), class = "rlib_error_dots")
})

test_that("assets_cleanup rejects extra dots args", {
  skip_if_assets_unavailable()
  expect_error(assets_cleanup(extra = "bad"), class = "rlib_error_dots")
})

# -- quarto_ext.R --

test_that("quarto_ext rejects extra dots args", {
  expect_error(
    quarto_ext(c("--version"), extra = "bad"),
    class = "rlib_error_dots"
  )
})

test_that("quarto_ext errors on empty args", {
  expect_error(quarto_ext(character(0)), class = "rlang_error")
})
