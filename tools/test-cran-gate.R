#!/usr/bin/env Rscript
# Self-test for the CRAN gate (tools/cran-gate.R): a check that can't fail protects nothing.
#
#   Rscript tools/test-cran-gate.R [all|static|heavy]
#
#   static          a clean copy must pass; then one planted defect per lint-mode step (tools, air, biome, docs,
#                   lintr, value, spelling) must make that step FAIL
#   heavy           the same for check_fast, tests, coverage, check_full and tarball (several minutes)
#   all   (default) both
#
# Each probe copies the package (tracked and new files; nothing git ignores) to tempdir(), plants one defect there
# and runs the gate on the copy. PASS means the gate did what the probe expects: exit 1 with FAIL for the named
# step (exit 0 for the clean copy). Exits 1 if any probe isn't caught. The repo itself is never changed.
#
# Run from the package root with the gate's setup (see tools/cran-gate.R). Run it after changing the gate, .lintr,
# air.toml or biome.json; a new gate step gets a probe here in the same PR.

groups <- c("all", "static", "heavy")
rscript <- file.path(R.home("bin"), "Rscript")

# Environment for child processes: this session's library paths (a copy has no renv), plus a probe's own changes.
child_env <- function(extra = character()) {
  checkmate::assert_character(extra, any.missing = FALSE, names = "unique")
  vars <- c(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  vars[names(extra)] <- extra
  c("current", vars)
}

package_files <- function() {
  files <- system2("git", c("ls-files", "--cached", "--others", "--exclude-standard"), stdout = TRUE)
  files[file.exists(files)]
}

fresh_copy <- function(files) {
  checkmate::assert_character(files, min.len = 1, any.missing = FALSE)
  dir <- tempfile("gate-probe-")
  for (sub in unique(dirname(files))) {
    dir.create(file.path(dir, sub), recursive = TRUE, showWarnings = FALSE)
  }
  copied <- file.copy(files, file.path(dir, files))
  if (!all(copied)) {
    cli::cli_abort("Could not copy {.path {files[!copied]}} to {.path {dir}}.")
  }
  dir
}

plant <- function(dir, path, lines, append = FALSE) {
  checkmate::assert_directory_exists(dir)
  checkmate::assert_string(path)
  checkmate::assert_character(lines, any.missing = FALSE)
  checkmate::assert_flag(append)
  target <- file.path(dir, path)
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  write(lines, target, append = append)
}

# An exported, documented function for the documentation probes.
roxygen_function <- function(title, returns = TRUE) {
  checkmate::assert_string(title)
  checkmate::assert_flag(returns)
  c(
    paste0("#' ", title),
    "#'",
    "#' @param x A number.",
    if (returns) "#' @returns A number.",
    "#' @export",
    "probe <- function(x) {",
    "  x",
    "}"
  )
}

document <- function(dir) {
  checkmate::assert_directory_exists(dir)
  run <- processx::run(
    rscript,
    c("-e", "devtools::document(quiet = TRUE)"),
    wd = dir,
    env = child_env(),
    error_on_status = FALSE,
    stderr_to_stdout = TRUE
  )
  if (run$status != 0) {
    cli::cli_abort(c("devtools::document() failed in the copy.", run$stdout))
  }
}

# A probe: the gate mode to run, the defect to plant, and the steps that must FAIL (none: the gate must pass).
probe <- function(
  name,
  group,
  mode,
  plant,
  expect_fail = character(),
  expect_pass = character(),
  detail = NULL,
  env = character(),
  skip = function() NULL
) {
  checkmate::assert_string(name)
  checkmate::assert_choice(group, c("static", "heavy"))
  checkmate::assert_choice(mode, c("fast", "tests", "full", "lint"))
  checkmate::assert_function(plant)
  checkmate::assert_character(expect_fail, any.missing = FALSE)
  checkmate::assert_character(expect_pass, any.missing = FALSE)
  checkmate::assert_string(detail, null.ok = TRUE)
  checkmate::assert_character(env, names = "unique")
  checkmate::assert_function(skip)
  list(
    name = name,
    group = group,
    mode = mode,
    plant = plant,
    expect_fail = expect_fail,
    expect_pass = expect_pass,
    detail = detail,
    env = env,
    skip = skip
  )
}

# PATH for the "Air is missing" probe: enough for R to start, without the places tools are installed to.
bare_path <- "/usr/bin:/bin"

# Library settings that leave only R's own packages, for the "gate's packages are missing" probe.
no_packages_env <- function() {
  nowhere <- file.path(tempdir(), "no-library")
  c(R_LIBS = nowhere, R_LIBS_SITE = nowhere, R_LIBS_USER = nowhere)
}

gate_packages_still_found <- function() {
  code <- "cat(requireNamespace('checkmate', quietly = TRUE) || requireNamespace('cli', quietly = TRUE))"
  run <- processx::run(
    rscript,
    c("-e", code),
    wd = tempdir(),
    env = child_env(no_packages_env()),
    error_on_status = FALSE
  )
  !identical(run$stdout, "FALSE")
}

static_probes <- function() {
  has_biome <- nzchar(Sys.which("biome"))
  list(
    probe("clean copy passes", "static", "lint", function(dir) NULL),
    probe(
      "tools: the gate's own packages are missing",
      "static",
      "lint",
      function(dir) NULL,
      expect_fail = "tools",
      env = no_packages_env(),
      skip = function() {
        if (gate_packages_still_found()) "checkmate or cli is in R's own library here; can't hide them"
      }
    ),
    probe(
      "tools: Air isn't on the PATH",
      "static",
      "lint",
      function(dir) NULL,
      expect_fail = "tools",
      detail = "missing: air",
      env = c(PATH = bare_path),
      skip = function() {
        if (any(file.exists(file.path(strsplit(bare_path, ":", fixed = TRUE)[[1]], "air")))) {
          "Air is installed in /usr/bin or /bin here; can't hide it"
        }
      }
    ),
    probe(
      "air: an unformatted R file",
      "static",
      "lint",
      function(dir) plant(dir, "R/probe.R", "f <- function(x){x+1}"),
      expect_fail = "air"
    ),
    # With Biome installed the biome step must fail; without it the tools step must (JS present, no Biome).
    probe(
      if (has_biome) "biome: an unformatted JS file" else "tools: JS in inst/ but Biome isn't installed",
      "static",
      "lint",
      function(dir) plant(dir, "inst/www/probe.js", c("var a=1", "function f( x ){return x}")),
      expect_fail = if (has_biome) "biome" else "tools"
    ),
    probe(
      "docs: roxygen comments changed, document() not run",
      "static",
      "lint",
      function(dir) plant(dir, "R/probe.R", roxygen_function("Probe")),
      expect_fail = "docs"
    ),
    probe(
      "lintr: print() in package code",
      "static",
      "lint",
      function(dir) plant(dir, "R/probe.R", c("probe <- function(x) {", "  print(x)", "}")),
      expect_fail = "lintr"
    ),
    probe(
      "value: an exported function without @returns",
      "static",
      "lint",
      function(dir) {
        plant(dir, "R/probe.R", roxygen_function("Probe", returns = FALSE))
        document(dir)
      },
      expect_fail = "value",
      expect_pass = "docs"
    ),
    probe(
      "spelling: a misspelt word in a help page",
      "static",
      "lint",
      function(dir) {
        plant(dir, "R/probe.R", roxygen_function("Probe the mascott"))
        document(dir)
      },
      expect_fail = "spelling",
      detail = "mascott",
      expect_pass = "docs"
    )
  )
}

heavy_probes <- function() {
  # Enough untested lines to pull any coverage under 90%, however large the package gets.
  r_lines <- sum(lengths(lapply(list.files("R", full.names = TRUE), readLines, warn = FALSE)))
  untested <- c("probe <- function(x) {", rep("  x <- x + 1", max(50, r_lines)), "  x", "}")
  needs_not_cran <- c(
    "describe(\"the gate's tests step\", {",
    "  it(\"runs with NOT_CRAN=true\", {",
    "    expect_identical(Sys.getenv(\"NOT_CRAN\"), \"true\")",
    "  })",
    "})"
  )
  failing_test <- c("describe(\"probe\", {", "  it(\"fails\", {", "    expect_true(FALSE)", "  })", "})")
  list(
    probe(
      "check_fast: a note (unexpected top-level file)",
      "heavy",
      "fast",
      function(dir) plant(dir, "probe-note.txt", "x"),
      expect_fail = "check_fast",
      detail = "0 errors, 0 warnings, " # so the FAIL is for a note alone
    ),
    probe(
      "tests: a failing test",
      "heavy",
      "tests",
      function(dir) plant(dir, "tests/testthat/test-probe.R", failing_test),
      expect_fail = "tests"
    ),
    probe(
      "coverage: untested code",
      "heavy",
      "tests",
      function(dir) plant(dir, "R/probe.R", untested),
      expect_fail = "coverage",
      expect_pass = "tests"
    ),
    # One full run, two defects: a test that only passes with NOT_CRAN=true (so it passes in the tests step and
    # fails in the CRAN-like check), and a file in inst/ that .Rbuildignore keeps out of the tarball.
    probe(
      "check_full and tarball: a test that needs NOT_CRAN; an inst/ file left out of the build",
      "heavy",
      "full",
      function(dir) {
        plant(dir, "tests/testthat/test-probe.R", needs_not_cran)
        plant(dir, "inst/probe-secret.txt", "x")
        plant(dir, ".Rbuildignore", "^inst/probe-secret\\.txt$", append = TRUE)
      },
      expect_fail = c("check_full", "tarball"),
      expect_pass = "tests"
    )
  )
}

# The gate's step lines ("PASS air ( 1s)", "FAIL tools: ...") as a named vector of the lines, keyed by step.
step_lines <- function(output) {
  checkmate::assert_string(output)
  lines <- strsplit(output, "\r?\n")[[1]]
  lines <- lines[grepl("^(PASS|FAIL|SKIP) +[a-z_]+", lines)]
  stats::setNames(lines, sub("^(PASS|FAIL|SKIP) +([a-z_]+).*$", "\\2", lines))
}

# What's wrong with a gate run, given what the probe expects; empty when the gate behaved as expected.
problems <- function(probe, status, lines) {
  checkmate::assert_list(probe)
  checkmate::assert_int(status)
  checkmate::assert_character(lines)
  state <- substr(lines, 1, 4)
  want_exit <- if (length(probe$expect_fail) > 0) 1L else 0L
  out <- character()
  if (status != want_exit) {
    out <- c(out, sprintf("exit %d, expected %d", status, want_exit))
  }
  not_failed <- setdiff(probe$expect_fail, names(state)[state == "FAIL"])
  if (length(not_failed) > 0) {
    out <- c(out, paste("no FAIL for", toString(not_failed)))
  }
  not_passed <- setdiff(probe$expect_pass, names(state)[state == "PASS"])
  if (length(not_passed) > 0) {
    out <- c(out, paste("no PASS for", toString(not_passed)))
  }
  if (length(probe$expect_fail) == 0 && any(state == "FAIL")) {
    out <- c(out, paste("unexpected FAIL for", toString(names(state)[state == "FAIL"])))
  }
  if (!is.null(probe$detail) && length(not_failed) == 0) {
    line <- lines[[probe$expect_fail[1]]]
    if (!grepl(probe$detail, line, fixed = TRUE)) {
      out <- c(out, sprintf("the FAIL line doesn't mention '%s'", probe$detail))
    }
  }
  out
}

run_probe <- function(probe, files) {
  checkmate::assert_list(probe)
  checkmate::assert_character(files, min.len = 1, any.missing = FALSE)
  reason <- probe$skip()
  if (!is.null(reason)) {
    return(list(status = "SKIP", detail = reason, output = ""))
  }
  dir <- fresh_copy(files)
  on.exit(unlink(dir, recursive = TRUE))
  probe$plant(dir)
  run <- processx::run(
    rscript,
    c("tools/cran-gate.R", probe$mode),
    wd = dir,
    env = child_env(probe$env),
    error_on_status = FALSE,
    stderr_to_stdout = TRUE
  )
  lines <- step_lines(run$stdout)
  wrong <- problems(probe, run$status, lines)
  if (length(wrong) > 0) {
    return(list(status = "FAIL", detail = paste(wrong, collapse = "; "), output = run$stdout))
  }
  failed <- names(lines)[substr(lines, 1, 4) == "FAIL"]
  detail <- if (length(failed) > 0) paste("gate reported FAIL for", toString(failed)) else "gate passed"
  list(status = "PASS", detail = detail, output = run$stdout)
}

main <- function(args) {
  checkmate::assert_character(args, any.missing = FALSE, max.len = 1)
  group <- if (length(args) == 0) "all" else args
  checkmate::assert_choice(group, groups, .var.name = "group")
  if (!file.exists("DESCRIPTION") || !file.exists("tools/cran-gate.R")) {
    cli::cli_abort("Run the self-test from the package root (no gate in {.path {getwd()}}).")
  }
  probes <- c(
    if (group %in% c("all", "static")) static_probes(),
    if (group %in% c("all", "heavy")) heavy_probes()
  )
  files <- package_files()
  cli::cli_h1("CRAN gate self-test: {group} ({length(probes)} probes)")
  statuses <- character()
  for (probe in probes) {
    started <- Sys.time()
    res <- tryCatch(
      run_probe(probe, files),
      error = function(e) list(status = "FAIL", detail = conditionMessage(e), output = "")
    )
    secs <- as.numeric(difftime(Sys.time(), started, units = "secs"))
    statuses[probe$name] <- res$status
    cli::cat_line(sprintf("%-4s (%3.0fs) %s: %s", res$status, secs, probe$name, res$detail))
    if (res$status == "FAIL" && nzchar(res$output)) {
      cli::cat_line(paste0("    | ", strsplit(res$output, "\r?\n")[[1]]))
    }
  }
  failed <- names(statuses)[statuses == "FAIL"]
  if (length(failed) > 0) {
    cli::cat_line(
      "FAILED: the gate did not behave as expected for ",
      length(failed),
      " of ",
      length(probes),
      " probes."
    )
    quit(status = 1)
  }
  cli::cat_line("All probes behaved as expected (", sum(statuses == "SKIP"), " skipped).")
  invisible(statuses)
}

# Like the gate: say plainly, in base R, when the packages this script needs are missing.
ensure_packages <- function() {
  pkgs <- c("checkmate", "cli", "processx")
  absent <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent) > 0) {
    message("Missing R packages: ", toString(absent), "; .libPaths()[1] = ", .libPaths()[1])
    quit(status = 1)
  }
}

ensure_packages()
main(commandArgs(trailingOnly = TRUE))
