# Export a Shiny app to a directory

This function exports a Shiny app to a directory, which can then be
served using `httpuv`.

## Usage

``` r
export(
  appdir,
  destdir,
  ...,
  subdir = "",
  quiet = getOption("shinylive.quiet", !is_interactive()),
  wasm_packages = NULL,
  package_cache = TRUE,
  max_filesize = NULL,
  assets_version = NULL,
  template_dir = NULL,
  template_params = list(),
  verbose = deprecated()
)
```

## Arguments

- appdir:

  Directory containing the application.

- destdir:

  Destination directory.

- ...:

  Ignored

- subdir:

  Subdirectory of `destdir` to write the app to.

- quiet:

  Suppress console output during export. Follows the global
  `shinylive.quiet` option or defaults to `FALSE` in interactive
  sessions if not set.

- wasm_packages:

  Download and include binary WebAssembly packages as part of the output
  app's static assets. Logical, defaults to `TRUE`. The default value
  can be changed by setting the environment variable
  `SHINYLIVE_WASM_PACKAGES` to `TRUE` or `1` to enable, `FALSE` or `0`
  to disable.

- package_cache:

  Cache downloaded binary WebAssembly packages. Defaults to `TRUE`.

- max_filesize:

  Maximum file size for bundling of WebAssembly package assets. Parsed
  by [`fs::fs_bytes()`](https://fs.r-lib.org/reference/fs_bytes.html).
  Defaults to `"100M"`. The default value can be changed by setting the
  environment variable `SHINYLIVE_DEFAULT_MAX_FILESIZE`. Set to `Inf`,
  `NA` or `-1` to disable.

- assets_version:

  The version of the Shinylive assets to use in the exported app.
  Defaults to
  [`assets_version()`](https://posit-dev.github.io/r-shinylive/dev/reference/assets.md).
  Note, not all custom assets versions may work with this release of
  shinylive. Please visit the [shinylive asset
  releases](https://github.com/posit-dev/shinylive/releases) website to
  learn more information about the available `assets_version` values.

- template_dir:

  Path to a custom template directory to use when exporting the
  shinylive app. The template can be copied from the shinylive assets
  using: `fs::path(shinylive:::assets_dir(), "export_template")`.

- template_params:

  A list of parameters to pass to the template. The supported parameters
  depends on the template being used. Custom templates may support
  additional parameters (see `template_dir` for instructions on creating
  a custom template or to find the current shinylive assets' templates).

  With shinylive assets \> 0.4.1, the default export template supports
  the following parameters:

  1.  `title`: The title of the app. Defaults to `"Shiny app"`.

  2.  `include_in_head`, `include_before_body`, `include_after_body`:
      Raw HTML to be included in the `<head>`, just after the opening
      `<body>`, or just before the closing `</body>` tag, respectively.

- verbose:

  **\[deprecated\]** Use `quiet` instead.

## Value

Nothing. The app is exported to `destdir`. Instructions for serving the
directory are printed to stdout.

## Examples

``` r
if (FALSE) { # rlang::is_interactive()
app_dir <- system.file("examples", "01_hello", package = "shiny")
out_dir <- tempfile("shinylive-export")

# Export the app to a directory
export(app_dir, out_dir)

# Serve the exported directory
if (require(httpuv)) {
  httpuv::runStaticServer(out_dir)
}
}
```
