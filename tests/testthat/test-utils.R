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
