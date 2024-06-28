test_that("export - app.R", {
  maybe_skip_test()

  assets_ensure()

  # Ensure pkgcache metadata has been loaded
  invisible(pkgcache::meta_cache_list())

  # Create a temporary output directory
  out_dir <- file.path(tempfile(), "out")
  on.exit(unlink_path(out_dir), add = TRUE)

  app_dir <- test_path("apps", "app-r")

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


test_that("export - server.R", {
  maybe_skip_test()

  assets_ensure()

  # Create a temporary directory
  out_dir <- file.path(tempfile(), "out")
  on.exit(unlink_path(out_dir))

  app_dir <- test_path("apps", "server-r")

  # Verify global.R / ui.R / server.R app can be exported
  expect_silent({
    export(app_dir, out_dir)
  })
  
  # Verify global.R / ui.R / server.R exported files exist
  app_json <- jsonlite::read_json(file.path(out_dir, "app.json"))
  out_app_file_names <- vapply(app_json, `[[`, character(1), "name")
  expect_setequal(
    out_app_file_names,
    c("global.R", "ui.R", "server.R")
  )
})
