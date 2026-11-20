---
name: update-assets-version
description: Update the default shinylive web assets version used by the R package. Use when a new posit-dev/shinylive release is out, or when asked to bump, update or change `SHINYLIVE_ASSETS_VERSION`.
---

# Update the shinylive assets version

## Steps

1. **Find the new version and what it bundles.** Read the release notes:

   ```sh
   gh release view v<VERSION> -R posit-dev/shinylive
   ```

   Note the Shiny for Python version and the webR version it bundles. If a version was released but not deployed to shinylive.io, skip it and say so in the PR description.

2. **`R/version.R`:** set `SHINYLIVE_ASSETS_VERSION <- "<VERSION>"`. `export()` reads the webR R version from the assets. If the webR version changes the R version, update the expected R version in the "default assets use the expected webR R version" test in `tests/testthat/test-assets.R`.

3. **`NEWS.md`:** under the development version, keep a single bullet for the assets update. Replace the old version in it instead of adding a new bullet:

   ```md
   * Updated the default shinylive assets to
     [v<VERSION>](https://github.com/posit-dev/shinylive/releases/tag/v<VERSION>),
     which bundles Shiny for Python
     [v<PY_SHINY>](https://github.com/posit-dev/py-shiny/releases/tag/v<PY_SHINY>). The
     bundled webR is unchanged at
     [v<WEBR>](https://github.com/r-wasm/webr/releases/tag/v<WEBR>).
   ```

   If webR changed, say what it changed from and to.

4. **Update examples that name the old version.** The `assets-version` examples in `README.md` and `examples/deploy-app.yaml` show a version. Find every place:

   ```sh
   git grep -n "<OLD_VERSION>" -- ':!NEWS.md'
   ```

5. **Open the PR** with the title `chore: Update shinylive assets to v<VERSION>`.

## The deploy-app workflow

`.github/workflows/deploy-app.yaml` does not name an assets version. Its `assets-version` input defaults to `""`, which uses the installed package's `SHINYLIVE_ASSETS_VERSION`. No workflow change or `actions-v1` tag move is needed for an assets update: callers that install from GitHub get the new assets once it merges, and callers that install from CRAN get them with the next CRAN release.
