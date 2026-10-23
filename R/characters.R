#' Built-in character registry
#' @noRd
builtin_characters <- function() {
  data.frame(
    id = c("tessa", "sela", "knurl", "neer"),
    name = c("Tessa", "Sela", "Knurl", "Neer"),
    file = c("tessa.json", "sela.json", "knurl.json", "neer.json"),
    lifecycle = c("stable", "stable", "experimental", "experimental")
  )
}

#' Choose a mascot character
#'
#' The helper behind the `character` argument of [mascot()]. Tessa and Sela
#' are stable built-in characters; Knurl and Neer are experimental.
#'
#' @param id A non-empty string naming a known character, or checked
#'   `mascot_character_data` from [mascot_read_character()] or
#'   [mascot_check_character()]. Defaults to `"tessa"`; `NULL` is not accepted.
#'   A checked object is used as passed and is not stored anywhere; pass it
#'   each time you choose that character.
#' @returns A `mascot_character` helper carrying the character's identity and,
#'   for a custom character, its checked drawing data.
#' The returned object's fields are internal; pass the object on rather than reading its fields.
#' @details Tessa and Sela are stable: their ids, names, five shared moods,
#'   gesture names, colour-role names and palette names stay the same in every
#'   release. Their drawings, motion and exact palette colours may be polished.
#'   Knurl and Neer are experimental: any part may change, and neither will be
#'   removed without a warning in the release before its removal. The character
#'   file format and character authoring functions are experimental too.
#' @family mascot helpers
#' @seealso [mascot()]
#' @evalRd paste0(
#'   "\\section{Experimental characters}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nKnurl and Neer.\n}"
#' )
#' @export
#' @examples
#' mascot_character()
#' mascot_character("tessa")
#' path <- system.file("examples", "characters", "study_bot.json", package = "mascot")
#' mascot_character(mascot_read_character(path))
mascot_character <- function(id = "tessa") {
  with_mascot_asserts({
    checkmate::assert(
      checkmate::check_string(id, min.chars = 1),
      checkmate::check_class(id, "mascot_character_data"),
      .var.name = "id"
    )
  })
  if (inherits(id, "mascot_character_data")) {
    return(as_character_arg(id, environment()))
  }
  registry <- mascot_characters()
  if (!id %in% registry$id) {
    abort_choice(id, registry$id, "id", "character", environment())
  }
  row <- registry[registry$id == id, ]
  structure(list(id = row$id, name = row$name), class = "mascot_character")
}

#' Read a character as text safe for an HTML data block
#' @noRd
character_json <- function(id) {
  checkmate::assert_choice(id, builtin_characters()$id)
  file <- builtin_characters()$file[match(id, builtin_characters()$id)]
  text <- paste(
    readLines(
      system.file("format", "characters", file, package = "mascot", mustWork = TRUE),
      encoding = "UTF-8",
      warn = FALSE
    ),
    collapse = "\n"
  )
  gsub("</", "<\\/", text, fixed = TRUE)
}

#' A built-in character's data as an HTML dependency
#'
#' The dependency is named after the character and puts the same inert `<script type="application/json">` block that a
#' custom character carries in its tag into the page head. htmltools and Shiny add a dependency once per page by name,
#' so five Tessas carry Tessa's data once, and a page carries only the characters it uses. Shiny adds a dependency's
#' head before it inserts the HTML of `renderUI()`, `insertUI()` or a modal, so the data is on the page when the engine
#' mounts. The dependency has no files: `href = ""` keeps htmltools from copying a folder and Shiny from serving one.
#' @noRd
character_dependency <- function(id) {
  checkmate::assert_choice(id, builtin_characters()$id)
  block <- htmltools::tags$script(
    type = "application/json",
    `data-mascot-character` = id,
    htmltools::HTML(character_json(id))
  )
  htmltools::htmlDependency(
    name = paste0("mascot-character-", id),
    version = getNamespaceVersion("mascot")[[1]],
    src = c(href = ""),
    head = as.character(block)
  )
}

#' Report a choice at the public caller
#' @noRd
abort_choice <- function(value, valid, arg, what, call) {
  checkmate::assert_string(value)
  checkmate::assert_character(valid, min.len = 1, any.missing = FALSE)
  checkmate::assert_string(arg)
  checkmate::assert_string(what)
  checkmate::assert_environment(call)
  cli::cli_abort(
    c(
      "{.arg {arg}} must be one of {.or {.val {valid}}}.",
      "x" = "{.val {value}} is not a {what}."
    ),
    call = call,
    class = c("mascot_error_choice", "mascot_error"),
    argument = arg,
    choices = valid,
    value = value
  )
}

#' @export
#' @noRd
format.mascot_character <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_character")
  })
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_character <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_character")
  })
  cli::cat_line(format(x))
  invisible(x)
}
