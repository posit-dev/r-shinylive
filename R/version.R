# The Shinylive assets series used by default. Patch releases in this series
# are picked up without a package release. Bump for a new minor series, along
# with the `version` defaults of `export()`, `assets_download()`, and
# `assets_ensure()` (a test checks they match).
SHINYLIVE_ASSETS_VERSION_DEFAULT <- "0.10.*"
# A known-good version in the default series, tested at package release. Used
# when no matching version is known.
SHINYLIVE_ASSETS_VERSION_FALLBACK <- "0.10.16"
SHINYLIVE_R_VERSION <- as.character(utils::packageVersion("shinylive"))
