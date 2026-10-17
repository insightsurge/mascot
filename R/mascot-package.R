#' @section Conditions:
#' Building UI with [mascot()] or helpers errors on invalid values;
#' [update_mascot()] warns and leaves the mascot unchanged. All errors raised by
#' mascot, including checkmate assertions, carry class `mascot_error`. Warnings
#' have class `mascot_warning` and messages have class `mascot_message`. Invalid
#' update values also carry
#' `mascot_update_ignored`; low contrast carries `mascot_contrast`, and messages
#' about inline placement carry `mascot_placement_ignored`. Checkmate assertion
#' errors keep checkmate's message, line by line.
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
