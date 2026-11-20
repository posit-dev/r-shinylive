---
title: "WebAssembly package bundling"
description: "How R/packages.R finds an app's R package dependencies, skips packages already in webR, downloads Wasm binaries from repo.r-wasm.org, r-universe, or GitHub releases, and caches them with metadata.rds. Covers max_filesize, SHINYLIVE_WASM_PACKAGES, and the R version check. Read before changing package bundling or debugging missing, stale, or re-downloaded packages."
---

# WebAssembly package bundling

## Overview

webR can only load R packages built for WebAssembly (Wasm). When an app is
exported, `download_wasm_packages()` in `R/packages.R` finds the app's R
packages, looks up a Wasm binary for each one, and copies it into
`<destdir>/shinylive/webr/packages/<pkg>/`. It also writes
`<destdir>/shinylive/webr/packages/metadata.rds`, which lists what was
bundled. This file is also the cache: the next export into the same `destdir`
reads it to skip downloads.

Two callers use it:

| Caller | `wasm_packages` | `package_cache` | `max_filesize` | `r_version` |
|---|---|---|---|---|
| `export()` in `R/export.R` | argument, else `sys_env_wasm_packages()` | argument (default `TRUE`) | argument (default `NULL`) | `assets_webr_r_version(assets_version)` |
| `quarto_ext()` "app-resources" in `R/quarto_ext.R` | `sys_env_wasm_packages()` only | always `TRUE` | always `NULL` | `assets_webr_r_version()` |

Both first call `wasm_packages_able()`, which warns and skips bundling for
assets older than 0.8.0. The Quarto caller runs with `shinylive.quiet = TRUE`
and then turns every file under `shinylive/webr/` into an HTML dependency.

## Key files

- `R/packages.R` - everything below, including `parse_max_filesize()`.
- `R/export.R` - `export()` roxygen documents `wasm_packages`,
  `package_cache`, and `max_filesize`; `wasm_packages_able()`.
- `R/quarto_ext.R` - Quarto caller.
- `R/utils.R` - `cran_is_testing()`.
- `tests/testthat/test-packages.R` - cache key tests and mocked
  `download_wasm_packages()` runs. They mock `utils::packageDescription`,
  `utils::download.file`, `renv::dependencies`, `get_wasm_assets()`, and
  `resolve_dependencies()`, so they need no network and no assets. Also
  `parse_max_filesize()` tests and a test that a package dropped for its
  size is tried again.

## Finding dependencies

Steps in `download_wasm_packages()`:

1. Build the skip list: `resolve_dependencies(c("shiny", "bslib", "renv"),
   local = FALSE)`. These packages and all their dependencies are already in
   the webR base image. `local = FALSE` resolves against CRAN with
   pkgdepends, so this needs the network on every export.
2. Remove names in `SHINYLIVE_DOWNLOAD_WASM_CORE_PACKAGES` from the skip list
   (`env_download_wasm_core_packages()`). Values are split on spaces, commas,
   and new lines. This is a developer tool to force a core package to be
   bundled.
3. Scan the app with `renv::dependencies(appdir)` and drop skipped packages.
4. If anything is left, `resolve_dependencies(pkgs_app)` (local mode) and drop
   skipped packages again.

