#!/usr/bin/env Rscript
# cran-gate version: 2026-10-21
# CRAN gate: one command that says whether an R package would pass CRAN's checks, before you submit it.
#
#   Rscript <path to this file> [fast|tests|full|lint] [--update-wordlist]
#
#   fast  (default) tools, style, docs in sync, \value, spelling, R CMD check --as-cran without tests
#   tests           tools, tests (NOT_CRAN=true, so tests that CRAN skips run too) and coverage
#   full            everything: fast steps, tests, coverage, CRAN-like check with tests, built tarball
#   lint            the quick static steps only: tools, style, docs in sync, \value, spelling
#
# Run it from the package root. It prints one PASS/FAIL/SKIP line per step and a summary, and exits 1 if any step
# fails. Detailed output goes to a run folder that outlives the gate (its path is printed): one log per step,
# gate.json (one row per step) and, after the tests step, tests.txt, tests.json and tests.rds.
#
# Always checked (CRAN or its reviewers ask for these): R CMD check --as-cran with 0 errors, 0 warnings and 0 notes;
# a \value section for every exported function; help pages in sync with the roxygen comments; spelling; every file
# in inst/ present in the built package, and the package's size.
#
# Checked when the package has the tool's settings file (skipped with a reason otherwise):
#   air.toml    formatting with Air            (https://posit-dev.github.io/air/)
#   .lintr      lintr, with the package's rules
#   biome.json  Biome on the JS and CSS in inst/ (https://biomejs.dev)
#
# Optional settings, as fields in the package's DESCRIPTION:
#   Config/cran-gate/coverage: 80      lowest line coverage allowed, in percent (default 70; 0 = no limit).
#                                      A good-practice check: CRAN itself does not measure coverage
#   Config/cran-gate/tarball-mb: 5     largest built package allowed, in MB (default 5; 5 to 9, CRAN's limit is 10)
#   Config/cran-gate/extra-dirs: tools more folders to format-check and lint, comma separated (default: none)
#
# Needs the R packages checkmate, cli, devtools, jsonlite and spelling, plus roxygen2, lintr, covr, testthat, withr
# and pkgbuild for the steps that use them; the tools step names whatever is missing.
#
# Writes to the package: devtools::document() may rewrite man/, NAMESPACE and DESCRIPTION (the docs step then fails
# and names the files); --update-wordlist rewrites inst/WORDLIST. Outside the package it writes only to tempdir()
# and the run folder: <CRAN_GATE_OUT>/<YYYYmmdd-HHMMSS>-<mode>, where CRAN_GATE_OUT defaults to cran-gate/ in the
# system temp folder (the parent of tempdir()).

modes <- c("fast", "tests", "full", "lint")

setting <- function(name, default) {
  checkmate::assert_string(name)
  checkmate::assert_string(default)
  value <- read.dcf("DESCRIPTION", fields = paste0("Config/cran-gate/", name))[[1]]
  if (is.na(value)) default else trimws(value)
}

read_settings <- function() {
  coverage <- suppressWarnings(as.numeric(setting("coverage", "70")))
  tarball_mb <- suppressWarnings(as.numeric(setting("tarball-mb", "5")))
  extra_dirs <- trimws(strsplit(setting("extra-dirs", ""), ",", fixed = TRUE)[[1]])
  extra_dirs <- extra_dirs[nzchar(extra_dirs)]
  checkmate::assert_number(coverage, lower = 0, upper = 100, .var.name = "Config/cran-gate/coverage")
  # CRAN asks for source packages under 10 MB if possible, so the limit can be raised to 9 but not further.
  checkmate::assert_number(tarball_mb, lower = 5, upper = 9, .var.name = "Config/cran-gate/tarball-mb")
  for (dir in extra_dirs) {
    checkmate::assert_directory_exists(dir, .var.name = "Config/cran-gate/extra-dirs")
  }
  list(coverage = coverage, tarball_mb = tarball_mb, extra_dirs = extra_dirs)
}

