# Manage shinylive assets

Helper methods for managing shinylive assets.

## Usage

``` r
assets_download(
  version = assets_version(),
  ...,
  dir = assets_cache_dir(),
  url = assets_bundle_url(version)
)

assets_ensure(
  version = assets_version(),
  ...,
  dir = assets_cache_dir(),
  url = assets_bundle_url(version)
)

assets_cleanup(..., dir = assets_cache_dir())

assets_remove(versions, ..., dir = assets_cache_dir())

assets_info(quiet = FALSE)

assets_version()
```

## Arguments

- version:

  The version of the assets to download.

- ...:

  Ignored.

- dir:

  The asset cache directory. Unless testing, the default behavior should
  be used.

- url:

  The URL to download the assets from. Unless testing, the default
  behavior should be used.

- versions:

  The assets versions to remove.

- quiet:

  In `assets_info()`, if `quiet = TRUE`, the function will not print the
  assets information to the console.

## Value

`assets_version()` returns the version of the currently supported
Shinylive.

All other methods return
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
  except for the one used by the current version of shinylive.

- `assets_remove()`: Removes a local copies of shinylive web assets.

- `assets_info()`: Prints information about the local shinylive assets
  that have been installed. Invisibly returns a table of installed asset
  versions and their associated paths.

- `assets_version()`: Returns the version of the currently supported
  Shinylive assets version. If the `SHINYLIVE_ASSETS_VERSION`
  environment variable is set, that value will be used.
