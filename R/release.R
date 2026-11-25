# Extra bullets for the release checklist made by `usethis::use_release_issue()`
release_bullets <- function() {
  c(
    paste0(
      "After CRAN accepts the release, change the `shinylive-version` input ",
      "default in `.github/workflows/deploy-app.yaml` from ",
      "`posit-dev/r-shinylive` to `shinylive`, so the workflow installs the ",
      "CRAN release. Then move the `actions-v1` tag to that commit ",
      "(see `.agents/skills/update-actions-tag/SKILL.md`). Remove this bullet ",
      "afterwards."
    ),
    paste0(
      "After CRAN accepts the release with floating assets versions ",
      "(posit-dev/r-shinylive#218), update the `assets-version` input ",
      "description in `.github/workflows/deploy-app.yaml` and the comment in ",
      "`examples/deploy-app.yaml`: an empty value now uses the newest release ",
      "in the package's series, and a series such as `0.11.*` is accepted. ",
      "Then move the `actions-v1` tag to that commit (see ",
      "`.agents/skills/update-actions-tag/SKILL.md`). Do not move it before ",
      "the release. Remove this bullet afterwards."
    )
  )
}
