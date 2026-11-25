---
title: "CI, workflows, and repo tooling"
description: "What the GitHub Actions workflows do (R-CMD-check.yaml jobs, the reusable deploy-app.yaml and its test), the actions-v1 tag, examples/, release helpers (release_bullets(), NEWS.md, cran-comments.md, revdep/), air formatting, pkgdown, local/ dev apps, and .Rbuildignore. Read before changing a workflow, releasing, or adding top-level files."
---

# CI, workflows, and repo tooling

## Overview

The repo has three workflows in `.github/workflows/`:

- `R-CMD-check.yaml`: package checks, formatting, the pkgdown site, and an
  integration test with Quarto and freshly built assets.
- `deploy-app.yaml`: a **reusable** workflow that users call to export their
  Shiny app and deploy it to GitHub Pages. Users call it from the
  `actions-v1` tag, not from `main`.
- `test-deploy-app.yaml`: runs `deploy-app.yaml` on pull requests.

## Key files

| File | What it is |
|---|---|
| `.github/workflows/R-CMD-check.yaml` | Main CI ("Package checks"). |
| `.github/workflows/deploy-app.yaml` | Reusable export-and-deploy workflow. |
| `.github/workflows/test-deploy-app.yaml` | PR test for `deploy-app.yaml`. |
| `.github/deploy-app-test/app.R` | Small app exported by the PR test. |
| `examples/deploy-app.yaml`, `examples/README.md` | Caller example users copy with `usethis::use_github_action()`. |
| `.agents/skills/update-actions-tag/SKILL.md` | How and when to move `actions-v1`. |
| `R/release.R` | `release_bullets()` for `usethis::use_release_issue()`. |
| `NEWS.md`, `cran-comments.md`, `revdep/` | Release notes and CRAN submission files. |
| `air.toml`, `.vscode/` | air formatter config (empty file, so defaults) and editor settings. |
| `_pkgdown.yml` | pkgdown site config. |
| `local/` | Hand-run dev apps and the Quarto test project. |
| `.Rbuildignore` | Files left out of the package tarball. |

## R-CMD-check.yaml

Runs on push to `main` and `rc-**`, on PRs to `main`, and every Monday at
09:00 UTC.

| Job | What it does |
|---|---|
| `website` | `rstudio/shiny-workflows` `website.yaml@v1`: builds and deploys the pkgdown site. |
| `routine` | `routine.yaml@v1` with `format-r-code: true`: formats R code with air, runs `usethis::use_tidy_description()` and `devtools::document()`. On PRs from this repo it pushes any changes back to the PR branch. On pushes and on fork PRs it fails if anything changed. |
| `R-CMD-check` | `R-CMD-check.yaml@v1`: check on several OSes and R versions (release and older). `TEST_ASSETS` is not set, so asset tests skip. |
| `R-CMD-check-test-assets` | See below. |
| `integration` | See below. |

### R-CMD-check-test-assets

Ubuntu only. Sets up R with `needs: check`, reads the assets version
(resolved without downloading) into a step output, and caches
`~/.cache/shinylive` with `actions/cache@v4` under the key
`shinylive-assets-<version>`. Then runs `r-lib/actions/check-r-package@v2`
with `TEST_ASSETS: "TRUE"` and `--as-cran`, and prints `testthat.Rout*` and
`00install.out`.

The job sets `R_USER_CACHE_DIR: ~/.cache`. `assets_cache_dir()` uses
`rappdirs::user_cache_dir("shinylive")`, and rappdirs reads
`R_USER_CACHE_DIR` first (before `XDG_CACHE_HOME` and the OS default). So the
assets go to `~/.cache/shinylive`, the same path that `actions/cache` saves.

### integration

1. Installs Python 3.12, Jupyter, and py-shinylive (`pip install shinylive`),
   and saves `shinylive assets version` as an output.
2. Installs Quarto and runs `quarto add quarto-ext/shinylive` in
   `local/quarto/`.
3. Sets up R with `needs: quarto`.
4. Renders `local/quarto/` with `SHINYLIVE_ASSETS_VERSION` set to the
   py-shinylive assets version, so R and Python use the same assets.
