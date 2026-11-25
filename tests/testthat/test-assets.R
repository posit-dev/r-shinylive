test_that("assets_dirs() contains files", {
  skip_if_assets_unavailable()

  assets_ensure()

  # Make sure we have assets installed
  expect_true(length(assets_dirs()) > 0)
  expect_true(length(dir(assets_dirs()[1])) > 0)
})

test_that("assets_path_webr_r_version() reads the R version from the assets", {
  assets_path <- withr::local_tempdir()
  translations <- fs::path(
    assets_path,
    "shinylive/webr/vfs/usr/lib/R/library/translations"
  )
  fs::dir_create(translations)
  writeLines(
    c("Package: translations", "Version: 4.7.1", "Priority: base"),
    fs::path(translations, "DESCRIPTION")
  )

  expect_equal(assets_path_webr_r_version(assets_path), "4.7.1")
})

test_that("assets_path_webr_r_version() errors when the version is missing", {
  assets_path <- withr::local_tempdir()

  expect_error(
    assets_path_webr_r_version(assets_path),
    "Can't find the webR R version"
  )
})

test_that("the default assets use the expected webR R version", {
  skip_if_assets_unavailable()

  # Update this when a new default assets version changes the webR R version.
  # It catches an R version change that would otherwise go unnoticed.
  expect_equal(
    assets_webr_r_version(SHINYLIVE_ASSETS_VERSION_FALLBACK),
    "4.6.0"
  )
})

test_that("assets_dir() uses `dir`", {
  dir <- withr::local_tempdir()
  expect_equal(
    assets_dir("0.10.99", dir = dir),
    fs::path(dir, "shinylive-0.10.99")
  )
})

test_that("assets_ensure() downloads to and returns a path in `dir`", {
  dir <- withr::local_tempdir()
  local_mocked_bindings(
    assets_download = function(version, ..., dir, url) {
      fs::dir_create(fs::path(dir, paste0("shinylive-", version)))
      invisible(dir)
    }
  )
  path <- assets_ensure("0.10.99", dir = dir)
  expect_equal(path, fs::path(dir, "shinylive-0.10.99"))
  expect_true(fs::dir_exists(path))
})

test_that("assets_dirs() skips entries that are not version folders", {
  dir <- withr::local_tempdir()
  fs::dir_create(fs::path(dir, c("shinylive-0.9.0", "shinylive-0.10.1")))
  fs::dir_create(fs::path(dir, "shinylive-dev"))
  fs::file_create(fs::path(dir, "shinylive-1.0.0.tar.gz"))

  expect_equal(
    assets_dirs(dir = dir),
    fs::path(dir, c("shinylive-0.10.1", "shinylive-0.9.0"))
  )
})

test_that("assets_info() works when no assets are installed", {
  dir <- withr::local_tempdir()
  assets_version_reset()
  withr::defer(assets_version_reset())
  local_mocked_bindings(
    assets_cache_dir = function() dir,
    fetch_latest_assets_version = function() stop("offline"),
    assets_download = function(...) stop("must not download")
  )

  info <- assets_info(quiet = TRUE)
  expect_equal(nrow(info), 0)
  expect_named(info, c("version", "path", "is_assets_version"))

  fs::dir_create(fs::path(dir, "shinylive-0.9.0"))
  info <- assets_info(quiet = TRUE)
  expect_equal(info$version, "0.9.0")
  expect_equal(info$path, as.character(fs::path(dir, "shinylive-0.9.0")))
})

test_that("assets_ensure() shows the cache folder it creates", {
  dir <- fs::path(withr::local_tempdir(), "cache")
  local_mocked_bindings(
    assets_download = function(version, ..., dir, url) {
      fs::dir_create(fs::path(dir, paste0("shinylive-", version)))
      invisible(dir)
    }
  )
  withr::local_options(shinylive.quiet = FALSE)
  expect_message(
    assets_ensure("0.10.99", dir = dir),
    "Creating assets cache directory .*cache"
  )
})

test_that("check_assets_url() returns FALSE for a missing release", {
  skip_on_cran()
  skip_if_offline("github.com")
  expect_false(check_assets_url(url = assets_bundle_url("0.0.0-missing")))
})

test_that("assets_path_version() returns the version of an assets folder", {
  expect_equal(
    assets_path_version(c("/cache/shinylive-0.10.16", "shinylive-1.0.0")),
    c("0.10.16", "1.0.0")
  )
  expect_equal(assets_path_version("/x/shinylive-shinylive-1"), "shinylive-1")
  expect_equal(assets_path_version(character(0)), character(0))
})

test_that("assets_cleanup() keeps the newest of the default series only", {
  dir <- withr::local_tempdir()
  fs::dir_create(fs::path(
    dir,
    paste0("shinylive-", c("0.11.0", "0.10.16", "0.10.5", "0.9.3", "dev"))
  ))
  withr::local_options(shinylive.quiet = TRUE)
  withr::local_envvar(SHINYLIVE_ASSETS_VERSION = NA)
  local_mocked_bindings(SHINYLIVE_ASSETS_VERSION_DEFAULT = "0.10.*")

  assets_cleanup(dir = dir)
  expect_equal(assets_dirs(dir = dir), fs::path(dir, "shinylive-0.10.16"))
  # Not a version folder, so not touched
  expect_true(fs::dir_exists(fs::path(dir, "shinylive-dev")))
})