# What this package uses, which decides the steps that run and the tools they need.
package_uses <- function() {
  roxygen_fields <- c("Roxygen", "RoxygenNote", "Config/roxygen2/version")
  list(
    air = any(file.exists(c("air.toml", ".air.toml"))),
    lintr = any(file.exists(c(".lintr", ".lintr.R"))),
    biome = any(file.exists(c("biome.json", "biome.jsonc"))),
    roxygen = !all(is.na(read.dcf("DESCRIPTION", fields = roxygen_fields))),
    tests = dir.exists("tests"),
    testthat = dir.exists("tests/testthat")
  )
}

required_packages <- function(mode, uses) {
  checkmate::assert_choice(mode, modes)
  checkmate::assert_list(uses, types = "logical")
  pkgs <- c("checkmate", "cli", "devtools", "jsonlite", "spelling")
  if (uses$roxygen) {
    pkgs <- c(pkgs, "roxygen2")
  }
  if (uses$lintr) {
    pkgs <- c(pkgs, "lintr")
  }
  if (mode %in% c("tests", "full") && uses$tests) {
    pkgs <- c(pkgs, "covr", "withr", if (uses$testthat) "testthat")
  }
  if (mode == "full") {
    pkgs <- c(pkgs, "pkgbuild")
  }
  pkgs
}

steps_for <- function(mode) {
  checkmate::assert_choice(mode, modes)
  static <- c("air", "biome", "docs", "lintr", "value", "spelling")
  switch(
    mode,
    fast = c("tools", static, "check_fast"),
    tests = c("tools", "tests", "coverage"),
    full = c("tools", static, "tests", "coverage", "check_full", "tarball"),
    lint = c("tools", static)
  )
}

# A step returns list(status = "PASS"|"FAIL"|"SKIP", detail = "..."); errors become FAIL.
result <- function(status, detail = "") {
  checkmate::assert_choice(status, c("PASS", "FAIL", "SKIP"))
  checkmate::assert_string(detail)
  list(status = status, detail = detail)
}

# The run folder: one per gate run, outside the session's tempdir() (which R deletes when the gate exits), so the
# logs and results are still there when you read them. `parent` is CRAN_GATE_OUT or cran-gate/ in the system temp
# folder.
run_folder <- function(parent, mode) {
  checkmate::assert_string(parent, min.chars = 1)
  checkmate::assert_string(mode, min.chars = 1)
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  checkmate::assert_directory_exists(parent, access = "w", .var.name = "CRAN_GATE_OUT")
  base <- file.path(normalizePath(parent), paste0(format(Sys.time(), "%Y%m%d-%H%M%S"), "-", mode))
  dir <- base
  n <- 1L
  while (!dir.create(dir, showWarnings = FALSE)) {
    n <- n + 1L
    dir <- paste0(base, "-", n)
  }
  dir
}

default_out <- function() {
  Sys.getenv("CRAN_GATE_OUT", file.path(dirname(tempdir()), "cran-gate"))
}

# Runs `fun`, sending its printed output and messages to the log file.
run_logged <- function(fun, log) {
  checkmate::assert_function(fun)
  checkmate::assert_string(log)
  con <- file(log, open = "a")
  sink(con)
  sink(con, type = "message")
  on.exit({
    sink(type = "message")
    sink()
    close(con)
  })
  fun()
}

js_css_files <- function() {
  if (!dir.exists("inst")) {
    return(character())
  }
  list.files("inst", pattern = "\\.(js|css)$", recursive = TRUE, full.names = TRUE)
}

