# Writes the browser-tests part of the pull request's CI report, for one R version: the counts, the failing and
# skipped tests, the slowest test files and the files that got slower than on main. Sourced by browser-tests.yaml's
# test step, which runs the tests with file_time_reporter and calls write_browser_report(results, reporter$seconds())
# before it decides whether the job fails.
# Environment: R_LABEL (the matrix's R version), OUT (the Markdown part), TIMINGS (a CSV of seconds per file, kept
# from main runs), BASELINE_DIR, BASELINE_FOUND and BASELINE_SHA (main's timings, from main-baseline).

# A file counts as slower when it takes at least this much longer than on main, both relatively and in seconds.
slower_ratio <- 1.25
slower_seconds <- 10

# testthat's parallel progress reporter (a line per file as it finishes, with its time) that also keeps each file's
# elapsed time. Two processes run the files at once (#502), and in a parallel run the results' own test times are
# about zero, so the times come from when each file's first event and its end arrive (testthat sends a parallel
# reporter the events as they happen).
file_time_reporter <- R6::R6Class(
  "FileTimeReporter",
  inherit = testthat::ParallelProgressReporter,
  public = list(
    starts = list(),
    ends = list(),
    current = NA_character_,
    start_file = function(file) {
      self$current <- file
      if (is.null(self$starts[[file]])) {
        self$starts[[file]] <- Sys.time()
      }
      super$start_file(file)
    },
    end_file = function() {
      self$ends[[self$current]] <- Sys.time()
      super$end_file()
    },
    seconds = function() {
      files <- intersect(names(self$starts), names(self$ends))
      secs <- vapply(files, function(f) as.numeric(difftime(self$ends[[f]], self$starts[[f]], units = "secs")), 1)
      data.frame(file = files, seconds = unname(secs))
    }
  )
)

# The first lines of a test's message, on one line for a table cell.
short_message <- function(message) {
  lines <- utils::head(strsplit(message, "\n", fixed = TRUE)[[1]], 3)
  text <- paste(trimws(lines), collapse = " ")
  text <- gsub("|", "\\|", text, fixed = TRUE)
  if (nchar(text) > 200) paste0(substr(text, 1, 200), "...") else text
}

# One row per failing, erroring or skipped test, with its first such message.
problem_rows <- function(results, classes) {
  rows <- lapply(results, function(test) {
    hits <- Filter(function(e) inherits(e, classes), test$results)
    if (length(hits) == 0) {
      return(NULL)
    }
    data.frame(file = test$file, test = test$test, message = short_message(conditionMessage(hits[[1]])))
  })
  do.call(rbind, c(list(data.frame(file = character(), test = character(), message = character())), rows))
}

# At most `max` rows, then a line saying how many were left out (the job's log has them all).
table_lines <- function(rows, max = 30) {
  shown <- utils::head(rows, max)
  test <- gsub("|", "\\|", shown$test, fixed = TRUE)
  c(
    "| File | Test | Message |",
    "|---|---|---|",
    sprintf("| `%s` | %s | %s |", shown$file, test, shown$message),
    if (nrow(rows) > max) c("", sprintf("And %d more: see the job's log.", nrow(rows) - max))
  )
}

plural <- function(n, word) sprintf("%d %s%s", n, word, if (n == 1) "" else "s")

details <- function(summary, body) c("<details>", sprintf("<summary>%s</summary>", summary), "", body, "", "</details>")

write_browser_report <- function(results, timings) {
  label <- Sys.getenv("R_LABEL")
  frame <- as.data.frame(results)
  utils::write.csv(timings, Sys.getenv("TIMINGS"), row.names = FALSE)

  failed <- problem_rows(results, c("expectation_failure", "expectation_error"))
  skipped <- problem_rows(results, "expectation_skip")
  first <- sprintf(
    "**Browser and snapshot tests, R %s:** %d tests in %d files, %d failed, %d skipped (any skip fails this job).",
    label,
    nrow(frame),
    length(unique(frame$file)),
    nrow(failed),
    nrow(skipped)
  )
  out <- first
  if (nrow(failed) > 0) {
    out <- c(out, "", details(plural(nrow(failed), "failing test"), table_lines(failed)))
  }
  if (nrow(skipped) > 0) {
    out <- c(out, "", details(plural(nrow(skipped), "skipped test"), table_lines(skipped)))
  }

  slowest <- utils::head(timings[order(-timings$seconds), ], 5)
  timing_rows <- sprintf("| `%s` | %.1f s |", slowest$file, slowest$seconds)
  timing_body <- c("| File | Time |", "|---|---|", timing_rows)
  if (!identical(Sys.getenv("BASELINE_FOUND"), "true") && identical(Sys.getenv("GITHUB_EVENT_NAME"), "pull_request")) {
    timing_body <- c(timing_body, "", "No test times from `main` to compare with.")
  }
  if (identical(Sys.getenv("BASELINE_FOUND"), "true")) {
    base_file <- file.path(Sys.getenv("BASELINE_DIR"), basename(Sys.getenv("TIMINGS")))
    if (file.exists(base_file)) {
      base <- utils::read.csv(base_file)
      both <- merge(timings, base, by = "file", suffixes = c("", "_main"))
      slower <- both[
        both$seconds >= both$seconds_main * slower_ratio &
          both$seconds - both$seconds_main >= slower_seconds,
      ]
      sha <- substr(Sys.getenv("BASELINE_SHA"), 1, 7)
      timing_body <- c(
        timing_body,
        "",
        if (nrow(slower) == 0) {
          sprintf("No file is much slower than on `main` at %s.", sha)
        } else {
          c(
            sprintf("Slower than on `main` at %s:", sha),
            "",
            "| File | Here | `main` |",
            "|---|---|---|",
            sprintf("| `%s` | %.1f s | %.1f s |", slower$file, slower$seconds, slower$seconds_main)
          )
        }
      )
    }
  }
  out <- c(
    out,
    "",
    details(
      sprintf("Test times, R %s (the files add up to %.0f s; two run at once)", label, sum(timings$seconds)),
      timing_body
    )
  )
  writeLines(out, Sys.getenv("OUT"))
}
