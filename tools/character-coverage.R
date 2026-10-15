# Targeted character-file line coverage, independent of the full tests gate.
# Rscript tools/character-coverage.R [output-directory]
character_coverage <- function(output = NULL) {
  checkmate::assert_string(output, null.ok = TRUE)
  devtools::load_all(quiet = TRUE)
  env <- new.env(parent = asNamespace("mascot"))
  for (name in getNamespaceExports("testthat")) {
    env[[name]] <- getExportedValue("testthat", name)
  }
  sources <- normalizePath(list.files("R", "^character-.*[.]R$", full.names = TRUE))
  tests <- normalizePath(c(
    "tests/testthat/helper-character-format.R",
    list.files("tests/testthat", "^test-character-.*[.]R$", full.names = TRUE)
  ))
  if (!is.null(output)) {
    checkmate::assert_directory_exists(output)
    output <- normalizePath(output)
  }
  withr::local_dir("tests/testthat")
  coverage <- NULL
  testthat::with_reporter(testthat::StopReporter$new(), {
    coverage <- covr::file_coverage(sources, tests, parent_env = env)
  })
  lines <- covr::tally_coverage(coverage)
  totals <- stats::aggregate(value ~ filename, lines, function(x) 100 * mean(x > 0))
  totals$filename <- basename(totals$filename)
  for (index in seq_len(nrow(totals))) {
    cli::cli_inform("{totals$filename[[index]]}: {round(totals$value[[index]], 2)}%")
  }
  if (!is.null(output)) {
    saveRDS(coverage, file.path(output, "coverage.rds"))
    utils::write.csv(totals, file.path(output, "coverage.csv"), row.names = FALSE)
    utils::write.csv(covr::zero_coverage(coverage), file.path(output, "uncovered.csv"), row.names = FALSE)
  }
  invisible(totals)
}

args <- commandArgs(trailingOnly = TRUE)
character_coverage(if (length(args)) args[[1L]] else NULL)
