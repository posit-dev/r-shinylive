local_quiet <- function(quiet = FALSE, .envir = parent.frame()) {
  withr::local_options(list(shinylive.quiet = quiet), .local_envir = .envir)
}

is_quiet <- function() {
  isTRUE(getOption("shinylive.quiet", FALSE))
}

cli_alert <- function(..., .envir = parent.frame()) {
  if (is_quiet()) return(invisible())
  cli::cli_alert(..., .envir = .envir)
}

cli_alert_info <- function(..., .envir = parent.frame()) {
  if (is_quiet()) return(invisible())
  cli::cli_alert_info(..., .envir = .envir)
}

cli_alert_warning <- function(..., .envir = parent.frame()) {
  if (is_quiet()) return(invisible())
  cli::cli_alert_warning(..., .envir = .envir)
}

cli_alert_success <- function(..., .envir = parent.frame()) {
  if (is_quiet()) return(invisible())
  cli::cli_alert_success(..., .envir = .envir)
}

cli_progress_step <- function(..., .envir = parent.frame()) {
  if (is_quiet()) return(invisible())
  cli::cli_progress_step(..., .envir = .envir)
}

cli_progress_done <- function(..., .envir = parent.frame()) {
  if (is_quiet()) return(invisible())
  cli::cli_progress_done(..., .envir = .envir)
}

cli_text <- function(..., .envir = parent.frame()) {
  if (is_quiet()) return(invisible())
  cli::cli_text(..., .envir = .envir)
}

cli_bullets <- function(..., .envir = parent.frame()) {
  if (is_quiet()) return(invisible())
  cli::cli_bullets(..., .envir = .envir)
}
