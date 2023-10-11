## Comments

#### 2023-10-10

Updates:
* Package description length and wording.
* Added single quotes around `'shiny'`
* Added return value for `assets.Rd` and `install.Rd`
* Updated `export.Rd` example to use `if(interactive())`
* The `export.Rd` example writes to a temp folder, the tests are only run on CI, and there are no vignettes. Only temp files are created.

Thank you,
Barret


#### 2023-10-09

Thanks,

Please do not start the description with "This package", package name,
title or similar.

The Description field is intended to be a (one paragraph) description of
what the package does and why it may be useful. Please add more details
about the package functionality and implemented methods in your
Description text.

Please always write package names, software names and API (application
programming interface) names in single quotes in title and description.
e.g: --> 'shiny'
Please note that package names are case sensitive.

Please add \value to .Rd files regarding exported methods and explain
the functions results in the documentation. Please write about the
structure of the output (class) and also what the output means. (If a
function does not return a value, please document that too, e.g.
\value{No return value, called for side effects} or similar)
Missing Rd-tags:
      install.Rd: \value

Functions which are supposed to only run interactively (e.g. shiny)
should be wrapped in if(interactive()). Please replace /dontrun{} with
if(interactive()){} if possible, then users can see that the functions
are not intended for use in scripts / functions that are supposed to run
non interactively.

Please ensure that your functions do not write by default or in your
examples/vignettes/tests in the user's home filespace (including the
package directory and getwd()). This is not allowed by CRAN policies.
Please omit any default path in writing functions. In your
examples/vignettes/tests you can write to tempdir().

Please fix and resubmit.

Best,
Benjamin Altmann

#### 2023-10-06

This is a new package.

Please let me know if I can provide any more information.

Thank you,
Barret


## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Barret Schloerke <barret@posit.co>'

New submission
