---
title: "Testing shinylive"
description: "How the testthat suite in tests/testthat/ is laid out, how skip_if_assets_unavailable() and TEST_ASSETS gate the tests that need the Shinylive assets, the test apps and custom export template, mocking in test-packages.R, the spelling test, and what runs on CI. Read before writing, running, or debugging any test."
---

# Testing shinylive

## Overview

Tests use testthat 3rd edition (`Config/testthat/edition: 3` in
`DESCRIPTION`). There are two kinds of tests:

- **Asset tests** need the Shinylive web assets (several hundred MB unpacked,
  cached after the first download) and often the network. They call
  `skip_if_assets_unavailable()` and are skipped unless you opt in.
- **Offline tests** check argument validation, small helpers, and the Wasm
  package cache logic with mocks. They always run (some skip on CRAN).

Results on this machine (assets 0.10.16 already cached):

| Command | Skips | Failures |
|---|---|---|
| `Rscript -e 'devtools::test(reporter="summary")'` | 20 | 0 |
| `TEST_ASSETS=true Rscript -e 'devtools::test(reporter="summary")'` | 0 | 0 |

## Key files

| File | What it holds |
|---|---|
| `tests/testthat.R` | Standard `test_check("shinylive")`. |
| `tests/spelling.R` | Spelling check during `R CMD check` (see below). |
| `tests/testthat/setup-skip.R` | `can_test_assets()`, `is_interactive_or_test_assets()`, `skip_if_assets_unavailable()`. |
| `tests/testthat/test-setup-skip.R` | Checks that `can_test_assets()` accepts `1`, `true`, `TRUE` and rejects `0`, `false`, `""`. |
| `tests/testthat/test-assertions.R` | Argument checks in `R/utils.R`, `R/app_json.R`, `R/deps.R`, `R/assets.R`, `R/quarto_ext.R`; `cran_is_testing()` and the `assets_cache_dir()` CRAN guard. |
| `tests/testthat/test-assets.R` | `assets_dirs()`, `assets_path_webr_r_version()`, the webR R version of the default assets; offline tests for `assets_dir(dir=)`, `assets_ensure(dir=)`, stray cache entries, `assets_info()` (nothing installed, the default series, the last check, unresolved), `check_assets_url()` on a 404, `assets_path_version()`, `assets_cleanup()` (`keep=` series and exact versions, `SHINYLIVE_ASSETS_VERSION`, old temp files), `assets_install_copy()` outside the default series, and `assets_download()` moving the extracted folder into place (partial folders, races with another process, failed moves). |
| `tests/testthat/test-assets_version.R` | Offline tests for `R/assets_version.R`: `parse_assets_version()`, series matching, reading and writing `versions.json`, when the daily GitHub check runs or is skipped (including during CRAN checks), failed checks keeping old data, `resolve_assets_version()` (highest match, offline use of downloaded versions, the fallback version, session memory, `"latest"`, exact versions and the outside-default warning), `assets_version_input()` order, and that `assets_bundle_url()`, `check_assets_url()`, and `quarto_ext info` do not download. GitHub and downloads are mocked. |
| `tests/testthat/test-app_json.R` | Offline `read_app_files()` tests (non-UTF-8 text, app inside `destdir`, app folder with an excluded name, relative `destdir`), `export()` into its own `appdir`, and `write_app_json()` over a custom template's other files. |
| `tests/testthat/test-deps.R` | `shinylive_common_dep_htmldep()` uses `version` and defaults `dep_type` to `"base"`. Uses a fake assets folder. |
| `tests/testthat/test-export.R` | `export()` end to end: `app.R`, `ui.R`/`server.R`, `subdir`, custom template, Wasm packages, `max_filesize`, non-UTF-8 paths, deprecated `verbose`. Also offline `check_subdir()` tests. |
| `tests/testthat/test-packages.R` | Wasm package cache logic in `R/packages.R` (`prepare_wasm_metadata()`, `download_wasm_packages()`, `wasm_contrib_url()`), `parse_max_filesize()`, and the size limit staying the same, growing, or shrinking between runs. Fully mocked. |
| `tests/testthat/test-quarto_ext.R` | `quarto_ext()` subcommands and their JSON output; offline `build_app_resources()` path and bad-binary checks. |
| `tests/testthat/test-utils.R` | `unlink_path()` on files, folders, and links; `create_copy_fn(overwrite = TRUE)`; the "copies differ" message staying quiet. |
| `tests/testthat/apps/` | Test apps and the custom export template. |
| `inst/WORDLIST` | Words the spelling check accepts. |

