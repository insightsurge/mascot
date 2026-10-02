#!/usr/bin/env Rscript
# Self-test for the CRAN gate (cran-gate.R, in the same folder): a check that can't fail protects nothing.
#
#   Rscript <path to this file> [all|static|heavy]
#
#   static          a clean copy of the package must pass; then one planted defect per quick step (settings,
#                   tools, air, biome, docs, lintr, value, spelling) must make that step FAIL
#   heavy           the same for check_fast, tests, coverage, check_full and tarball (a minute or more)
#   all   (default) both
#
# Run it from the root of a package that passes the gate. Each probe copies the package to tempdir() (tracked and
# new files in a git repository; nothing git ignores), plants one defect in the copy and runs the gate on it. PASS
# means the gate did what the probe expects: exit 1 with FAIL for the named step (exit 0 for the clean copy). A
# probe for a step this package doesn't use (no air.toml, no .lintr, no tests...) is skipped. Exits 1 if the gate
# misses a defect. The package itself is never changed.
#
# Run it after changing the gate or the settings it reads (.lintr, air.toml, biome.json, the Config/cran-gate
# fields); a new gate step gets a probe here at the same time.

groups <- c("all", "static", "heavy")
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
  skip = NULL
) {
  checkmate::assert_string(name)
  checkmate::assert_choice(group, c("static", "heavy"))
  checkmate::assert_choice(mode, c("fast", "tests", "full", "lint"))
  checkmate::assert_function(plant)
  checkmate::assert_character(expect_fail, any.missing = FALSE)
  checkmate::assert_character(expect_pass, any.missing = FALSE)
  checkmate::assert_string(detail, null.ok = TRUE)
  checkmate::assert_character(env, names = "unique")
  checkmate::assert_string(skip, null.ok = TRUE)
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
      detail = "tarball-mb"
    ),
    probe(
      "tools: the gate's own packages are missing",
      "static",
      "lint",
      function(dir) NULL,
      expect_fail = "tools",
      env = no_packages_env(),
      skip = if (gate_packages_still_found()) "checkmate or cli is in R's own library here; can't hide them"
    ),
    probe(
      "tools: Air isn't on the PATH",
      "static",
      "lint",
      function(dir) NULL,
      expect_fail = "tools",
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
    )
  )
}

heavy_probes <- function(uses) {
  checkmate::assert_list(uses, types = "logical")
  # Enough untested lines to pull any coverage under the limit, however large the package gets.
  r_lines <- sum(lengths(lapply(list.files("R", full.names = TRUE), readLines, warn = FALSE)))
  untested <- c("gate_probe <- function(x) {", rep("  x <- x + 1", max(50, 10 * r_lines)), "  x", "}")
  needs_not_cran <- c(
    "test_that(\"the gate's tests step runs with NOT_CRAN=true\", {",
    "  expect_identical(Sys.getenv(\"NOT_CRAN\"), \"true\")",
    "})"
  )
  failing_test <- c("test_that(\"the gate probe fails\", {", "  expect_true(FALSE)", "})")
  no_testthat <- if (!uses$testthat) "the package has no tests/testthat"
  list(
    probe(
      "check_fast: a note (unexpected top-level file)",
      "heavy",
      "fast",
      function(dir) plant(dir, "gate-probe-note.txt", "x"),
      expect_fail = "check_fast",
      detail = "0 errors, 0 warnings, " # so the FAIL is for a note alone
    ),
    probe(
      "tests: a failing test",
      "heavy",
      "tests",
      function(dir) plant(dir, "tests/testthat/test-zz-gate-probe.R", failing_test),
      expect_fail = "tests",
      skip = no_testthat
    ),
    probe(
      "coverage: untested code",
      "heavy",
      "tests",
      function(dir) plant(dir, "R/zz-gate-probe.R", untested),
      expect_fail = "coverage",
      expect_pass = "tests",
      skip = if (!uses$testthat) {
        no_testthat
      } else if (!uses$coverage_limit) {
        "the coverage limit is set to 0"
      }
    ),
    # One full run, two defects: a test that only passes with NOT_CRAN=true (so it passes in the tests step and
    # fails in the CRAN-like check), and a file in inst/ that .Rbuildignore keeps out of the tarball.
    probe(
      if (uses$testthat) {
        "check_full and tarball: a test that needs NOT_CRAN; an inst/ file left out of the build"
      } else {
        "tarball: an inst/ file left out of the build"
      },
      "heavy",
      "full",
      function(dir) {
        if (uses$testthat) {
          plant(dir, "tests/testthat/test-zz-gate-probe.R", needs_not_cran)
        }
        plant(dir, "inst/gate-probe-secret.txt", "x")
        plant(dir, ".Rbuildignore", "^inst/gate-probe-secret\\.txt$", append = TRUE)
      },
      expect_fail = c(if (uses$testthat) "check_full", "tarball"),
      expect_pass = if (uses$testthat) "tests" else character()
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

run_probe <- function(probe, files, gate) {
  checkmate::assert_list(probe)
  checkmate::assert_character(files, min.len = 1, any.missing = FALSE)
  checkmate::assert_file_exists(gate)
  if (!is.null(probe$skip)) {
    return(list(status = "SKIP", detail = probe$skip, output = ""))
  }
  dir <- fresh_copy(files)
  on.exit(unlink(dir, recursive = TRUE))
  probe$plant(dir)
  run <- processx::run(
    rscript,
    c(gate, probe$mode),
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
  if (!file.exists("DESCRIPTION")) {
    cli::cli_abort("Run the self-test from the package root (no DESCRIPTION in {.path {getwd()}}).")
  }
  gate <- gate_path()
  uses <- package_uses()
  probes <- c(
    if (group %in% c("all", "static")) static_probes(uses),
    if (group %in% c("all", "heavy")) heavy_probes(uses)
  )
  files <- package_files()
  cli::cli_h1("CRAN gate self-test: {group} ({length(probes)} probes)")
  statuses <- character()
  for (probe in probes) {
    started <- Sys.time()
    res <- tryCatch(
      run_probe(probe, files, gate),
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
  pkgs <- c("checkmate", "cli", "processx")
  absent <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent) > 0) {
    message("Missing R packages: ", toString(absent), "; .libPaths()[1] = ", .libPaths()[1])
    quit(status = 1)
  }
}

ensure_packages()
main(commandArgs(trailingOnly = TRUE))
