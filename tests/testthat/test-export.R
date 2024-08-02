expect_silent_unattended <- function(expr) {
  if (interactive()) {
    return(expr)
  }
  expect_silent(expr)
}

test_that("export - app.R", {
  maybe_skip_test()

  assets_ensure()

  # Ensure pkgcache metadata has been loaded
  invisible(pkgcache::meta_cache_list())

  # Create a temporary output directory
  out_dir <- file.path(tempfile(), "out")
  on.exit(unlink_path(out_dir), add = TRUE)

  app_dir <- test_path("apps", "app-r")

  expect_silent_unattended({
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

  expect_silent_unattended({
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
  expect_silent_unattended({
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

test_that("export with template", {
  maybe_skip_test()
  skip_if(assets_version() <= "0.4.1")

  # For local testing until next release after 0.4.1
  # withr::local_envvar(list("SHINYLIVE_ASSETS_VERSION" = "0.4.1"))

  assets_ensure()
  
  path_export <- test_path("apps", "export_template")

  if (FALSE) {
    # Run this manually to re-initialize the export template, but you'll need to
    # add the template parameters tested below.
    path_export_src <- fs::path(shinylive:::assets_dir(), "export_template")
    fs::dir_copy(path_export_src, path_export, overwrite = TRUE)
  }

  # Create a temporary directory
  out_dir <- file.path(tempfile(), "out")
  on.exit(unlink_path(out_dir))

  app_dir <- test_path("apps", "app-r")

  expect_silent_unattended({
    export(
      app_dir,
      out_dir,
      template_dir = path_export,
      template_params = list(
        # Included in export template for > 0.4.1
        title = "Shinylive Test App",
        include_before_body = "<h1>Shinylive Test App</h1>",
        include_after_body = "<footer>r-shinylive</footer>",
        # Included in the customized export template in test suite
        description = "My custom export template param test app"
      )
    )
  })

  index_content <- brio::read_file(fs::path(out_dir, "index.html"))
  expect_match(
    index_content,
    "<title>Shinylive Test App</title>"
  )
  
  expect_match(
    index_content,
    "<body>\\s+<h1>Shinylive Test App</h1>"
  )

  expect_match(
    index_content,
    "<footer>r-shinylive</footer>\\s+</body>"
  )

  expect_match(
    index_content,
    "<meta name=\"description\" content=\"My custom export template param test app\">"
  )
})

test_that("export - include R package in wasm assets", {
  maybe_skip_test()

  assets_ensure()

  # Ensure pkgcache metadata has been loaded
  invisible(pkgcache::meta_cache_list())

  # Create a temporary output directory
  out_dir <- file.path(tempfile(), "out")
  pkg_dir <- file.path(out_dir, "shinylive", "webr", "packages")

  # A package with an external dependency
  app_dir <- test_path("apps", "app-utf8")
  asset_package <- c("utf8")

  # No external dependencies exported
  expect_silent_unattended({
    withr::with_envvar(
      list("SHINYLIVE_WASM_PACKAGES" = "FALSE"),
      export(app_dir, out_dir)
    )
  })
  expect_length(dir(pkg_dir), 0)
  unlink_path(out_dir)

  # Default filesize 100MB
  expect_silent_unattended({
    export(app_dir, out_dir)
  })
  expect_contains(dir(pkg_dir), c(asset_package))
  unlink_path(out_dir)

  # No maximum filesize
  expect_silent_unattended({
    export(app_dir, out_dir, max_filesize = Inf)
  })
  expect_contains(dir(pkg_dir), c(asset_package))
  unlink_path(out_dir)

  # Set a maximum filesize
  expect_error({
    export(app_dir, out_dir, max_filesize = "1K")
  })
  unlink_path(out_dir)

  expect_error({
    withr::with_envvar(
      list("SHINYLIVE_DEFAULT_MAX_FILESIZE" = "1K"),
      export(app_dir, out_dir)
    )
  })
  unlink_path(out_dir)

})
