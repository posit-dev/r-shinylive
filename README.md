
# shinylive

<!-- badges: start -->
[![R-CMD-check](https://github.com/posit-dev/r-shinylive/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/posit-dev/r-shinylive/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/shinylive)](https://CRAN.R-project.org/package=shinylive)
<!-- badges: end -->

<!-- [py-shinylive Documentation site](https://shiny.rstudio.com/py/docs/shinylive.html) -->

The goal of the `{shinylive}` R package is to help you create Shinylive applications from your [Shiny for R](https://shiny.posit.co) applications.
Shinylive is a new way to run Shiny entirely in the browser, without any need for a hosted server, using WebAssembly via the [webR](https://docs.r-wasm.org/webr/latest/) project.

## About Shinylive

The Shinylive project consists of four interdependent components that work together in several different contexts.

1. Shinylive ([posit-dev/shinylive](https://github.com/posit-dev/shinylive)) is web assets library that runs Shiny applications in the browser. You can try it out online at [shinylive.io/r](https://shinylive.io/r) or [shinylive.io/py](https://shinylive.io/py). For a more in-depth exploration of the Shinylive web assets, please check out https://www.tidyverse.org/blog/2024/10/shinylive-0-8-0/.

2. The `{shinylive}` R package ([posit-dev/r-shinylive](https://github.com/posit-dev/r-shinylive)) helps you export your Shiny applications from local files to a directory that can be hosted on a static web server. 

   The R package also downloads the Shinylive web assets mentioned above and manages them in a local cache. These assets are included in the exported Shinylive applications and are used to run your Shiny app in the browser.

3. The [shinylive Python package](https://shiny.posit.co/py/docs/shinylive.html) ([posit-dev/py-shinylive](https://github.com/posit-dev/py-shinylive)) serves the same role as `{shinylive}` but for Shiny for Python applications.

4. The [shinylive Quarto extension](https://quarto-ext.github.io/shinylive/) ([quarto-ext/shinylive](https://github.com/quarto-ext/shinylive)) lets you write Shiny applications in [Quarto web documents and slides](https://quarto.org) and uses the R or Python package (or both) to translate `shinylive-r` or `shinylive-py` code blocks into Shinylive applications.


## Installation

You can install the released version of shinylive from CRAN via:

``` r
install.packages("shinylive")
```

You can install the development version of shinylive from GitHub via:

``` r
# install.packages("pak")
pak::pak("posit-dev/r-shinylive")
```

## Usage

To get started, we'll create a basic shiny application in a new directory `myapp/`. If you have an existing Shiny application, you can skip this step and replace `"myapp"` with the path to your existing app.

``` r
# Copy "Hello World" from `{shiny}`
system.file("examples", "01_hello", package="shiny") |>
    fs::dir_copy("myapp", overwrite = TRUE)
```

Once you have a Shiny application in `myapp/` and would like turn it into a Shinylive app in `site/`:

```  r
shinylive::export("myapp", "site")
```

Then you can preview the application by running a web server and visiting it in a browser:

``` r
httpuv::runStaticServer("site/")
```

At this point, you can deploy the `site/` directory to any static web hosting service.


### Multiple applications

If you have multiple applications that you want to put on the same site, you can export them to subdirectories of the site, so that they can all share the same Shinylive assets. You can do this with the `--subdir` option:

``` r
shinylive::export("myapp1", "site", subdir = "app1")
shinylive::export("myapp2", "site", subdir = "app2")
```

### GitHub Pages

`posit-dev/r-shiny` has a workflow to automatically deploy your Shiny app from the root directory in your GitHub repository to its GitHub Pages. You can add this workflow to your repo with help from [usethis](https://usethis.r-lib.org/).

```r
usethis::use_github_action(url="https://github.com/posit-dev/r-shinylive/blob/actions-v1/examples/deploy-app.yaml")
```

For more information, see the [examples folder](https://github.com/posit-dev/r-shinylive/tree/actions-v1/examples).


## R package availability

The `{shinylive}` web assets will statically inspect which packages are being used in your app.

If your app includes a package that is not automatically discovered, you can add an impossible-to-reach code within your Shiny application that has a library call to that R package. For example:

```r
if (FALSE) {
  library(HIDDEN_CRAN_PKG)
}
```

If you'd rather handle it manually, call `webr::install("CRAN_PKG")` in your Shiny application before calling `library(CRAN_PKG)` or `require("CRAN_PKG")`.

If an R package has trouble loading, visit https://repo.r-wasm.org/ to see if it is able to be installed as a precompiled WebAssembly binary.

> [Note from `{webr}`](https://docs.r-wasm.org/webr/latest/packages.html#building-r-packages-for-webr):<br />
> It is not possible to install packages from source in webR. This is not likely to change in the near future, as such a process would require an entire C and Fortran compiler toolchain to run inside the browser. For the moment, providing pre-compiled WebAssembly binaries is the only supported way to install R packages in webR.


## Shinylive asset management

Each version of the Shinylive R package is associated with a particular version of the Shinylive web assets. ([See the releases here](https://github.com/posit-dev/shinylive/releases).)

To see which version of this R package you have, and which version of the web assets it is associated with, simply run `shinylive::assets_info()` in your R session. It will also show which asset versions you have already installed locally:

``` r
shinylive::assets_info()
#> shinylive R package version:  0.1.0
#> shinylive web assets version: 0.2.1
#>
#> Local cached shinylive asset dir:
#>     /Users/username/Library/Caches/shinylive
#>
#> Installed assets:
#>     /Users/username/Library/Caches/shinylive/0.2.1
#>     /Users/username/Library/Caches/shinylive/0.2.0
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
#> Keeping version 0.2.1
#> Removing /Users/username/Library/Caches/shinylive/0.2.0
#> Removing /Users/username/Library/Caches/shinylive/0.1.5
```

To remove a specific version, use `shinylive::assets_remove()`:

``` r
shinylive::assets_remove("0.2.1")
#> Removing /Users/username/Library/Caches/shinylive/0.2.1
```

## Known limitations

* [Note from `{webr}`](https://docs.r-wasm.org/webr/latest/packages.html#building-r-packages-for-webr):
    * > It is not possible to install packages from source in webR. This is not likely to change in the near future, as such a process would require an entire C and Fortran compiler toolchain to run inside the browser. For the moment, providing pre-compiled WebAssembly binaries is the only supported way to install R packages in webR.


## Development

### Setup - shinylive assets

Works with latest GitHub version of [`posit-dev/shinylive`](https://github.com/posit-dev/shinylive/) (>= v`0.2.1`).

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
library(httpuv) # >= 1.6.12
pkgload::load_all()

# Delete prior
unlink("local/shiny-apps-out/", recursive = TRUE)
export("local/shiny-apps/simple-r", "local/shiny-apps-out")

# Host the local directory
httpuv::runStaticServer("local/shiny-apps-out/")
```
