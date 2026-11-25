---
title: "Quarto extension interface"
description: "How quarto_ext() talks to the quarto-ext/shinylive extension: the command-line contract, the JSON it prints, the HTML dependency builders in R/deps.R, which asset files go in each dependency, and how app-resources downloads Wasm packages. Read before changing R/quarto_ext.R or R/deps.R, or when a Quarto render with shinylive-r blocks breaks."
---

# Quarto extension interface

## Overview

The [quarto-ext/shinylive](https://github.com/quarto-ext/shinylive) extension
is a Lua filter. For each `{shinylive-r}` code block it runs
`Rscript -e "shinylive:::quarto_ext()" <args>` and reads the JSON that R
prints to stdout. For `{shinylive-python}` blocks it runs the `shinylive`
command from py-shinylive with the same arguments. So the R and Python
packages must give the same commands and the same JSON shapes.

`quarto_ext()` is not exported. The extension uses `:::`.

The extension calls, once per document: `extension info`, then
`extension base-htmldeps --sw-dir <offset>`, then
`extension language-resources`. Then, once per code block,
`extension app-resources` with the app files as JSON on stdin.
It runs `--version` only for Python.

If R and Python report different `assets_version` values in the same
document, the extension stops with an error. This is why the CI
`integration` job sets `SHINYLIVE_ASSETS_VERSION` to the py-shinylive assets
version.

## Key files

| File | What it holds |
|---|---|
| `R/quarto_ext.R` | `quarto_ext()`, `build_app_resources()`, `quarto_codeblock_to_json_path()` |
| `R/deps.R` | `html_dep_obj()`, `html_dep_serviceworker_obj()`, `quarto_html_dependency_obj()`, `serviceworker_dep()`, `shinylive_base_deps_htmldep()`, `shinylive_r_resources()`, `shinylive_common_dep_htmldep()`, `shinylive_common_files()` |
| `R/utils.R` | `drop_nulls_rec()`, `assert_nzchar_string()`, `assert_list_items()` |
| `R/packages.R` | `download_wasm_packages()`, `sys_env_wasm_packages()` (see the packages doc) |
| `tests/testthat/test-quarto_ext.R` | Three argument-error tests, then one test each for `info`, `base-htmldeps`, `language-resources`, and two for `app-resources` (all skip unless assets are available); then two offline `build_app_resources()` tests (path check, bad binary) |
| `tests/testthat/test-deps.R` | Offline `shinylive_common_dep_htmldep()` tests with a fake assets folder |
| `local/quarto/` | Small Quarto project with one `shinylive-r` and one `shinylive-python` block |
| `.github/workflows/R-CMD-check.yaml` | `integration` job: installs py-shinylive and the extension, renders `local/quarto/`, then builds assets from source and runs the tests against them |

## Command-line contract

`args` defaults to `commandArgs(trailingOnly = TRUE)`.

| Arguments | Output |
|---|---|
| `--version` | `cat(SHINYLIVE_R_VERSION, "\n")`, plain text, not JSON (prints `0.5.0.9000 \n`, with a space) |
| `extension info` | Object: `version`, `assets_version`, `scripts$"codeblock-to-json"` (path to `scripts/codeblock-to-json.js` in the assets folder) |
| `extension base-htmldeps --sw-dir <dir>` | Array of two Quarto HTML dependencies (service worker, then `shinylive`) |
| `extension language-resources` | Array of `{name, path}` for every file under `shinylive/webr/` |
| `extension app-resources` | Reads app JSON from `con` (default `"stdin"`); returns array of `{name, path}` for Wasm package files |

Rules:

- The first argument must be `extension` (or `--version`). This matches
  py-shinylive, which nests these commands under `extension`.
- Errors use `cli::cli_abort()`. Missing or unknown subcommands list the
  available methods and tell the user to run `quarto add quarto-ext/shinylive`.
- `--sw-dir` is required for `base-htmldeps` and must have a value. It may
  appear anywhere after the subcommand. Its value is the page offset from
  Quarto and is stored in the service worker dependency `meta`.
- Only `info` checks GitHub for new assets releases (and saves
  `versions.json`). It resolves with `download = FALSE`, so with an assets
  version that is not installed it prints a path to a file that does not
  exist yet; `base-htmldeps` downloads it before the extension runs the
  script.
- The later commands run in separate R processes and resolve through
  `quarto_assets_version()` (`check = FALSE`): they only read the
  `versions.json` that `info` just wrote, so one render uses one version.
  They can still differ if another R process rewrites `versions.json` during
  the render, or if the cache is read-only and `info` could not save it.

### Only JSON on stdout

The Lua filter parses all of stdout as JSON. Anything else printed to stdout
breaks the render.

- The result goes through `drop_nulls_rec()`, then
  `jsonlite::toJSON(auto_unbox = TRUE, pretty = is_interactive())`, then
  `print()`. Do not rely on Rscript to auto-print the value.
- `quarto_ext()` returns `invisible()`.
- cli messages, warnings, errors, and the pkgdepends "Loading metadata
  database" lines go to stderr in a non-interactive Rscript. Checked: with
  Wasm downloads on, stdout held only the JSON.
- The download in `build_app_resources()` runs with `shinylive.quiet = TRUE`.
- Never add `cat()` or `print()` in code reached from these commands.

## HTML dependency objects

These builders check their inputs and add an S3 class. The class lets
`quarto_html_dependency_obj()` check list items. `toJSON()` ignores the class.

| Builder | Fields | Class |
|---|---|---|
| `html_dep_obj()` | `name`, `path`, optional `attribs` (list) | `shinylive_html_dep` |
| `html_dep_serviceworker_obj()` | `source`, `destination` | `shinylive_html_dep_serviceworker` |
| `quarto_html_dependency_obj()` | `name`, `version`, `scripts`, `stylesheets`, `resources`, `meta`, `head`, `serviceworkers` | `shinylive_quarto_html_dependency` |

- `name` in `html_dep_obj()` is the path relative to the assets folder (for
  example `shinylive/shinylive.js`). Quarto copies the file to that path in the
  site. `path` is the absolute file path.
- `scripts`, `stylesheets`, and `resources` must be lists of `html_dep_obj()`.
  A plain `list(name =, path =)` is rejected.
- Unset fields stay `NULL`. `drop_nulls_rec()` removes `NULL` list items at
  every level, so they do not show up as `{}` in the JSON. An item that is
  `list(NULL)` becomes an empty list, which prints as `[]`.

`serviceworker_dep()` builds `shinylive-serviceworker`: one service worker
from `<assets>/shinylive-sw.js` to `/shinylive-sw.js`, plus
`meta = list("shinylive:serviceworker_dir" = sw_dir)`.

`shinylive_common_dep_htmldep(dep_type, version)` builds the dependency that
must be named `shinylive`, because the extension attaches more files to it by
that name. `dep_type` goes through `match.arg()`, so it defaults to `"base"`.
`version` is used for the file list (`shinylive_common_files(dep_type,
version)`), the absolute paths, and the dependency `version` field.

## Which asset files go where

`shinylive_common_files(dep_type, version)` returns paths relative to
`assets_dir(version)`. It calls `assets_ensure()` first.
`export()` also uses it, for `"base"` and `"r"`.

| `dep_type` | Files |
|---|---|
| `base` | Top-level files of the assets folder (not recursive), plus top-level files of `shinylive/`, minus `shinylive/examples.json`. So `scripts/`, `export_template/`, `shinylive/webr/`, `shinylive/pyodide/`, `shinylive/pyright/` are left out. |
| `r` | Everything under `shinylive/webr/` (recursive) |
| `python` | Everything under `shinylive/pyodide/` and `shinylive/pyright/` (recursive). Not used by `quarto_ext()` |

For `base`, `shinylive_common_dep_htmldep()` sorts files by base name:

- `load-shinylive-sw.js` is the first script, with `type = "module"`. It
  must exist or the call errors.
- `run-python-blocks.js`, if present, is the last script, also a module.
- `shinylive.css` is the only stylesheet.
- Everything else is a resource. This includes `shinylive-sw.js` (also in the
  service worker dependency) and Python files like `pyodide-worker.js`.

With assets 0.10.16: `base` has 15 files (2 scripts, 1 stylesheet,
12 resources), `r` has 170, `python` has 666.

For `r` and `python`, every file is a resource. `language-resources` prints
only the `resources` list of the `r` dependency.

## build_app_resources()

Input is the app JSON lines from stdin: an array of
`{name, type, content}`, made by `codeblock-to-json.js`. Lines are joined by
`jsonlite::fromJSON()`, so pretty JSON works.

1. `projdir` is `QUARTO_PROJECT_DIR`, or `"."` if unset. Quarto sets it.
2. `appdir` is `<projdir>/.quarto/_webr/appdir`. It is deleted and made again
   for every app. `destdir` is `<projdir>/.quarto/_webr/destdir` and is kept.
3. Each file name goes through `fs::path_norm()`, then is split on `/` and
   `\`. It errors ("App file paths must be relative to the app directory")
   if the name is absolute, starts with a drive letter (`C:`) or `~`, or has
   a `..` part. So `../x`, `a/../../x`, `C:/x.R`, and `~/x.R` error, while
   `..foo.R` is allowed.
4. `type == "text"` is written with `writeLines()`. Anything else is base64
   decoded and written with `writeBin()`. A decode error stops with "Could
   not decode binary app file".
5. If `sys_env_wasm_packages()` is true (env `SHINYLIVE_WASM_PACKAGES`,
   default true) and `wasm_packages_able(assets_version())`, it calls
   `download_wasm_packages(appdir, destdir, package_cache = TRUE,
   max_filesize = NULL, r_version = assets_webr_r_version())`. `renv` finds the
   app's packages in `appdir`.
6. It lists every file under `<destdir>/shinylive/webr/` and returns one
   `html_dep_obj()` per file, named `shinylive/webr/<file>`. If nothing was
   downloaded this is an empty list, printed as `[]`.

Files usually returned: `shinylive/webr/packages/metadata.rds` and
`shinylive/webr/packages/<pkg>/<pkg>_<ver>.tgz`.

## Testing

- `TEST_ASSETS=1 Rscript -e 'devtools::test(filter = "quarto_ext")'`.
- Tests use `capture.output()` around `quarto_ext()` and parse the JSON.
  `app-resources` tests pass a file through `con =` instead of stdin, and
  run in a `withr::local_tempdir()` with `QUARTO_PROJECT_DIR` set.
- To test the real command, install the package to a temp library and run
  `Rscript -e 'shinylive:::quarto_ext()' extension info`. Set
  `QUARTO_PROJECT_DIR` to a temp dir for `app-resources`, and
  `SHINYLIVE_WASM_PACKAGES=0` to skip network calls.
- Full check: in `local/quarto/`, run `quarto add quarto-ext/shinylive`, then
  `quarto render`. `.quarto/` is git-ignored there.

## Pitfalls

- **Match py-shinylive.** Command names, argument names, and JSON keys are
  shared with py-shinylive and the Lua filter. Change them in all three repos
  together.
- **Extra stdout breaks renders.** Running through `pkgload::load_all()` (as the
  README dev setup suggests) can print build output to stdout.
- **The `"Unknown dep_type"` branches never run.** An unknown `dep_type`
  fails in `match.arg()` first.
- **Text files gain a final newline.** `writeLines()` adds `\n`, so
  `"abc"` becomes 4 bytes.
- **A bad binary file stops the render.** A base64 decode error is an error
  ("Could not decode binary app file"), not a skipped file.
- **A file without `type` fails** with "argument is of length zero". Empty
  stdin fails with a jsonlite lexical error.
- **`destdir` is shared by all apps in the project.** Every `app-resources`
  call returns every package downloaded so far, not just this app's. The Lua
  filter attaches each name only once, so pages get the union of packages.
- **`.quarto/_webr/` persists** between renders and acts as the package cache.
  Delete it to force fresh downloads.
