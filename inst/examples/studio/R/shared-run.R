# Running a real mascot call for a view and reporting what happened. Plain R: no Shiny notifications or logs here;
# each view shows the result in its own way.

# Evaluates a call in envir, as an app would run it, and reports the outcome:
# - ok: FALSE when the call failed or the package left the mascot unchanged (class mascot_update_ignored); a
#   warning such as mascot_contrast or mascot_palette_dropped comes with a changed mascot, so ok stays TRUE.
# - class: "error", "warning", "message" or "ok", the most serious outcome;
# - message: the error, the warnings or the messages, one per line, without cli's styling (NULL when ok);
# - silencer: code that runs the call with only its specific warnings and messages muffled, in the form
#   ?mascot_theme shows for mascot_contrast (NULL after an error, or when nothing can be muffled that way);
# - condition_classes: every class of every condition the call raised.
# options are set only while the call runs, and only where the caller has not set them: the studio shows contrast
# warnings without changing an option the user chose.
run_real_call <- function(call, envir, options = list(mascot.contrast_warnings = TRUE)) {
  checkmate::assert_class(call, "call")
  checkmate::assert_environment(envir)
  checkmate::assert_list(options, names = "unique")
  unset <- Filter(function(name) is.null(getOption(name)), names(options))
  old <- base::options(options[unset])
  on.exit(base::options(old), add = TRUE)
  conditions <- list()
  error <- NULL
  tryCatch(
    withCallingHandlers(
      eval(call, envir),
      warning = function(w) {
        conditions[[length(conditions) + 1L]] <<- w
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        conditions[[length(conditions) + 1L]] <<- m
        invokeRestart("muffleMessage")
      }
    ),
    error = function(e) error <<- e
  )
  warnings <- Filter(function(condition) inherits(condition, "warning"), conditions)
  messages <- Filter(function(condition) inherits(condition, "message"), conditions)
  text <- function(items, trim) {
    lines <- vapply(items, function(item) cli::ansi_strip(conditionMessage(item)), character(1))
    paste(if (trim) trimws(lines) else lines, collapse = "\n")
  }
  outcome <- if (!is.null(error)) {
    "error"
  } else if (length(warnings)) {
    "warning"
  } else if (length(messages)) {
    "message"
  } else {
    "ok"
  }
  classes <- unique(unlist(lapply(c(conditions, if (!is.null(error)) list(error)), class)))
  list(
    ok = is.null(error) && !"mascot_update_ignored" %in% classes,
    class = outcome,
    message = switch(
      outcome,
      error = cli::ansi_strip(conditionMessage(error)),
      warning = text(warnings, trim = FALSE),
      message = text(messages, trim = TRUE),
      NULL
    ),
    silencer = if (is.null(error)) call_silencer(call, conditions),
    condition_classes = classes
  )
}

# withCallingHandlers() around the call, with one handler per specific class (mascot_contrast, not mascot_warning).
# A warning that left the mascot unchanged (mascot_update_ignored) is never muffled: the call needs fixing instead.
call_silencer <- function(call, conditions) {
  checkmate::assert_class(call, "call")
  checkmate::assert_list(conditions)
  general <- c("mascot_warning", "mascot_message", "mascot_update_ignored")
  handlers <- character()
  for (condition in conditions) {
    specific <- setdiff(grep("^mascot_", class(condition), value = TRUE), general)
    if (!length(specific) || specific[[1L]] %in% names(handlers)) {
      next
    }
    handlers[[specific[[1L]]]] <- if (inherits(condition, "warning")) {
      'function(w) invokeRestart("muffleWarning")'
    } else {
      'function(m) invokeRestart("muffleMessage")'
    }
  }
  if (!length(handlers)) {
    return(NULL)
  }
  paste0(
    "withCallingHandlers(\n  ",
    deparse1(call),
    ",\n",
    paste0("  ", names(handlers), " = ", handlers, collapse = ",\n"),
    "\n)"
  )
}
