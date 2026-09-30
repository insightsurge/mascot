#!/usr/bin/env Rscript
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
# fails. Detailed output goes to a log file in tempdir() whose path is printed.
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
# Needs the R packages checkmate, cli, devtools and spelling, plus roxygen2, lintr, covr, withr and pkgbuild for the
# steps that use them; the tools step names whatever is missing.
#
# Writes to the package: devtools::document() may rewrite man/, NAMESPACE and DESCRIPTION (the docs step then fails
# and names the files); --update-wordlist rewrites inst/WORDLIST. Nothing else outside tempdir().

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
  pkgs <- c("checkmate", "cli", "devtools", "spelling")
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

step_tests <- function(uses, log) {
  checkmate::assert_list(uses, types = "logical")
  checkmate::assert_string(log)
  if (!uses$testthat) {
    return(result("SKIP", "no tests/testthat (R CMD check still runs whatever is in tests/)"))
  }
  withr::local_envvar(NOT_CRAN = "true")
  res <- run_logged(function() devtools::test(stop_on_failure = TRUE, reporter = "summary"), log)
  df <- as.data.frame(res)
  result("PASS", paste0(sum(df$nb), " expectations, ", sum(df$skipped), " skipped"))
}

step_coverage <- function(uses, settings, log) {
  checkmate::assert_list(uses, types = "logical")
  checkmate::assert_list(settings)
  checkmate::assert_string(log)
  if (!uses$tests) {
    return(result("SKIP", "the package has no tests/"))
  }
  withr::local_envvar(NOT_CRAN = "true")
  cov <- run_logged(function() covr::package_coverage(quiet = TRUE), log)
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

run_step <- function(step, mode, update, uses, settings, log) {
  checkmate::assert_string(step)
  checkmate::assert_choice(mode, modes)
  checkmate::assert_flag(update)
  checkmate::assert_list(uses, types = "logical")
  checkmate::assert_list(settings)
  checkmate::assert_string(log)
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
      tests = step_tests(uses, log),
      coverage = step_coverage(uses, settings, log),
      check_full = step_check(tests = TRUE, log),
      tarball = step_tarball(settings, log)
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
  settings <- tryCatch(read_settings(), error = function(e) conditionMessage(e))
  if (is.character(settings)) {
    cli::cat_line("FAIL settings: ", settings, " (fix the Config/cran-gate fields in DESCRIPTION)")
    cli::cat_line("FAILED: settings")
    quit(status = 1)
  }
  uses <- package_uses()
  log <- tempfile("cran-gate-", fileext = ".log")
  file.create(log)
  cli::cli_h1("CRAN gate: {mode}")
  statuses <- character()
  for (step in steps_for(mode)) {
    started <- Sys.time()
    res <- run_step(step, mode, update, uses, settings, log)
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
