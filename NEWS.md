# shinylive (development version)

* `export()` gains an `assets_version` argument to choose the version of the Shinylive web assets to be used with the exported app. This is primarily useful for testing new versions of the Shinylive assets before they're officially released via a package update. In CI and other automated workflow settings, the `SHINYLIVE_ASSETS_VERSION` environment variable can be used to set the assets version. (#91)

# shinylive 0.1.1

* Bump shinylive assets dependency to 0.2.3. (#38)
* Use `{httpuv}` to serve static folder instead of plumber. (#40)
* Use `{httr2}` to download assets from GitHub releases. (@dgkf #30, #39)

# shinylive 0.1.0

* Initial CRAN submission.
