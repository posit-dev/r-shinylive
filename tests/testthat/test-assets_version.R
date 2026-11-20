test_that("parse_assets_version() handles each kind", {
  expect_equal(parse_assets_version("0.10.16")$kind, "exact")
  expect_equal(parse_assets_version("0.10.16")$prefix, c(0L, 10L, 16L))
  expect_equal(parse_assets_version("0.10.*")$kind, "pattern")
  expect_equal(parse_assets_version("0.10.*")$prefix, c(0L, 10L))
  expect_equal(parse_assets_version("0.*")$prefix, 0L)
  expect_equal(parse_assets_version("latest")$kind, "latest")
  expect_equal(parse_assets_version("latest")$prefix, integer(0))
})

test_that("parse_assets_version() rejects invalid input", {
  bad <- c("", "0.10.x", "*", "0.*.1", "0.10.**", "v0.10.16", "latest*")
  for (x in bad) {
    expect_error(parse_assets_version(x), "assets version")
  }
  expect_error(parse_assets_version(c("0.10.16", "0.10.17")), "assets version")
  expect_error(parse_assets_version(NA_character_), "assets version")
  expect_error(parse_assets_version(NULL), "assets version")
})

test_that("assets_version_matches() matches patterns by series", {
  versions <- c("0.9.0", "0.10.1", "0.10.16", "0.11.0", "1.0.0", "dev")
  expect_equal(
    assets_version_matches(versions, parse_assets_version("0.10.*")),
    c(FALSE, TRUE, TRUE, FALSE, FALSE, FALSE)
  )
  expect_equal(
    assets_version_matches(versions, parse_assets_version("0.*")),
    c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE)
  )
  expect_equal(
    assets_version_matches(versions, parse_assets_version("latest")),
    c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE)
  )
  expect_equal(
    assets_version_matches(versions, parse_assets_version("0.10.16")),
    c(FALSE, FALSE, TRUE, FALSE, FALSE, FALSE)
  )
  expect_equal(
    assets_version_matches(character(0), parse_assets_version("0.*")),
    logical(0)
  )
})

test_that("assets_version_matches() does not match a shorter version", {
  # "0.10" has no third part, so it isn't in the "0.10.1.*" series
  expect_false(
    assets_version_matches("0.10", parse_assets_version("0.10.1.*"))
  )
})
