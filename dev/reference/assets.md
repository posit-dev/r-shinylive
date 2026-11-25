# Manage shinylive assets

Helper methods for managing shinylive assets.

## Usage

``` r
assets_download(
  version = NULL,
  ...,
  dir = assets_cache_dir(),
  url = assets_bundle_url(version, dir = dir)
)

assets_ensure(
  version = NULL,
  ...,
  dir = assets_cache_dir(),
  url = assets_bundle_url(version, dir = dir)
)

assets_cleanup(..., keep = NULL, dir = assets_cache_dir())

assets_remove(versions, ..., dir = assets_cache_dir())

assets_info(quiet = FALSE)

assets_version()
```

## Arguments

- version:

  The version of the assets: an exact version (`"0.10.16"`), a series
  (`"0.10.*"`), or `"latest"`. See
  [`export()`](https://posit-dev.github.io/r-shinylive/dev/reference/export.md)
  for details. When `NULL` (the default), the `SHINYLIVE_ASSETS_VERSION`
  environment variable is used if set, and otherwise the default series
  of this version of shinylive (`"0.10.*"`).

- ...:

  Ignored.

- dir:

  The asset cache directory. Unless testing, the default behavior should
  be used.

- url:

  The URL to download the assets from. Unless testing, the default
  behavior should be used.

- keep:

  In `assets_cleanup()`, the versions to keep: exact versions
  (`"0.10.16"`) and series (`"0.10.*"`) or `"latest"`. For a series,
  only the newest downloaded match is kept. Defaults to the default
  series of this version of shinylive (`"0.10.*"`), plus the
  `SHINYLIVE_ASSETS_VERSION` environment variable if set.

- versions:

  The assets versions to remove.

- quiet:

  In `assets_info()`, if `quiet = TRUE`, the function will not print the
  assets information to the console.

## Value

`assets_version()` returns the version of the currently supported
Shinylive.

`assets_download()` invisibly returns the cache directory and
`assets_ensure()` invisibly returns the assets directory for `version`.

`assets_cleanup()` and `assets_remove()` return
[`invisible()`](https://rdrr.io/r/base/invisible.html).

## Functions

- `assets_download()`: Downloads the shinylive assets bundle from GitHub
  and extracts it to the specified directory. The bundle will always be
  downloaded from GitHub, even if it already exists in the cache
  directory (`dir=`).

- `assets_ensure()`: Ensures a local copy of shinylive is installed. If
  a local copy of shinylive is not installed, it will be downloaded and
  installed. If a local copy of shinylive is installed, its path will be
  returned.

- `assets_cleanup()`: Removes local copies of shinylive web assets,
  except for those matched by `keep`. Also removes temp files older than
  10 minutes that an interrupted download left in `dir`.

- `assets_remove()`: Removes a local copies of shinylive web assets.

- `assets_info()`: Prints information about the local shinylive assets
  that have been installed. Returns a table of installed asset versions
  and their associated paths, invisibly unless `quiet = TRUE`.

- `assets_version()`: Returns the exact Shinylive assets version to use.
  It is the newest release in the default series (`"0.10.*"`), checked
  on GitHub at most once a day, or the highest downloaded version when
  offline. If the `SHINYLIVE_ASSETS_VERSION` environment variable is
  set, it is used instead (an exact version, a series, or `"latest"`).
  The result is remembered for the R session and may download the
  assets.
