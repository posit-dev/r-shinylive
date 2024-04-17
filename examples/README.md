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

To add the workflow to your repository, call `usethis::use_github_action(url="https://github.com/posit-dev/r-shinylive/blob/actions-v1/examples/deploy-app.yaml")`.


# Contributing

If any changes are made to the reusable workflows in `.github/workflows/`, please force update the tag `actions-v1` to the latest appropriate git sha. This will allow users to easily reference the latest version of the workflow.

```bash
git tag -f actions-v1
git push --tags
```

This update is not necessary for changes in `examples/` as these files are copied within each of the user's repositories.
