---
title: "Assets cache"
description: "How shinylive downloads, caches, installs, and removes the Shinylive web assets (R/assets.R, R/assets_version.R, R/version.R): the cache folder layout, how the assets version is chosen (series patterns, versions.json, the daily GitHub check), local builds of posit-dev/shinylive, and the webR R version lookup. Read before changing any assets_*() function or bumping the default assets version."
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
- `R/assets_version.R` - version inputs (exact, series, `"latest"`),
  `versions.json`, the GitHub check, and `resolve_assets_version()`.
- `R/version.R` - `SHINYLIVE_ASSETS_VERSION_DEFAULT` (default series, like
  `"0.10.*"`), `SHINYLIVE_ASSETS_VERSION_FALLBACK` (known-good exact version),
  and `SHINYLIVE_R_VERSION` (this package's version, from
  `utils::packageVersion()`).
- `R/utils.R` - `cran_is_testing()`, `unlink_path()`, `package_json_version()`.
- `tests/testthat/test-assets.R` - asset tests, including the expected webR R
  version for the default assets, plus offline tests for `dir=`, stray cache
  entries, `assets_info()` with nothing installed, and `check_assets_url()`.
- `tests/testthat/test-assets_version.R` - offline tests for version
  parsing, `versions.json`, the check rules, and resolution (the network is
  mocked).
- `tests/testthat/test-assertions.R` - argument checks and the CRAN guard.
- `.agents/skills/update-assets-version/SKILL.md` - steps to bump the default
  assets version.

## Cache folder layout

```
<assets_cache_dir()>/          e.g. ~/Library/Caches/shinylive on macOS
  versions.json                last GitHub check (see below)
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
  prefix is the `shinylive_prefix` constant. `assets_path_version(path)` does
  the reverse: it returns the version from a folder path. Use it instead of
  stripping the prefix by hand.
- `assets_dirs(dir)` lists `shinylive-*` entries in `dir` (with base
  `dir()`, which is faster than `fs::dir_ls()`), keeps only folders whose
  suffix parses with `numeric_version(strict = FALSE)`, and sorts them newest
  first. So stray entries like a `shinylive-dev` folder or a
  `shinylive-1.0.0.tar.gz` file are skipped.

## Which version is used

A version input is an exact version (`"0.10.16"`), a series (`"0.10.*"`,
`"0.*"`: whole numbers and one trailing `.*`), or `"latest"`. Anything else
errors in `parse_assets_version()`.

The input comes from (first wins): a non-`NULL` argument
(`export(assets_version=)`, `assets_download(version=)`,
`assets_ensure(version=)`, all `NULL` by default), the
`SHINYLIVE_ASSETS_VERSION` env var (empty counts as unset), then
`SHINYLIVE_ASSETS_VERSION_DEFAULT`. See `assets_version_input()`.

`resolve_assets_version(version, dir, download = TRUE, check = TRUE)` turns
an input into an exact version:

- **Exact:** returned as is. Warns once per session if it is outside the
  default series.
- **Series or `"latest"`:** runs the GitHub check if due (always for
  `"latest"`), then takes the highest match from the `versions.json` list and
  the downloaded folders. With no match, it uses
  `SHINYLIVE_ASSETS_VERSION_FALLBACK` if that matches, else errors. If the
  pick is not downloaded and `download = TRUE`, it downloads it; if that
  fails, it warns and uses the highest downloaded match. With none, it tries
  to download the fallback version, and errors only if that fails too.
- If the check failed and no listed release matches (for example, GitHub
  rate-limited the release list and only a newer series' latest tag is
  known), it warns that the pick may be old.
- `check = FALSE` reads `versions.json` only, with no network. `assets_info()`
  uses it, and shows "unresolved (<reason>)" if resolution errors.
- The result is remembered for the R session (`assets_version_memo`;
  `assets_version_reset()` clears it). So one `export()` or Quarto call does
  at most one check. So `"latest"` is checked once per session, not on every
  call.

`assets_version()` is `resolve_assets_version()` of the env var or default,
so it can use the network and download assets.

### versions.json and the GitHub check

`versions.json` holds `checked_at` (UTC), `latest`, `versions`, and `error`
when the last check (or the download after it) failed.
`check_versions_info(info)` runs the check when: there is no (valid) file,
the last good check is 24 or more hours old, the last failed check is 1 or
more hours old, `checked_at` is in the future, or `force = TRUE`. It returns
the new info and writes nothing.

1. `fetch_latest_assets_version()`: HEAD request to
   `github.com/posit-dev/shinylive/releases/latest`, reading the tag from the
   redirect. Not the API, so no rate limit. 1 s connect, 3 s total timeout.
2. Only if the tag differs from the stored `latest` (or the list is empty):
   `fetch_assets_versions()` lists releases with `gh` (drafts and
   prereleases skipped).
3. Any error writes `error` and a new `checked_at` but keeps the old `latest`
   and `versions`. A latest tag seen before the error is added to `versions`
   (not to `latest`, so the next check fetches the full list).

**Rule: `versions.json` only names a version once it is downloaded.**
Quarto's later commands (`check = FALSE`), in R and in py-shinylive (they
share the file), only read it. If it named a release that is not
downloaded, they would download it, and one render could mix two assets
versions. So `resolve_assets_version()`:

- saves the new info (`save_versions_json()`) only when `check = TRUE`, a
  check ran, and the chosen version is in the local cache (already there or
  just downloaded). A `download = FALSE` call with a new release not yet
  downloaded saves nothing, so the next call checks again.
- after a failed download with a local fallback, saves
  `drop_versions_newer_than()`: the list without the releases matching the
  spec that are newer than the version used (other series kept),
  `latest = NULL` (so the next check fetches the full list), and `error` (so
  the next check runs within the hour).
- never writes with `check = FALSE`.
- ignores a failed write (read-only cache). The old file follows the same
  rule, so later commands still pick a downloaded version.

Both fetchers stop under `cran_is_testing()`, and `check_versions_info()`
returns the old info then, so nothing is saved. The file is written to a
temp file in the same folder, then renamed.

To start a new minor series, follow the `update-assets-version` skill.

## Functions

| Function | Exported | What it does |
|---|---|---|
| `assets_download(version, dir, url)` | yes | Resolves `version` (without downloading), then always downloads `url` with httr2 into a temp `.tar.gz`, extracts it into a temp folder inside `dir`, and moves `shinylive-<version>/` into place. A folder that existed before the call is replaced; one that appeared during the call (another R process), even between the check and the move, is kept and the new copy dropped. Returns `invisible(dir)`. |
| `assets_bundle_url(version, dir)` | no | `https://github.com/posit-dev/shinylive/releases/download/v<version>/shinylive-<version>.tar.gz`. A series or `"latest"` is resolved first (no download), so the `url` defaults work before or after the caller resolves `version`. |
| `assets_ensure(version, dir, url)` | yes | Creates `dir` if missing (and prints "Creating assets cache directory" with the path). Resolves `version`. If `<dir>/shinylive-<version>` is missing, calls `assets_download()` into `dir`. Returns that version folder invisibly. |
| `assets_dir(version, dir)` | no | Path `<dir>/shinylive-<version>`. Does not check that it exists. |
| `assets_cleanup(keep, dir)` | yes | Keeps the versions in `dir` matched by `keep` (exact versions kept as is; for a series or `"latest"`, only the newest local match) and removes the rest. `keep = NULL` means `SHINYLIVE_ASSETS_VERSION_DEFAULT` plus `SHINYLIVE_ASSETS_VERSION` if set (`assets_cleanup_keep_default()`). |
| `assets_remove(versions, dir)` | yes | Removes the given versions. Errors if `versions` is not a non-empty character vector. Warns (does not error) for a version that is not there. |
| `assets_info(quiet)` | yes | Prints package version, resolved assets version (reads `versions.json` only: no network, no download), default series, last check time and error, cache dir, and installed folders (or `(None)`). Returns a `tbl_df` with `version`, `path`, `is_assets_version`; zero rows when nothing is installed. |
| `assets_version()` | yes | See above. |
| `assets_install_copy(assets_repo_dir, dir, version)` | yes | Copies a local build into the cache. |
| `assets_install_link(assets_repo_dir, dir, version)` | yes | Symlinks a local build into the cache. |
| `assets_webr_r_version(version)` | no | Ensures the version is cached, then calls `assets_path_webr_r_version()`. |
| `assets_path_webr_r_version(assets_path)` | no | Reads the webR R version from the assets. |
| `check_assets_url(version, url)` | no | HEAD request with HTTP errors turned off (`httr2::req_error()`); `TRUE` if status is 200, `FALSE` otherwise (for example a 404 for a missing release). Network errors still throw. Not called anywhere in `R/`; tested in `test-assets.R`. |

