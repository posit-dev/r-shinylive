# shinylive 0.2.0

* shinylive now uses [shinylive web assets v0.5.0](https://github.com/posit-dev/shinylive/releases/tag/v0.5.0) by default, which bundles webR 0.4.0 with R 4.4.1. This update brings improved keyboard shortcuts for R users in the Shinylive editor, the ability to export a custom library of R packages with the exported app, and a few improvements to the Quarto integration. (#108)

* `export()` gains an `assets_version` argument to choose the version of the Shinylive web assets to be used with the exported app. This is primarily useful for testing new versions of the Shinylive assets before they're officially released via a package update. In CI and other automated workflow settings, the `SHINYLIVE_ASSETS_VERSION` environment variable can be used to set the assets version. (#91)

* `export()` gains `template_params` and `template_dir` arguments to control the template HTML files used in the export, allowing users to partially or completely customize the exported HTML. The export template is provided by the shinylive assets and may change from release-to-release. Use `assets_info()` to locate installed shinylive assets; the template files for a given release are in the `export_template` directory of the release. (#96)
    * `template_params` takes a list of parameters to be interpolated into the template. The default template include `title` (the title for the page with the exported app), `include_in_head` (HTML added to the `<head>` of the page), and `include_before_body` (HTML added just after `<body>`) and `include_after_body` (HTML added just after `</body>`).
    * `template_dir` is the directory containing the template files. The default is the `export_template` directory of the shinylive assets being used for the export. Use `assets_info()` to locate installed shinylive assets where you can find the default template files.

* shinylive now uses `{cli}` for console printing. Console output can be suppressed via the global R option by calling `options(shinylive.quiet = TRUE)`. (#104)

* `export()` and `assets_info()` gain a `quiet` argument. In `export()`, `quiet` replaces the now-deprecated `verbose` option, which continues to work with a warning. (#104)

# shinylive 0.1.1

* Bump shinylive assets dependency to 0.2.3. (#38)
* Use `{httpuv}` to serve static folder instead of plumber. (#40)
* Use `{httr2}` to download assets from GitHub releases. (@dgkf #30, #39)

# shinylive 0.1.0

* Initial CRAN submission.
