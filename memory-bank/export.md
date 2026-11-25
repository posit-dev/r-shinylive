---
title: "Export pipeline"
description: "How export() turns an app folder into a static site: copying assets, reading app files into app.json, rendering the export template, subdir and multiple apps, re-exporting, quiet output, and env vars. Read before changing R/export.R, R/app_json.R, create_copy_fn() in R/utils.R, or R/cli.R."
---

# Export pipeline

## Overview

`export(appdir, destdir)` builds a folder that any static web server can host.
It runs these steps in order:

1. Check arguments: `appdir` must be a folder with `app.R` or `server.R`;
   `destdir` must not be `appdir` or a folder that holds it (compared with
   `comparable_path()`); `subdir` is checked and cleaned by `check_subdir()`.
   Create `destdir` if needed.
2. Copy the base Shinylive asset files (the `base` and `r` sets) from the
   assets cache into `destdir` (`create_copy_fn()`).
3. Read every app file into a list (`read_app_files()`).
4. Download Wasm binaries of the app's R packages (`download_wasm_packages()`,
   see `wasmPackages.md`).
5. Render the export template and write `app.json` into `destdir/subdir`
   (`write_app_json()`).
6. Print how to serve the folder. Return `destdir` invisibly.

Asset download and caching are covered in `assets.md`.

## Key files

| File | Functions |
|---|---|
| `R/export.R` | `export()`, `wasm_packages_able()`, `check_subdir()` |
| `R/app_json.R` | `file_content_obj()`, `app_info_obj()`, `read_app_files()`, `write_app_json()` |
| `R/utils.R` | `create_copy_fn()`, `unlink_path()`, `files_are_equal()`, `full_path()`, `comparable_path()` |
| `R/deps.R` | `shinylive_common_files()` (which asset files are copied) |
| `R/cli.R` | `local_quiet()`, `is_quiet()`, and the `cli_*()` wrappers |
| `tests/testthat/test-export.R` | End-to-end tests (need the assets, see `TEST_ASSETS` in `AGENTS.md`), plus offline `check_subdir()` tests |
| `tests/testthat/test-app_json.R` | Offline `read_app_files()` and `write_app_json()` tests |
| `tests/testthat/test-utils.R` | `unlink_path()` and `create_copy_fn()` tests |
| `tests/testthat/apps/` | Test apps, including a custom `export_template/` |

## What ends up in destdir

With the default template and `subdir = ""`:

| Path | Source |
|---|---|
| `shinylive-sw.js` and other top-level asset files | `shinylive_common_files("base")`: files (not folders) at the top of the assets folder |
| `shinylive/*` (top level only, minus `examples.json`) | `shinylive_common_files("base")` |
| `shinylive/webr/**` | `shinylive_common_files("r")`, all of it, recursive |
| `shinylive/webr/packages/` | Wasm package binaries and `metadata.rds` (only when `wasm_packages` is on) |
| `index.html`, `edit/index.html` | Rendered from the template folder |
| `app.json` | The app files, written by `write_app_json()` |

Not copied: `scripts/`, `export_template/`, `shinylive/pyodide/`,
`shinylive/pyright/`. Some Python files at the top of `shinylive/` (for
example `pyodide-worker.js`, `run-python-blocks.js`) are still copied.

## Reading app files (read_app_files)

`read_app_files(appdir, destdir)` walks `appdir` with `inspect_dir()` and
returns a list of `file_content_obj(name, content, type)`. `name` is the path
relative to `appdir`. This list is written as-is to `app.json`.

- **Order:** in each folder, paths are sorted with a radix sort on UTF-8
  names (C-style byte order, so `B` comes before `a`). Then any of `app.R`,
  `server.R`, `ui.R` move to the front, keeping that sorted order. Folders are walked when met, so their files sit in the middle.
- **Hidden files and folders** are skipped, because base `dir()` is called
  without `all.files = TRUE`.
- **Excluded folder names:** `__pycache__`, `venv`, `.venv`, `rsconnect`, at
  any depth below `appdir`. Only folders are checked. A *file* named `venv`
  is kept. The `appdir` folder itself is never excluded, so an app folder
  named `venv` still works.