step_tools <- function(mode, uses) {
  checkmate::assert_choice(mode, modes)
  checkmate::assert_list(uses, types = "logical")
  missing <- character()
  if (uses$air && !nzchar(Sys.which("air"))) {
    missing <- c(missing, "air (https://posit-dev.github.io/air/), needed because the package has an air.toml")
  }
  if (uses$biome && length(js_css_files()) > 0 && !nzchar(Sys.which("biome"))) {
    missing <- c(missing, "biome (https://biomejs.dev), needed because inst/ has JS or CSS")
  }
  pkgs <- required_packages(mode, uses)
  absent <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent) > 0) {
    missing <- c(missing, paste0("R package ", absent))
  }
  lib <- paste0(".libPaths()[1] = ", .libPaths()[1])
  if (length(missing) > 0) {
    return(result("FAIL", paste(c(paste("missing:", paste(missing, collapse = ", ")), lib), collapse = "; ")))
  }
  result("PASS", lib)
}

step_air <- function(uses, settings, log) {
  checkmate::assert_list(uses, types = "logical")
  checkmate::assert_list(settings)
  checkmate::assert_string(log)
  if (!uses$air) {
    return(result("SKIP", "no air.toml: the package doesn't use Air"))
  }
  # Air skips hidden folders when given ".", so extra folders (which may be hidden) are named one by one.
  paths <- c(".", settings$extra_dirs)
  out <- suppressWarnings(system2("air", c("format", "--check", shQuote(paths)), stdout = TRUE, stderr = TRUE))
  write(out, log, append = TRUE)
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    fix <- paste0("run `air format ", paste(paths, collapse = " "), "`; ")
    return(result("FAIL", paste0(fix, paste(utils::head(out, 3), collapse = " | "))))
  }
  result("PASS")
}

step_biome <- function(uses, log) {
  checkmate::assert_list(uses, types = "logical")
  checkmate::assert_string(log)
  if (!uses$biome) {
    return(result("SKIP", "no biome.json: the package doesn't use Biome"))
  }
  files <- js_css_files()
  if (length(files) == 0) {
    return(result("SKIP", "no JS or CSS in inst/ yet"))
  }
  out <- suppressWarnings(system2("biome", c("ci", "inst"), stdout = TRUE, stderr = TRUE))
  write(out, log, append = TRUE)
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    return(result("FAIL", "run `biome check --write inst`; details in the log"))
  }
  result("PASS", paste(length(files), "files"))
}

# Hashes of the files roxygen writes. DESCRIPTION is hashed without the roxygen version fields, so a different
# roxygen2 version on another machine doesn't count as out-of-date docs.
docs_snapshot <- function() {
  files <- c("NAMESPACE", list.files("man", full.names = TRUE))
  files <- files[file.exists(files)]
  hashes <- unname(tools::md5sum(files))
  desc <- readLines("DESCRIPTION", warn = FALSE)
  desc <- desc[!grepl("^(RoxygenNote|Config/roxygen2/version):", desc)]
  stats::setNames(c(hashes, paste(desc, collapse = "\n")), c(files, "DESCRIPTION"))
}

step_docs <- function(uses, log) {
  checkmate::assert_list(uses, types = "logical")
  checkmate::assert_string(log)
  if (!uses$roxygen) {
    return(result("SKIP", "the package doesn't use roxygen2"))
  }
  before <- docs_snapshot()
  run_logged(function() devtools::document(quiet = TRUE), log)
  after <- docs_snapshot()
  changed <- union(setdiff(names(after), names(before)), setdiff(names(before), names(after)))
  common <- intersect(names(before), names(after))
  changed <- c(changed, common[before[common] != after[common]])
  if (length(changed) > 0) {
    return(result("FAIL", paste0("document() changed ", paste(changed, collapse = ", "), ": review and commit")))
  }
  result("PASS")
}