## Skipping asset tests

`tests/testthat/setup-skip.R`:

- `can_test_assets()` is true when `TEST_ASSETS` is `"1"` or anything
  `as.logical()` reads as `TRUE` (`true`, `TRUE`, `T`).
- `is_interactive_or_test_assets()` is `interactive() || can_test_assets()`.
  It does not look at `CI`.
- `skip_if_assets_unavailable()` calls `skip_on_cran()`, then skips unless
  `is_interactive_or_test_assets()` is true.

So asset tests run when R is interactive (for example, `devtools::test()` in
the RStudio console) or when `TEST_ASSETS` is `1`/`true`/`TRUE`/`T`.

Tests that call `skip_if_assets_unavailable()` (the 20 skips):

| File | Tests |
|---|---|
| `test-assertions.R` | The four `assets_remove()`, `assets_dirs()`, `assets_cleanup()` checks. |
| `test-assets.R` | `assets_dirs() contains files`; `the default assets use the expected webR R version`. |
| `test-export.R` | The six `export()` tests (not the two `check_subdir()`/`subdir` tests). |
| `test-quarto_ext.R` | The first eight tests, including the three argument-error tests (not the two `build_app_resources()` tests). |

The offline tests in `test-app_json.R`, `test-assets.R`,
`test-assets_version.R`, `test-deps.R`, `test-quarto_ext.R`, and
`test-utils.R` use temp folders (often a fake assets
folder or `SHINYLIVE_WASM_PACKAGES = "FALSE"`), so they run without assets.

Asset tests call `assets_ensure()`, which downloads the default assets into
the real user cache (`assets_cache_dir()`) if they are missing. The export
tests also need the network to download Wasm binaries from
`repo.r-wasm.org` and call `pkgcache::meta_cache_list()` to load CRAN
metadata. `pkgcache` is in `Suggests`.

`the default assets use the expected webR R version` pins `"4.6.0"`. Update it
when a new default assets version changes the webR R version.

## Test apps (tests/testthat/apps/)

| Folder | Used by | What it is |
|---|---|---|
| `app-r/` | most export tests | Single-file `app.R` with a slider. |
| `server-r/` | `export - server.R` | `global.R`, `ui.R`, `server.R`. The test checks all three land in `app.json`. |
| `app-utf8/` | `export - include R package in wasm assets` | `app.R` that calls `library(utf8)`, so a non-base package must be bundled. |
| `export_template/` | `export with template` | A copy of the assets' `export_template` (`index.html`, `edit/index.html`) with one extra `{{ description }}` meta tag. |

`export with template` passes `template_dir` and `template_params` (`title`,
`include_before_body`, `include_after_body`, `description`) to `export()` and
checks the rendered `index.html`. To refresh the template from the assets,
there is an `if (FALSE)` block in the test that copies
`fs::path(shinylive:::assets_dir(), "export_template")`; you must re-add the
`description` meta tag afterwards.

`export - non utf8 paths` copies `app-r/app.R` into a temp folder named
`• app` and exports it.

## Helpers inside test files

- `expect_silent_unattended(expr)` in `test-export.R`: in an interactive
  session it just runs `expr`; otherwise it is `expect_silent(expr)`. This lets
  you watch export progress when running by hand, while CI checks that
  `export()` prints nothing when not interactive. `export - non utf8 paths`
  uses plain `expect_silent()` instead.