test_that("assets_cleanup(keep=) takes exact versions and series", {
  dir <- withr::local_tempdir()
  fs::dir_create(fs::path(
    dir,
    paste0("shinylive-", c("0.11.2", "0.11.0", "0.10.16", "0.10.5", "0.9.3"))
  ))
  withr::local_options(shinylive.quiet = TRUE)

  assets_cleanup(keep = c("0.11.*", "0.10.5"), dir = dir)
  expect_equal(
    assets_dirs(dir = dir),
    fs::path(dir, c("shinylive-0.11.2", "shinylive-0.10.5"))
  )

  assets_cleanup(keep = character(0), dir = dir)
  expect_equal(assets_dirs(dir = dir), character(0))
})

test_that("assets_cleanup(keep=) rejects invalid values", {
  dir <- withr::local_tempdir()
  expect_error(assets_cleanup(keep = 1, dir = dir), "character")
  expect_error(assets_cleanup(keep = "0.10.x", dir = dir), "keep")
})

local_assets_tarball <- function(version, env = parent.frame()) {
  src <- withr::local_tempdir(.local_envir = env)
  fs::dir_create(fs::path(src, paste0("shinylive-", version), "shinylive"))
  writeLines(
    "ok",
    fs::path(src, paste0("shinylive-", version), "shinylive", "x.txt")
  )
  tarball <- withr::local_tempfile(fileext = ".tar.gz", .local_envir = env)
  withr::with_dir(src, archive::archive_write_dir(tarball, "."))
  tarball
}

test_that("assets_download() moves the extracted folder into place", {
  dir <- withr::local_tempdir()
  withr::local_options(shinylive.quiet = TRUE)
  tarball <- local_assets_tarball("0.10.99")

  assets_download("0.10.99", dir = dir, url = paste0("file://", tarball))
  expect_true(fs::file_exists(
    fs::path(dir, "shinylive-0.10.99", "shinylive", "x.txt")
  ))
  expect_equal(basename(fs::dir_ls(dir)), "shinylive-0.10.99")
})

test_that("assets_download() leaves no partial folder when extracting fails", {
  dir <- withr::local_tempdir()
  withr::local_options(shinylive.quiet = TRUE)
  tarball <- local_assets_tarball("0.10.99")
  local_mocked_bindings(
    archive_extract = function(archive, dir, ...) {
      fs::dir_create(fs::path(dir, "shinylive-0.10.99"))
      stop("corrupt archive")
    },
    .package = "archive"
  )

  expect_error(
    assets_download("0.10.99", dir = dir, url = paste0("file://", tarball)),
    "corrupt archive"
  )
  expect_equal(fs::dir_ls(dir), character(0), ignore_attr = TRUE)
})

test_that("assets_info() shows the default series and the last check", {
  dir <- withr::local_tempdir()
  assets_version_reset()
  withr::defer(assets_version_reset())
  withr::local_envvar(SHINYLIVE_ASSETS_VERSION = NA)
  write_versions_json(
    list(
      checked_at = Sys.time() - 3600 * 2,
      latest = "0.10.16",
      versions = "0.10.16",
      error = "Could not resolve host"
    ),
    dir
  )
  local_mocked_bindings(
    assets_cache_dir = function() dir,
    fetch_latest_assets_version = function() stop("Could not resolve host")
  )
  fs::dir_create(fs::path(dir, "shinylive-0.10.16"))

  msgs <- testthat::capture_messages(assets_info())
  out <- paste(msgs, collapse = "")
  expect_match(out, "0.10.*", fixed = TRUE)
  expect_match(out, "0.10.16", fixed = TRUE)
  expect_match(out, "Could not resolve host", fixed = TRUE)
  expect_match(out, "Last checked", fixed = TRUE)
})

local_assets_repo <- function(env = parent.frame()) {
  repo <- withr::local_tempdir(.local_envir = env)
  fs::dir_create(fs::path(repo, "build"))
  repo
}

test_that("assets_install_copy() warns outside the default series", {
  dir <- withr::local_tempdir()
  repo <- local_assets_repo()

  expect_warning(
    assets_install_copy(repo, dir = dir, version = "0.9.0"),
    "0.10.*",
    fixed = TRUE
  )
  expect_no_warning(assets_install_copy(repo, dir = dir, version = "0.10.99"))
})