step_lintr <- function(uses, settings, log) {
  checkmate::assert_list(uses, types = "logical")
  checkmate::assert_list(settings)
  checkmate::assert_string(log)
  if (!uses$lintr) {
    return(result("SKIP", "no .lintr: the package doesn't use lintr"))
  }
  # lint_package() covers R/, tests/ and inst/; Config/cran-gate/extra-dirs adds more folders.
  lints <- lintr::lint_package()
  for (dir in settings$extra_dirs) {
    lints <- c(lints, lintr::lint_dir(dir))
  }
  if (length(lints) > 0) {
    run_logged(function() print(lints), log) # nolint: undesirable_function_linter. Full lint report for the log.
    first <- vapply(
      utils::head(lints, 3),
      function(x) paste0(x$filename, ":", x$line_number, " ", x$linter),
      character(1)
    )
    return(result("FAIL", paste0(length(lints), " lints: ", paste(first, collapse = "; "))))
  }
  result("PASS")
}

rd_tags <- function(rd) {
  checkmate::assert_class(rd, "Rd")
  vapply(rd, function(x) attr(x, "Rd_tag"), character(1))
}

# The package's own exported functions (re-exports from other packages don't need a \value section here).
exported_functions <- function(log) {
  checkmate::assert_string(log)
  pkg <- read.dcf("DESCRIPTION", fields = "Package")[[1]]
  if (!isNamespaceLoaded(pkg)) {
    run_logged(function() devtools::load_all(quiet = TRUE), log)
  }
  ns <- asNamespace(pkg)
  own <- function(name) {
    obj <- get0(name, envir = ns)
    is.function(obj) && !is.primitive(obj) && identical(topenv(environment(obj)), ns)
  }
  exports <- getNamespaceExports(ns)
  sort(exports[vapply(exports, own, logical(1))])
}

# Exported functions whose help page has no \value section (CRAN reviewers ask for one on every function).
step_value <- function(log) {
  checkmate::assert_string(log)
  exports <- exported_functions(log)
  if (length(exports) == 0) {
    return(result("PASS", "no exported functions yet"))
  }
  documented <- character()
  missing <- character()
  if (dir.exists("man")) {
    for (rd in tools::Rd_db(dir = ".")) {
      tags <- rd_tags(rd)
      aliases <- intersect(unlist(lapply(rd[tags == "\\alias"], as.character)), exports)
      documented <- c(documented, aliases)
      if (!"\\value" %in% tags) {
        missing <- c(missing, aliases)
      }
    }
  }
  undocumented <- setdiff(exports, documented)
  problems <- c(
    if (length(missing) > 0) paste0("no \\value (add @returns) for: ", toString(missing)),
    if (length(undocumented) > 0) paste0("no help page for: ", toString(undocumented))
  )
  if (length(problems) > 0) {
    return(result("FAIL", paste(problems, collapse = "; ")))
  }
  result("PASS", paste(length(exports), "exported functions"))
}

step_spelling <- function(update, log) {
  checkmate::assert_flag(update)
  checkmate::assert_string(log)
  words <- run_logged(function() spelling::spell_check_package("."), log)
  if (nrow(words) == 0) {
    return(result("PASS"))
  }
  run_logged(function() print(words), log) # nolint: undesirable_function_linter. Full report for the log.
  if (update) {
    run_logged(function() spelling::update_wordlist(".", confirm = FALSE), log)
    return(result("PASS", paste0("added to inst/WORDLIST (review before committing): ", toString(words$word))))
  }
  result("FAIL", paste0("unknown words: ", toString(words$word), "; fix them, or add with --update-wordlist"))
}

# The failing tests named in testthat's check output (testthat.Rout.fail under R CMD check or covr): lines such as
# "-- Failure ('test-x.R:3:3'): the name --", with the rule characters taken off.
failure_headers <- function(text) {
  checkmate::assert_character(text, any.missing = FALSE)
  lines <- unlist(strsplit(text, "\n", fixed = TRUE))
  found <- regmatches(lines, regexpr("(Failure|Error) \\('[^']+'\\): .*$", lines))
  trimws(sub("[ ─-]+$", "", found))
}

