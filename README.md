
# shinylive

<!-- badges: start -->
[![R-CMD-check](https://github.com/posit-dev/r-shinylive/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/posit-dev/r-shinylive/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of shinylive is to ... TODO-barret; document

## Installation

You can install the development version of shinylive from GitHub via:

``` r
# install.packages("pak")
pak::pak("posit-dev/r-shinylive")
```

## Example

This is a basic example that will export a shiny app to a directory which can be hosted locally:

``` r
library(shinylive)

app_dir <- system.file("examples", "01_hello", package="shiny")
out_dir <- tempfile("shinylive-export")

# Export the app to a directory
export(app_dir, out_dir)
#> Run the following in an R session to serve the app:
#>   httpuv::runStaticServer(<OUT_DIR>, port=8008)

# Serve the exported directory
httpuv::runStaticServer(out_dir, port=8008)
```


## Development

### Testing

Works with latest GitHub version of [`posit-dev/shinylive`](https://github.com/posit-dev/shinylive/) (>= v`0.1.6.9000`).

```r
shinylive::link_shinylive_local("PATH/TO/posit-dev/shinylive")
```

Export a local app to a dir and run it:

```r
pkgload::load_all()
# Delete prior
unlink("local/shiny-apps-out/")
export("local/shiny-apps/simple-r", "local/shiny-apps-out")
#> Run the following in an R session to serve the app:
#>   httpuv::runStaticServer("local/shiny-apps-out", port=8008)

# Host the local directory
httpuv::runStaticServer("local/shiny-apps-out", port=8008)
```


## TODO-barret

* TODO-barret; document readme
* TODO-barret; test
  * quarto_ext_call(c("base-deps", "--sw-dir", "asdfasfd"))
  * quarto_ext_call(c("package-deps"))
  * quarto_ext_call(c("codeblock-to-json-path"))
* TOOD-barret; Move quarto extensions changes to `quarto-ext/shinylive`
  * Remove pkgload::load_all() call
