#!/usr/bin/env Rscript
# CRAN gate for mascot: one command for the checks CRAN and our house rules need.
#
#   Rscript tools/cran-gate.R [fast|tests|full|lint] [--update-wordlist]
#
#   fast  (default) tools, formatting, docs in sync, lint, \value, spelling, R CMD check --as-cran without tests
#   tests           tools, tests (NOT_CRAN=true, so Chrome tests run) and coverage (at least 90%)
#   full            everything: fast steps, tests, coverage, CRAN-like check with tests, built tarball
#   lint            what the CI lint job runs: tools, formatting, docs in sync, lint, \value, spelling
#
# Prints one PASS/FAIL/SKIP line per step and a summary; exits 1 if any step fails. Detailed output goes to a log
# file in tempdir() whose path is printed. Run from the package root, with the dev packages on .libPaths()
# (renv in the main checkout; in a worktree, set R_LIBS to what `Rscript -e 'cat(.libPaths()[1])'` prints there).
#
# Writes to the repo: devtools::document() may rewrite man/, NAMESPACE and DESCRIPTION (the docs step then fails
# and names the files); --update-wordlist rewrites inst/WORDLIST. Nothing else outside tempdir().

modes <- c("fast", "tests", "full", "lint")
min_coverage <- 90
max_tarball_mb <- 5 # house target; CRAN: under 10 MB if possible

