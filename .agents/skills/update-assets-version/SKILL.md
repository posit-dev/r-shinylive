---
name: update-assets-version
description: Update the default shinylive web assets version used by the R package and the deploy-app GitHub Actions workflow. Use when a new posit-dev/shinylive release is out, or when asked to bump, update or change `SHINYLIVE_ASSETS_VERSION`.
---

# Update the shinylive assets version

The assets version is set in more than one place. Update all of them in the same PR.

## Steps

1. **Find the new version and what it bundles.** Read the release notes:

   ```sh
   gh release view v<VERSION> -R posit-dev/shinylive
   ```

   Note the Shiny for Python version and the webR version it bundles. If a version was released but not deployed to shinylive.io, skip it and say so in the PR description.

2. **`R/version.R`:** set `SHINYLIVE_ASSETS_VERSION <- "<VERSION>"`. If the webR version changes the R version, also update `WEBR_R_VERSION`.

3. **`.github/workflows/deploy-app.yaml`:** set the `default:` of the `assets-version` input to `"<VERSION>"`. `tests/testthat/test-deploy-app.R` fails if this does not match `R/version.R`.

4. **`NEWS.md`:** under the development version, keep a single bullet for the assets update. Replace the old version in it instead of adding a new bullet:

   ```md
   * Updated the default shinylive assets to
     [v<VERSION>](https://github.com/posit-dev/shinylive/releases/tag/v<VERSION>),
     which bundles Shiny for Python
     [v<PY_SHINY>](https://github.com/posit-dev/py-shiny/releases/tag/v<PY_SHINY>). The
     bundled webR is unchanged at
     [v<WEBR>](https://github.com/r-wasm/webr/releases/tag/v<WEBR>).
   ```

   If webR changed, say what it changed from and to.

5. **Check:**

   ```r
   devtools::test(filter = "deploy-app")
   ```

   Then confirm no other file still names the old version:

   ```sh
   git grep -n "<OLD_VERSION>" -- ':!NEWS.md'
   ```

6. **Open the PR** with the title `chore: Update shinylive assets to v<VERSION>`.

7. **After the PR is merged:** the workflow change only reaches users once the `actions-v1` tag points at the merge commit. Ask the maintainer before moving the tag, since it changes every app that uses `@actions-v1`:

   ```sh
   git fetch origin
   git tag -f actions-v1 origin/main
   git push -f origin actions-v1
   ```
