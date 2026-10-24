#' Check a character description
#'
#' Checks a character description against format version 1 and the package's
#' limits on input, drawing and capabilities. It never repairs or recolours
#' anything. To change a character, edit the JSON or the plain list and check it
#' again; a checked object cannot be opened or edited.
#' @param x A JSON string, a parsed plain list, or checked
#'   `mascot_character_data`. A string always means JSON, never a path or id.
#'   `NULL` is not accepted.
#' @returns A checked, resolved, self-contained `mascot_character_data` object,
#'   visibly. Its fields are internal implementation details.
#' @details Content problems inherit `mascot_error_character` and `mascot_error`,
#'   with `code`, `path`, `value` and `fix`. Argument problems inherit
#'   `mascot_error_argument` and `mascot_error`, with `argument`, `code` and `value`.
#'   Every character needs `wave` and `nod` tracks that change something. `wave`
#'   must change a channel of a part other than `root`; `nod` may change any
#'   channel, including `root`. A checked object is not stored anywhere, so pass
#'   it each time you use it. The format version, the set of supported
#'   capabilities and the admission policy version can each change on their own.
#'   Built-in character ids are reserved and refused here, so give your
#'   character its own id before checking it.
#' @seealso [mascot_character_format]
#' @family mascot helpers
#' @evalRd paste0(
#'   "\\section{Experimental}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nIts arguments, results and diagnostics may change in a later release.\n}"
#' )
#' @export
#' @examples
#' path <- system.file("examples", "characters", "study_bot.json", package = "mascot")
#' source <- jsonlite::read_json(path)
#' bot <- mascot_check_character(source)
mascot_check_character <- function(x) {
  character_api_asserts(
    {
      checkmate::assert(checkmate::check_list(x), checkmate::check_string(x), .var.name = "x")
    },
    "x",
    x
  )
  if (
    is.character(x) &&
      (grepl("\\.json$", x, ignore.case = TRUE) || (nchar(x, type = "bytes") <= 4096L && file.exists(x)))
  ) {
    character_format_abort(
      "input_type",
      "$",
      x,
      paste0(
        "To check a character file, use mascot_read_character(path). ",
        "mascot_check_character() expects JSON text or a parsed list."
      )
    )
  }
  checked <- if (inherits(x, "mascot_character_data")) {
    character_data_verify(x)
  } else {
    character_format_check(x, from = if (is.character(x)) "text" else "list")
  }
  attr(checked, "mascot_origin") <- if (inherits(x, "mascot_character_data")) attr(x, "mascot_origin") else "object"
  checked
}

#' Read a local character file
#'
#' Reads one local JSON file, the one you name, within the format's input
#' limits. URLs and wildcards are not expanded. The checked result includes its
#' family and face kits; keep the source file too if you want to edit the
#' character later.
#' @param path A non-empty string naming one local JSON file. `NULL` is not accepted.
#' @returns A checked `mascot_character_data` object, visibly.
#' @details File problems inherit `mascot_error_file` and `mascot_error`, with
#'   the exact supplied `path`, `operation = "read"` and a stable `code`.
#'   Content and argument diagnostics are described in [mascot_check_character()].
#' @seealso [mascot_character_format]
#' @family mascot helpers
#' @evalRd paste0(
#'   "\\section{Experimental}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nIts arguments, results and diagnostics may change in a later release.\n}"
#' )
#' @export
#' @examples
#' path <- system.file("examples", "characters", "study_bot.json", package = "mascot")
#' bot <- mascot_read_character(path)
mascot_read_character <- function(path) {
  character_api_asserts(checkmate::assert_string(path, min.chars = 1), "path", path)
  checked <- character_format_check(path, from = "file")
  attr(checked, "mascot_origin") <- path
  checked
}

#' Register a checked character for this R process
#'
#' Internal: not exported. The tests call it.
#'
#' Register during app start-up or development. Inside a Shiny reactive domain,
#' pass the checked object directly instead; visitor objects must stay private.
#' Registering identical content again does nothing. Built-in ids and different
#' content under an existing id are refused with `mascot_error_character`.
#' Identity uses canonical resolved content, independent of key order or origin.
#' @param x A checked `mascot_character_data` object. `NULL` is not accepted.
#' @returns The character id, invisibly.
#' @seealso [mascot_check_character()], [mascot_characters()]
#' @noRd
#' @examples
#' path <- system.file("examples", "characters", "study_bot.json", package = "mascot")
#' bot <- mascot_read_character(path)
#' mascot_register_character(bot)
mascot_register_character <- function(x) {
  character_api_asserts(checkmate::assert_class(x, "mascot_character_data"), "x", x)
  attr(x, "mascot_origin") <- "registry"
  checked <- character_data_register(x)
  invisible(checked$id)
}