check_result <- function(res) {
  checkmate::assert_class(res, "rcmdcheck")
  counts <- c(errors = length(res$errors), warnings = length(res$warnings), notes = length(res$notes))
  detail <- paste(counts, names(counts), collapse = ", ")
  if (sum(counts) > 0) {
    first <- strsplit(c(res$errors, res$warnings, res$notes)[1], "\n", fixed = TRUE)[[1]][1]
    failing <- failure_headers(as.character(unlist(res$test_fail)))
    tests <- if (length(failing) > 0) {
      more <- if (length(failing) > 3) sprintf(" +%d more", length(failing) - 3) else ""
      paste0("; failing tests: ", paste(utils::head(failing, 3), collapse = "; "), more)
    } else {
      ""
    }
    return(result("FAIL", paste0(detail, "; first: ", first, tests)))
  }
  result("PASS", detail)
}

# CRAN-like check: NOT_CRAN=false so tests behind skip_on_cran() skip as they do on CRAN (devtools::check() sets
# NOT_CRAN=true by default, which is not what CRAN runs).
step_check <- function(tests, log) {
  checkmate::assert_flag(tests)
  checkmate::assert_string(log)
  args <- c("--as-cran", if (!tests) "--no-tests")
  res <- run_logged(
    function() {
      devtools::check(
        document = FALSE,
        args = args,
        env_vars = c(NOT_CRAN = "false"),
        error_on = "never",
        quiet = TRUE
      )
    },
    log
  )
  check_result(res)
}

# The first line of a test's message, without testthat's "Error in `eval(code, test_env)`: " prefix, cut to 100
# characters. A line ending in ":" (cli's "Error in `f()`:") keeps the line after it.
first_message_line <- function(message) {
  checkmate::assert_string(message)
  lines <- trimws(strsplit(message, "\n", fixed = TRUE)[[1]])
  lines <- lines[nzchar(lines)]
  if (length(lines) == 0) {
    return("")
  }
  line <- if (length(lines) > 1 && endsWith(lines[1], ":")) paste(lines[1:2], collapse = " ") else lines[1]
  line <- sub("^Error in `eval\\(code, test_env\\)`: ", "", line)
  if (nchar(line) > 100) paste0(substr(line, 1, 97), "...") else line
}

# One row per failure, error and warning in a testthat results object: file, line, test, kind, message.
test_issues <- function(res) {
  checkmate::assert_class(res, "testthat_results")
  kinds <- c(expectation_failure = "Failure", expectation_error = "Error", expectation_warning = "Warning")
  rows <- lapply(res, function(t) {
    found <- Filter(function(e) inherits(e, names(kinds)), t$results)
    lapply(found, function(e) {
      data.frame(
        file = t$file,
        line = if (inherits(e$srcref, "srcref")) as.integer(e$srcref[[1]]) else NA_integer_,
        test = if (length(t$test) == 0 || is.na(t$test)) "(code outside test_that())" else t$test,
        kind = unname(kinds[intersect(class(e), names(kinds))[1]]),
        message = first_message_line(conditionMessage(e))
      )
    })
  })
  empty <- data.frame(
    file = character(),
    line = integer(),
    test = character(),
    kind = character(),
    message = character()
  )
  do.call(rbind, c(list(empty), unlist(rows, recursive = FALSE)))
}

# Issues as `file:line "test" (Kind: message)`.
issue_text <- function(issues) {
  checkmate::assert_data_frame(issues)
  sprintf("%s:%s \"%s\" (%s: %s)", issues$file, issues$line, issues$test, issues$kind, issues$message)
}

