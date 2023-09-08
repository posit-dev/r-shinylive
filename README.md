
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

TODO-barret; document

This is a basic example which shows you how to solve a common problem:

``` r
library(shinylive)
## basic example code
```


## Development

### Testing

Works with latest GitHub version of [`posit-dev/shinylive@r-shinylive-support`](https://github.com/posit-dev/shinylive/tree/r-shinylive-support).

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