Removal goes through `unlink_path()` in `R/utils.R`, which deletes a symlink
with `fs::link_delete()` (so the linked repo is untouched), a real folder with
`fs::dir_delete()`, and a file with `fs::file_delete()`.

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
- Warns if the version is outside the default series. A local version in
  the series is picked up automatically if it is the highest; otherwise set
  `SHINYLIVE_ASSETS_VERSION` to the local version so export and Quarto use
  it.

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
guard for every function that has a `dir` argument (including
`assets_dir()` and `assets_ensure()`), but not for `assets_info()`, which
has no `dir` argument.

## Pitfalls

- **`assets_info()` has no `dir` argument.** It always reads the real cache.
- **`assets_info()` visibility is reversed from what you may expect.**
  `quiet = FALSE` prints and returns invisibly; `quiet = TRUE` returns the
  table visibly. The roxygen now says this.
- **`assets_version()` is not a constant.** It can change from day to day,
  can use the network, and can download assets. In tests, mock
  `fetch_latest_assets_version`, `fetch_assets_versions`, and
  `assets_download`, pass `dir=`, and call `assets_version_reset()`.
- **Session memo hides changes.** After changing the env var or the cache in
  one R session, call `assets_version_reset()`.
- **A backport release is missed** until the latest tag changes, because the
  release list is only fetched when `latest` changes. This is on purpose:
  releases only move forward, and an older series gets no new patch after a
  newer series is out.
- **Callers that do not pass `dir` still use the real cache.** For example
  `assets_webr_r_version()` calls `assets_ensure(version)` with the default
  `dir`, and `export()` calls `assets_dir(version = assets_version)`.
- **Calling the exported helpers in tests or scripts touches the real
  cache** unless you pass `dir=`. For code paths that do not take `dir`, mock
  `assets_cache_dir` with `testthat::local_mocked_bindings()` (as
  `test-deps.R` does) or set `R_USER_CACHE_DIR` to a temp folder.