# Reads a testthat results object: writes tests.rds and tests.json to the run folder and returns the counts, the
# issues and the slowest files.
summarise_tests <- function(res, run_dir) {
  checkmate::assert_class(res, "testthat_results")
  checkmate::assert_directory_exists(run_dir, access = "w")
  df <- as.data.frame(res)
  issues <- test_issues(res)
  slow <- if (nrow(df) > 0) {
    utils::head(sort(tapply(df$real, df$file, sum, na.rm = TRUE), decreasing = TRUE), 10)
  } else {
    numeric()
  }
  bad <- issues[issues$kind != "Warning", , drop = FALSE]
  counts <- list(
    expectations = sum(df$nb),
    failed = nrow(bad),
    warnings = sum(issues$kind == "Warning"),
    skipped = sum(df$skipped)
  )
  saveRDS(res, file.path(run_dir, "tests.rds"))
  jsonlite::write_json(
    list(
      counts = counts,
      issues = issues,
      slowest_files = as.list(slow),
      tests = df[setdiff(names(df), "result")]
    ),
    file.path(run_dir, "tests.json"),
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = NA,
    na = "null"
  )
  list(counts = counts, issues = issues, bad = bad, slow = slow)
}

# The tests step's line: counts and the slowest file on PASS; counts, the first 3 problems and where the details
# are on FAIL.
tests_result <- function(summary, txt) {
  checkmate::assert_list(summary)
  checkmate::assert_string(txt)
  n <- summary$counts
  counts <- sprintf(
    "%d expectations, %d failed, %d warnings, %d skipped",
    n$expectations,
    n$failed,
    n$warnings,
    n$skipped
  )
  if (nrow(summary$bad) == 0) {
    slowest <- if (length(summary$slow) > 0) {
      sprintf("; slowest file %s (%.0fs)", names(summary$slow)[1], summary$slow[[1]])
    } else {
      ""
    }
    return(result("PASS", paste0(counts, slowest)))
  }
  named <- issue_text(utils::head(summary$bad, 3))
  more <- if (nrow(summary$bad) > 3) sprintf("; +%d more", nrow(summary$bad) - 3) else ""
  result("FAIL", paste0(counts, ": ", paste(named, collapse = "; "), more, "; details: ", txt))
}

step_tests <- function(uses, run_dir, log, state) {
  checkmate::assert_list(uses, types = "logical")
  checkmate::assert_directory_exists(run_dir, access = "w")
  checkmate::assert_string(log)
  checkmate::assert_environment(state)
  if (!uses$testthat) {
    return(result("SKIP", "no tests/testthat (R CMD check still runs whatever is in tests/)"))
  }
  withr::local_envvar(NOT_CRAN = "true")
  txt <- file.path(run_dir, "tests.txt")
  reporter <- testthat::SummaryReporter$new(file = txt, max_reports = Inf)
  # stop_on_failure = FALSE: with TRUE, testthat aborts with "Test failures." and its results are lost.
  res <- run_logged(function() devtools::test(stop_on_failure = FALSE, reporter = reporter), log)
  state$tests <- summarise_tests(res, run_dir)
  tests_result(state$tests, txt)
}

step_coverage <- function(uses, settings, log, state) {
  checkmate::assert_list(uses, types = "logical")
  checkmate::assert_list(settings)
  checkmate::assert_string(log)
  checkmate::assert_environment(state)
  if (!uses$tests) {
    return(result("SKIP", "the package has no tests/"))
  }
  if (identical(state$statuses[["tests"]], "FAIL")) {
    return(result("SKIP", "tests failed, and covr gives no percentage when a test fails"))
  }
  withr::local_envvar(NOT_CRAN = "true")
  # covr cuts the failure output to warning.length characters (1000 by default): raise it to R's maximum.
  withr::local_options(warning.length = 8170L)
  cov <- tryCatch(
    run_logged(function() covr::package_coverage(quiet = TRUE), log),
    error = function(e) {
      message <- conditionMessage(e)
      write(message, log, append = TRUE)
      failing <- failure_headers(message)
      if (length(failing) == 0) {
        return(result("FAIL", first_message_line(message)))
      }
      more <- if (length(failing) > 3) sprintf(" +%d more", length(failing) - 3) else ""
      result("FAIL", paste0("tests failed under covr: ", paste(utils::head(failing, 3), collapse = "; "), more))
    }
  )
  if (!inherits(cov, "coverage")) {
    return(cov)
  }
  if (nrow(as.data.frame(cov)) == 0) {
    return(result("PASS", "no R code lines to cover yet"))
  }
  pct <- covr::percent_coverage(cov)
  if (pct < settings$coverage) {
    return(result("FAIL", sprintf("%.1f%% is under %g%%; see covr::zero_coverage()", pct, settings$coverage)))
  }
  limit <- if (settings$coverage > 0) sprintf("at least %g%% needed", settings$coverage) else "no limit set"
  result("PASS", sprintf("%.1f%% (%s)", pct, limit))
}

