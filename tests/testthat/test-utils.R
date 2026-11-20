test_that("unlink_path() removes files, folders, and links", {
  dir <- withr::local_tempdir()

  file <- fs::file_create(fs::path(dir, "file.txt"))
  unlink_path(file)
  expect_false(fs::file_exists(file))

  folder <- fs::dir_create(fs::path(dir, "folder"))
  target <- fs::dir_create(fs::path(dir, "target"))
  link <- fs::link_create(target, fs::path(dir, "link"))
  unlink_path(folder)
  unlink_path(link)
  expect_false(fs::dir_exists(folder))
  expect_false(fs::link_exists(link))
  expect_true(fs::dir_exists(target))

  expect_no_error(unlink_path(fs::path(dir, "missing")))
})

test_that("create_copy_fn(overwrite = TRUE) replaces existing files", {
  dir <- withr::local_tempdir()
  src <- fs::path(dir, "src.txt")
  dst <- fs::path(dir, "dst.txt")
  writeLines("new", src)
  writeLines("old", dst)

  cp <- create_copy_fn(overwrite = TRUE)
  withr::with_options(list(shinylive.quiet = TRUE), cp$mark_file(src, dst))
  cp$copy_files()
  expect_equal(readLines(dst), "new")
})

test_that("create_copy_fn() is silent about differing files when quiet", {
  dir <- withr::local_tempdir()
  src <- fs::path(dir, "src.txt")
  dst <- fs::path(dir, "dst.txt")
  writeLines("new", src)
  writeLines("old", dst)

  cp <- create_copy_fn(overwrite = FALSE)
  withr::local_options(shinylive.quiet = TRUE)
  expect_no_message(cp$mark_file(src, dst))

  withr::local_options(shinylive.quiet = FALSE)
  expect_message(cp$mark_file(src, dst), "differ")
})

test_that("full_path() resolves symlinks in the parent of a missing path", {
  skip_on_os("windows")
  real <- withr::local_tempdir()
  link <- fs::path(withr::local_tempdir(), "link")
  fs::link_create(real, link)

  expected <- fs::path(normalizePath(real, winslash = "/"), "missing", "x")
  expect_equal(full_path(fs::path(link, "missing", "x")), expected)
  expect_equal(full_path(link), fs::path(normalizePath(real, winslash = "/")))
})

test_that("comparable_path() ignores case only on case-insensitive systems", {
  dir <- withr::local_tempdir()

  local_mocked_bindings(is_case_insensitive_os = function() TRUE)
  expect_equal(
    comparable_path(fs::path(dir, "MyApp")),
    comparable_path(fs::path(dir, "myapp"))
  )

  local_mocked_bindings(is_case_insensitive_os = function() FALSE)
  expect_false(
    comparable_path(fs::path(dir, "MyApp")) ==
      comparable_path(fs::path(dir, "myapp"))
  )
  expect_equal(
    fs::path_file(comparable_path(fs::path(dir, "MyApp"))),
    "MyApp"
  )
})
