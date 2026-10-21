#!/usr/bin/env Rscript
# cran-gate version: 2026-10-21
# Self-test for the CRAN gate (cran-gate.R, in the same folder): a check that can't fail protects nothing.
#
#   Rscript <path to this file> [all|unit|static|heavy] [step,step,...]
#
#   A list of steps (for example `heavy tests,coverage`) runs only the probes that expect one of them to FAIL or PASS.
#
#   unit            the gate's reporting code, sourced without running the gate and fed a real testthat results
#                   object from a tiny temporary test folder (seconds)
#   static          a clean copy of the package must pass; then one planted defect per quick step (settings,
#                   tools, air, biome, docs, lintr, value, spelling) must make that step FAIL
#   heavy           the same for check_fast, tests, coverage, check_full and tarball, on a tiny generated package
#                   (a few minutes, not the hours the real package's own suite would need)
#   all   (default) all three; static also checks that this folder's gate and the skill's copy are the same files
#
# Run it from the root of a package that passes the gate. Each probe copies the package to tempdir() (tracked and
# new files in a git repository; nothing git ignores; the heavy probes copy the tiny generated package instead),
# plants one defect in the copy and runs the gate on it. PASS
# means the gate did what the probe expects: exit 1 with FAIL for the named step (exit 0 for the clean copy). A
# probe for a step this package doesn't use (no air.toml, no .lintr, no tests...) is skipped. Exits 1 if the gate
# misses a defect. The package itself is never changed.
#
# Run it after changing the gate or the settings it reads (.lintr, air.toml, biome.json, the Config/cran-gate
# fields); a new gate step gets a probe here at the same time.

groups <- c("all", "unit", "static", "heavy")
rscript <- file.path(R.home("bin"), "Rscript")

# The gate is the file next to this one, wherever the skill is installed.
gate_path <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 0) {
    cli::cli_abort("Run this file with Rscript, so it can find cran-gate.R beside it.")
  }
  file.path(dirname(normalizePath(sub("^--file=", "", file_arg[1]))), "cran-gate.R")
}

# What this package uses (the same tests as the gate), which decides the probes that apply.
package_uses <- function() {
  fields <- read.dcf("DESCRIPTION", fields = c("Roxygen", "RoxygenNote", "Config/roxygen2/version"))
  coverage <- read.dcf("DESCRIPTION", fields = "Config/cran-gate/coverage")[[1]]
  list(
    air = any(file.exists(c("air.toml", ".air.toml"))),
    lintr = any(file.exists(c(".lintr", ".lintr.R"))),
    biome = any(file.exists(c("biome.json", "biome.jsonc"))),
    roxygen = !all(is.na(fields)),
    testthat = dir.exists("tests/testthat"),
    coverage_limit = is.na(coverage) || !identical(as.numeric(coverage), 0)
  )
}

