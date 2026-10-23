# Throwaway: run the named test files against the installed package, one reporter line per test.
files <- strsplit(Sys.getenv("REPRO_FILES"), " ", fixed = TRUE)[[1]]
library(testthat)
library(mascot)
pattern <- paste0("^(", paste(gsub("^test-|\\.R$", "", files), collapse = "|"), ")$")
message("Files: ", pattern)
results <- testthat::test_dir(
  "tests/testthat",
  filter = pattern,
  package = "mascot",
  load_package = "installed",
  reporter = testthat::ProgressReporter$new(show_praise = FALSE),
  stop_on_failure = FALSE
)
df <- as.data.frame(results)
print(df[, c("file", "test", "nb", "failed", "skipped", "error", "real")], right = FALSE)
if (any(df$failed > 0 | df$error)) quit(status = 1)
