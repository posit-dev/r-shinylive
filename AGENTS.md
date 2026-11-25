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

See `memory-bank/architecture.md` for how the pieces fit and which file holds
what.

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

## Keep py-shinylive in sync

[posit-dev/py-shinylive](https://github.com/posit-dev/py-shinylive) is the
Python version of this package. The two packages share:

- the `quarto_ext()` commands and the JSON they print, used by
  quarto-ext/shinylive for both `shinylive-r` and `shinylive-python` blocks;
- the assets cache folder, its `shinylive-<version>` folders, and its
  `versions.json` file;
- how the assets version is chosen: the `SHINYLIVE_ASSETS_VERSION`
  environment variable, and exact versions, series (`0.10.*`), and `latest`.

When you add a feature or fix a bug, check whether py-shinylive needs the same
change. Skip this for changes that only apply to R, such as finding the Wasm
binaries of an app's R packages. If py-shinylive needs it:

- Open an issue in posit-dev/py-shinylive that links to your PR and says what
  to change. Or open the py-shinylive PR yourself.
- Link that issue or PR in your PR's description.

Changes to the shared items above must be released in both packages at about
the same time. Otherwise, a Quarto document with both `shinylive-r` and
`shinylive-python` blocks can fail to render.

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
- `update-assets-version`: start a new assets series or raise the fallback version.
- `update-actions-tag`: move the `actions-v1` tag after changes to the
  reusable `deploy-app` workflow or `examples/`.

Only allowlisted skills are tracked, so when adding or removing one, update
the `!/.agents/skills/<name>/` lines in `.gitignore` to match.
