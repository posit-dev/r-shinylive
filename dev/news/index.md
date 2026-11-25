# Changelog

## shinylive (development version)

### New features

- Shinylive web assets are no longer pinned to one version per package
  release, so new assets releases no longer need a new version of
  shinylive. By default, the newest release in the `0.10.*` series is
  used. GitHub is checked for new releases at most once a day (once an
  hour after a failed check), and the result is saved in `versions.json`
  in the assets cache folder once the chosen version is downloaded. If
  that download fails, the saved list leaves out the newer matching
  releases, so later Quarto commands (and py-shinylive, which shares the
  file) keep using the downloaded version for the whole render
  ([\#223](https://github.com/posit-dev/r-shinylive/issues/223)). The
  Quarto `info` command now downloads the assets it reports. Offline,
  the newest downloaded matching version is used. A new series, like
  `0.11.*`, is only used by default after a shinylive update.

  `export(assets_version=)`, `assets_download(version=)`,
  `assets_ensure(version=)`, and the `SHINYLIVE_ASSETS_VERSION`
  environment variable now accept an exact version (`"0.10.16"`), a
  series (`"0.11.*"`), or `"latest"` (check GitHub once per R session).
  Pin an exact version for builds that must repeat exactly, such as in
  CI.

  Because of this,
  [`assets_version()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md)
  can return different values over time and may use the network or
  download assets.
  [`assets_cleanup()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md)
  gains a `keep` argument (exact versions and series). By default it
  keeps the newest downloaded version of the default series and of
  `SHINYLIVE_ASSETS_VERSION`. It also removes temp files left by
  interrupted downloads.
  [`assets_info()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md)
  shows the default series and the last check. An empty
  `SHINYLIVE_ASSETS_VERSION` is now treated as unset.

### Bug fixes and minor improvements

- Shinylive assets fixes, to match py-shinylive
  ([\#225](https://github.com/posit-dev/r-shinylive/issues/225)):

  - `assets_ensure(url=)` and `assets_download(url=)`, such as for a
    mirror, no longer contact GitHub. The version comes from
    `versions.json` and the downloaded assets, and the tarball is
    downloaded from `url`. For a series or `"latest"`, the tarball may
    hold any matching version.
  - A download that gets no data for 60 seconds now fails instead of
    hanging.
  - A bad `SHINYLIVE_ASSETS_VERSION` gives an error that names the
    environment variable, also in
    [`assets_cleanup()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md).
  - When the fallback download also fails, the error says why.
  - The warning after a failed GitHub check says when the check failed
    and when GitHub is checked again.

- [`export()`](https://posit-dev.github.io/r-shinylive/dev/reference/export.md)
  and the Quarto extension now pick WebAssembly package binaries for the
  R version of the webR in the Shinylive assets being used. Before, they
  always used the R version of the package’s default assets, so a
  different `assets_version` could bundle binaries that webR can’t load.
  Cached binaries from another R version are now deleted and downloaded
  again ([\#209](https://github.com/posit-dev/r-shinylive/issues/209)).

- [`export()`](https://posit-dev.github.io/r-shinylive/dev/reference/export.md)
  fixes ([\#216](https://github.com/posit-dev/r-shinylive/issues/216)):

  - Exporting into the app folder (`export(".", ".")`) or into a folder
    that holds the app (`export("myapp", ".")`) is now an error instead
    of giving an empty `app.json`. Keep the app and the export in
    separate folders, like `export("myapp", "site")`.
  - An app folder named `venv` or `rsconnect`, and a mix of relative and
    absolute paths, no longer give an empty or wrong `app.json`. Paths
    are compared without case on Windows and macOS.
  - `subdir` can no longer point outside `destdir`, and `subdir = "."`
    is the same as no subdir.
  - App text files that are not valid UTF-8 are stored as binary, so
    `app.json` stays valid JSON.
  - Re-exporting with a custom template that has non-HTML files works.
  - The message about differing asset copies respects `quiet = TRUE`.
  - `max_filesize` (and `SHINYLIVE_DEFAULT_MAX_FILESIZE`) accept
    `"Inf"`, `"NA"`, and `"-1"` to turn the limit off. Values that can’t
    be parsed, like `""`, now warn and use the default instead of
    turning the limit off.
  - A package left out for being larger than `max_filesize` is
    downloaded again once the limit allows its size, and the warning
    shows on every export while it is left out. A cached package larger
    than a new, smaller limit is now left out too (or is an error when
    the limit is set).

- Assets fixes
  ([\#216](https://github.com/posit-dev/r-shinylive/issues/216)):
  `assets_ensure(dir=)` and `assets_dir(dir=)` use `dir` instead of the
  default cache,
  [`assets_info()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md)
  works when no assets are installed, stray `shinylive-*` files or
  folders in the cache no longer break
  [`assets_info()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md)
  and
  [`assets_cleanup()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md),
  and
  [`assets_ensure()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md)
  shows the cache folder it creates.

- The Quarto extension’s `app-resources` command checks app file paths
  by their parts (so `..foo.R` is allowed and `C:/x.R` or `~/x.R` are
  not) and errors on binary files that can’t be decoded instead of
  skipping them
  ([\#216](https://github.com/posit-dev/r-shinylive/issues/216)).

- Updated the default shinylive assets to
  [v0.10.16](https://github.com/posit-dev/shinylive/releases/tag/v0.10.16),
  which bundles Shiny for Python
  [v1.9.0](https://github.com/posit-dev/py-shiny/releases/tag/v1.9.0).
  The bundled webR is unchanged at
  [v0.6.0](https://github.com/r-wasm/webr/releases/tag/v0.6.0).

- [`export()`](https://posit-dev.github.io/r-shinylive/dev/reference/export.md)
  no longer downloads the CRAN package `webr` when an app calls the
  `webr` package built into webR, such as `webr::install()`. The CRAN
  package shares the name but is unrelated, and it pulled in many other
  packages, which made the exported app much slower to load. The CRAN
  package could never be loaded in Shinylive anyway, since webR loads
  its own `webr` package first. If your app needs functions from the
  CRAN `webr` package, copy them into your app’s code
  ([\#206](https://github.com/posit-dev/r-shinylive/issues/206)).

## shinylive 0.5.0

CRAN release: 2026-06-08

### Bug fixes and minor improvements

- Updated the default shinylive assets to
  [v0.10.12](https://github.com/posit-dev/shinylive/releases/tag/v0.10.12),
  which upgrades the bundled webR to
  [v0.6.0](https://github.com/r-wasm/webr/releases/tag/v0.6.0)
  ([\#193](https://github.com/posit-dev/r-shinylive/issues/193),
  [\#195](https://github.com/posit-dev/r-shinylive/issues/195)).

- WebAssembly package binaries cached during
  [`export()`](https://posit-dev.github.io/r-shinylive/dev/reference/export.md)
  are now replaced once the WebAssembly repository catches up to the
  locally installed version. Previously, a binary downloaded while the
  repository lagged behind was never refreshed
  ([\#194](https://github.com/posit-dev/r-shinylive/issues/194)).

## shinylive 0.4.1

CRAN release: 2026-04-07

### Bug fixes

- Fixed CRAN policy violation where tests could create the shinylive
  assets cache directory (`~/.cache/shinylive` or
  `~/Library/Caches/shinylive` on macOS). Tests that interact with the
  cache are now skipped on CRAN, and `assets_cache_dir()` includes a
  runtime guard that errors if called during CRAN testing
  ([\#185](https://github.com/posit-dev/r-shinylive/issues/185),
  [\#186](https://github.com/posit-dev/r-shinylive/issues/186)).

## shinylive 0.4.0

CRAN release: 2026-03-31

### Lifecycle changes

- `export(verbose=)` now signals its deprecation warning using
  [`lifecycle::deprecate_warn()`](https://lifecycle.r-lib.org/reference/deprecate_soft.html).
  `verbose` was soft-deprecated in shinylive 0.2.0 in favor of `quiet`
  ([\#182](https://github.com/posit-dev/r-shinylive/issues/182)).

### New features

- [`export()`](https://posit-dev.github.io/r-shinylive/dev/reference/export.md)
  now displays [cli](https://cli.r-lib.org) progress bars when
  downloading WebAssembly packages
  ([\#169](https://github.com/posit-dev/r-shinylive/issues/169)).

### Bug fixes and minor improvements

- Updated default shinylive assets to
  [v0.10.8](https://github.com/posit-dev/shinylive/releases/tag/v0.10.8)
  ([\#165](https://github.com/posit-dev/r-shinylive/issues/165),
  [\#166](https://github.com/posit-dev/r-shinylive/issues/166),
  [\#177](https://github.com/posit-dev/r-shinylive/issues/177)).

- [`export()`](https://posit-dev.github.io/r-shinylive/dev/reference/export.md)
  no longer produces an encoding error when exporting certain apps
  ([\#118](https://github.com/posit-dev/r-shinylive/issues/118),
  [\#172](https://github.com/posit-dev/r-shinylive/issues/172)), now
  uses HTTPS when downloading WebAssembly packages
  ([\#171](https://github.com/posit-dev/r-shinylive/issues/171)), and no
  longer warns when an app has zero package dependencies
  ([\#172](https://github.com/posit-dev/r-shinylive/issues/172)).

## shinylive 0.3.0

CRAN release: 2024-11-12

- Updated default shinylive assets to
  [v0.9.1](https://github.com/posit-dev/shinylive/releases/tag/v0.9.1).
  ([\#120](https://github.com/posit-dev/r-shinylive/issues/120),
  [\#129](https://github.com/posit-dev/r-shinylive/issues/129),
  [\#135](https://github.com/posit-dev/r-shinylive/issues/135))

- Resources are now built relative to Quarto project root.
  ([\#130](https://github.com/posit-dev/r-shinylive/issues/130))

- In CI and other automated workflow settings the
  `SHINYLIVE_WASM_PACKAGES` environment variable can now be used to
  control whether WebAssembly R package binaries are bundled with the
  exported shinylive app, in addition to the `wasm_packages` argument of
  the
  [`export()`](https://posit-dev.github.io/r-shinylive/dev/reference/export.md)
  function.
  ([\#116](https://github.com/posit-dev/r-shinylive/issues/116))

- shinylive now avoids bundling WebAssembly R package dependencies
  listed only in the `LinkingTo` section of required packages. With this
  change dependencies that are only required at build time are no longer
  included as part of the exported WebAssembly asset bundle. This
  reduces the total static asset size and improves the loading time of
  affected shinylive apps.
  ([\#115](https://github.com/posit-dev/r-shinylive/issues/115))

- shinylive now supports adding files in virtual subdirectories in
  `shinylive-r` apps embedded in Quarto documents. For example,
  `## file: R/load_data.R` in a `shinylive-r` chunk followed by the
  `load_data.R` code will create a file `load_data.R` in the `R`
  subdirectory of the exported app.
  ([\#119](https://github.com/posit-dev/r-shinylive/issues/119))

## shinylive 0.2.0

CRAN release: 2024-07-19

- shinylive now uses [shinylive web assets
  v0.5.0](https://github.com/posit-dev/shinylive/releases/tag/v0.5.0) by
  default, which bundles webR 0.4.0 with R 4.4.1. This update brings
  improved keyboard shortcuts for R users in the Shinylive editor, the
  ability to export a custom library of R packages with the exported
  app, and a few improvements to the Quarto integration.
  ([\#108](https://github.com/posit-dev/r-shinylive/issues/108))

- [`export()`](https://posit-dev.github.io/r-shinylive/dev/reference/export.md)
  gains an `assets_version` argument to choose the version of the
  Shinylive web assets to be used with the exported app. This is
  primarily useful for testing new versions of the Shinylive assets
  before they’re officially released via a package update. In CI and
  other automated workflow settings, the `SHINYLIVE_ASSETS_VERSION`
  environment variable can be used to set the assets version.
  ([\#91](https://github.com/posit-dev/r-shinylive/issues/91))

- [`export()`](https://posit-dev.github.io/r-shinylive/dev/reference/export.md)
  gains `template_params` and `template_dir` arguments to control the
  template HTML files used in the export, allowing users to partially or
  completely customize the exported HTML. The export template is
  provided by the shinylive assets and may change from
  release-to-release. Use
  [`assets_info()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md)
  to locate installed shinylive assets; the template files for a given
  release are in the `export_template` directory of the release.
  ([\#96](https://github.com/posit-dev/r-shinylive/issues/96))

  - `template_params` takes a list of parameters to be interpolated into
    the template. The default template include `title` (the title for
    the page with the exported app), `include_in_head` (HTML added to
    the `<head>` of the page), and `include_before_body` (HTML added
    just after `<body>`) and `include_after_body` (HTML added just
    before `</body>`).
  - `template_dir` is the directory containing the template files. The
    default is the `export_template` directory of the shinylive assets
    being used for the export. Use
    [`assets_info()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md)
    to locate installed shinylive assets where you can find the default
    template files.

- shinylive now uses [cli](https://cli.r-lib.org) for console printing.
  Console output can be suppressed via the global R option by calling
  `options(shinylive.quiet = TRUE)`.
  ([\#104](https://github.com/posit-dev/r-shinylive/issues/104))

- [`export()`](https://posit-dev.github.io/r-shinylive/dev/reference/export.md)
  and
  [`assets_info()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md)
  gain a `quiet` argument. In
  [`export()`](https://posit-dev.github.io/r-shinylive/dev/reference/export.md),
  `quiet` replaces the now-deprecated `verbose` option, which continues
  to work with a warning.
  ([\#104](https://github.com/posit-dev/r-shinylive/issues/104))

## shinylive 0.1.1

CRAN release: 2023-12-04

- Bump shinylive assets dependency to 0.2.3.
  ([\#38](https://github.com/posit-dev/r-shinylive/issues/38))

- Use [httpuv](https://rstudio.github.io/httpuv/) to serve static folder
  instead of plumber.
  ([\#40](https://github.com/posit-dev/r-shinylive/issues/40))

- Use [httr2](https://httr2.r-lib.org) to download assets from GitHub
  releases. ([@dgkf](https://github.com/dgkf)
  [\#30](https://github.com/posit-dev/r-shinylive/issues/30),
  [\#39](https://github.com/posit-dev/r-shinylive/issues/39))

## shinylive 0.1.0

CRAN release: 2023-10-11

- Initial CRAN submission.