- **destdir inside appdir:** both paths go through `comparable_path()` first
  (`full_path()`: absolute, symlinks resolved, also for paths that do not
  exist yet; lower case on Windows and macOS), so relative and absolute forms
  (and macOS `/var` vs `/private/var`) compare correctly. Folders under
  `destdir` are skipped only when `destdir` is a subfolder of `appdir`.
  `export()` rejects `appdir` inside `destdir` before this runs.
- **`shinylive.js` found:** gives a warning that you may be bundling a
  Shinylive copy into the app.
- **Text or binary:** `brio::read_file()` is tried first. If it errors (on
  embedded NUL bytes) or the result is not valid UTF-8 (`validUTF8()`), the
  file is read with `brio::read_file_raw()` and marked `"binary"`.
  `jsonlite` writes raw vectors as base64. So a latin1 text file is stored
  as binary, and `app.json` stays valid JSON.

## Template and app.json (write_app_json)

`write_app_json(app_info, destdir, template_dir, template_params, quiet)`:

1. Lists every file in `template_dir` (recursive).
2. For files with extension `html`, renders them with
   `whisker::whisker.render()` and writes them with `brio::write_file()`
   (overwrites). Other files are copied with
   `fs::file_copy(overwrite = TRUE)`. Note `.htm` is not rendered.
3. Writes `app.json` with `jsonlite::write_json(auto_unbox = TRUE,
   pretty = FALSE)`.

The default `template_dir` is `export_template/` in the assets folder. It has
`index.html` and `edit/index.html` (a redirect to
`../index.html?_shinylive-mode=editor-terminal-viewer`).

### Template parameters

Built with `rlang::dots_list(..., .homonyms = "first")`, so the first value of
a name wins:

| Order | Name | Value | Can the user change it? |
|---|---|---|---|
| 1 | `REL_PATH` | `../` repeated once per `subdir` part, with a trailing `/`; `""` when no subdir | No |
| 2 | `APP_ENGINE` | `"r"` | No |
| 3 | user `template_params` | anything | - |
| 4 | `title` | `"Shiny App"` | Yes, via `template_params$title` |

If the user list has the same name twice, the first one wins. The default
template wraps `<title>` in `{{#title}}`, so `title = FALSE` or `""` drops
the tag. The default template also uses `include_in_head`,
`include_before_body`, and `include_after_body` with triple braces (raw HTML).
Unknown names render as empty.

`REL_PATH` lets `index.html` in `destdir/subdir` reach the shared
`destdir/shinylive/` folder.

### check_subdir()

`check_subdir(subdir)` in `R/export.R` runs before anything is written. It:

