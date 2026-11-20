# Example workflows

Package workflows:

- [`deploy-app`](#deploy-app) - Export a Shiny app with shinylive and deploy
    it to GitHub Pages.

## Deploy App

Reusable workflow that will deploy a Shiny app dir (the repo root by default) to GitHub Pages.

The agreed upon contract is:

- Inspect the app directory (`app-dir`, default: the repo root) for package dependencies
- Install R and the found packages
- Export the Shiny app directory to `./site`
- On the default branch (and on scheduled runs), deploy the exported app to GitHub Pages

If this contract is not met or could be easily improved for others, please open
a new Issue https://github.com/posit-dev/r-shinylive/ .

To add the workflow to your repository, call `usethis::use_github_action(url="https://github.com/posit-dev/r-shinylive/blob/actions-v1/examples/deploy-app.yaml")`.


# Contributing

Callers and `usethis::use_github_action()` read from the `actions-v1` tag, not from `main`. After a change to `.github/workflows/` or `examples/` merges, move the tag. See [`.agents/skills/update-actions-tag/SKILL.md`](../.agents/skills/update-actions-tag/SKILL.md) for when and how.
