---
paths:
  - "R/**/*.R"
  - "tools/**/*.R"
---

# R code

Labels: **CRAN** = CRAN policy, Writing R Extensions or R CMD check; **house** = our standard (a justified
exception is fine with a comment saying why). Reasons and sources: `docs/standards.md`.

## Arguments and messages
- **house:** every function (exported and internal) starts with `checkmate::assert_*()` calls, one per argument,
  before any other work. Use the strictest check that fits (`assert_string()`, `assert_flag()`, `assert_count()`,
  `assert_number(lower =, upper =)`, `assert_choice(mood, moods())`, `assert_character(min.chars = 1,
  any.missing = FALSE)`, `assert_class()`, `assert_function()`, `assert_list(names = "unique")`,
  `assert_file_exists()`, `assert_path_for_output()`) and say what `NULL` means with `null.ok = TRUE`. Several
  arguments can share `checkmate::makeAssertCollection()`. Functions without arguments need none.
- **house:** every other message, warning and error uses cli (`cli::cli_abort()`, `cli::cli_warn()`,
  `cli::cli_inform()`), with the argument or value named in the message.
- **CRAN (Cookbook):** no `print()` or `cat()` for messages (lintr flags them; a `print()` method may print with
  `# nolint: undesirable_function_linter.` and a reason).

## Dependencies
- **house:** call other packages as `pkg::fn()`. `@importFrom` only for operators (such as `%||%`), and only in
  `R/mascot-package.R`; never `@import` a whole package.
- **CRAN:** every package used is declared in `DESCRIPTION` (R CMD check warns otherwise). `Imports` stays
  minimal (htmltools, shiny, checkmate, cli); optional features use `Suggests` and check with
  `rlang::check_installed()` or `requireNamespace()` before use (CRAN also checks without Suggests).
- **CRAN:** no `library()`, `require()` or `attach()` in package code.

## Behaviour
- **CRAN:** write only to `tempdir()` or a path the user passes; never the home directory or the clipboard.
- **CRAN:** no side effects on load (`.onLoad()` registers things only); restore anything you change (`options()`,
  `par()`, working directory, environment variables) with `on.exit()` or `withr::local_*()`.
- **CRAN:** no network access; nothing is downloaded at runtime (all assets ship in `inst/`).
- **CRAN:** no `:::` into other packages, no `<<-` into the global environment, at most 2 cores, `TRUE`/`FALSE`
  never `T`/`F`, no `set.seed()` inside functions (take a `seed` argument), no `q()`.
- **CRAN:** R code is ASCII only: write other characters as `"\uXXXX"`.
- **house:** names: `mascot()` is the main object; Shiny's convention for `mascotOutput()`, `renderMascot()`,
  `updateMascot()`; `use_*()` only for project setup; otherwise short verbs without a prefix. Check a new name
  against base R, shiny, bslib and ggplot2 first. Few exports: prefer an argument over a new function.