5. Checks out posit-dev/shinylive (default branch) into `./shinylive_assets`
   and runs `make submodules` and `make all`.
6. "Link shinylive assets": reads the version with
   `shinylive:::package_json_version()`, calls `assets_remove()` for it, then
   `assets_install_copy("shinylive_assets")` (a copy, not a link).
7. Uncomments the `print("Calling` debug line in the extension's
   `shinylive.lua`.
8. Runs `testthat::test_local()` with `TEST_ASSETS=TRUE` and
   `SHINYLIVE_ASSETS_VERSION` set to the built version.

So the R tests also run against unreleased assets. A render step for the
built assets is commented out because py-shinylive does not follow
`SHINYLIVE_ASSETS_VERSION`.

## deploy-app.yaml (reusable)

`on: workflow_call` with these inputs:

| Input | Default | Meaning |
|---|---|---|
| `cache-version` | `"1"` | Passed to `setup-r-package`; change it to bust the R package cache. No description. |
| `app-dir` | `"."` | Folder with the app, relative to the repo root. |
| `shinylive-version` | `"posit-dev/r-shinylive"` | pak reference for the shinylive R package. A TODO says to switch to `shinylive` (CRAN) after the next CRAN release. |
| `assets-version` | `""` | Empty passes `NULL` to `export()`, so the installed package picks the version (with the dev package, the newest release in its series; the input description still says "default version" until the release bullet is done); a version or series such as `0.10.*` is passed through; `latest` asks `gh api` for the newest posit-dev/shinylive release. A leading `v` is removed. |

`build` job: checkout, `setup-r-package` with `renv`, the shinylive
reference, and `sessioninfo`; installs the app's packages with
`pak::pak(unique(renv::dependencies(APP_DIR)$Package))`; then
`shinylive::export(APP_DIR, "site", assets_version = ...)`. It uploads the
Pages artifact only on the default branch or on `schedule` events.

`deploy` job: same condition, needs `pages: write` and `id-token: write`, uses
`actions/deploy-pages@v4`. The caller must grant these permissions.

## test-deploy-app.yaml

Runs on PRs that touch the deploy workflows, `.github/deploy-app-test/**`,
`R/**`, `inst/**`, or `DESCRIPTION`. A matrix calls `./.github/workflows/deploy-app.yaml`
with `app-dir: .github/deploy-app-test`:

- "PR package, package assets": `posit-dev/r-shinylive#<PR number>`, empty
  `assets-version`.
- "CRAN package, latest assets": `shinylive`, `latest`.

It runs on PRs only. On `main` the deploy job would replace this repo's
pkgdown site on GitHub Pages.

## actions-v1 tag and examples/

Callers use `posit-dev/r-shinylive/.github/workflows/deploy-app.yaml@actions-v1`.
`usethis::use_github_action(url = ".../blob/actions-v1/examples/deploy-app.yaml")`
copies `examples/deploy-app.yaml`. Changes to `deploy-app.yaml` or
`examples/` reach users only after the tag moves. Follow the
`update-actions-tag` skill: tag a commit on `origin/main`, review
`git diff actions-v1 <SHA> -- .github/workflows/ examples/`, ask the user,
then `git tag -f` and `git push --force origin actions-v1`. Do not move it
for assets bumps or R-only changes.

## Release helpers

