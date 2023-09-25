
# shinylive

<!-- badges: start -->
[![R-CMD-check](https://github.com/posit-dev/r-shinylive/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/posit-dev/r-shinylive/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/shinylive)](https://CRAN.R-project.org/package=shinylive)
<!-- badges: end -->

<!-- [py-shinylive Documentation site](https://shiny.rstudio.com/py/docs/shinylive.html) -->


This repository contains an R package for exporting Shiny applications as Shinylive applications.

This repository is not the same as the https://github.com/posit-dev/shinylive repository. That repository is used to generate the Shinylive assets distribution, which is a bundle containing HTML, JavaScript, CSS, and wasm files. The R package in this repository downloads the assets and uses them to create Shinylive applications.

Twin shinylive python package: https://github.com/posit-dev/py-shinylive

## Installation

You can install the development version of shinylive from GitHub via:

``` r
# install.packages("pak")
pak::pak("posit-dev/r-shinylive")
```

## Usage

(Optional) Create a basic shiny application in a new directory `myapp/`:

``` r
# Copy "Hello World" from `{shiny}`
system.file("examples", "01_hello", package="shiny") |>
    fs::dir_copy("myapp", overwrite = TRUE)
```

Once you have a Shiny application in `myapp/` and would like turn it into a Shinylive app in `site/`:

```  r
shinylive::export("myapp", "site")
```

Then you can preview the application by running a web server and visiting it in a browser (this example is using the development version of `{httpuv}`):

``` r
## Get development version of `{httpuv}`
# install.packages("pak")
# pak::pak("rstudio/httpuv")
httpuv::runStaticServer("site/")
```

At this point, you can deploy the `site/` directory to any static web hosting service.


### Multiple applications

If you have multiple applications that you want to put on the same site, you can export them to subdirectories of the site, so that they can all share the same Shinylive assets. You can do this with the `--subdir` option:

``` r
shinylive::export("myapp1", "site", subdir = "app1")
shinylive::export("myapp2", "site", subdir = "app2")
```

## R package availaility

To tell `{webr}` that you need to use a package outside of `{shiny}` and its dependencies, call `webr::install("CRAN_PKG")`. Once the package has been installed by `{webr}`, you can use `library(CRAN_PKG)` or `require(CRAN_PKG)` as you desire.

```` markdown
<!-- file: shinylive_example.qmd -->

# Shinylive example chunk that uses `{plotly}` and `{DT}`

```{shinylive-r}
#| standalone: true
#| components: [editor, viewer]

# Install {plotly} and {DT} via {webr}
webr::install("plotly")
webr::install("DT")

# Use plotly, DT, and shiny like normal
library("shiny")
library("plotly")
library("DT")

## INSERT `ui` and `server` CODE HERE ##
ui <- ....
server <- ....

shinyApp(ui, server)
```
````

If a package has trouble loading, visit https://repo.r-wasm.org/ to see if it is able to be installed as a precompiled WebAssembly binary.

> [Note from `{webr}`](https://docs.r-wasm.org/webr/latest/packages.html#building-r-packages-for-webr):<br />
> It is not possible to install packages from source in webR. This is not likely to change in the near future, as such a process would require an entire C and Fortran compiler toolchain to run inside the browser. For the moment, providing pre-compiled WebAssembly binaries is the only supported way to install R packages in webR.


## Shinylive asset management

Each version of the Shinylive R package is associated with a particular version of the Shinylive web assets. ([See the releases here](https://github.com/posit-dev/shinylive/releases).)

To see which version of this R package you have, and which version of the web assets it is associated with, simply run `shinylive::assets_info()` in your R session. It will also show which asset versions you have already installed locally:

``` r
shinylive::assets_info()
#> shinylive R package version:  0.0.1
#> shinylive web assets version: 0.1.7
#>
#> Local cached shinylive asset dir:
#>     /Users/username/Library/Caches/shinylive
#>
#> Installed assets:
#>     /Users/username/Library/Caches/shinylive/0.1.7
#>     /Users/username/Library/Caches/shinylive/0.1.6
```

The web assets will be downloaded and cached the first time you run `shinylive::export()`. Or, you can run `shinylive::assets_download()` to fetch them manually.

``` r
shinylive::assets_download("0.1.5")
#> Downloading shinylive v0.1.5...
#> Unzipping to /Users/username/Library/Caches/shinylive/
```

You can remove old versions with `shinylive::assets_cleanup()`. This will remove all versions except the one that the Python package wants to use:

``` r
shinylive::assets_cleanup()
#> Keeping version 0.1.7
#> Removing /Users/username/Library/Caches/shinylive/0.1.6
#> Removing /Users/username/Library/Caches/shinylive/0.1.5
```

To remove a specific version, use `shinylive::assets_remove()`:

``` r
shinylive::assets_remove("0.1.5")
#> Removing /Users/username/Library/Caches/shinylive/0.1.5
```

## Known limitations

* A single quarto document can have both `shinylive-python` and `shinylive-r` code blocks, but `shinylive-r` code block must come first.
  * Details: Only the first shinylive code block will be initialized. Currently `posit-dev/shinylive-py` does not know about `shinylive-r` code blocks.
  * Details: This should be (naturally) fixed in the next release of `posit-dev/shinylive-py`.
* The current R common files contain files for python's pyodide and pyright when used within the quarto extension.
  * Details: If only R files are used, these python files should be removed for smaller bundles / faster loading.
  * Details: Currently, the extension does not know if there are more chunks with python code, so `r-shinylive` includes the `py-shinylive` asset files by default.
* [Note from `{webr}`](https://docs.r-wasm.org/webr/latest/packages.html#building-r-packages-for-webr):
    * > It is not possible to install packages from source in webR. This is not likely to change in the near future, as such a process would require an entire C and Fortran compiler toolchain to run inside the browser. For the moment, providing pre-compiled WebAssembly binaries is the only supported way to install R packages in webR.


## Development

### Setup - shinylive assets

Works with latest GitHub version of [`posit-dev/shinylive`](https://github.com/posit-dev/shinylive/) (>= v`0.2.0`).

Before linking the shinylive assets to the asset cache folder, you must first build the shiny live assets:

```bash
## In your shinylive assets repo
# cd PATH/TO/posit-dev/shinylive

# Generate the shiny live assets
make submodules all
```

Then link the assets (using the `{shinylive}` R package) to the asset cache folder so that changes to the assets are automatically in your cached shinylive assets:

```r
# Link to your local shinylive repo
shinylive::assets_install_link("PATH/TO/posit-dev/shinylive")
```

### Setup - quarto

In your quarto project, call the following lines in the terminal to install the updated shinylive quarto extension:

```bash
# Go to the quarto project directory
cd local/quarto

# Install the updated shinylive quarto extension
quarto add quarto-ext/shinylive
```

By default, the extension will used the installed `{shinylive}` R package. To use the local `{shinylive}` R package, run the following in your R session to update the quarto extension locally:

```R
if (!require("pkgload")) install.packages("pkgload")

shinylive_lua <- file.path("local", "quarto", "_extensions", "quarto-ext", "shinylive", "shinylive.lua")
shinylive_lua |>
    brio::read_file() |>
    sub(
        pattern = "shinylive::quarto_ext()",
        replacement = "pkgload::load_all('../../', quiet = TRUE); shinylive::quarto_ext()",
        fixed = TRUE
    ) |>
    brio::write_file(shinylive_lua)
```

### Execute - `export()`

Export a local app to a directory and run it:

```r
pkgload::load_all()
# Delete prior
unlink("local/shiny-apps-out/")
export("local/shiny-apps/simple-r", "local/shiny-apps-out")
#> Run the following in an R session to serve the app:
#>   httpuv::runStaticServer("local/shiny-apps-out")

# Host the local directory
httpuv::runStaticServer("local/shiny-apps-out")
```