- `test-packages.R` builds fake inputs with `cran_desc()` and `wasm_asset()`,
  seeds an output folder with `seed_packages_dir()` (a stale `.tgz` plus
  `metadata.rds` with `_webr_r_version`), and installs mocks with
  `mock_download_env()`.

## Mocking in test-packages.R

`testthat::local_mocked_bindings()` replaces functions for one test:

- `utils::packageDescription()` and `utils::download.file()` with
  `.package = "utils"`.
- `renv::dependencies()` with `.package = "renv"`.
- shinylive's own `get_wasm_assets()` and `resolve_dependencies()` (no
  `.package`, so the shinylive namespace).

`mock_download_env()` passes `.env = parent.frame()` so the mocks last for the
calling test, not just the helper. It records calls in an environment
(`downloaded$queried`, `downloaded$called`) so tests can check whether the
repo was queried and whether a file was downloaded. These tests use
`withr::local_tempdir()` for output and `shinylive.quiet = TRUE`. They need
no assets and no network. All but `the Wasm repo URL follows the given R
version` call `skip_on_cran()`.

## Spelling

`tests/spelling.R` runs, if `spelling` is installed:

```r
spelling::spell_check_test(vignettes = TRUE, error = TRUE, skip_on_cran = TRUE)
```

`error = TRUE` means a misspelling fails `R CMD check` (not on CRAN). Add
accepted words to `inst/WORDLIST` (one per line). Check by hand with
`spelling::spell_check_package()`; it also checks `NEWS.md` and `README.md`.

## Running tests

```r
devtools::test()                       # offline tests only (when not interactive)
devtools::test(filter = "packages")    # one file; filter matches the name after "test-"
devtools::test(reporter = "summary")   # shows each skip and its reason
devtools::check()                      # full R CMD check
```

```sh
TEST_ASSETS=1 Rscript -e 'devtools::test()'   # include asset tests
```

`devtools::test()` sets `NOT_CRAN=true`, so `skip_on_cran()` does not skip.

## What runs on CI

See `ciAndTooling.md` for the full workflow. In short, in
`.github/workflows/R-CMD-check.yaml`:

| Job | `TEST_ASSETS` | Asset tests |
|---|---|---|
| `R-CMD-check` (shiny-workflows matrix of OS and R versions) | not set | skipped |
| `R-CMD-check-test-assets` (ubuntu, `--as-cran`) | `TRUE` | run, with cached assets |
| `integration` (`testthat::test_local()` against assets built from posit-dev/shinylive `main`) | `TRUE` | run |

`r-lib/actions/setup-r` sets `NOT_CRAN=true` on CI, so `skip_on_cran()` does
not skip there even with `--as-cran`.

## Pitfalls

- **Asset tests write to your real cache.** `assets_ensure()` downloads into
  `assets_cache_dir()`. There is no temp cache for tests.
- **Interactive runs include asset tests.** Running `devtools::test()` from
  the console downloads assets and hits the network.
- **`app-resources` writes under `QUARTO_PROJECT_DIR`.** The `app-resources`
  tests in `test-quarto_ext.R` move into a `withr::local_tempdir()` and set
  `QUARTO_PROJECT_DIR = "."`. The `build_app_resources()` tests use the
  `local_app_resources_project()` helper for the same reason. Do the same in
  new tests, or `.quarto/_webr/` is written into the working folder.
- **`export - include R package in wasm assets` needs `utf8` installed
  locally.** `resolve_dependencies()` calls `find.package()` on the app's
  packages, which errors if one is missing. `shiny` is in the skip list, so it
  is not looked up. `utf8` is not listed in `DESCRIPTION`.
- **The quarto argument-error tests are gated too.** `quarto_ext errors on
  missing --sw-dir argument` and the two after it call
  `skip_if_assets_unavailable()`, so they only run with assets.
- **`export with template` keeps an old guard**,
  `skip_if(assets_version() <= package_version("0.4.1"))`. It never skips with
  current assets.
- **Spelling fails the build** (`error = TRUE`). Run
  `spelling::spell_check_package()` after editing docs, `NEWS.md`, or
  roxygen, and add real words to `inst/WORDLIST`.
