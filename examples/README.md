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

Callers of the reusable workflow and `usethis::use_github_action()` both read from the `actions-v1` tag, not from `main`. After a change to `.github/workflows/deploy-app.yaml` or to `examples/` merges to `main`, move the tag to that commit:

```bash
git fetch origin --tags --force
git tag -f actions-v1 <SHA>
git push --force origin actions-v1
```

The tag ships every workflow and example change up to `<SHA>`, so check `git diff actions-v1 <SHA> -- .github/workflows/ examples/` first. See `.agents/skills/update-actions-tag/SKILL.md` for when to move the tag and when not to.