step_tarball <- function(settings, log) {
  checkmate::assert_list(settings)
  checkmate::assert_string(log)
  path <- run_logged(function() pkgbuild::build(dest_path = tempdir(), quiet = TRUE), log)
  size_mb <- file.size(path) / 1024^2
  pkg <- read.dcf("DESCRIPTION", fields = "Package")[[1]]
  shipped <- utils::untar(path, list = TRUE)
  inst <- if (dir.exists("inst")) list.files("inst", recursive = TRUE, all.files = TRUE) else character()
  absent <- inst[!file.path(pkg, "inst", inst) %in% shipped]
  problems <- character()
  if (size_mb > settings$tarball_mb) {
    problems <- c(
      problems,
      sprintf("%.2f MB is over the %g MB limit (CRAN: under 10 MB)", size_mb, settings$tarball_mb)
    )
  }
  if (length(absent) > 0) {
    problems <- c(problems, paste0("inst/ files not in the tarball: ", toString(absent)))
  }
  if (length(problems) > 0) {
    return(result("FAIL", paste(problems, collapse = "; ")))
  }
  result("PASS", sprintf("%.2f MB (limit %g MB), %d inst/ files shipped", size_mb, settings$tarball_mb, length(inst)))
}

run_step <- function(step, mode, update, uses, settings, run_dir, log, state) {
  checkmate::assert_string(step)
  checkmate::assert_choice(mode, modes)
  checkmate::assert_flag(update)
  checkmate::assert_list(uses, types = "logical")
  checkmate::assert_list(settings)
  checkmate::assert_directory_exists(run_dir)
  checkmate::assert_string(log)
  checkmate::assert_environment(state)
  tryCatch(
    switch(
      step,
      tools = step_tools(mode, uses),
      air = step_air(uses, settings, log),
      biome = step_biome(uses, log),
      docs = step_docs(uses, log),
      lintr = step_lintr(uses, settings, log),
      value = step_value(log),
      spelling = step_spelling(update, log),
      check_fast = step_check(tests = FALSE, log),
      tests = step_tests(uses, run_dir, log, state),
      coverage = step_coverage(uses, settings, log, state),
      check_full = step_check(tests = TRUE, log),
      tarball = step_tarball(settings, log)
    ),
    error = function(e) result("FAIL", conditionMessage(e))
  )
}

# gate.json in the run folder: the mode and one row per step (status, seconds, detail). Rewritten after every step,
# so a gate that is stopped part-way still leaves the steps it finished.
write_gate_json <- function(run_dir, mode, rows) {
  checkmate::assert_directory_exists(run_dir, access = "w")
  checkmate::assert_string(mode)
  checkmate::assert_data_frame(rows)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    return(invisible(FALSE)) # the tools step names jsonlite as missing
  }
  jsonlite::write_json(
    list(mode = mode, run_folder = run_dir, steps = rows),
    file.path(run_dir, "gate.json"),
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = NA
  )
  invisible(TRUE)
}

