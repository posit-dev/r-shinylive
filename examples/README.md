# Example workflows

Package workflows:

- [`deploy-app`](#deploy-app) - A simple CI workflow to
    check with the release version of R.

## Deploy App

Reusable workflow that will deploy the root Shiny app dir to GitHub pages.

The agreed upon contract is:

- Inspect the root directory for package dependencies
- Install R and the found packages
- Export the Shiny app directory to `./site`
- On push events, deploy the exported app to GitHub Pages

If this contract is not met or could be easily improved for others, please open
a new Issue https://github.com/posit-dev/r-shinylive/ .

To add the workflow to your repository, call `usethis::use_github_action(url="https://github.com/posit-dev/r-shinylive/blob/barret/examples/deploy-app.yaml")`.
