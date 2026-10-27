---
paths:
  - "R/**/*.R"
  - "tools/**/*.R"
  - "inst/examples/**/*.R"
---

# R code

Labels: **CRAN** = CRAN policy, Writing R Extensions or R CMD check; **house** = our standard (a justified
exception is fine with a comment saying why). Reasons and sources: `docs/standards.md`.

## Formatting
- **house:** after editing R files, run `air format .`; the gate's `air` step fails on unformatted code.

## Arguments and messages
- **house:** every function (exported and internal) starts with `checkmate::assert_*()` calls, one per argument,
  before any other work. Use the strictest check that fits (`assert_string()`, `assert_flag()`, `assert_count()`,
  `assert_number(lower =, upper =)`, `assert_choice(mood, moods())`, `assert_character(min.chars = 1,
  any.missing = FALSE)`, `assert_class()`, `assert_function()`, `assert_list(names = "unique")`,
  `assert_file_exists()`, `assert_path_for_output()`) and say what `NULL` means with `null.ok = TRUE`. Several
  arguments can share `checkmate::makeAssertCollection()`. Functions without arguments need none.
- **house (exception):** an internal helper that runs once per node or per recursion step, and is called only
  from a function that has already asserted the same inputs (for example `character_format_node()` inside the
  character checker), may skip its own assertions to keep large checks fast. Top-level helpers need a one-line
  comment above the function. Inner closures (named helpers and anonymous callbacks) inherit this exception
  when consuming their enclosing function's checked inputs; they need no repeated comment. Entry points
  and every other function keep their assertions.
- **house:** exported functions wrap their checkmate assertion blocks in `with_mascot_asserts()` so failures also carry `mascot_error`.
- **house:** every other message, warning and error uses cli (`cli::cli_abort()`, `cli::cli_warn()`,
  `cli::cli_inform()`), with the argument or value named in the message.
- **CRAN (Cookbook):** no `print()` or `cat()` for messages (lintr flags them; a `print()` method may print with
  `# nolint: undesirable_function_linter.` and a reason).

## Dependencies
- **house:** the built-in characters ship already checked, in `R/sysdata.rda`. After editing a file in
  `inst/format/characters/` or the character checker (`R/character-*.R`), run `Rscript tools/build-sysdata.R` and
  commit the new `R/sysdata.rda` with the change; `test-character-catalogue-extended.R` fails until you do.
- **house:** call other packages as `pkg::fn()`. `@importFrom` only for operators (such as `%||%`), and only in
  `R/mascot-package.R`; never `@import` a whole package.
- **CRAN:** every package used is declared in `DESCRIPTION` (R CMD check warns otherwise). `Imports` stays
  minimal (the list in `DESCRIPTION`); optional features use `Suggests` and check with
  `requireNamespace()` before use (CRAN also checks without Suggests).
- **CRAN:** no `library()`, `require()` or `attach()` in package code.

## Behaviour
- **CRAN:** write only to `tempdir()` or a path the user passes; never the home directory or the clipboard.
- **CRAN:** no side effects on load (`.onLoad()` registers things only); restore anything you change (`options()`,
  `par()`, working directory, environment variables) with `on.exit()` or `withr::local_*()`.
- **CRAN:** no network access; nothing is downloaded at runtime (all assets ship in `inst/`).
- **CRAN:** no `:::` into other packages, no `<<-` into the global environment, at most 2 cores, `TRUE`/`FALSE`
  never `T`/`F`, no `set.seed()` inside functions (take a `seed` argument), no `q()`.
- **CRAN:** R code is ASCII only: write other characters as `"\uXXXX"`.
- **house:** names: `mascot()` is the main object; `update_mascot()` follows bslib's snake case (`update_switch()`); no camelCase aliases;
  `use_*()` is only for project setup. Every top-level argument of `mascot()` takes a plain shortcut or a
  `mascot_*()` helper (bslib style), and every helper and listing function carries the `mascot_` prefix
  (autocomplete, no clashes). Check each new exported name against base R, shiny, bslib and ggplot2 first.

## Shiny apps (the example apps and any app the package ships)
The page changes at once and the server answers a moment later, so a click can act on an earlier state (#548, #574).
Debounced inputs, Copy of code the server generates, controls the server sets back and frames that load later all open
that gap. Reasons: `docs/standards.md`, section 3, "Shiny apps". The page side of each rule is in `js-css.md`.
1. **house:** the server holds the truth: what the app copies, builds or shows as a result (code, a preview, a check)
   comes from server state, never from values read in the page. A control may show a choice the server hasn't had
   yet. Example: Copy copies `output$theme_code`, drawn from `theme()`, not the pickers' values.
2. **house:** an action collects waiting inputs first: Copy, Download, Build and Check send any input still waiting
   (a debounced picker, typing that hasn't paused) before their own event, and so does a choice that redraws those
   inputs (a palette or character change); the server applies them first (a higher observer `priority`) and answers
   the action only after that. Example: the studio's `inputs.js` sends every colour picker with a waiting value
   before Copy, then `copy_gate()` answers the copy ticket.
3. **house:** never echo the control the user just used: when two controls show the same choice, the server updates
   only the other one. Only the user's own changes count as choices: not a value the server set, and not the value a
   control reports when it is drawn again. Example: a change of `input$start_from` calls
   `updateRadioButtons(session, "palette_grid", selected = input$start_from)` and leaves `start_from` alone.
4. **house:** a late answer can't undo a newer choice: an update the server sends to a control carries the revision of
   the choice it answers, and the page ignores one older than its latest choice; a control that has sent no revision
   yet counts as revision 0. Inputs drawn again carry the number of their drawing, so the server drops an edit from
   an older one. Example: `session$sendInputMessage("palette_grid", list(value = palette(), revision = revision))`.
5. **house:** busy means "until my own result is drawn": a busy button stays busy until its output shows the mark of
   its own click (`busy_done_mark()`, `inst/examples/studio/R/shared-check.R`) and any frame in it has loaded, or the
   output shows an error; not until Shiny goes idle (#547, #550). The click number is kept with the result it built,
   never read again from the input. Example: `busy_done_mark(page$click)` inside the page built for that click.

The test for these rules ("do X, then Y at once") is in `tests.md`.