# What to read after a FAIL: the first 10 test problems, then the last lines of each failed step's log (the whole log
# on CI, where the run folder isn't visible afterwards).
failure_report <- function(failed, run_dir, state, whole_logs) {
  checkmate::assert_character(failed, any.missing = FALSE)
  checkmate::assert_directory_exists(run_dir)
  checkmate::assert_environment(state)
  checkmate::assert_flag(whole_logs)
  out <- character()
  bad <- state$tests$bad
  if ("tests" %in% failed && !is.null(bad) && nrow(bad) > 0) {
    out <- c(
      out,
      sprintf("---- tests: the first %d of %d problems (all in tests.json) ----", min(10, nrow(bad)), nrow(bad)),
      issue_text(utils::head(bad, 10))
    )
  }
  for (step in failed) {
    log <- file.path(run_dir, paste0(step, ".log"))
    lines <- if (file.exists(log)) readLines(log, warn = FALSE) else character()
    if (length(lines) == 0) {
      next
    }
    if (whole_logs) {
      out <- c(out, sprintf("---- %s: log ----", step), lines)
    } else {
      out <- c(out, sprintf("---- %s: the last lines of %s.log ----", step, step), utils::tail(lines, 20))
    }
  }
  out
}

main <- function(args) {
  checkmate::assert_character(args, any.missing = FALSE)
  update <- "--update-wordlist" %in% args
  mode <- setdiff(args, "--update-wordlist")
  mode <- if (length(mode) == 0) "fast" else mode
  checkmate::assert_choice(mode, modes, .var.name = "mode")
  if (!file.exists("DESCRIPTION")) {
    cli::cli_abort("Run the gate from the package root (no DESCRIPTION in {.path {getwd()}}).")
  }
  settings <- tryCatch(read_settings(), error = function(e) conditionMessage(e))
  if (is.character(settings)) {
    cli::cat_line("FAIL settings: ", settings, " (fix the Config/cran-gate fields in DESCRIPTION)")
    cli::cat_line("FAILED: settings")
    quit(status = 1)
  }
  uses <- package_uses()
  run_dir <- run_folder(default_out(), mode)
  state <- new.env()
  state$statuses <- character()
  rows <- data.frame(step = character(), status = character(), seconds = numeric(), detail = character())
  cli::cli_h1("CRAN gate: {mode}")
  cli::cat_line("Run folder: ", run_dir)
  for (step in steps_for(mode)) {
    log <- file.path(run_dir, paste0(step, ".log"))
    file.create(log)
    started <- Sys.time()
    res <- run_step(step, mode, update, uses, settings, run_dir, log, state)
    secs <- as.numeric(difftime(Sys.time(), started, units = "secs"))
    state$statuses[step] <- res$status
    rows[nrow(rows) + 1L, ] <- list(step, res$status, round(secs, 1), res$detail)
    write_gate_json(run_dir, mode, rows)
    detail <- if (nzchar(res$detail)) paste0(": ", res$detail) else ""
    cli::cat_line(sprintf("%-4s %-10s (%3.0fs)%s", res$status, step, secs, detail))
    if (step == "tools" && res$status == "FAIL") {
      break
    }
  }
  statuses <- state$statuses
  failed <- names(statuses)[statuses == "FAIL"]
  cli::cat_line("Run folder: ", run_dir)
  if (length(failed) > 0) {
    cli::cat_line(failure_report(failed, run_dir, state, whole_logs = identical(Sys.getenv("CI"), "true")))
    cli::cat_line("FAILED: ", paste(failed, collapse = ", "))
    quit(status = 1)
  }
  cli::cat_line("All steps passed (", sum(statuses == "SKIP"), " skipped).")
  invisible(statuses)
}

# The gate itself needs checkmate and cli: say so plainly, in base R, when they're missing.
ensure_gate_packages <- function() {
  pkgs <- c("checkmate", "cli")
  absent <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent) > 0) {
    message("FAIL tools: missing R packages ", toString(absent), "; .libPaths()[1] = ", .libPaths()[1])
    message("FAILED: tools")
    quit(status = 1)
  }
}

# Run only under Rscript: sourcing the file (as the self-test does) defines the functions without running the gate.
if (sys.nframe() == 0L) {
  ensure_gate_packages()
  main(commandArgs(trailingOnly = TRUE))
}