- errors unless `subdir` is a single non-`NA` string;
- errors on an absolute path;
- splits on `/` and `\`, drops empty and `.` parts, and errors if any part
  is `..`;
- returns the parts joined with `/`.

So `subdir = "."` or `"./"` is the same as `""` (`REL_PATH` is `""`), and
`subdir = "../x"` or `"a/../b"` is an error.

## Multiple apps and re-exporting

- **Multiple apps:** export each app to the same `destdir` with a different
  `subdir`. They share `shinylive/` and `shinylive/webr/packages/`. Package
  metadata is merged across exports (see `wasmPackages.md`).
- **Copying is skip-if-exists.** `export()` uses
  `create_copy_fn(overwrite = FALSE)`. `mark_file()` skips any destination
  that already exists. If its MD5 differs from the source and output is not
  quiet, it prints "Source and destination copies differ" and suggests a
  clean re-export. The old file stays. All marked files are then copied in
  one `fs::file_copy()` call by `copy_files()`.
- **`create_copy_fn(overwrite = TRUE)`** removes each existing destination
  with `unlink_path()` (file, folder, or link) before copying. Nothing calls
  it with `TRUE` today.
- **Always rewritten:** `app.json`, rendered `.html` template files, and the
  template's other files.
- **Never removed:** files from an earlier export that are no longer needed
  (old app files, old assets from another assets version). Delete `destdir`
  for a clean result.

## Quiet output (R/cli.R)

- `local_quiet(quiet)` sets the `shinylive.quiet` option for the calling
  function's frame (`withr::local_options()`).
- `is_quiet()` is `isTRUE(getOption("shinylive.quiet", FALSE))`.
- Wrappers `cli_alert()`, `cli_alert_info()`, `cli_alert_warning()`,
  `cli_alert_danger()`, `cli_alert_success()`, `cli_progress_step()`,
  `cli_progress_done()`, `cli_text()`, `cli_bullets()` do nothing when quiet.
  They pass `.envir` so `{}` glue works in the caller's frame.
- `export()` default: `quiet = getOption("shinylive.quiet",
  !is_interactive())`. So it is quiet in `Rscript`, CI, and tests, and chatty
  in an interactive session.
- `write_app_json()` has its own default, `getOption("shinylive.quiet",
  FALSE)`; `export()` passes its value through.
- The "Copying base Shinylive files" progress bar calls
  `cli::cli_progress_bar()` directly, guarded by `is_quiet()`.
- `cli::cli_warn()` and `cli::cli_abort()` are not wrapped. They show even
  when quiet. The one direct `cli::cli_inform()` call (the "copies differ"
  message in `create_copy_fn()`) checks `is_quiet()` itself.

## Environment variables

| Variable | Effect on export | Read in |
|---|---|---|
| `SHINYLIVE_ASSETS_VERSION` | `assets_version` when not passed (empty counts as unset) | `assets_version_input()` |
| `SHINYLIVE_WASM_PACKAGES` | Default `wasm_packages` (`TRUE`/`1`, `FALSE`/`0`; other values error) | `sys_env_wasm_packages()` |
| `SHINYLIVE_DEFAULT_MAX_FILESIZE` | Default `max_filesize` | `sys_env_max_filesize()` |
| `SHINYLIVE_DOWNLOAD_WASM_CORE_PACKAGES` | Core packages to download anyway | `env_download_wasm_core_packages()` (called by `download_wasm_packages()`) |

The option `shinylive.quiet` is the matching R option for quiet output.

## Hand-off to Wasm packages

When `wasm_packages` is true and `wasm_packages_able(assets_version)` is true
(assets 0.8.0 or later; older versions warn and skip), `export()` calls
`download_wasm_packages(appdir, destdir, package_cache, max_filesize,
r_version = assets_webr_r_version(assets_version))`. This runs after the
assets copy and before `write_app_json()`. If it errors (for example, a
package is over `max_filesize`), the assets are already copied but `app.json`
and `index.html` are not written. Details are in `wasmPackages.md`.

## Pitfalls

- **Keep `appdir` and `destdir` separate.** `destdir` equal to `appdir`
  (`export(".", ".")`) or holding it (`export("myapp", ".")`) is an error.
  Before, those silently gave an empty `app.json` (every app file sat inside
  `destdir` and was skipped), or wrote `index.html`/`app.json` into the app
  source. `destdir` inside `appdir` (`export(".", "site")`) still works but
  is not recommended.
- **Use `comparable_path()` to compare paths.** Plain `fs::path_has_parent()`
  on raw paths misses relative vs absolute forms, symlinks, and case. Never
  use its result to create files: it is lower case on Windows and macOS.
- **Empty files become `"content": []`** in `app.json`, not `""`, because
  `brio::read_file()` returns `character(0)` for an empty file.
- **The "copies differ" message keeps the stale file.** It only warns; delete
  `destdir` for a clean result.
- **`export()` does not check `ui.R`.** A folder with only `ui.R` is rejected;
  one with only `server.R` passes.
- **Stale comment in `inspect_dir()`** mentions `fs::dir_walk(all = FALSE)`;
  the code uses base `dir()`.
- **`export()` prints its first messages before checking `appdir`.** A bad
  `appdir` still prints "Exporting Shiny app from" first when not quiet. The
  assets version is resolved later, after all argument checks, because
  `resolve_assets_version()` may use the network or download assets. Keep new
  argument checks above that call.