# Environment for child processes: this session's library paths (a copy may have no renv), plus a probe's own changes.
child_env <- function(extra = character()) {
  checkmate::assert_character(extra, any.missing = FALSE, names = "unique")
  vars <- c(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  vars[names(extra)] <- extra
  c("current", vars)
}

package_files <- function() {
  if (dir.exists(".git") || file.exists(".git")) {
    files <- system2("git", c("ls-files", "--cached", "--others", "--exclude-standard"), stdout = TRUE)
  } else {
    files <- list.files(".", recursive = TRUE, all.files = TRUE)
    files <- files[!grepl("^(renv|\\.Rproj\\.user)/|\\.Rcheck/", files)]
  }
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
    "gate_probe <- function(x) {",
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
# `skip` is a reason not to run it here (NULL: run it).
probe <- function(
  name,
  group,
  mode,
  plant,
  expect_fail = character(),
  expect_pass = character(),
  detail = NULL,
  env = character(),
  skip = NULL,
  package = "real",
  check_output = NULL,
  args = character(),
  expect_exit = NULL
) {
  checkmate::assert_string(name)
  checkmate::assert_choice(group, c("static", "heavy"))
  checkmate::assert_choice(mode, c("fast", "tests", "full", "lint", "nosuggests"))
  checkmate::assert_function(plant)
  checkmate::assert_character(expect_fail, any.missing = FALSE)
  checkmate::assert_character(expect_pass, any.missing = FALSE)
  checkmate::assert_string(detail, null.ok = TRUE)
  checkmate::assert_character(env, names = "unique")
  checkmate::assert_string(skip, null.ok = TRUE)
  checkmate::assert_choice(package, c("real", "fixture"))
  checkmate::assert_function(check_output, null.ok = TRUE)
  checkmate::assert_character(args, any.missing = FALSE)
  checkmate::assert_int(expect_exit, null.ok = TRUE)
  list(
    name = name,
    group = group,
    mode = mode,
    plant = plant,
    expect_fail = expect_fail,
    expect_pass = expect_pass,
    detail = detail,
    env = env,
    skip = skip,
    package = package,
    check_output = check_output,
    args = args,
    expect_exit = expect_exit
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

# A tiny package for the heavy probes: they plant one defect in a copy and run the gate on it, so a probe takes seconds
# of test time instead of the minutes or hours of the real package's suite. It has an exported, documented, tested
# function, no air.toml, .lintr or biome.json (those steps skip), and no Suggests besides testthat.
fixture_package <- function() {
  dir <- tempfile("gate-fixture-")
  dir.create(dir)
  roxygen <- as.character(utils::packageVersion("roxygen2"))
  plant(
    dir,
    "DESCRIPTION",
    c(
      "Package: fixturepkg",
      "Title: A Tiny Package for the Gate's Self-Test",
      "Version: 0.0.1",
      "Authors@R: person(\"Gate\", \"Fixture\", email = \"gate@example.com\", role = c(\"aut\", \"cre\", \"cph\"))",
      "Description: Holds one small function so the self-test can plant defects in a copy and see the gate notice.",
      "License: GPL-3",
      "Encoding: UTF-8",
      "Roxygen: list(markdown = TRUE)",
      paste0("RoxygenNote: ", roxygen),
      "Suggests: testthat (>= 3.0.0)",
      "Config/testthat/edition: 3"
    )
  )
  plant(
    dir,
    "R/add-one.R",
    c(
      "#' Add one",
      "#'",
      "#' @param x A number.",
      "#' @returns A number, one more than `x`.",
      "#' @export",
      "#' @examples",
      "#' add_one(1)",
      "add_one <- function(x) {",
      "  stopifnot(is.numeric(x))",
      "  x + 1",
      "}"
    )
  )
  plant(dir, "tests/testthat.R", c("library(testthat)", "library(fixturepkg)", "test_check(\"fixturepkg\")"))
  plant(
    dir,
    "tests/testthat/test-add-one.R",
    c("test_that(\"add_one adds one\", {", "  expect_equal(add_one(1), 2)", "})")
  )
  document(dir)
  dir
}

# A fresh copy of a directory (the fixture), so one probe's defect never reaches the next.
copy_dir <- function(from) {
  checkmate::assert_directory_exists(from)
  dir <- tempfile("gate-probe-")
  dir.create(dir)
  kids <- list.files(from, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  if (!all(file.copy(kids, dir, recursive = TRUE))) {
    cli::cli_abort("Could not copy {.path {from}} to {.path {dir}}.")
  }
  dir
}

static_probes <- function(uses) {
  checkmate::assert_list(uses, types = "logical")
  has_biome <- nzchar(Sys.which("biome"))
  air_in_bare_path <- any(file.exists(file.path(strsplit(bare_path, ":", fixed = TRUE)[[1]], "air")))
  no_roxygen <- if (!uses$roxygen) "the package doesn't use roxygen2"
  list(
    probe("clean copy passes", "static", "lint", function(dir) NULL),
    probe(
      "settings: a tarball limit above 9 MB",
      "static",
      "lint",
      function(dir) {
        desc <- readLines(file.path(dir, "DESCRIPTION"), warn = FALSE)
        desc <- c(desc[!grepl("^Config/cran-gate/tarball-mb:", desc)], "Config/cran-gate/tarball-mb: 12")
        plant(dir, "DESCRIPTION", desc)
      },
      expect_fail = "settings",
      detail = "tarball-mb",
      expect_exit = 2L
    ),
    probe(
      "tools: the gate's own packages are missing",
      "static",
      "lint",
      function(dir) NULL,
      expect_fail = "tools",
      expect_exit = 2L,
      env = no_packages_env(),
      skip = if (gate_packages_still_found()) "checkmate or cli is in R's own library here; can't hide them"
    ),
    probe(
      "tools: Air isn't on the PATH",
      "static",
      "lint",
      function(dir) NULL,
      expect_fail = "tools",
      expect_exit = 2L,
      detail = "missing: air",
      env = c(PATH = bare_path),
      skip = if (!uses$air) {
        "the package doesn't use Air (no air.toml)"
      } else if (air_in_bare_path) {
        "Air is installed in /usr/bin or /bin here; can't hide it"
      }
    ),
    probe(
      "air: an unformatted R file",
      "static",
      "lint",
      function(dir) plant(dir, "R/zz-gate-probe.R", "gate_probe <- function(x){x+1}"),
      expect_fail = "air",
      skip = if (!uses$air) "the package doesn't use Air (no air.toml)"
    ),
    # With Biome installed the biome step must fail; without it the tools step must (JS present, no Biome).
    probe(
      if (has_biome) "biome: an unformatted JS file" else "tools: JS in inst/ but Biome isn't installed",
      "static",
      "lint",
      function(dir) plant(dir, "inst/www/gate-probe.js", c("var a=1", "function f( x ){return x}")),
      expect_fail = if (has_biome) "biome" else "tools",
      expect_exit = if (has_biome) NULL else 2L,
      skip = if (!uses$biome) "the package doesn't use Biome (no biome.json)"
    ),
    probe(
      "docs: roxygen comments changed, document() not run",
      "static",
      "lint",
      function(dir) plant(dir, "R/zz-gate-probe.R", roxygen_function("Probe")),
      expect_fail = "docs",
      skip = no_roxygen
    ),
    # Several lints at once (= for assignment, a semicolon, T for TRUE, trailing spaces), so at least one is caught
    # whatever the package's .lintr turns off.
    probe(
      "lintr: code with lints",
      "static",
      "lint",
      function(dir) plant(dir, "R/zz-gate-probe.R", c("gate_probe = function(x) {", "  y = x; T  ", "}")),
      expect_fail = "lintr",
      skip = if (!uses$lintr) "the package doesn't use lintr (no .lintr)"
    ),
    probe(
      "value: an exported function without @returns",
      "static",
      "lint",
      function(dir) {
        plant(dir, "R/zz-gate-probe.R", roxygen_function("Probe", returns = FALSE))
        document(dir)
      },
      expect_fail = "value",
      expect_pass = "docs",
      detail = "gate_probe",
      skip = no_roxygen
    ),
    probe(
      "spelling: a misspelt word in a help page",
      "static",
      "lint",
      function(dir) {
        plant(dir, "R/zz-gate-probe.R", roxygen_function("Probe the speling"))
        document(dir)
      },
      expect_fail = "spelling",
      detail = "speling",
      expect_pass = "docs",
      skip = no_roxygen
    ),
    probe(
      "--steps: only the named steps run and the run is marked PARTIAL",
      "static",
      "lint",
      function(dir) NULL,
      expect_pass = "spelling",
      package = "fixture",
      args = c("--steps", "spelling"),
      check_output = function(output) {
        out <- character()
        if (!grepl("(^|\n)PARTIAL: only tools, spelling", output)) {
          out <- c(out, "no PARTIAL line")
        }
        if (grepl("(^|\n)(PASS|SKIP|FAIL) +docs", output)) {
          out <- c(out, "docs ran")
        }
        out
      }
    ),
    probe(
      "--list: the steps of each mode, then stop",
      "static",
      "lint",
      function(dir) NULL,
      package = "fixture",
      args = "--list",
      check_output = function(output) {
        if (
          grepl("nosuggests: tools, nosuggests", output, fixed = TRUE) &&
            grepl("skips: no air.toml", output, fixed = TRUE)
        ) {
          character()
        } else {
          "the list lacks the nosuggests mode or the reason a step skips"
        }
      }
    ),
    probe(
      "--help: usage and exit codes",
      "static",
      "lint",
      function(dir) NULL,
      package = "fixture",
      args = "--help",
      check_output = function(output) {
        if (grepl("Exit codes:", output, fixed = TRUE)) character() else "no exit codes shown"
      }
    ),
    probe(
      "usage: an unknown option exits 2",
      "static",
      "lint",
      function(dir) NULL,
      expect_fail = "usage",
      package = "fixture",
      args = "--bogus",
      expect_exit = 2L,
      check_output = function(output) {
        if (grepl("FAIL usage: unknown option --bogus", output, fixed = TRUE)) character() else "no usage message"
      }
    ),
    probe(
      "pkgdown: a reference entry for a topic that doesn't exist",
      "static",
      "lint",
      function(dir) {
        plant(dir, "_pkgdown.yml", c("reference:", "- title: Everything", "  contents:", "  - not_a_topic"))
      },
      expect_fail = "pkgdown",
      package = "fixture",
      skip = if (!requireNamespace("pkgdown", quietly = TRUE)) "pkgdown isn't installed here"
    )
  )
}

# The run folder the gate printed ("Run folder: <path>"), or NA.
printed_run_folder <- function(output) {
  checkmate::assert_string(output)
  line <- grep("^Run folder: ", strsplit(output, "\r?\n")[[1]], value = TRUE)
  if (length(line) == 0) NA_character_ else sub("^Run folder: ", "", line[[1]])
}

heavy_probes <- function() {
  untested <- c("gate_probe <- function(x) {", rep("  x <- x + 1", 100), "  x", "}")
  needs_not_cran <- c(
    "test_that(\"the gate's tests step runs with NOT_CRAN=true\", {",
    "  expect_identical(Sys.getenv(\"NOT_CRAN\"), \"true\")",
    "})"
  )
  failing_test <- c("test_that(\"the gate probe fails\", {", "  expect_true(FALSE)", "})")
  # Fails the first time it runs (the counter file doesn't exist yet) and passes after: the gate's re-run sees it pass.
  flaky_test <- c(
    "test_that(\"the gate probe fails once\", {",
    "  counter <- Sys.getenv(\"GATE_PROBE_COUNTER\")",
    "  first <- !file.exists(counter)",
    "  file.create(counter)",
    "  expect_false(first)",
    "})"
  )
  # A cascade: a shared resource (think of one browser for the whole run) closes in the first file, the first time the
  # suite runs, and every later file that uses it fails with the same message. A fresh process starts a new one.
  shared_resource <- c(
    "shared <- new.env()",
    "use_resource <- function() {",
    "  if (isTRUE(shared$closed)) stop(\"The shared resource has been closed.\")",
    "  TRUE",
    "}"
  )
  closes_once <- c(
    "test_that(\"the shared resource closes the first time\", {",
    "  counter <- Sys.getenv(\"GATE_PROBE_COUNTER\")",
    "  if (!file.exists(counter)) {",
    "    file.create(counter)",
    "    shared$closed <- TRUE",
    "  }",
    "  expect_true(TRUE)",
    "})"
  )
  uses_resource <- c("test_that(\"uses the shared resource\", {", "  expect_true(use_resource())", "})")
  list(
    probe("clean fixture passes in full", "heavy", "full", function(dir) NULL, package = "fixture"),
    probe(
      "check_fast: a note (unexpected top-level file)",
      "heavy",
      "fast",
      function(dir) plant(dir, "gate-probe-note.txt", "x"),
      expect_fail = "check_fast",
      detail = "0 errors, 0 warnings, ", # so the FAIL is for a note alone
      package = "fixture"
    ),
    probe(
      "tests: a failing test is named, its run folder survives and it is re-run (failed again)",
      "heavy",
      "tests",
      function(dir) plant(dir, "tests/testthat/test-zz-gate-probe.R", failing_test),
      expect_fail = "tests",
      detail = "test-zz-gate-probe.R",
      package = "fixture",
      check_output = function(output) {
        out <- character()
        folder <- printed_run_folder(output)
        if (is.na(folder) || !file.exists(file.path(folder, "tests.json"))) {
          out <- c(out, "the printed run folder is gone or has no tests.json")
        }
        if (!grepl("re-run of 1 file(s) in a fresh R process: failed again", output, fixed = TRUE)) {
          out <- c(out, "the FAIL line doesn't say the file was re-run and failed again")
        }
        out
      }
    ),
    probe(
      "tests: a test that fails once and then passes exits 3 (probable flake)",
      "heavy",
      "tests",
      function(dir) plant(dir, "tests/testthat/test-zz-gate-probe.R", flaky_test),
      expect_fail = "tests",
      detail = "passed (probable flake)",
      package = "fixture",
      env = c(GATE_PROBE_COUNTER = file.path(tempdir(), "gate-flake-counter")),
      expect_exit = 3L,
      check_output = function(output) {
        if (grepl("FAILED: tests \\(every failing test passed", output)) character() else "no exit-3 note after FAILED"
      }
    ),
    probe(
      "tests: --no-retry doesn't re-run",
      "heavy",
      "tests",
      function(dir) plant(dir, "tests/testthat/test-zz-gate-probe.R", failing_test),
      expect_fail = "tests",
      package = "fixture",
      args = "--no-retry",
      check_output = function(output) if (grepl("re-run of", output, fixed = TRUE)) "it re-ran" else character()
    ),
    probe(
      "tests: --no-coverage runs plainly, skips coverage and is marked PARTIAL",
      "heavy",
      "tests",
      function(dir) NULL,
      expect_pass = "tests",
      package = "fixture",
      args = "--no-coverage",
      check_output = function(output) {
        c(
          if (!grepl("(^|\n)SKIP +coverage[^\n]*--no-coverage", output)) "coverage wasn't skipped",
          if (!grepl("(^|\n)PARTIAL: [^\n]*without coverage", output)) "the run isn't marked PARTIAL"
        )
      }
    ),
    probe(
      "tests: a non-standard tests/ layout runs plainly; a failure then skips coverage",
      "heavy",
      "tests",
      function(dir) {
        plant(dir, "tests/testthat/test-zz-gate-probe.R", failing_test)
        plant(dir, "tests/extra.R", "invisible(1)")
      },
      expect_fail = "tests",
      package = "fixture",
      check_output = function(output) {
        if (grepl("(^|\n)SKIP +coverage[^\n]*covr gives no percentage", output)) character() else "coverage ran"
      }
    ),
    probe(
      "tests: a cascade in 6 files is said once and re-run in a fresh process, where it passes (exit 3)",
      "heavy",
      "tests",
      function(dir) {
        plant(dir, "tests/testthat/helper-gate-probe.R", shared_resource)
        plant(dir, "tests/testthat/test-a-gate-probe.R", closes_once)
        for (i in 1:6) {
          plant(dir, sprintf("tests/testthat/test-zz-gate-probe-%d.R", i), uses_resource)
        }
      },
      expect_fail = "tests",
      detail = "cascade: 6 failures in 6 files share one message",
      package = "fixture",
      env = c(GATE_PROBE_COUNTER = file.path(tempdir(), "gate-cascade-counter")),
      expect_exit = 3L,
      check_output = function(output) {
        if (grepl("re-run of 6 file(s) in a fresh R process: passed (probable flake)", output, fixed = TRUE)) {
          character()
        } else {
          "the six files were not re-run, or did not pass"
        }
      }
    ),
    probe(
      "coverage: --steps coverage alone runs covr's own run",
      "heavy",
      "tests",
      function(dir) NULL,
      expect_pass = "coverage",
      package = "fixture",
      args = c("--steps", "coverage")
    ),
    probe(
      "coverage: untested code",
      "heavy",
      "tests",
      function(dir) plant(dir, "R/zz-gate-probe.R", untested),
      expect_fail = "coverage",
      expect_pass = "tests",
      package = "fixture"
    ),
    # One full run, two defects: a test that only passes with NOT_CRAN=true (so it passes in the tests step and
    # fails in the CRAN-like check), and a file in inst/ that .Rbuildignore keeps out of the tarball.
    probe(
      "check_full and tarball: a test that needs NOT_CRAN; an inst/ file left out of the build",
      "heavy",
      "full",
      function(dir) {
        plant(dir, "tests/testthat/test-zz-gate-probe.R", needs_not_cran)
        plant(dir, "inst/gate-probe-secret.txt", "x")
        plant(dir, ".Rbuildignore", "^inst/gate-probe-secret\\.txt$", append = TRUE)
      },
      expect_fail = c("check_full", "tarball"),
      expect_pass = "tests",
      package = "fixture"
    ),
    probe(
      "nosuggests: a clean fixture passes",
      "heavy",
      "nosuggests",
      function(dir) NULL,
      expect_pass = "nosuggests",
      package = "fixture"
    ),
    probe(
      "nosuggests: a test that assumes a Suggests package is installed fails (testthat skips a missing package itself)",
      "heavy",
      "nosuggests",
      function(dir) {
        desc <- readLines(file.path(dir, "DESCRIPTION"), warn = FALSE)
        plant(
          dir,
          "DESCRIPTION",
          sub("^Suggests: testthat \\(>= 3.0.0\\)$", "Suggests: testthat (>= 3.0.0), covr", desc)
        )
        plant(
          dir,
          "tests/testthat/test-zz-gate-probe.R",
          c(
            "test_that(\"assumes a Suggests package is installed\", {",
            "  expect_true(requireNamespace(\"covr\", quietly = TRUE))",
            "})"
          )
        )
      },
      expect_fail = "nosuggests",
      detail = "failing tests: Failure ('test-zz-gate-probe.R",
      package = "fixture"
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
  want_exit <- if (!is.null(probe$expect_exit)) {
    probe$expect_exit
  } else if (length(probe$expect_fail) > 0) {
    1L
  } else {
    0L
  }
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

run_probe <- function(probe, files, gate, fixture = NULL) {
  checkmate::assert_list(probe)
  checkmate::assert_character(files, min.len = 1, any.missing = FALSE)
  checkmate::assert_file_exists(gate)
  if (!is.null(fixture)) {
    checkmate::assert_directory_exists(fixture)
  }
  if (!is.null(probe$skip)) {
    return(list(status = "SKIP", detail = probe$skip, output = ""))
  }
  dir <- if (probe$package == "fixture") copy_dir(fixture) else fresh_copy(files)
  on.exit(unlink(dir, recursive = TRUE))
  probe$plant(dir)
  run <- processx::run(
    rscript,
    c(gate, probe$mode, probe$args),
    wd = dir,
    env = child_env(probe$env),
    error_on_status = FALSE,
    stderr_to_stdout = TRUE
  )
  lines <- step_lines(run$stdout)
  wrong <- problems(probe, run$status, lines)
  if (!is.null(probe$check_output)) {
    wrong <- c(wrong, probe$check_output(run$stdout))
  }
  if (length(wrong) > 0) {
    return(list(status = "FAIL", detail = paste(wrong, collapse = "; "), output = run$stdout))
  }
  failed <- names(lines)[substr(lines, 1, 4) == "FAIL"]
  detail <- if (length(failed) > 0) paste("gate reported FAIL for", toString(failed)) else "gate passed"
  list(status = "PASS", detail = detail, output = run$stdout)
}

# One unit check: its name, whether it held, and what was seen when it didn't.
unit <- function(name, ok, seen = "") {
  checkmate::assert_string(name)
  checkmate::assert_flag(ok, na.ok = TRUE)
  checkmate::assert_string(seen)
  list(name = name, ok = isTRUE(ok), seen = seen)
}

# A tiny test folder with one passing, one failing, one erroring, one warning and one skipped test. Each problem is
# on line 2 of its file.
unit_test_folder <- function(dir) {
  checkmate::assert_string(dir)
  tests <- file.path(dir, "tests")
  dir.create(tests, recursive = TRUE, showWarnings = FALSE)
  plant(dir, "tests/test-pass.R", c("test_that(\"passes\", {", "  expect_true(TRUE)", "})"))
  plant(dir, "tests/test-fail.R", c("test_that(\"fails\", {", "  expect_true(FALSE)", "})"))
  plant(dir, "tests/test-error.R", c("test_that(\"errors\", {", "  stop(\"boom\")", "})"))
  plant(dir, "tests/test-warn.R", c("test_that(\"warns\", {", "  warning(\"careful\")", "  expect_true(TRUE)", "})"))
  plant(dir, "tests/test-skip.R", c("test_that(\"skips\", {", "  skip(\"not today\")", "})"))
  tests
}

# The unit group: sources the gate (its last lines run the gate only under Rscript) and checks the reporting code
# on a real testthat results object. Returns a list of unit() results.
unit_checks <- function(gate) {
  checkmate::assert_file_exists(gate)
  g <- new.env()
  sys.source(gate, envir = g)
  dir <- tempfile("gate-unit-")
  on.exit(unlink(dir, recursive = TRUE))
  tests <- unit_test_folder(dir)
  run_tests <- function(filter = NULL) {
    testthat::test_dir(tests, filter = filter, reporter = "silent", stop_on_failure = FALSE, stop_on_warning = FALSE)
  }
  parent <- file.path(dir, "out")
  run_dir <- g$run_folder(parent, "tests")
  second <- g$run_folder(parent, "tests")
  txt <- file.path(run_dir, "tests.txt")
  failing <- g$tests_result(g$summarise_tests(run_tests(), run_dir), txt)
  # testthat's own wording for expect_true(FALSE), which changes between versions.
  false_message <- tryCatch(
    testthat::expect_true(FALSE),
    expectation_failure = function(e) g$first_message_line(conditionMessage(e))
  )
  json <- jsonlite::read_json(file.path(run_dir, "tests.json"), simplifyVector = TRUE)
  passing <- g$tests_result(g$summarise_tests(run_tests("pass|warn|skip"), second), txt)
  state <- new.env()
  state$tests <- g$summarise_tests(run_tests(), second)
  report <- g$failure_report("tests", second, state, whole_logs = FALSE)
  g$write_gate_json(run_dir, "tests", data.frame(step = "tests", status = "FAIL", seconds = 1, detail = "x"))
  gate_json <- jsonlite::read_json(file.path(run_dir, "gate.json"), simplifyVector = TRUE)
  # Lines as testthat's CheckReporter writes them (the format of testthat.Rout.fail under R CMD check and covr),
  # with its Unicode rule and with the ASCII one it uses when the output can't show Unicode.
  check_output <- c(
    "[ FAIL 2 | WARN 0 | SKIP 0 | PASS 1 ]",
    paste("── Failure ('test-a.R:3:3'): fails", strrep("─", 5)),
    "Expected FALSE to be TRUE.",
    "-- Error ('test-b.R:1:1'): (code run outside of `test_that()`) -----"
  )
  headers <- g$failure_headers(paste(check_output, collapse = "\n"))
  check <- structure(
    list(
      errors = "checking tests ... ERROR\n  Running 'testthat.R'",
      warnings = character(),
      notes = character(),
      test_fail = list(testthat = paste(check_output, collapse = "\n"))
    ),
    class = "rcmdcheck"
  )
  checked <- g$check_result(check)
  marked <- g$issue_text(
    data.frame(file = "test-x.R", line = 1L, test = "waits", kind = "Error", message = "timed out after 30 s")
  )
  filter_text <- g$rerun_filter(c("test-a.R", "tests/test-b.c.R"))
  flakes <- file.path(dir, "flakes.tsv")
  g$append_flakes(flakes, state$tests$bad, "tests", "passed (probable flake)")
  g$append_flakes(flakes, state$tests$bad, "tests", "failed again")
  flake_rows <- utils::read.delim(flakes, stringsAsFactors = FALSE)
  check_log <- file.path(dir, "check.log")
  file.create(check_log)
  g$check_result(check, check_log)
  # A cascade: one message in 8 files, plus one unrelated failure; and a mix of messages that is not a cascade.
  closed <- data.frame(
    file = sprintf("test-page%d.R", 1:8),
    line = 2L,
    test = sprintf("page %d draws", 1:8),
    kind = "Error",
    message = sprintf("Chromote has been closed (session %d).", 1:8)
  )
  other <- data.frame(file = "test-sum.R", line = 3L, test = "sums", kind = "Failure", message = "1 is not 2")
  cascade_bad <- rbind(closed, other)
  cascade <- g$cascade_of(cascade_bad)
  mixed <- closed
  mixed$message <- sprintf("message %s", letters[1:8])
  cascade_state <- new.env()
  cascade_state$tests <- list(bad = cascade_bad, cascade = cascade)
  cascade_line <- g$tests_result(
    list(
      counts = list(expectations = 9L, failed = 9L, warnings = 0L, skipped = 0L),
      bad = cascade_bad,
      cascade = cascade
    ),
    txt
  )
  cascade_report <- g$failure_report("tests", second, cascade_state, whole_logs = FALSE)
  list(
    unit(
      "run folder: <parent>/<YYYYmmdd-HHMMSS>-<mode>, created",
      dir.exists(run_dir) &&
        identical(dirname(run_dir), normalizePath(parent)) &&
        grepl("^[0-9]{8}-[0-9]{6}-tests$", basename(run_dir)),
      run_dir
    ),
    unit("run folder: a second run in the same second gets its own folder", dir.exists(second) && second != run_dir),
    unit(
      "tests FAIL line: the counts (5 expectations: a pass, a failure, a warning plus a pass, a skip)",
      failing$status == "FAIL" && startsWith(failing$detail, "5 expectations, 2 failed, 1 warnings, 1 skipped: "),
      failing$detail
    ),
    unit(
      "tests FAIL line: file:line, test name, kind and first message line of each problem",
      grepl("test-error.R:2 \"errors\" (Error: boom)", failing$detail, fixed = TRUE) &&
        grepl(sprintf("test-fail.R:2 \"fails\" (Failure: %s)", false_message), failing$detail, fixed = TRUE),
      failing$detail
    ),
    unit(
      "tests FAIL line: ends with where the details are",
      endsWith(failing$detail, paste0("; details: ", txt)),
      failing$detail
    ),
    unit(
      "tests.json: counts, one issue per failure, error and warning, one row per test",
      identical(json$counts$failed, 2L) &&
        setequal(json$issues$kind, c("Error", "Failure", "Warning")) &&
        nrow(json$tests) == 5 &&
        !"result" %in% names(json$tests) &&
        all(names(json$slowest_files) %in% basename(list.files(tests))),
      paste(names(json), collapse = ", ")
    ),
    unit("tests.rds: the raw results", file.exists(file.path(run_dir, "tests.rds"))),
    unit(
      "tests PASS line: counts and the slowest file",
      passing$status == "PASS" &&
        startsWith(passing$detail, "4 expectations, 0 failed, 1 warnings, 1 skipped; slowest file test-"),
      passing$detail
    ),
    unit(
      "failure report: the problems block after the summary",
      any(grepl("^---- tests: the first 2 of 2 problems", report)) &&
        any(grepl("test-fail.R:2 \"fails\"", report, fixed = TRUE)),
      paste(report, collapse = " | ")
    ),
    unit(
      "gate.json: the mode and one row per step",
      identical(gate_json$mode, "tests") && identical(gate_json$steps$status, "FAIL"),
      paste(names(gate_json), collapse = ", ")
    ),
    unit(
      "failure headers: taken from check output, with the rule characters off",
      identical(
        headers,
        c("Failure ('test-a.R:3:3'): fails", "Error ('test-b.R:1:1'): (code run outside of `test_that()`)")
      ),
      paste(headers, collapse = " | ")
    ),
    unit(
      "check_full FAIL line: names the failing tests from the check's test output",
      checked$status == "FAIL" &&
        grepl("failing tests: Failure ('test-a.R:3:3'): fails", checked$detail, fixed = TRUE),
      checked$detail
    ),
    unit(
      "timeout label: a failure that reads like a wait running out is marked, others are not",
      grepl("[looks like a timeout]", marked, fixed = TRUE) &&
        !grepl("[looks like a timeout]", g$issue_text(state$tests$bad[1, ]), fixed = TRUE),
      marked
    ),
    unit(
      "re-run filter: picks exactly the failing files, without test- and .R, dots escaped",
      identical(filter_text, "^(a|b\\.c)$") &&
        grepl(filter_text, "a") &&
        !grepl(filter_text, "ab") &&
        grepl(filter_text, "b.c") &&
        !grepl(filter_text, "bxc"),
      filter_text
    ),
    unit(
      "exit codes: 0 passed, 1 a failure, 3 only a flaky tests step, 1 for a flaky test plus another failure",
      identical(
        c(
          g$exit_code(character(), FALSE),
          g$exit_code("tests", FALSE),
          g$exit_code("tests", TRUE),
          g$exit_code(c("tests", "docs"), TRUE),
          g$exit_code("tools", FALSE),
          g$exit_code(c("tools", "tests"), TRUE)
        ),
        c(0L, 1L, 3L, 1L, 2L, 2L)
      )
    ),
    unit(
      "arguments: modes, flags with a value in two forms, flags without, and the mistakes that exit 2",
      identical(g$parse_args(character())$mode, "fast") &&
        identical(g$parse_args("lint")$mode, "lint") &&
        identical(g$parse_args(c("lint", "--steps", "spelling,docs"))$steps, c("spelling", "docs")) &&
        identical(g$parse_args(c("lint", "--steps=docs"))$steps, "docs") &&
        identical(g$parse_args(c("tests", "--filter", "a|b", "--no-retry", "--no-coverage"))$filter, "a|b") &&
        g$parse_args(c("tests", "--no-retry"))$no_retry &&
        g$parse_args("--list")$list &&
        !is.null(g$parse_args("--bogus")$error) &&
        !is.null(g$parse_args("nope")$error) &&
        !is.null(g$parse_args(c("fast", "lint"))$error) &&
        !is.null(g$parse_args("--steps")$error) &&
        !is.null(g$parse_args(c("lint", "--steps", "tests"))$error)
    ),
    unit(
      "list: every mode with its steps, and a skip reason for a package without Air",
      any(grepl(
        "^nosuggests: tools, nosuggests$",
        g$list_steps(list(
          air = TRUE,
          lintr = TRUE,
          biome = TRUE,
          roxygen = TRUE,
          tests = TRUE,
          testthat = TRUE,
          pkgdown = TRUE
        ))
      )) &&
        any(grepl(
          "air \\(skips: no air.toml\\)",
          g$list_steps(list(
            air = FALSE,
            lintr = TRUE,
            biome = TRUE,
            roxygen = TRUE,
            tests = TRUE,
            testthat = TRUE,
            pkgdown = TRUE
          ))
        ))
    ),
    unit(
      "check log: the check's problems and failing test output are written in full",
      any(grepl("checking tests ... ERROR", readLines(check_log), fixed = TRUE)) &&
        any(grepl("Expected FALSE to be TRUE.", readLines(check_log), fixed = TRUE))
    ),
    unit(
      "cascade: one message (numbers ignored) in 8 files is found, the first in run order; a mix of messages is not",
      !is.null(cascade) &&
        cascade$n == 8 &&
        cascade$files == 8 &&
        identical(cascade$first$file, "test-page1.R") &&
        is.null(g$cascade_of(mixed)) &&
        is.null(g$cascade_of(closed[1:5, ])),
      if (is.null(cascade)) "no cascade" else g$cascade_text(cascade)
    ),
    unit(
      "cascade: the FAIL line says it once, then names the failure it doesn't cover",
      grepl("cascade: 8 failures in 8 files share one message", cascade_line$detail, fixed = TRUE) &&
        grepl("test-sum.R:3 \"sums\"", cascade_line$detail, fixed = TRUE) &&
        !grepl("test-page2.R", cascade_line$detail, fixed = TRUE),
      cascade_line$detail
    ),
    unit(
      "cascade: the report says it once, shows its first 3 and the other problems",
      any(grepl("^---- tests: cascade: 8 failures", cascade_report)) &&
        sum(grepl("Chromote has been closed", cascade_report)) == 4 &&
        any(grepl("test-sum.R:3", cascade_report, fixed = TRUE)),
      paste(cascade_report, collapse = " | ")
    ),
    unit(
      "flake log: one row per retried failure with the re-run result, the header written once",
      nrow(flake_rows) == 4 &&
        identical(names(flake_rows)[1:4], c("date", "mode", "commit", "file")) &&
        all(
          flake_rows$rerun == c("passed (probable flake)", "passed (probable flake)", "failed again", "failed again")
        ),
      paste(names(flake_rows), collapse = ", ")
    )
  )
}

# The gate and this self-test live twice: in the repository and in the skill folder (the skill's copy is the one real
# source). When both exist and this run is from somewhere else, they must be the same files; elsewhere (CI, another
# machine) there is nothing to compare and the check is skipped.
skill_scripts <- function() path.expand("~/.agents/skills/cran-gate/scripts")

version_line <- function(path) {
  checkmate::assert_file_exists(path)
  line <- grep("^# cran-gate version: ", readLines(path, n = 5, warn = FALSE), value = TRUE)
  if (length(line) == 0) "no version line" else sub("^# cran-gate version: ", "", line[[1]])
}

copies_in_step <- function(gate) {
  checkmate::assert_file_exists(gate)
  here <- normalizePath(dirname(gate))
  there <- skill_scripts()
  if (!dir.exists(there)) {
    return(list(status = "SKIP", detail = "no skill copy of the gate on this machine"))
  }
  if (identical(here, normalizePath(there))) {
    return(list(status = "SKIP", detail = "this run is from the skill copy itself"))
  }
  files <- c("cran-gate.R", "test-cran-gate.R")
  same <- file.exists(file.path(there, files)) &
    tools::md5sum(file.path(here, files)) == tools::md5sum(file.path(there, files))
  differ <- files[!same]
  if (length(differ) == 0) {
    return(list(status = "PASS", detail = paste("same files as the skill copy, version", version_line(gate))))
  }
  copy <- paste0("cp ", file.path(here, differ), " ", file.path(there, differ), collapse = "; ")
  list(
    status = "FAIL",
    detail = paste0(
      toString(differ),
      " differ from the skill copy (here: ",
      version_line(file.path(here, differ[[1]])),
      ", there: ",
      if (file.exists(file.path(there, differ[[1]]))) version_line(file.path(there, differ[[1]])) else "missing",
      "). Copy the newer one over the older: ",
      copy
    )
  )
}

run_unit <- function(gate) {
  checkmate::assert_file_exists(gate)
  started <- Sys.time()
  checks <- tryCatch(
    unit_checks(gate),
    error = function(e) list(unit("the unit checks ran", FALSE, conditionMessage(e)))
  )
  secs <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  statuses <- character()
  for (check in checks) {
    status <- if (check$ok) "PASS" else "FAIL"
    statuses[paste("unit:", check$name)] <- status
    seen <- if (check$ok || !nzchar(check$seen)) "" else paste0(": saw ", check$seen)
    cli::cat_line(sprintf("%-4s unit: %s%s", status, check$name, seen))
  }
  cli::cat_line(sprintf("     unit group: %d checks in %.0fs", length(checks), secs))
  statuses
}

main <- function(args) {
  checkmate::assert_character(args, any.missing = FALSE, max.len = 2)
  group <- if (length(args) == 0) "all" else args[[1]]
  checkmate::assert_choice(group, groups, .var.name = "group")
  steps <- if (length(args) == 2) strsplit(args[[2]], ",", fixed = TRUE)[[1]] else character()
  if (!file.exists("DESCRIPTION")) {
    cli::cli_abort("Run the self-test from the package root (no DESCRIPTION in {.path {getwd()}}).")
  }
  gate <- gate_path()
  uses <- package_uses()
  probes <- c(
    if (group %in% c("all", "static")) static_probes(uses),
    if (group %in% c("all", "heavy")) heavy_probes()
  )
  if (length(steps) > 0) {
    probes <- Filter(function(p) length(intersect(steps, c(p$expect_fail, p$expect_pass))) > 0, probes)
  }
  files <- package_files()
  cli::cli_h1("CRAN gate self-test: {group} ({length(probes)} probes)")
  statuses <- if (group %in% c("all", "unit") && length(steps) == 0) run_unit(gate) else character()
  if (group %in% c("all", "static") && length(steps) == 0) {
    copies <- copies_in_step(gate)
    statuses["copies in step"] <- copies$status
    cli::cat_line(sprintf("%-4s copies in step: %s", copies$status, copies$detail))
  }
  fixture <- if (any(vapply(probes, function(p) p$package == "fixture", logical(1)))) fixture_package()
  for (probe in probes) {
    started <- Sys.time()
    res <- tryCatch(
      run_probe(probe, files, gate, fixture),
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
      length(statuses),
      " checks and probes."
    )
    if (identical(unname(statuses["clean copy passes"]), "FAIL")) {
      cli::cat_line("The clean copy didn't pass: make the gate pass on the package first, then run the self-test.")
    }
    quit(status = 1)
  }
  cli::cat_line("All probes behaved as expected (", sum(statuses == "SKIP"), " skipped).")
  invisible(statuses)
}

# Like the gate: say plainly, in base R, when the packages this script needs are missing.
ensure_packages <- function() {
  pkgs <- c("checkmate", "cli", "jsonlite", "processx", "testthat")
  absent <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent) > 0) {
    message("Missing R packages: ", toString(absent), "; .libPaths()[1] = ", .libPaths()[1])
    quit(status = 1)
  }
}

ensure_packages()
main(commandArgs(trailingOnly = TRUE))