required_packages <- function(mode) {
  checkmate::assert_choice(mode, modes)
  pkgs <- c("checkmate", "cli", "devtools", "roxygen2", "lintr", "spelling")
  if (mode %in% c("tests", "full")) {
    pkgs <- c(pkgs, "testthat", "covr", "withr")
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

step_tools <- function(mode) {
  checkmate::assert_choice(mode, modes)
  missing <- character()
  if (!nzchar(Sys.which("air"))) {
    missing <- c(missing, "air (https://posit-dev.github.io/air/)")
  }
  if (length(js_css_files()) > 0 && !nzchar(Sys.which("biome"))) {
    missing <- c(missing, "biome (https://biomejs.dev), needed because inst/ has JS or CSS")
  }
  pkgs <- required_packages(mode)
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

step_air <- function(log) {
  checkmate::assert_string(log)
  out <- suppressWarnings(system2("air", c("format", "--check", "."), stdout = TRUE, stderr = TRUE))
  write(out, log, append = TRUE)
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    return(result("FAIL", paste0("run `air format .`; ", paste(utils::head(out, 3), collapse = " | "))))
  }
  result("PASS")
}

step_biome <- function(log) {
  checkmate::assert_string(log)
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
# roxygen2 version on CI doesn't count as out-of-date docs.
docs_snapshot <- function() {
  files <- c("NAMESPACE", list.files("man", full.names = TRUE))
  files <- files[file.exists(files)]
  hashes <- unname(tools::md5sum(files))
  desc <- readLines("DESCRIPTION", warn = FALSE)
  desc <- desc[!grepl("^(RoxygenNote|Config/roxygen2/version):", desc)]
  stats::setNames(c(hashes, paste(desc, collapse = "\n")), c(files, "DESCRIPTION"))
}

step_docs <- function(log) {
  checkmate::assert_string(log)
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

step_lintr <- function(log) {
  checkmate::assert_string(log)
  # lint_package() covers R/, tests/ and inst/; tools/ (this script) is linted too.
  lints <- c(lintr::lint_package(), lintr::lint_dir("tools"))
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

# Exported functions whose help page has no \value section (CRAN reviewers ask for one on every function).
step_value <- function() {
  ns <- readLines("NAMESPACE", warn = FALSE)
  exports <- sub("^export\\((.+)\\)$", "\\1", ns[grepl("^export\\(", ns)])
  exports <- gsub("[`\"]", "", exports)
  pkg_env <- asNamespace(read.dcf("DESCRIPTION", fields = "Package")[[1]])
  exports <- exports[vapply(exports, function(x) is.function(get0(x, envir = pkg_env)), logical(1))]
  if (length(exports) == 0) {
    return(result("PASS", "no exported functions yet"))
  }
  missing <- character()
  for (rd in tools::Rd_db(dir = ".")) {
    tags <- rd_tags(rd)
    aliases <- unlist(lapply(rd[tags == "\\alias"], as.character))
    if (any(aliases %in% exports) && !"\\value" %in% tags) {
      missing <- c(missing, intersect(aliases, exports))
    }
  }
  if (length(missing) > 0) {
    return(result("FAIL", paste0("add @returns to: ", paste(missing, collapse = ", "))))
  }
  result("PASS", paste(length(exports), "exported functions"))
}

step_spelling <- function(update, log) {
  checkmate::assert_flag(update)
  checkmate::assert_string(log)
  words <- spelling::spell_check_package(".")
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

check_result <- function(res) {
  checkmate::assert_class(res, "rcmdcheck")
  counts <- c(errors = length(res$errors), warnings = length(res$warnings), notes = length(res$notes))
  detail <- paste(counts, names(counts), collapse = ", ")
  if (sum(counts) > 0) {
    first <- strsplit(c(res$errors, res$warnings, res$notes)[1], "\n", fixed = TRUE)[[1]][1]
    return(result("FAIL", paste0(detail, "; first: ", first)))
  }
  result("PASS", detail)
}

# CRAN-like check: NOT_CRAN=false so Chrome tests skip as on CRAN (devtools::check() sets NOT_CRAN=true by default).
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

step_tests <- function(log) {
  checkmate::assert_string(log)
  withr::local_envvar(NOT_CRAN = "true")
  res <- run_logged(function() devtools::test(stop_on_failure = TRUE, reporter = "summary"), log)
  df <- as.data.frame(res)
  result("PASS", paste0(sum(df$nb), " expectations, ", sum(df$skipped), " skipped"))
}

step_coverage <- function(log) {
  checkmate::assert_string(log)
  withr::local_envvar(NOT_CRAN = "true")
  cov <- run_logged(function() covr::package_coverage(quiet = TRUE), log)
  if (nrow(as.data.frame(cov)) == 0) {
    return(result("PASS", "no R code lines to cover yet"))
  }
  pct <- covr::percent_coverage(cov)
  if (pct < min_coverage) {
    return(result("FAIL", sprintf("%.1f%% is under %d%%; see covr::zero_coverage()", pct, min_coverage)))
  }
  result("PASS", sprintf("%.1f%%", pct))
}

step_tarball <- function(log) {
  checkmate::assert_string(log)
  path <- run_logged(function() pkgbuild::build(dest_path = tempdir(), quiet = TRUE), log)
  size_mb <- file.size(path) / 1024^2
  pkg <- read.dcf("DESCRIPTION", fields = "Package")[[1]]
  shipped <- utils::untar(path, list = TRUE)
  inst <- if (dir.exists("inst")) list.files("inst", recursive = TRUE, all.files = TRUE) else character()
  absent <- inst[!file.path(pkg, "inst", inst) %in% shipped]
  problems <- character()
  if (size_mb > max_tarball_mb) {
    problems <- c(problems, sprintf("%.2f MB is over the %d MB house target", size_mb, max_tarball_mb))
  }
  if (length(absent) > 0) {
    problems <- c(problems, paste0("inst/ files not in the tarball: ", toString(absent)))
  }
  if (length(problems) > 0) {
    return(result("FAIL", paste(problems, collapse = "; ")))
  }
  result("PASS", sprintf("%.2f MB, %d inst/ files shipped", size_mb, length(inst)))
}

run_step <- function(step, mode, update, log) {
  checkmate::assert_string(step)
  checkmate::assert_choice(mode, modes)
  checkmate::assert_flag(update)
  checkmate::assert_string(log)
  tryCatch(
    switch(
      step,
      tools = step_tools(mode),
      air = step_air(log),
      biome = step_biome(log),
      docs = step_docs(log),
      lintr = step_lintr(log),
      value = step_value(),
      spelling = step_spelling(update, log),
      check_fast = step_check(tests = FALSE, log),
      tests = step_tests(log),
      coverage = step_coverage(log),
      check_full = step_check(tests = TRUE, log),
      tarball = step_tarball(log)
    ),
    error = function(e) result("FAIL", conditionMessage(e))
  )
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
  log <- tempfile("cran-gate-", fileext = ".log")
  file.create(log)
  cli::cli_h1("CRAN gate: {mode}")
  statuses <- character()
  for (step in steps_for(mode)) {
    started <- Sys.time()
    res <- run_step(step, mode, update, log)
    secs <- as.numeric(difftime(Sys.time(), started, units = "secs"))
    statuses[step] <- res$status
    detail <- if (nzchar(res$detail)) paste0(": ", res$detail) else ""
    cli::cat_line(sprintf("%-4s %-10s (%3.0fs)%s", res$status, step, secs, detail))
    if (step == "tools" && res$status == "FAIL") {
      break
    }
  }
  failed <- names(statuses)[statuses == "FAIL"]
  cli::cat_line("Log: ", log)
  if (length(failed) > 0 && identical(Sys.getenv("CI"), "true")) {
    # On CI the log file isn't visible afterwards, so show it.
    cli::cat_line("---- log ----")
    cli::cat_line(readLines(log, warn = FALSE))
  }
  if (length(failed) > 0) {
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

ensure_gate_packages()
main(commandArgs(trailingOnly = TRUE))
