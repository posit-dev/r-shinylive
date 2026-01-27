# Quarto extension for shinylive

Integration with https://github.com/quarto-ext/shinylive

## Usage

``` r
quarto_ext(
  args = commandArgs(trailingOnly = TRUE),
  ...,
  pretty = is_interactive(),
  con = "stdin"
)
```

## Arguments

- args:

  Command line arguments passed by the extension. See details for more
  information.

- ...:

  Ignored.

- pretty:

  Whether to pretty print the JSON output.

- con:

  File from which to take input. Default: `"stdin"`.

## Value

Nothing. Values are printed to stdout.

## Command arguments

The first argument must be `"extension"`. This is done to match
`py-shinylive` so that it can nest other sub-commands under the
`extension` argument to minimize the api clutter the user can see.

### CLI Interface

- `extension info`

  - Prints information about the extension including:

    - `version`: The version of the R package

    - `assets_version`: The version of the web assets

    - `scripts`: A list of paths scripts that are used by the extension,
      mainly `codeblock-to-json`

  - Example

        {
          "version": "0.1.0",
          "assets_version": "0.2.0",
          "scripts": {
            "codeblock-to-json": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/scripts/codeblock-to-json.js"
          }
        }

- `extension base-htmldeps`

  - Prints the language agnostic quarto html dependencies as a JSON
    array.

    - The first html dependency is the `shinylive` service workers.

    - The second html dependency is the `shinylive` base dependencies.
      This dependency will contain the core `shinylive` asset scripts
      (JS files automatically sourced), stylesheets (CSS files that are
      automatically included), and resources (additional files that the
      JS and CSS files can source).

  - Example

        [
          {
            "name": "shinylive-serviceworker",
            "version": "0.2.0",
            "meta": { "shinylive:serviceworker_dir": "." },
            "serviceworkers": [
              {
                "source": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive-sw.js",
                "destination": "/shinylive-sw.js"
              }
            ]
          },
          {
            "name": "shinylive",
            "version": "0.2.0",
            "scripts": [{
              "name": "shinylive/load-shinylive-sw.js",
              "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/load-shinylive-sw.js",
                "attribs": { "type": "module" }
            }],
            "stylesheets": [{
              "name": "shinylive/shinylive.css",
              "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/shinylive.css"
            }],
            "resources": [
              {
                "name": "shinylive/shinylive.js",
                "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/shinylive.js"
              },
              ... # [ truncated ]
            ]
          }
        ]

- `extension language-resources`

  - Prints the language-specific resource files as JSON that should be
    added to the quarto html dependency.

    - For r-shinylive, this includes the webr resource files

    - For py-shinylive, this includes the pyodide and pyright resource
      files.

  - Example

        [
          {
            "name": "shinylive/webr/esbuild.d.ts",
            "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/webr/esbuild.d.ts"
          },
          {
            "name": "shinylive/webr/libRblas.so",
            "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/webr/libRblas.so"
          },
          ... # [ truncated ]
        ]

- `extension app-resources`

  - Prints app-specific resource files as JSON that should be added to
    the `"shinylive"` quarto html dependency.

  - Currently, r-shinylive does not return any resource files.

  - Example

        [
          {
            "name": "shinylive/pyodide/anyio-3.7.0-py3-none-any.whl",
            "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/pyodide/anyio-3.7.0-py3-none-any.whl"
          },
          {
            "name": "shinylive/pyodide/appdirs-1.4.4-py2.py3-none-any.whl",
            "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/pyodide/appdirs-1.4.4-py2.py3-none-any.whl"
          },
          ... # [ truncated ]
        ]
