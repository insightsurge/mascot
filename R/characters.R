#' Built-in character registry
#' @noRd
builtin_characters <- function() {
  data.frame(id = "tessa", name = "Tessa", file = "tessa.json")
}

#' Choose a mascot character
#'
#' The helper behind the `character` argument of [mascot()]. Currently Tessa
#' is the only built-in character.
#'
#' @param name A string naming a built-in character. Defaults to `"tessa"`.
#'   `NULL` is not accepted.
#' @returns A `mascot_character` object with `id` and `name` elements.
#' @family mascot helpers
#' @seealso [mascot()]
#' @export
#' @examples
#' mascot_character()
#' mascot_character("tessa")
mascot_character <- function(name = "tessa") {
  checkmate::assert_string(name, min.chars = 1)
  registry <- builtin_characters()
  if (!name %in% registry$id) {
    abort_choice(name, registry$id, "name", "character", environment())
  }
  row <- registry[registry$id == name, ]
  structure(list(id = row$id, name = row$name), class = "mascot_character")
}

#' Read a character as text safe for an HTML data block
#' @noRd
character_json <- function(id) {
  checkmate::assert_choice(id, builtin_characters()$id)
  file <- builtin_characters()$file[match(id, builtin_characters()$id)]
  text <- paste(
    readLines(
      system.file("characters", file, package = "mascot"),
      encoding = "UTF-8",
      warn = FALSE
    ),
    collapse = "\n"
  )
  gsub("</", "<\\/", text, fixed = TRUE)
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
    call = call
  )
}

#' @export
#' @noRd
format.mascot_character <- function(x, ...) {
  checkmate::assert_class(x, "mascot_character")
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_character <- function(x, ...) {
  checkmate::assert_class(x, "mascot_character")
  cli::cat_line(format(x))
  invisible(x)
}
