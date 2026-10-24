# The tests CRAN skips live in files of their own (#516): browser tests (Chrome, through shinytest2 or chromote) in
# `test-<name>-browser.R` and snapshot tests (`expect_snapshot()` skips itself on CRAN) in `test-<name>-snap.R`. CI's
# browser job picks those files by name, so a browser or snapshot test anywhere else would skip in R CMD check and
# never run, and a plain test in them would run twice. These helpers read the test files' code to check the layout.

# What a call to a function needs: "browser" for anything that starts Chrome or skips on CRAN, "snap" for a snapshot.
layout_snapshot_calls <- c(
  "expect_snapshot",
  "expect_snapshot_error",
  "expect_snapshot_file",
  "expect_snapshot_output",
  "expect_snapshot_value",
  "expect_snapshot_warning"
)
layout_browser_seeds <- c("skip_on_cran", "chromote::", "shinytest2::")

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

# The names among `definitions` that start Chrome or skip on CRAN, directly or through another definition.
layout_browser_names <- function(definitions) {
  checkmate::assert_list(definitions, names = "named")
  found <- layout_browser_seeds
  repeat {
    more <- names(definitions)[vapply(definitions, function(calls) any(calls %in% found), logical(1))]
    if (all(more %in% found)) {
      return(found)
    }
    found <- union(found, more)
  }
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
  for (file in list.files(dir, "^test.*[.]R$")) {
    code <- read(file)
    browser <- layout_browser_names(c(helpers, layout_definitions(code)))
    kind <- if (grepl("-browser[.]R$", file)) {
      "browser"
    } else if (grepl("-snap[.]R$", file)) {
      "snap"
    } else {
      "plain"
    }
    calls <- layout_calls(code)
    uses_browser <- intersect(calls, browser)
    uses_snapshot <- intersect(calls, layout_snapshot_calls)
    if (kind == "plain" && length(uses_browser) > 0L) {
      problems <- c(
        problems,
        cli::format_inline(
          "{file} starts Chrome or skips on CRAN ({.code {uses_browser}}): move those tests to a -browser.R file."
        )
      )
    }
    if (kind == "plain" && length(uses_snapshot) > 0L) {
      problems <- c(
        problems,
        cli::format_inline(
          "{file} has snapshot tests ({.code {uses_snapshot}}): move them to a -snap.R file."
        )
      )
    }
    if (kind == "snap" && length(uses_browser) > 0L) {
      problems <- c(
        problems,
        cli::format_inline(
          "{file} starts Chrome or skips on CRAN ({.code {uses_browser}}): move those tests to a -browser.R file."
        )
      )
    }
    if (kind == "plain") {
      next
    }
    needs <- if (kind == "browser") browser else layout_snapshot_calls
    for (test in layout_tests(code)) {
      if (!any(layout_calls(test) %in% needs)) {
        name <- if (is.character(test[[2]])) test[[2]] else deparse1(test[[2]])
        problems <- c(
          problems,
          cli::format_inline(
            "{file}: {.val {name}} runs on CRAN too, so it belongs in the plain test file."
          )
        )
      }
    }
  }
  problems
}
