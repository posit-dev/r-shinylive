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
    )
  )
}
