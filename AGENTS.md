# AGENTS.md

This file gives guidance to coding agents working in this repository.

## Project overview

`shinylive` is an R package that exports Shiny for R apps to static sites that
run entirely in the browser through [webR](https://docs.r-wasm.org/webr/latest/).
It does three jobs:

- **Export** (`export()`): copy the Shinylive web assets, the app files (as
  `app.json`), and WebAssembly (Wasm) binaries of the app's R packages into a
  folder that any static web server can host.
- **Assets** (`assets_*()`): download, cache, and manage versions of the
  Shinylive web assets from
  [posit-dev/shinylive](https://github.com/posit-dev/shinylive) releases.
- **Quarto** (`quarto_ext()`): a command-line interface called by the
  [quarto-ext/shinylive](https://github.com/quarto-ext/shinylive) extension. It
  prints JSON to stdout.

Much of the code was ported from
[posit-dev/py-shinylive](https://github.com/posit-dev/py-shinylive), and the
Quarto interface must match it. Commented-out Python in `R/` is left over from
that port.

## Development commands

```r
devtools::load_all()        # load the package
devtools::document()        # rebuild man/ and NAMESPACE from roxygen
devtools::test()            # run tests
devtools::test(filter = "export")
devtools::check()           # R CMD check
```

Format R code with [air](https://posit-dev.github.io/air/) (`air format .`).
CI checks the formatting.

### Tests that need the assets

Most tests download the Shinylive assets (several hundred MB unpacked, cached
after the first time) and are skipped unless the session is interactive or `TEST_ASSETS` is
true. Run them from a shell with:

```sh
TEST_ASSETS=true Rscript -e 'devtools::test()'
```

The skip helper is `skip_if_assets_unavailable()` in
`tests/testthat/setup-skip.R`. Tests that mock everything (for example, most of
`test-packages.R`) run without the assets.

## Code layout

| File | What it holds |
|---|---|
| `R/export.R` | `export()`, the main entry point |
| `R/app_json.R` | Reads app files into `app.json`; writes `index.html` and `edit/index.html` from the export template |
| `R/assets.R` | Download, cache, install, and remove assets; `assets_version()`; webR R version lookup |
| `R/deps.R` | Lists asset files and builds the HTML dependency objects that the Quarto extension uses |
| `R/packages.R` | Finds the app's R package dependencies and downloads their Wasm binaries |
| `R/quarto_ext.R` | `quarto_ext()` command-line interface for the Quarto extension |
| `R/cli.R` | `cli` wrappers that respect the `shinylive.quiet` option |
| `R/utils.R` | Small helpers: argument checks, file copying, `cran_is_testing()` |
| `R/version.R` | `SHINYLIVE_ASSETS_VERSION`, the default assets version |
| `R/release.R` | Extra release checklist bullets for `usethis::use_release_issue()` |

## Conventions

- **Quiet output:** use the wrappers in `R/cli.R` (`cli_alert_info()`,
  `cli_progress_step()`, ...) instead of calling `cli::` directly for progress
  messages. Wrap a function body with `local_quiet(quiet)` to honor a `quiet`
  argument. Warnings and errors still use `cli::cli_warn()` and
  `cli::cli_abort()`.
- **No user cache writes during CRAN tests:** `assets_cache_dir()` stops when
  `cran_is_testing()` is true. Guard any new code that writes to a user cache
  the same way.
- **Environment variables** change defaults: `SHINYLIVE_ASSETS_VERSION`,
  `SHINYLIVE_WASM_PACKAGES`, `SHINYLIVE_DEFAULT_MAX_FILESIZE`, and
  `SHINYLIVE_DOWNLOAD_WASM_CORE_PACKAGES`. Document new ones in the roxygen
  docs of the function they change.
- **NEWS:** add a bullet to `NEWS.md` under the development version for any
  user-facing change.

## Memory Bank

The `memory-bank/` directory holds contributor documentation with YAML
frontmatter (`title`, `description`). **Before exploring the codebase**, invoke
the `memory-bank` skill to find and read the relevant docs. Start with
`memory-bank/architecture.md`; it explains how the pieces fit and which doc
covers each `R/` file. Update or add docs when you learn something future
contributors will need (see the skill for conventions).

## Skills

Task-specific instructions live in `.agents/skills/` (`.claude/skills` is a
symlink to it):

- `memory-bank`: find, read, and update the docs in `memory-bank/`.
- `update-assets-version`: bump `SHINYLIVE_ASSETS_VERSION`.
- `update-actions-tag`: move the `actions-v1` tag after changes to the
  reusable `deploy-app` workflow or `examples/`.

Only allowlisted skills are tracked, so when adding or removing one, update
the `!/.agents/skills/<name>/` lines in `.gitignore` to match.
