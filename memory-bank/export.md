---
title: "Export pipeline"
description: "How export() turns an app folder into a static site: copying assets, reading app files into app.json, rendering the export template, subdir and multiple apps, re-exporting, quiet output, and env vars. Read before changing R/export.R, R/app_json.R, create_copy_fn() in R/utils.R, or R/cli.R."
---

# Export pipeline

## Overview

`export(appdir, destdir)` builds a folder that any static web server can host.
It runs these steps in order:

1. Check arguments: `appdir` must be a folder with `app.R` or `server.R`, and
   `subdir` must not be an absolute path. Create `destdir` if needed.
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
| `R/export.R` | `export()`, `wasm_packages_able()` |
| `R/app_json.R` | `file_content_obj()`, `app_info_obj()`, `read_app_files()`, `write_app_json()` |
| `R/utils.R` | `create_copy_fn()`, `unlink_path()`, `files_are_equal()` |
| `R/deps.R` | `shinylive_common_files()` (which asset files are copied) |
| `R/cli.R` | `local_quiet()`, `is_quiet()`, and the `cli_*()` wrappers |
| `tests/testthat/test-export.R` | End-to-end tests (need the assets, see `TEST_ASSETS` in `AGENTS.md`) |
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
  any depth. Only folders are checked. A *file* named `venv` is kept.
- **destdir inside appdir:** a folder is skipped when
  `fs::path_has_parent(folder, destdir)` is true. This is a plain path
  compare (see Pitfalls).
- **`shinylive.js` found:** gives a warning that you may be bundling a
  Shinylive copy into the app.
- **Text or binary:** `brio::read_file()` is tried first. If it errors, the
  file is read with `brio::read_file_raw()` and marked `"binary"`.
  `jsonlite` writes raw vectors as base64. `brio::read_file()` errors only
  on embedded NUL bytes. So any file without a NUL byte is `"text"`, even if
  it is not valid UTF-8.

## Template and app.json (write_app_json)

`write_app_json(app_info, destdir, template_dir, template_params, quiet)`:

1. Lists every file in `template_dir` (recursive).
2. For files with extension `html`, renders them with
   `whisker::whisker.render()` and writes them with `brio::write_file()`
   (overwrites). Other files are copied with `fs::file_copy()` (does not
   overwrite). Note `.htm` is not rendered.
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

## Multiple apps and re-exporting

- **Multiple apps:** export each app to the same `destdir` with a different
  `subdir`. They share `shinylive/` and `shinylive/webr/packages/`. Package
  metadata is merged across exports (see `wasmPackages.md`).
- **Copying is skip-if-exists.** `export()` uses
  `create_copy_fn(overwrite = FALSE)`. `mark_file()` skips any destination
  that already exists. If its MD5 differs from the source, it prints
  "Source and destination copies differ" and suggests a clean re-export. The
  old file stays. All marked files are then copied in one
  `fs::file_copy()` call by `copy_files()`.
- **Always rewritten:** `app.json` and rendered `.html` template files.
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
- `cli::cli_warn()`, `cli::cli_abort()`, and `cli::cli_inform()` are not
  wrapped. They show even when quiet.

## Environment variables

| Variable | Effect on export | Read in |
|---|---|---|
| `SHINYLIVE_ASSETS_VERSION` | Default `assets_version` | `assets_version()` |
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

- **destdir that contains appdir gives an empty app.**
  `export("myapp", ".")` reads zero files: `inspect_dir()` sees that `appdir`
  itself has `destdir` as a parent and returns early. Same if the `appdir`
  folder is named `venv`, `.venv`, `rsconnect`, or `__pycache__`. No error
  is raised.
- **destdir inside appdir is only skipped when both paths use the same form.**
  `export(".", "site")` works. `export("/abs/app", "site")` from inside the
  app (absolute vs relative) does not skip `site/`, so a second export puts
  the whole site (about 190 files) into `app.json`. Paths are not
  normalized before `fs::path_has_parent()`.
- **`subdir` is only checked for being absolute.** `subdir = "."` writes to
  `destdir` but sets `REL_PATH` to `../`, which breaks asset links.
  `subdir = "../x"` writes outside `destdir` with a wrong `REL_PATH`.
- **Non-UTF-8 text breaks `app.json`.** A latin1 file (or any binary file
  with no NUL byte) is stored as `"text"` and its bytes are written as-is.
  The result is not valid JSON (`jsonlite::validate()` fails).
- **Empty files become `"content": []`** in `app.json`, not `""`, because
  `brio::read_file()` returns `character(0)` for an empty file.
- **Custom template with non-HTML files cannot be re-exported.** The second
  export fails with `EEXIST` from `fs::file_copy()` in `write_app_json()`.
- **`create_copy_fn(overwrite = TRUE)` does not work for files.**
  `unlink_path()` only deletes folders and links to folders, so the file
  stays and `copy_files()` fails with `EEXIST`. Nothing calls it with
  `overwrite = TRUE` today.
- **The "copies differ" message is not quiet.** It uses `cli::cli_inform()`,
  so it shows with `quiet = TRUE`, and the stale file is kept.
- **Roxygen says the default title is `"Shiny app"`**; the code uses
  `"Shiny App"`.
- **`export()` does not check `ui.R`.** A folder with only `ui.R` is rejected;
  one with only `server.R` passes.
- **Stale comment in `inspect_dir()`** mentions `fs::dir_walk(all = FALSE)`;
  the code uses base `dir()`.
- **`export()` calls `assets_version()` and prints its first messages before
  checking `appdir`.** A bad `appdir` still prints "Exporting Shiny app
  from" first when not quiet.