- `release_bullets()` in `R/release.R` (internal) adds two checklist items to
  `usethis::use_release_issue()`. Both wait until CRAN accepts the release,
  then end with moving `actions-v1`:
  - Change the `shinylive-version` default in `deploy-app.yaml` to
    `shinylive`.
  - Update the `assets-version` input description in `deploy-app.yaml` and
    the comment in `examples/deploy-app.yaml` for floating assets versions
    ([posit-dev/r-shinylive#218](https://github.com/posit-dev/r-shinylive/issues/218)):
    an empty value uses the newest release in the package's series, and a
    series such as `0.11.*` is accepted.
- `NEWS.md`: `# shinylive (development version)` at the top, then
  `## Bug fixes and minor improvements` (also `## New features`,
  `## Lifecycle changes`, `## Bug fixes` in older releases). Bullets start
  with `*`, wrap at about 80 columns, name functions in backticks, and end
  with the PR as `(#209)`. The `release-update-news` skill polishes them.
- `cran-comments.md`: check results and "No reverse dependencies."
- `revdep/`: output of `revdepcheck` (0 reverse dependencies last run).
  Work folders are in `revdep/.gitignore`.

## DESCRIPTION notes

Version `0.5.0.9000` (dev). `Depends: R (>= 4.0)`. `Suggests` has `httpuv`,
`pkgcache`, `spelling`, `testthat`. `Language: en-US` is used by the
spelling check. `Config/Needs/website: tidyverse/tidytemplate` matches the
`tidytemplate` theme in `_pkgdown.yml`. The `routine` job may reformat this
file with `use_tidy_description()`.

## Formatting and pkgdown

- air: `air.toml` is empty, so air defaults apply. `.vscode/settings.json`
  formats R on save with `Posit.air-vscode`. Run `air format .` before
  pushing; otherwise the `routine` job commits the formatting for you.
- pkgdown: `_pkgdown.yml` sets the URL, `development: mode: auto`, the
  `tidytemplate` Bootstrap 5 template with bslib colors, and
  `trailing_slash_redirect`. There is no reference index, so pkgdown lists
  topics itself.

## local/

Not shipped (`^local$` in `.Rbuildignore`).

- `local/shiny-apps/`: `simple-r` (with `about.txt`), `global-r`
  (`global.R`/`ui.R`/`server.R`), `simple-py`, and repro apps for
  [posit-dev/r-shinylive#28](https://github.com/posit-dev/r-shinylive/issues/28)
  and [posit-dev/r-shinylive#29](https://github.com/posit-dev/r-shinylive/issues/29).
  Export them by hand; `local/shiny-apps-out/` is git-ignored.
- `local/quarto/`: `shinylive.qmd` with one R and one Python app, used by the
  `integration` job. `_extensions/` and rendered output are git-ignored.

## .Rbuildignore

Leaves out dev-only files: `.github`, `examples`, `local`, `revdep`,
`cran-comments.md`, `_pkgdown.yml`, `air.toml`, `.vscode`, `.context`,
`.agents`, `.claude`, `AGENTS.md`, `memory-bank`, `shinylive_assets`, venvs,
and more. A test `R CMD build` confirmed the tarball holds only
`DESCRIPTION`, `LICENSE`, `NAMESPACE`, `NEWS.md`, `README.md`, `R/`, `inst/`,
`man/`, and `tests/`. Add new top-level dev files here.

## Pitfalls

- **Editing `deploy-app.yaml` or `examples/` does nothing for users until
  `actions-v1` moves.** Use the `update-actions-tag` skill.
- **`test-deploy-app.yaml` must stay PR-only**, or it will overwrite the
  pkgdown site on GitHub Pages.
- **The "PR package" matrix entry installs the PR from GitHub**
  (`posit-dev/r-shinylive#<n>`) with pak, not from the checkout. It tests the
  pushed PR head.
- **Escape dots in `.Rbuildignore`.** Patterns are regular expressions, so
  write `^\.venv$`, not `^.venv$` (where `.` means "any character").
- **The test-assets cache key step must not download the assets.** It runs
  before `actions/cache` restores, so it calls
  `shinylive:::resolve_assets_version(..., download = FALSE)` instead of
  `shinylive::assets_version()`, which downloads the version it picks. The key
  still changes when a new patch release in the series comes out, which is
  what we want: the tests then run against the new assets.
- **`R_USER_CACHE_DIR` in the test-assets job sets the assets cache path.**
  rappdirs reads it before anything else. If you change it, change the
  `actions/cache` `path` to match, or the cache will miss.
- **Deploys are not limited to push events.** `app-dir` picks the folder,
  and deploys happen for any event on the default branch (including
  `workflow_dispatch`) plus `schedule`. `examples/README.md` now says this.
- **Spelling fails CI; formatting does not.** `tests/spelling.R` uses
  `error = TRUE`, so a new word must go in `inst/WORDLIST`. air changes on
  PRs from this repo are committed by `routine` instead of failing (fork PRs
  and pushes do fail).
