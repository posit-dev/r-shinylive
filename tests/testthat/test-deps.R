local_fake_assets <- function(version, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  assets <- fs::path(dir, paste0("shinylive-", version))
  fs::dir_create(fs::path(assets, "shinylive", "webr"))
  fs::file_create(fs::path(assets, "shinylive-sw.js"))
  fs::file_create(fs::path(assets, "shinylive", "load-shinylive-sw.js"))
  fs::file_create(fs::path(assets, "shinylive", "shinylive.css"))
  fs::file_create(fs::path(assets, "shinylive", "webr", "R.wasm"))
  local_mocked_bindings(assets_cache_dir = function() dir, .env = env)
  assets
}

test_that("shinylive_common_dep_htmldep() uses `version`", {
  assets <- local_fake_assets("9.9.9")

  dep <- shinylive_common_dep_htmldep("base", version = "9.9.9")
  expect_equal(dep$version, "9.9.9")
  expect_equal(
    dep$scripts[[1]]$path,
    file.path(assets, "shinylive", "load-shinylive-sw.js")
  )

  r_dep <- shinylive_common_dep_htmldep("r", version = "9.9.9")
  expect_equal(r_dep$version, "9.9.9")
  expect_equal(r_dep$resources[[1]]$name, "shinylive/webr/R.wasm")
})

test_that("shinylive_common_dep_htmldep() defaults to the base dependency", {
  local_fake_assets("9.9.9")
  dep <- shinylive_common_dep_htmldep(version = "9.9.9")
  expect_equal(dep$scripts[[1]]$name, "shinylive/load-shinylive-sw.js")
})
