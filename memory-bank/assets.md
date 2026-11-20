---
title: "Assets cache"
description: "How shinylive downloads, caches, installs, and removes the Shinylive web assets (R/assets.R, R/version.R): the cache folder layout, assets_version(), local builds of posit-dev/shinylive, and the webR R version lookup. Read before changing any assets_*() function or bumping the default assets version."
---

# Assets cache

## Overview

The Shinylive web assets (JavaScript, webR, Pyodide, the export template)
come from [posit-dev/shinylive](https://github.com/posit-dev/shinylive)
releases. They are too big to ship in the package, so they are downloaded
once per version into a user cache folder and reused.

Every function that needs assets (`export()`, `shinylive_common_files()` in
`R/deps.R`, `quarto_ext()`) asks for a version, makes sure that version is in
the cache, and reads files from it.

## Key files

- `R/assets.R` - every `assets_*()` function, `check_assets_url()`, and the
  webR R version lookup.
- `R/version.R` - `SHINYLIVE_ASSETS_VERSION` (default assets version) and
  `SHINYLIVE_R_VERSION` (this package's version, from `utils::packageVersion()`).
- `R/utils.R` - `cran_is_testing()`, `unlink_path()`, `package_json_version()`.
- `tests/testthat/test-assets.R` - asset tests, including the expected webR R
  version for the default assets.
- `tests/testthat/test-assertions.R` - argument checks and the CRAN guard.
- `.agents/skills/update-assets-version/SKILL.md` - steps to bump the default
  assets version.

## Cache folder layout

```
<assets_cache_dir()>/          e.g. ~/Library/Caches/shinylive on macOS
  shinylive-0.10.16/           one folder per version
    shinylive/                 the web assets (webr/, pyodide/, ...)
    scripts/                   codeblock-to-json.js for Quarto
    export_template/           index.html, edit/index.html
    shinylive-sw.js            service worker
  shinylive-0.10.15/
```

- `assets_cache_dir()` returns `rappdirs::user_cache_dir("shinylive")`,
  creates it if missing, and returns it through `normalizePath()` (Quarto
  can't handle `~`). rappdirs honors the `R_USER_CACHE_DIR` env var, so
  `withr::local_envvar(R_USER_CACHE_DIR = tmp)` moves the cache to
  `tmp/shinylive`. `XDG_CACHE_HOME` is ignored on macOS.
- `assets_dir_impl(dir, version)` builds `<dir>/shinylive-<version>`. The
  prefix is the `shinylive_prefix` constant.
- `assets_dirs(dir)` lists `shinylive-*` entries in `dir` (with base
  `dir()`, which is faster than `fs::dir_ls()`) and sorts them newest first
  with `numeric_version()`.

## Which version is used

`assets_version()` returns `Sys.getenv("SHINYLIVE_ASSETS_VERSION",
SHINYLIVE_ASSETS_VERSION)`. The env var wins over the constant in
`R/version.R`. `export(assets_version=)` lets a caller pick another version
for one export.

To bump the default, follow the `update-assets-version` skill: change
`R/version.R`, the expected webR R version test in `test-assets.R` if webR's
R changed, the `NEWS.md` bullet, and examples that name the old version.

## Functions

| Function | Exported | What it does |
|---|---|---|
| `assets_download(version, dir, url)` | yes | Always downloads `url` with httr2 into a temp `.tar.gz`, then extracts it into `dir` with `archive::archive_extract()`. The tarball's top folder is `shinylive-<version>/`. Returns `invisible(dir)`. Deletes the temp file on exit. |
| `assets_bundle_url(version)` | no | `https://github.com/posit-dev/shinylive/releases/download/v<version>/shinylive-<version>.tar.gz` |
| `assets_ensure(version, dir, url)` | yes | Creates `dir` if missing. If the version folder is missing, calls `assets_download()`. Returns the version folder invisibly. |
| `assets_dir(version, dir)` | no | Path to one version folder. Does not check that it exists. |
| `assets_cleanup(dir)` | yes | Removes every version in `dir` except `assets_version()`. |
| `assets_remove(versions, dir)` | yes | Removes the given versions. Errors if `versions` is not a non-empty character vector. Warns (does not error) for a version that is not there. |
| `assets_info(quiet)` | yes | Prints package version, assets version, cache dir, and installed folders. Returns a `tbl_df` with `version`, `path`, `is_assets_version`. |
| `assets_version()` | yes | See above. |
| `assets_install_copy(assets_repo_dir, dir, version)` | yes | Copies a local build into the cache. |
| `assets_install_link(assets_repo_dir, dir, version)` | yes | Symlinks a local build into the cache. |
| `assets_webr_r_version(version)` | no | Ensures the version is cached, then calls `assets_path_webr_r_version()`. |
| `assets_path_webr_r_version(assets_path)` | no | Reads the webR R version from the assets. |
| `check_assets_url(version, url)` | no | HEAD request; `TRUE` if status is 200. Not called anywhere in `R/` or tests. |

Removal goes through `unlink_path()`, which deletes a symlink with
`fs::link_delete()` (so the linked repo is untouched) and a real folder with
`fs::dir_delete()`.

## Local builds of posit-dev/shinylive

For testing asset changes before a release:

1. In a posit-dev/shinylive clone, run `make submodules all`. This fills
   `build/`.
2. Run `assets_install_link("path/to/shinylive")` (changes show up right
   away) or `assets_install_copy(...)` (repeat after each change).

Both call `install_local_helper()`, which:

- Errors if `assets_repo_dir` or `assets_repo_dir/build` is missing.
- Reads the version from `package.json` in the repo
  (`package_json_version()`) unless `version=` is given.
- Deletes any existing `<dir>/shinylive-<version>` (link or folder), then
  copies or links `build/` there. The contents of `build/` become the version
  folder.
- Warns if the version is not `assets_version()`. Set
  `SHINYLIVE_ASSETS_VERSION` to the local version, or pass `version =
  assets_version()`, so export and Quarto pick it up.

## webR R version

Wasm package binaries must match the R version of the webR inside the
assets. `assets_path_webr_r_version()` reads `Version` from
`shinylive/webr/vfs/usr/lib/R/library/translations/DESCRIPTION` in the
version folder (the `translations` base package has the R version; present
in assets 0.8.0 and later). It errors with a hint to delete the folder if
the file is missing. `export()` and `quarto_ext()` pass this value to
`download_wasm_packages()` (see `wasmPackages.md`).

## CRAN guard

`assets_cache_dir()` stops with "must not be called during CRAN testing"
when `cran_is_testing()` is true (`TESTTHAT=true` and `NOT_CRAN` not
`true`). This keeps CRAN checks from writing to the user cache. Because
`dir = assets_cache_dir()` is a lazy default, passing `dir=` avoids the
guard for most functions, but not for `assets_dir()` and `assets_info()`
(see Pitfalls).

## Pitfalls

- **`assets_dir()` ignores `dir=`.** It calls
  `assets_dir_impl(dir = assets_cache_dir(), ...)`. So the path always
  points at the real cache, and passing `dir=` does not avoid the CRAN guard.
- **`assets_ensure(dir = other)` mixes two folders.** It checks for and
  returns `<real cache>/shinylive-<version>` (through `assets_dir()`), but
  downloads into `other`. If the real cache already has the version, nothing
  is downloaded into `other` at all.
- **`assets_info()` errors when no versions are installed.** It sets the list
  to `"(None)"`, prints it, then `strsplit(..., "shinylive-")` gives one piece
  and `x[[2]]` fails with "subscript out of bounds".
- **`assets_info()` has no `dir` argument.** It always reads the real cache.
  Its "(Cache dir does not exist)" branch can't run, because
  `assets_cache_dir()` creates the folder.
- **`assets_info()` visibility is reversed from what you may expect.**
  `quiet = FALSE` prints and returns invisibly; `quiet = TRUE` returns the
  table visibly.
- **A stray `shinylive-*` entry breaks listing.** A folder like
  `shinylive-dev` or a file like `shinylive-1.0.0.tar.gz` in the cache makes
  `assets_dirs()` fail with "invalid version specification". That also breaks
  `assets_info()` and `assets_cleanup()`. Files are not filtered out.
- **`assets_ensure()` does not print the dir it creates.** The message is
  `cli_alert_info("Creating assets cache directory ", dir)`; `dir` lands in
  `cli::cli_alert_info()`'s `id` argument, so only the text shows.
- **Empty `SHINYLIVE_ASSETS_VERSION` is not unset.** If the env var is set to
  `""`, `assets_version()` returns `""`, not the default.
- **`check_assets_url()` never returns `FALSE` for a 404.** httr2 turns
  HTTP errors into R errors, so a bad version throws "HTTP 404 Not Found".
- **`assets_download()` does not clear the target first.** It extracts over
  any existing version folder, so stale files from a partial or local
  install can remain. Use `assets_remove()` first.
- **Calling the exported helpers in tests or scripts touches the real
  cache** unless you pass `dir=` (and even then, see `assets_dir()` above).
  Mock `assets_cache_dir` with `testthat::local_mocked_bindings()` or set
  `R_USER_CACHE_DIR` to a temp folder.