#' Save a checked character as resolved JSON
#'
#' Internal: not exported; the tests call it.
#'
#' Saves the portable, self-contained recipe, including family metadata, palette
#' sources and face kits. Validates serialised content before writing a temporary
#' file beside the destination, then renames it into place. Failure removes the
#' temporary file and leaves an existing destination untouched. No other folder
#' is written. A mounted mascot cannot change content under the same id: give an
#' edited character a new id before using it in a running app.
#' @param x A checked `mascot_character_data` object. `NULL` is not accepted.
#' @param path A non-empty string naming the output file in an existing directory.
#'   `NULL` is not accepted.
#' @param ... Must be empty. Forces `overwrite` to be named.
#' @param overwrite A logical flag. `FALSE` (the default) refuses an existing file;
#'   `TRUE` replaces it atomically. `NULL` is not accepted.
#' @returns The exact supplied path, invisibly.
#' @details File problems inherit `mascot_error_file` and `mascot_error`, with
#'   `path`, `operation = "save"` and `code` (including `"exists"`). Unexpected
#'   dots inherit `mascot_error_dots` with `names`; content and argument problems
#'   are described in [mascot_check_character()].
#' @seealso [mascot_read_character()], [mascot_character_format]
#' @noRd
#' @examples
#' path <- system.file("examples", "characters", "study_bot.json", package = "mascot")
#' bot <- mascot_read_character(path)
#' out <- tempfile("study-bot-", tmpdir = tempdir(), fileext = ".json")
#' mascot_save_character(bot, out)
#' unlink(out)
mascot_save_character <- function(x, path, ..., overwrite = FALSE) {
  character_api_asserts(checkmate::assert_class(x, "mascot_character_data"), "x", x)
  character_api_asserts(checkmate::assert_string(path, min.chars = 1), "path", path)
  character_api_asserts(checkmate::assert_flag(overwrite), "overwrite", overwrite)
  if (...length() > 0L) {
    extras <- names(substitute(list(...)))[-1L]
    if (is.null(extras) || any(!nzchar(extras))) {
      extras <- if (is.null(extras)) rep("unnamed", ...length()) else replace(extras, !nzchar(extras), "unnamed")
      cli::cli_abort(
        "Options after {.code ...} must be named; use {.code overwrite = TRUE} to replace a file.",
        class = c("mascot_error_dots", "mascot_error"),
        names = extras
      )
    }
    abort_dots(extras, ...length(), "overwrite", environment())
  }
  character_save(x, path, overwrite = overwrite)
}

#' Add the authoring argument diagnostic to checkmate failures
#' @noRd
character_api_asserts <- function(code, argument, value) {
  checkmate::assert_string(argument)
  # code is a promise containing assertions; value can be any invalid caller input.
  tryCatch(force(code), error = function(error) {
    checkmate::assert_class(error, "error")
    supplied <- tryCatch(value, error = function(error) {
      checkmate::assert_class(error, "error")
      NULL
    })
    cli::cli_abort(
      "Invalid {.arg {argument}}: {conditionMessage(error)}",
      class = c("mascot_error_argument", "mascot_error"),
      argument = argument,
      code = "argument",
      value = supplied,
      parent = error
    )
  })
}

#' Compact display of checked character data
#' @method print mascot_character_data
#' @exportS3Method print mascot_character_data
#' @noRd
print.mascot_character_data <- function(x, ...) {
  with_mascot_asserts(checkmate::assert_class(x, "mascot_character_data"))
  character_build_dots(..., .path = "$")
  cli::cat_line(format(x))
  invisible(x)
}

#' Compact text for checked character data
#' @method format mascot_character_data
#' @exportS3Method format mascot_character_data
#' @noRd
format.mascot_character_data <- function(x, ...) {
  with_mascot_asserts(checkmate::assert_class(x, "mascot_character_data"))
  character_build_dots(..., .path = "$")
  checked <- character_data_verify(x)
  origin <- attr(x, "mascot_origin")
  if (is.null(origin)) {
    origin <- "object"
  }
  # lod's fields are the two bands; a note or an extension key there is not a band.
  bands <- intersect(c("small", "micro"), names(checked$lod))
  c(
    paste0(checked$id, ": ", checked$name, " (", checked$family, ")"),
    paste("Moods:", paste(names(checked$moods), collapse = ", ")),
    paste("Gestures:", paste(names(checked$gestures), collapse = ", ")),
    paste("Detail overrides:", if (length(bands)) paste(bands, collapse = ", ") else "none"),
    paste("From:", origin)
  )
}

