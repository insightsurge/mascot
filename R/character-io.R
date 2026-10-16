#' Serialise checked character data as JSON text
#'
#' Checked data is already normalised by the reader (arrays are unnamed lists,
#' objects are named lists, nulls are kept), so the writer needs no schema.
#' Class and the derived manifest are not saved.
#' @noRd
character_json_write <- function(x) {
  checkmate::assert_class(x, "mascot_character_data")
  plain <- unclass(x)
  attributes(plain)[setdiff(names(attributes(plain)), "names")] <- NULL
  as.character(jsonlite::toJSON(plain, auto_unbox = TRUE, null = "null", digits = NA, pretty = TRUE))
}

#' Check a source specification, raw list, checked data or supplied JSON
#'
#' Never fixes or recolours anything. A `mascot_character_spec` has its
#' `requires` computed here, after resolution: every capability is declared for
#' a first pass, the capabilities the resolved recipe uses are read from that
#' pass, and the second pass checks the final list (used capabilities plus any
#' extras the spec declared). A string is never guessed to be a path or an id:
#' say `from = "file"` or `"text"`.
#' @noRd
character_check <- function(x, ..., from = "list", families = character_object(), kits = character_format_kits()) {
  checkmate::assert(checkmate::check_list(x), checkmate::check_string(x))
  checkmate::assert_choice(from, c("list", "text", "file"))
  checkmate::assert_list(families, names = "unique")
  checkmate::assert_list(kits, names = "unique")
  character_build_dots(..., .path = "$")
  if (inherits(x, "mascot_character_data")) {
    return(character_data_verify(x))
  }
  if (!inherits(x, "mascot_character_spec")) {
    return(character_format_check(x, from = from, families = families, kits = kits))
  }
  source <- unclass(x)
  capabilities <- unlist(character_format_policy()$capabilities, use.names = FALSE)
  extras <- unlist(source$requires)
  draft <- source
  draft$requires <- as.list(capabilities)
  first <- character_format_check(draft, families = families, kits = kits)
  manifest <- attr(first, "mascot_manifest")
  used <- character_format_capabilities(first, character_format_references(first), manifest$work)
  declared <- unique(c(used, extras))
  source$requires <- as.list(c(intersect(capabilities, declared), setdiff(declared, capabilities)))
  character_format_check(source, families = families, kits = kits)
}

#' Save checked character data as complete resolved JSON
#'
#' The intended output is read back and checked before anything replaces the
#' destination; the temporary file sits beside it and is removed on failure.
#' @noRd
character_save <- function(x, path, ..., overwrite = FALSE) {
  checkmate::assert_class(x, "mascot_character_data")
  checkmate::assert_path_for_output(path, overwrite = TRUE)
  checkmate::assert_flag(overwrite)
  character_build_dots(..., .path = "$")
  fail <- function(message, parent = NULL) {
    cli::cli_abort(
      message,
      class = c("mascot_error_file", "mascot_error"),
      path = path,
      operation = "save",
      parent = parent
    )
  }
  if (file.exists(path) && !overwrite) {
    fail("Cannot save to {.path {path}}: the file exists. Use {.code overwrite = TRUE} to replace it.")
  }
  verified <- character_data_verify(x)
  text <- character_json_write(verified)
  again <- character_format_check(text, from = "text")
  if (!identical(attr(again, "mascot_manifest")$identity, attr(verified, "mascot_manifest")$identity)) {
    character_format_abort("identity", "$", verified$id, "The saved text does not match the checked character.")
  }
  temporary <- tempfile("character-", tmpdir = dirname(path), fileext = ".tmp")
  on.exit(unlink(temporary), add = TRUE)
  tryCatch(
    {
      writeBin(charToRaw(enc2utf8(paste0(text, "\n"))), temporary)
      if (!isTRUE(file.rename(temporary, path))) {
        stop("Could not move the temporary file into place.", call. = FALSE)
      }
    },
    error = function(error) {
      checkmate::assert_class(error, "error")
      fail("Cannot save to {.path {path}}.", error)
    },
    warning = function(warning) {
      checkmate::assert_class(warning, "warning")
      fail("Cannot save to {.path {path}}.", warning)
    }
  )
  invisible(path)
}

#' Read a character from a supplied file or from the registry
#' @noRd
character_read <- function(x, ..., from = "file", families = character_object()) {
  checkmate::assert_string(x, min.chars = 1)
  checkmate::assert_choice(from, c("file", "id"))
  checkmate::assert_list(families, names = "unique")
  character_build_dots(..., .path = "$")
  if (from == "id") {
    return(character_data_get(x))
  }
  character_format_check(x, from = "file", families = families)
}
