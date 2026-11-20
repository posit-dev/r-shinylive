---
name: update-actions-tag
description: Move the `actions-v1` git tag so callers of the reusable deploy-app workflow get the latest version. Use after a PR that changes `.github/workflows/deploy-app.yaml` or `examples/` merges to `main`, after the CRAN release that switches the `shinylive-version` default, or when asked to move, update or force-push `actions-v1`.
---

# Update the `actions-v1` tag

Callers use `posit-dev/r-shinylive/.github/workflows/deploy-app.yaml@actions-v1`. New users copy the example with `usethis::use_github_action(url = ".../blob/actions-v1/examples/deploy-app.yaml")`. Both read from the tag, not from `main`. A change only reaches users after the tag moves.

## When to move it

Move the tag after a PR merges to `main` and it changes:

- `.github/workflows/deploy-app.yaml`: callers run the workflow from the tag.
- `examples/deploy-app.yaml` or `examples/README.md`: new users copy these from the tag.

Also move it after a CRAN release, once the `shinylive-version` input default is changed to `shinylive` (see `release_bullets()` in `R/release.R`).

Do not move it for:

- Assets updates (`R/version.R`). The `assets-version` input defaults to the installed package's assets, so callers get new assets through the package.
- Changes to the R package only. Callers get them through the package they install.

## Steps

1. **Find the target commit (`<SHA>`).** It is usually the head of `origin/main`. It must be on `origin/main`. Never tag a PR branch or an unmerged commit.

   ```sh
   git fetch origin --tags --force
   git log --oneline -1 origin/main
   ```

2. **Check what the move ships.** The tag ships every change up to the target commit, not only the PR you have in mind. List the changes since the current tag:

   ```sh
   git log --oneline actions-v1..<SHA> -- .github/workflows/ examples/
   git diff actions-v1 <SHA> -- .github/workflows/ examples/
   ```

   If a change in that list isn't ready for users, stop and tell the user. Pick an earlier `<SHA>` only if the user asks.

3. **Ask the user before pushing.** Show the current tag commit, the target commit and the list from step 2. A force push changes the next run of every caller.

4. **Move and push the tag.** `git push --tags` does not work here: the remote rejects a moved tag without force, and it also pushes every other local tag.

   ```sh
   git tag -f actions-v1 <SHA>
   git push --force origin actions-v1
   ```

5. **Confirm the move.** The remote tag must match the target commit:

   ```sh
   git ls-remote --tags origin actions-v1
   ```
