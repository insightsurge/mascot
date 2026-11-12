#!/usr/bin/env Rscript
# Writes R/sysdata.rda, the checked data of the built-in characters: Rscript tools/build-sysdata.R
#
# The full check of a shipped character takes most of a second (several on CRAN's Windows machines), so the package
# ships each one already checked and character_catalogue_builtin() reads it from here. Run this after editing any file
# in inst/format/characters/ or the character checker; test-character-catalogue-extended.R fails until you do.

build_sysdata <- function(path) {
  checkmate::assert_path_for_output(path, overwrite = TRUE)
  if (!file.exists("DESCRIPTION") || !dir.exists(file.path("inst", "format", "characters"))) {
    cli::cli_abort("Run from the package root (no {.path inst/format/characters} in {.path {getwd()}}).")
  }
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    cli::cli_abort("Install {.pkg pkgload} to build {.path {path}}.")
  }
  pkgload::load_all(".", quiet = TRUE, export_all = FALSE)
  mascot <- asNamespace("mascot")
  builtin_checked <- list()
  for (id in mascot$builtin_characters()$id) {
    file <- file.path("inst", "format", "characters", paste0(id, ".json"))
    checked <- mascot$character_format_check(file, from = "file", builtin = TRUE)
    if (!identical(checked$id, id)) {
      cli::cli_abort("{.path {file}} has the id {.val {checked$id}}; ship each character under its own id.")
    }
    builtin_checked[[id]] <- checked
  }
  # The data must read back exactly as it was checked.
  if (!identical(unserialize(serialize(builtin_checked, NULL)), builtin_checked)) {
    cli::cli_abort("The checked characters don't read back identical after saving.")
  }
  save(builtin_checked, file = path, compress = "xz", version = 3)
  cli::cli_inform("Wrote {.path {path}} ({file.size(path)} bytes): {.val {names(builtin_checked)}}.")
  invisible(path)
}

build_sysdata(file.path("R", "sysdata.rda"))
