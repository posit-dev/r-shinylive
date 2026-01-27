# Install shinylive assets from from a local directory

Helper methods for testing updates to shinylive assets.

## Usage

``` r
assets_install_copy(
  assets_repo_dir,
  ...,
  dir = assets_cache_dir(),
  version = package_json_version(assets_repo_dir)
)

assets_install_link(
  assets_repo_dir,
  ...,
  dir = assets_cache_dir(),
  version = package_json_version(assets_repo_dir)
)
```

## Arguments

- assets_repo_dir:

  The local repository directory for shinylive assets (e.g.
  [`posit-dev/shinylive`](https://github.com/posit-dev/py-shinylive))

- ...:

  Ignored.

- dir:

  The asset cache directory. Unless testing, the default behavior should
  be used.

- version:

  The version of the assets being installed.

## Value

All method return
[`invisible()`](https://rdrr.io/r/base/invisible.html).

## Functions

- `assets_install_copy()`: Copies all shinylive assets from a local
  shinylive repository (e.g.
  [`posit-dev/shinylive`](https://github.com/posit-dev/py-shinylive)).
  This must be repeated for any change in the assets.

- `assets_install_link()`: Creates a symlink of the local shinylive
  assets to the cached assets directory. After the first installation,
  the assets will the same as the source due to the symlink.

## See also

[`assets_download()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md),
[`assets_ensure()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md),
[`assets_cleanup()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md)
