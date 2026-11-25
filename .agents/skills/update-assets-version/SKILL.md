---
name: update-assets-version
description: Update the Shinylive web assets series or fallback version used by the R package. Use when a new posit-dev/shinylive minor release is out (such as 0.11.0), when the package must require a newer assets patch, or when asked to bump, update or change `SHINYLIVE_ASSETS_VERSION_DEFAULT` or `SHINYLIVE_ASSETS_VERSION_FALLBACK`.
---

# Update the shinylive assets version

The package does not pin one assets version. `SHINYLIVE_ASSETS_VERSION_DEFAULT`
in `R/version.R` is a series, such as `"0.10.*"`, and the newest release in it
is used (see `memory-bank/assets.md`).

**Patch releases (0.10.17, 0.10.18, ...) need no change.** Users get them within
a day.

Change the package only when:

- **A new minor series is out (0.11.0).** It may change the files the package
  reads, so the package opts in with a release.
- **The package needs a newer patch** to work. Raise the fallback.

## Steps

1. **Find the new version and what it bundles.** Read the release notes:

   ```sh
   gh release view v<VERSION> -R posit-dev/shinylive
   ```

   Note the Shiny for Python version and the webR version it bundles.

2. **Test the new assets** with `TEST_ASSETS=1` and
   `SHINYLIVE_ASSETS_VERSION=<VERSION>`. Check that `export()` and the Quarto
   extension still work, since a new series may move files.

3. **`R/version.R`:**
   - New series: set `SHINYLIVE_ASSETS_VERSION_DEFAULT <- "<MAJOR>.<MINOR>.*"`
     and `SHINYLIVE_ASSETS_VERSION_FALLBACK <- "<VERSION>"`.
   - Newer patch required: set only `SHINYLIVE_ASSETS_VERSION_FALLBACK`.

4. **New series only: update the docs.** The roxygen docs of
   `export(assets_version=)`, `assets_download(version=)`, `assets_cleanup()`,
   and `assets_version()` name the series. Update them, then run
   `devtools::document()`. Their defaults are `NULL`, so no formals change.

5. **webR R version.** If webR's R version changed, update the expected R
   version in the "default assets use the expected webR R version" test in
   `tests/testthat/test-assets.R`.

6. **`NEWS.md`:** under the development version, add a bullet:

   ```md
   * The default shinylive assets series is now
     [`<MAJOR>.<MINOR>.*`](https://github.com/posit-dev/shinylive/releases/tag/v<VERSION>),
     which bundles Shiny for Python
     [v<PY_SHINY>](https://github.com/posit-dev/py-shiny/releases/tag/v<PY_SHINY>)
     and webR [v<WEBR>](https://github.com/r-wasm/webr/releases/tag/v<WEBR>).
   ```

7. **Update examples that name the old version.** The `assets-version` examples
   in `README.md` and `examples/deploy-app.yaml` show a version:

   ```sh
   git grep -n "<OLD_VERSION>" -- ':!NEWS.md'
   ```

8. **Open the PR** with the title `feat: Use the shinylive assets <MAJOR>.<MINOR>.* series`
   (or `chore: Require shinylive assets v<VERSION>` for a fallback bump).

## The deploy-app workflow

`.github/workflows/deploy-app.yaml` does not name an assets version. Its
`assets-version` input defaults to `""`, which uses the installed package's
default series. No workflow change or `actions-v1` tag move is needed: callers
get new patch releases without a package release, and a new series with the
next shinylive release.
