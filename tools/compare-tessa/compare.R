#!/usr/bin/env Rscript
# Compare the package's Tessa with the R Engineering Playbook's, pixel by pixel, in the same browser.
#
#   Rscript tools/compare-tessa/compare.R [playbook engine.js] [output folder]
#
# Run it from the package root. Defaults: ../r-engineering-playbook/tools/animate/engine.js and a new folder in
# tempdir(). One headless Chrome page (chromote) loads the playbook's engine.js from its own folder (read only) and the
# package's inst/www/ files, draws every case of compare-page.js with both on canvases of the same size, and counts
# the differing pixels. Writes summary.csv and sheet.png (playbook | package | differences) to the output folder and
# exits 1 if any case differs. It also checks that the playbook's engine.js is the same file before and after.
#
# Needs the R packages checkmate, cli, chromote and jsonlite, and Chrome or Chromium. Not part of the built package.

engine_default <- "../r-engineering-playbook/tools/animate/engine.js"
package_js <- c("inst/www/mascot.js", "inst/www/mascot-draw.js")
page_js <- "tools/compare-tessa/compare-page.js"

file_url <- function(path) {
  checkmate::assert_file_exists(path)
  paste0("file://", normalizePath(path, winslash = "/"))
}

# The file's git blob hash and whether git reports it changed in its own repository.
engine_state <- function(engine) {
  checkmate::assert_file_exists(engine)
  dir <- dirname(normalizePath(engine))
  hash <- system2("git", c("-C", shQuote(dir), "hash-object", shQuote(basename(engine))), stdout = TRUE)
  status <- system2("git", c("-C", shQuote(dir), "status", "--porcelain", "--", "."), stdout = TRUE)
  list(hash = hash, status = status)
}

write_page <- function(engine, out_dir) {
  checkmate::assert_file_exists(engine)
  checkmate::assert_directory_exists(out_dir, access = "w")
  scripts <- vapply(c(engine, package_js, page_js), file_url, character(1))
  page <- c(
    "<!doctype html>",
    "<html lang=\"en\"><head><meta charset=\"utf-8\"><title>Tessa: playbook and package</title></head><body>",
    sprintf("<script src=\"%s\"></script>", scripts),
    "</body></html>"
  )
  path <- file.path(out_dir, "compare.html")
  writeLines(page, path)
  path
}

run_page <- function(page, out_dir) {
  checkmate::assert_file_exists(page)
  checkmate::assert_directory_exists(out_dir, access = "w")
  session <- chromote::ChromoteSession$new()
  on.exit(try(session$close(), silent = TRUE), add = TRUE)
  invisible(session$Page$navigate(file_url(page)))
  for (i in seq_len(100)) {
    done <- session$Runtime$evaluate("window.__done === true")$result$value
    if (isTRUE(done)) {
      break
    }
    Sys.sleep(0.2)
  }
  if (!isTRUE(done)) {
    cli::cli_abort(c(
      "The comparison page did not finish within 20 seconds.",
      i = "Open {.file {page}} in Chrome and look at its console to see why."
    ))
  }
  version <- session$Browser$getVersion()$product
  result <- session$Runtime$evaluate("JSON.stringify(window.__result)")$result$value
  sheet <- session$Runtime$evaluate("window.__sheet")$result$value
  writeBin(jsonlite::base64_dec(sub("^data:image/png;base64,", "", sheet)), file.path(out_dir, "sheet.png"))
  list(browser = version, cases = jsonlite::fromJSON(result))
}

main <- function(args) {
  checkmate::assert_character(args, max.len = 2)
  engine <- if (length(args) >= 1) args[[1]] else engine_default
  out_dir <- if (length(args) >= 2) args[[2]] else tempfile("compare-tessa-")
  checkmate::assert_file_exists(engine, extension = "js")
  for (path in c(package_js, page_js)) {
    checkmate::assert_file_exists(path)
  }
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  if (is.null(chromote::find_chrome())) {
    cli::cli_abort("No Chrome or Chromium found: chromote needs one to draw the pages.")
  }

  before <- engine_state(engine)
  outcome <- run_page(write_page(engine, out_dir), out_dir)
  after <- engine_state(engine)
  cases <- outcome$cases
  utils::write.csv(cases, file.path(out_dir, "summary.csv"), row.names = FALSE)

  differing <- cases[cases$pixels_differing > 0, , drop = FALSE]
  cli::cli_inform(c(
    "Playbook engine: {.file {normalizePath(engine)}} (git blob {before$hash})",
    "Browser: {outcome$browser}",
    "Cases: {nrow(cases)}; differing: {nrow(differing)}",
    "Output: {.file {normalizePath(out_dir)}} (summary.csv, sheet.png)"
  ))
  ok <- TRUE
  if (!identical(before, after)) {
    cli::cli_alert_danger("The playbook's engine.js changed during the run.")
    ok <- FALSE
  }
  if (length(before$status) > 0) {
    cli::cli_alert_warning("The playbook's {.file tools/animate/} has uncommitted changes: {before$status}")
  }
  if (nrow(differing) > 0) {
    for (i in seq_len(nrow(differing))) {
      cli::cli_alert_danger(sprintf(
        "%s: %d pixels differ (largest channel difference %d)",
        differing$case[[i]],
        differing$pixels_differing[[i]],
        differing$max_delta[[i]]
      ))
    }
    ok <- FALSE
  }
  if (!ok) {
    quit(status = 1)
  }
  cli::cli_alert_success("Every case is identical, pixel for pixel.")
}

main(commandArgs(trailingOnly = TRUE))