test_that("assets_cleanup() keeps what SHINYLIVE_ASSETS_VERSION selects", {
  dir <- withr::local_tempdir()
  fs::dir_create(fs::path(
    dir,
    paste0("shinylive-", c("0.11.1", "0.11.0", "0.10.17", "0.10.16"))
  ))
  withr::local_options(shinylive.quiet = TRUE)
  local_mocked_bindings(SHINYLIVE_ASSETS_VERSION_DEFAULT = "0.10.*")

  withr::local_envvar(SHINYLIVE_ASSETS_VERSION = "0.10.16")
  assets_cleanup(dir = dir)
  expect_equal(
    assets_dirs(dir = dir),
    fs::path(dir, paste0("shinylive-", c("0.10.17", "0.10.16")))
  )

  fs::dir_create(fs::path(dir, paste0("shinylive-", c("0.11.1", "0.11.0"))))
  withr::local_envvar(SHINYLIVE_ASSETS_VERSION = "0.11.*")
  assets_cleanup(dir = dir)
  expect_equal(
    assets_dirs(dir = dir),
    fs::path(dir, paste0("shinylive-", c("0.11.1", "0.10.17")))
  )
})

test_that("assets_download() keeps a folder another process just made", {
  dir <- withr::local_tempdir()
  withr::local_options(shinylive.quiet = TRUE)
  tarball <- local_assets_tarball("0.10.99")
  target <- fs::path(dir, "shinylive-0.10.99")
  real_extract <- archive::archive_extract
  local_mocked_bindings(
    archive_extract = function(archive, dir, ...) {
      # Another process finishes the same download while we extract
      fs::dir_create(target)
      writeLines("other", fs::path(target, "marker.txt"))
      real_extract(archive, dir, ...)
    },
    .package = "archive"
  )

  assets_download("0.10.99", dir = dir, url = paste0("file://", tarball))
  expect_true(fs::file_exists(fs::path(target, "marker.txt")))
  expect_equal(basename(fs::dir_ls(dir)), "shinylive-0.10.99")
})

test_that("assets_download() keeps a folder moved in just before its own move", {
  dir <- withr::local_tempdir()
  withr::local_options(shinylive.quiet = TRUE)
  tarball <- local_assets_tarball("0.10.99")
  target <- fs::path(dir, "shinylive-0.10.99")
  local_mocked_bindings(
    file_move = function(path, new_path) {
      # Another process wins the race between the check and the move
      fs::dir_create(target)
      writeLines("other", fs::path(target, "marker.txt"))
      stop("Directory not empty")
    },
    .package = "fs"
  )

  assets_download("0.10.99", dir = dir, url = paste0("file://", tarball))
  expect_true(fs::file_exists(fs::path(target, "marker.txt")))
  expect_equal(basename(fs::dir_ls(dir)), "shinylive-0.10.99")
})

test_that("assets_download() still errors when the move fails", {
  dir <- withr::local_tempdir()
  withr::local_options(shinylive.quiet = TRUE)
  tarball <- local_assets_tarball("0.10.99")
  local_mocked_bindings(
    file_move = function(path, new_path) stop("Permission denied"),
    .package = "fs"
  )

  expect_error(
    assets_download("0.10.99", dir = dir, url = paste0("file://", tarball)),
    "Permission denied"
  )
})

test_that("assets_info() shows unresolved when nothing matches", {
  dir <- withr::local_tempdir()
  assets_version_reset()
  withr::defer(assets_version_reset())
  withr::local_envvar(SHINYLIVE_ASSETS_VERSION = "0.99.*")
  local_mocked_bindings(
    assets_cache_dir = function() dir,
    fetch_latest_assets_version = function() stop("must not check")
  )

  msgs <- testthat::capture_messages(info <- assets_info())
  expect_match(paste(msgs, collapse = ""), "unresolved", fixed = TRUE)
  expect_equal(nrow(info), 0)
})

test_that("assets_download() replaces a folder that existed before", {
  dir <- withr::local_tempdir()
  withr::local_options(shinylive.quiet = TRUE)
  tarball <- local_assets_tarball("0.10.99")
  target <- fs::path(dir, "shinylive-0.10.99")
  fs::dir_create(target)
  writeLines("stale", fs::path(target, "stale.txt"))

  assets_download("0.10.99", dir = dir, url = paste0("file://", tarball))
  expect_false(fs::file_exists(fs::path(target, "stale.txt")))
  expect_true(fs::file_exists(fs::path(target, "shinylive", "x.txt"))) # The old folder moved aside is removed
  expect_equal(basename(fs::dir_ls(dir)), "shinylive-0.10.99")
})

test_that("assets_cleanup() removes old temp files only", {
  dir <- withr::local_tempdir()
  withr::local_options(shinylive.quiet = TRUE)
  local_mocked_bindings(SHINYLIVE_ASSETS_VERSION_DEFAULT = "0.10.*")
  withr::local_envvar(SHINYLIVE_ASSETS_VERSION = NA)
  fs::dir_create(fs::path(dir, c("extract-old", "old-old", "extract-new")))
  fs::file_create(fs::path(dir, c("versions-old.json", "versions.json")))
  stale <- fs::path(dir, c("extract-old", "old-old", "versions-old.json"))
  Sys.setFileTime(stale, Sys.time() - 11 * 60)

  assets_cleanup(dir = dir)
  expect_setequal(
    basename(fs::dir_ls(dir)),
    c("extract-new", "versions.json")
  )
})
