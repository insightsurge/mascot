# The tests CRAN skips live in files of their own (tests/README.md): -browser.R, -snap.R and -extended.R. Browser and
# extended files start with their skip; snapshot files don't, because a snapshot file skipped as a whole makes testthat
# delete its saved snapshots. These helpers read the test files' code to check the layout.

# What a call to a function needs: Chrome (a -browser.R file), a skip on CRAN (a -browser.R or -extended.R file), or a
# snapshot (a -snap.R file).
layout_snapshot_calls <- c(
  "expect_snapshot",
  "expect_snapshot_error",
  "expect_snapshot_file",
  "expect_snapshot_output",
  "expect_snapshot_value",
  "expect_snapshot_warning"
)
layout_chrome_seeds <- c("chromote::", "shinytest2::")
layout_skip_seeds <- "skip_on_cran"

# The skip a browser or extended file starts with, as its first expression.
layout_file_skips <- c(browser = "skip_without_chrome", extended = "skip_unless_extended")

# `f` applied to each part of `x` (code), leaving out empty arguments (such as the `i` of `x[, 1]` or a formal
# argument without a default), which cannot be passed on.
layout_map <- function(x, f) {
  parts <- as.list(x)
  lapply(seq_along(parts), function(i) if (identical(parts[[i]], quote(expr = ))) NULL else f(parts[[i]]))
}

# The functions `x` (code) calls, plus "pkg::" for each namespace it calls into (`testthat::skip_on_cran()` gives
# "testthat::" and "skip_on_cran"). What runs inside `expect_error()`
# doesn't count: an argument check of a helper that starts Chrome fails before Chrome starts, so it runs on CRAN.
layout_calls <- function(x) {
  if (is.pairlist(x) || is.expression(x)) {
    return(unique(unlist(layout_map(x, layout_calls))))
  }
  if (!is.call(x)) {
    return(character())
  }
  head <- x[[1]]
  if (is.name(head) && as.character(head) %in% c("::", ":::")) {
    return(c(paste0(as.character(x[[2]]), "::"), as.character(x[[3]])))
  }
  if (identical(head, as.name("expect_error"))) {
    return("expect_error")
  }
  own <- if (is.name(head)) as.character(head) else layout_calls(head)
  unique(c(own, unlist(layout_map(x[-1], layout_calls))))
}

# Every function `x` defines (`name <- function(...)`, at any depth) and every fixture it makes with
# `delayedAssign()`, as a list of the functions each one calls.
layout_definitions <- function(x) {
  if (is.pairlist(x) || is.expression(x) || (is.call(x) && !is.name(x[[1]]))) {
    return(do.call(c, layout_map(x, layout_definitions)))
  }
  if (!is.call(x)) {
    return(list())
  }
  head <- as.character(x[[1]])
  own <- list()
  if (head %in% c("<-", "=") && is.name(x[[2]]) && is.call(x[[3]]) && identical(x[[3]][[1]], as.name("function"))) {
    own[[as.character(x[[2]])]] <- layout_calls(x[[3]])
  }
  if (head == "delayedAssign" && is.character(x[[2]])) {
    own[[x[[2]]]] <- layout_calls(x[[3]])
  }
  c(own, do.call(c, layout_map(x[-1], layout_definitions)))
}

# The names among `definitions` that reach `seeds` (calls, or "pkg::" namespaces), directly or through another
# definition, plus the seeds themselves.
layout_names_reaching <- function(definitions, seeds) {
  checkmate::assert_list(definitions, names = "named")
  checkmate::assert_character(seeds, min.len = 1L)
  found <- seeds
  repeat {
    more <- names(definitions)[vapply(definitions, function(calls) any(calls %in% found), logical(1))]
    if (all(more %in% found)) {
      return(found)
    }
    found <- union(found, more)
  }
}

# The name of the function `x` (one expression) calls with no arguments, without its "pkg::"; NULL for anything else.
layout_bare_call <- function(x) {
  if (!is.call(x) || length(x) != 1L) {
    return(NULL)
  }
  head <- x[[1]]
  if (is.call(head) && as.character(head[[1]]) %in% c("::", ":::")) {
    return(as.character(head[[3]]))
  }
  if (is.name(head)) as.character(head) else NULL
}

# The `it()` calls in `x` (code), at any depth.
layout_tests <- function(x) {
  if (is.pairlist(x) || is.expression(x)) {
    return(do.call(c, layout_map(x, layout_tests)))
  }
  if (!is.call(x)) {
    return(list())
  }
  if (identical(x[[1]], as.name("it"))) {
    return(list(x))
  }
  do.call(c, layout_map(x, layout_tests))
}

# The layout problems of the test files in `dir`, one sentence each; none when every file holds the right tests.
layout_problems <- function(dir) {
  checkmate::assert_directory_exists(dir)
  read <- function(file) parse(file.path(dir, file), keep.source = FALSE)
  helpers <- do.call(c, lapply(list.files(dir, "^helper.*[.]R$"), function(file) layout_definitions(read(file))))
  problems <- character()
  add <- function(text) problems <<- c(problems, cli::format_inline(text, .envir = parent.frame()))
  for (file in list.files(dir, "^test.*[.]R$")) {
    code <- read(file)
    definitions <- c(list(), helpers, layout_definitions(code))
    chrome <- layout_names_reaching(definitions, layout_chrome_seeds)
    skipping <- layout_names_reaching(definitions, c(layout_skip_seeds, chrome))
    kind <- regmatches(file, regexpr("(?<=-)(browser|snap|extended)(?=[.]R$)", file, perl = TRUE))
    kind <- if (length(kind)) kind else "plain"
    calls <- layout_calls(code)
    uses_chrome <- intersect(calls, chrome)
    uses_skip <- intersect(calls, skipping)
    uses_snapshot <- intersect(calls, layout_snapshot_calls)
    if (kind == "plain" && length(uses_skip) > 0L) {
      add(
        "{file} starts Chrome or skips on CRAN ({.code {uses_skip}}): move those tests to a -browser.R or -extended.R file."
      )
    }
    if (kind %in% c("snap", "extended") && length(uses_chrome) > 0L) {
      add("{file} starts Chrome ({.code {uses_chrome}}): move those tests to a -browser.R file.")
    }
    if (kind %in% c("plain", "browser", "extended") && length(uses_snapshot) > 0L) {
      add("{file} has snapshot tests ({.code {uses_snapshot}}): move them to a -snap.R file.")
    }
    if (kind == "plain") {
      next
    }
    skip <- if (kind %in% names(layout_file_skips)) layout_file_skips[[kind]]
    if (!is.null(skip) && !identical(if (length(code)) layout_bare_call(code[[1]]), skip)) {
      add("{file} must start with {.code {skip}()}, so CRAN skips the whole file before any of its code runs.")
    }
    if (kind == "extended") {
      next
    }
    needs <- if (kind == "browser") skipping else layout_snapshot_calls
    for (test in layout_tests(code)) {
      if (!any(layout_calls(test) %in% needs)) {
        name <- if (is.character(test[[2]])) test[[2]] else deparse1(test[[2]])
        add("{file}: {.val {name}} runs on CRAN too, so it belongs in the plain test file.")
      }
    }
  }
  problems
}
