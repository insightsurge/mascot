#' @section Conditions:
#' [mascot()] and the helpers raise an error on an invalid value;
#' [update_mascot()] warns instead and leaves the mascot unchanged. All errors raised by
#' mascot, including checkmate assertions, carry class `mascot_error`. Warnings
#' have class `mascot_warning` and messages have class `mascot_message`. Invalid
#' update values also carry `mascot_update_ignored`; low contrast carries
#' `mascot_contrast`, and messages about inline placement carry
#' `mascot_placement_ignored`. Checkmate assertion errors keep checkmate's
#' message, line by line.
#'
#' Specific error classes are `mascot_error_choice` for invalid choices,
#' `mascot_error_dots` for unexpected arguments, `mascot_error_argument` for
#' authoring argument errors, `mascot_error_character` for character content
#' errors, and `mascot_error_file` for character file errors.
#'
#' `mascot_palette_dropped` is the warning when a character swap drops a palette
#' that the new character does not have. Two warnings are for development:
#' `mascot_gesture_dropped` when a pending gesture cannot play, and
#' `mascot_template_evicted` when unused UI templates leave the cache. Each
#' inherits `mascot_warning`.
#' @section Options:
#' `options(mascot.contrast_warnings = TRUE)` forces R contrast warnings on;
#' `FALSE` forces them off everywhere. By default they appear only when
#' [shiny::in_devmode()] is `TRUE`, and always in [mascot_preview()] and the
#' studio. Colours are kept unchanged.
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