`resolve_dependencies()` uses `pkgdepends::new_pkg_deps()` with
`platforms = "source"` and only `Depends` and `Imports`, for both direct and
indirect dependencies. `LinkingTo` and `Suggests` are left out on purpose
([posit-dev/r-shinylive#115](https://github.com/posit-dev/r-shinylive/issues/115)).
In local mode the refs are `local::<path>` from `find.package()`, so every app
dependency must be installed in the exporting R library. A missing package
stops the export.

Base R packages (`Priority: base`) are handled in `prepare_wasm_metadata()`:
they get `type = "base"`, are never downloaded, and are filtered out before
`metadata.rds` is saved.

## Where binaries come from

`prepare_wasm_metadata()` reads the installed `DESCRIPTION` and picks a source:

| Installed package | Source | `desired_ref` |
|---|---|---|
| `RemoteType: github` | GitHub release whose tag is `RemoteRef` (`get_github_wasm_assets()`) | `github::user/repo@RemoteSha` |
| `Repository` missing or `CRAN` | `https://repo.r-wasm.org` | `pkg@version` |
| `Repository` contains `Bioconductor` | `https://bioc.r-universe.dev` | `bioc::pkg@version` |
| `Repository` ends in `r-universe.dev` | that r-universe URL | `<repo>::pkg@RemoteSha` |
| any other `Repository` | `https://repo.r-wasm.org` | `pkg@version` |

CRAN-like sources go through `get_wasm_assets()`:

- `wasm_contrib_url()` builds `{repo}/bin/emscripten/contrib/{major.minor}`
  from the webR R version.
- `utils::available.packages()` reads that index. Unless
  `cran_is_testing()` is true, it uses `cache_user_dir = TRUE`, which caches
  the index in `tools::R_user_dir("base", "cache")` (R's own cache, about one
  hour). The folder is created first because `available.packages()` errors if
  it is missing
  ([posit-dev/r-shinylive#186](https://github.com/posit-dev/r-shinylive/issues/186)).
- If the package is not in the index, it warns and returns no assets. The
  export goes on without it.
- `check_repo_pkg_version()` warns only when major or minor differ between the
  local and repo versions. Patch differences are expected because the webR
  repo may patch packages.
- It returns one asset: `{pkg}_{ver}.tgz`, with `version`.

GitHub packages return two assets with no `version`: the release files whose
names contain `library.data` and equal `library.js.metadata`. A missing
release or missing assets is an error, not a warning.

## The metadata.rds cache

Each entry is named by package and holds `name`, `version` (local),
`ref`, `cached`, `type` (`"package"`, `"library"`, or `"base"`), `assets`,
`path` (`packages/<pkg>/<first asset filename>`), and `_webr_r_version`.

A cache hit needs all of: `package_cache = TRUE`, an entry from a previous run,
`cached` is `TRUE`, `ref` is not `NA`, and stored `ref == desired_ref`. On a
hit nothing is queried or downloaded.

The stored `ref` is not always the desired ref:

- CRAN-like and Bioconductor: `repo_ref()` builds it from the version the repo
  actually served. If the repo lags behind the local version, stored and
  desired refs differ, so every export re-queries the repo. Once the repo
  catches up, the new binary is downloaded
  ([posit-dev/r-shinylive#194](https://github.com/posit-dev/r-shinylive/issues/194)).
- r-universe and GitHub: the desired ref is stored, so a hit happens as long
  as `RemoteSha` is unchanged.
- No assets found: `ref` is `NA_character_`, so the next export retries.

On a miss, files in `packages/<pkg>/` whose names are not in the new asset
list are deleted (stale cleanup). A file whose name matches is not
downloaded again. So a lagging repo costs one index query, not a download.

After the loop, old and new entries are merged (new wins), base entries are
dropped, and the result is saved.

### R version check

Before the loop, `drop_other_r_version()` removes every entry whose
`_webr_r_version` is not exactly the current webR R version, and deletes its
`packages/<pkg>/` folder. Entries from older shinylive versions have no
`_webr_r_version` and are dropped too. The full version is compared on
purpose, so a patch bump (4.6.0 to 4.6.1) re-downloads everything
([posit-dev/r-shinylive#209](https://github.com/posit-dev/r-shinylive/issues/209)).

## Size limit: max_filesize

Resolution order: `max_filesize` argument, then
`SHINYLIVE_DEFAULT_MAX_FILESIZE`, then the constant
`SHINYLIVE_DEFAULT_MAX_FILESIZE` (`"100MB"`). The chosen value goes through
`parse_max_filesize()`:

- Strings are trimmed. `"NA"` and `"Inf"` (any case) turn the limit off.
  A string that is a plain number (like `"-1"` or `"1e8"`) becomes that
  number.
- `NA`, `Inf`, and negative numbers turn the limit off (`fs::fs_bytes(Inf)`).
- Anything else goes to `fs::fs_bytes()`. A value that does not parse warns
  "Could not parse `max_filesize` value" and falls back to `"100MB"`.

So the env var (always a string) can turn the limit off with `"-1"`,
`"Inf"`, or `"NA"`, the same as the argument.

Each asset is checked after download (or when already on disk). If it is too
big, the package folder is deleted, `assets` is emptied, the entry is saved
with `cached = FALSE` (so the next export tries it again, for example with a
larger `max_filesize`), and:

- if neither the argument nor the env var was set, `cli::cli_warn()` and the
  export goes on without the package;
- otherwise, `cli::cli_abort()` and the export stops. `metadata.rds` is not
  written in that run.

## SHINYLIVE_WASM_PACKAGES

`sys_env_wasm_packages()` reads the env var (default `TRUE`). `"1"` and `"0"`
map to `TRUE`/`FALSE`; anything else goes through `as.logical()`, so `TRUE`,
`true`, `T`, `False`, `F` work. Anything that gives `NA` (`"yes"`, `"2"`, or
an empty string) is an error. In `export()` an explicit `wasm_packages`
argument wins over the env var.

## Pitfalls

- A package dropped for being too large is saved with `cached = FALSE`, so
  every later export queries and downloads it again, then drops it again if
  it is still too big. Raise `max_filesize` to keep it.
- A cache hit never checks that files exist on disk. If someone deletes
  `packages/<pkg>/` but keeps `metadata.rds`, the package stays missing.
- Packages the app no longer uses stay in `metadata.rds` and on disk (the
  merge keeps old entries), so they are still shipped with the export.
- `parse_max_filesize("")` (an empty env var) and strings `fs::fs_bytes()`
  can't read (like `"+1GB"`) warn and fall back to 100MB. They do not turn
  the limit off.
- When the repo serves a patched build (local `1.4.0`, repo `1.4.0-1`), stored and
  desired refs never match, so every export re-queries the repo. No
  re-download happens because the file name matches. `test-packages.R` pins
  this.
- `drop_other_r_version()` uses entry names as folder names. An unnamed entry
  gives `fs::path(pkg_dir, "")`, which is `pkg_dir` itself, and the whole
  `packages/` folder is deleted. Metadata written by this code is always
  named, so this only bites hand-made or corrupt files.
- Mocking `utils::packageDescription` for all packages breaks cli and rlang
  error printing ("the condition has length > 1"). Mock it only for the
  package under test when a test expects an error or warning from cli.
- Bioconductor detection needs a `Repository` field containing
  `Bioconductor` in the installed `DESCRIPTION`. Without it, the package is
  looked up on repo.r-wasm.org.
