#' Built-in character registry
#' @noRd
builtin_characters <- function() {
  data.frame(id = "tessa", name = "Tessa", file = "tessa.json")
}

#' Choose a mascot character
#'
#' The helper behind the `character` argument of [mascot()]. Only Tessa is
#' built in; custom characters come later.
#'
#' @param id A non-empty string naming a built-in character. Defaults to
#'   `"tessa"`; `NULL` is not accepted.
#' @returns A `mascot_character` object with `id` and `name` elements.
#' The returned object's fields are internal; pass the object on rather than reading its fields.
#' @family mascot helpers
#' @seealso [mascot()]
#' @export
#' @examples
#' mascot_character()
#' mascot_character("tessa")
mascot_character <- function(id = "tessa") {
  with_mascot_asserts({
    checkmate::assert_string(id, min.chars = 1)
  })
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