#' Character format version 1
#'
#' A guide to the character file format read by [mascot_read_character()] and
#' [mascot_check_character()]. Descriptions are
#' JSON objects with `format_version = 1`, `id`, `name`, `description`,
#' a `family`, colours, ground, parts and five shared moods (`idle`, `thinking`,
#' `happy`, `worried`, `celebrating`). Optional anchors, palettes, face kits and
#' gestures describe their own supported names. Palette ids cannot be `original`
#' or the reserved style aliases `minimal`, `pastel`, `vivid`, `corporate`,
#' `earthy` and `night`. Small sizes may hide details
#' the character marks for small sizes. Text is displayed as text, never HTML.
#'
#' Start from `system.file("examples", "characters", "study_bot.json", package = "mascot")`.
#' To change a character, edit the plain list or JSON source and check it again; a checked object cannot be edited.
#' A source file names its `family` and gives that family's definition in
#' `family_definition` (`id`, `name`, `description` and optional `defaults`, such as
#' shared gestures and palettes); a custom character cannot take a definition from
#' the installed package. A resolved file has its family defaults merged in and
#' embeds its face kits, so it does not depend on the installed package.
#'
#' Drawing coordinates are design units in a 300 by 300 frame. The point where
#' the character stands on the ground is `(0, 0)`: 150 units from the left edge
#' and 270 from the top. `y` grows downwards, so a part above the ground has a
#' negative `y`. Every part, movement and effect must stay inside the frame at
#' every detail size.
#'
#' @section Capabilities and `requires`:
#' Every version-1 mascot can draw the eight version-1 capabilities: `parts`,
#' `paints`, `clip`, `outline`, `glow`, `face_kit`, `tracks` and `lod`. A file
#' does not need to ask for them, so it needs no `requires` field. `requires`
#' lists only capabilities added after version 1. A file that lists the
#' version-1 names still loads. A name this version of mascot does not know, or
#' a reserved one, stops the check with an error that names it and says to
#' update mascot.
#' Unsupported and reserved capabilities used as keys (such as `connector` or
#' `morph`) are refused too.
#'
#' @section Keys for other tools:
#' * A top-level `$schema` string is accepted and kept, so an editor can link the
#'   file to a schema. mascot never reads it.
#' * A key that starts with `x_`, in any object whose fields the format fixes
#'   (the character itself, a part, an item, a mood, a gesture, a face and so
#'   on), is an extension key. Its value can be any JSON value (from R, a list
#'   or an unnamed vector; a data frame or a named vector is refused). It is
#'   kept as written when the character is checked, resolved and saved, and it
#'   is never read; it counts towards the file's size, depth and node limits.
#'   Resolution keeps the character's own extension keys; those of a family's
#'   `defaults` object stay in the resolved family snapshot. In an object whose
#'   keys are ids or names (`colours`, `moods`, `gestures`, `palettes` and the
#'   other maps), a key that starts with `x_` is an ordinary id.
#' * A `note` string, accepted in every fixed-field object, is a comment.
#'
#' @section Diagnostics:
#' Checks stop at the first problem, giving a diagnostic code, the JSON path and a
#' repair instruction, and the value where one is at fault. A value outside its
#' range or choices is named with the range or the choices. A drawing budget gives
#' the band, the count and the limit; a character too big for its frame names
#' the part, face, effect or shadow that reaches furthest outside, the side and
#' by how much. The limits on input bytes, depth and node count, and the drawing
#' budgets, apply to every input form. The format version, the capability set
#' and the admission policy version can each change on their own. The installed
#' grammar and policy live in
#' `system.file("format", package = "mascot")`; the policy holds the input limits,
#' the capability names and the drawing budget of each detail band.
#'
#' @section Compatibility:
#' The format is experimental and its future direction is open; these points hold
#' either way. Additions (new optional keys, wider ranges, new categories) stay in
#' format version 1, so existing files keep working. A file that uses an addition
#' lists it in `requires`, and an older version of mascot then stops with an error
#' naming it instead of drawing it wrongly. Only a change that would break existing
#' files introduces format version 2; retiring an older format version is announced
#' in NEWS at least one release ahead. The checker may only get stricter in a new
#' format version, except for a documented security or resource-safety fix, which
#' comes with a diagnostic and migration guidance. Files are never modified or
#' upgraded silently. A resolved file is self-contained.
#'
#' @name mascot_character_format
#' @evalRd paste0(
#'   "\\section{Experimental}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nWhat the format accepts may grow in a later release; version-1 files keep loading (see Compatibility).\n}"
#' )
#' @seealso [mascot_check_character()], [mascot_read_character()]
#' @examples
#' # Start from the bundled source, give the copy its own id, then check it again.
#' path <- system.file("examples", "characters", "study_bot.json", package = "mascot")
#' source <- jsonlite::read_json(path)
#' source$id <- "my_bot"
#' source$name <- "My Bot"
#' source$colours$body <- "#2a9d8f"
#' bot <- mascot_check_character(source)
#' bot
#' ui <- mascot("helper", character = bot)
NULL
