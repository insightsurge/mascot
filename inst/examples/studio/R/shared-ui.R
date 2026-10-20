# Buttons that every view of the studio app shares. Their look is Bootstrap's; inputs.js answers data-copy.

# A small outline button with an accessible name; pressed (TRUE or FALSE) makes it a toggle (aria-pressed).
studio_button <- function(id, label, aria_label = label, pressed = NULL) {
  checkmate::assert_string(id)
  checkmate::assert_string(label)
  checkmate::assert_string(aria_label)
  checkmate::assert_flag(pressed, null.ok = TRUE)
  shiny::tags$button(
    id = id,
    type = "button",
    class = "btn btn-sm btn-outline-primary",
    `aria-label` = aria_label,
    `aria-pressed` = if (!is.null(pressed)) tolower(as.character(pressed)),
    label
  )
}

# Copies the text of the element whose id is target (inputs.js), and says so on the button for a moment.
copy_button <- function(target, label = "Copy") {
  checkmate::assert_string(target, min.chars = 1)
  checkmate::assert_string(label, min.chars = 1)
  shiny::tags$button(type = "button", class = "btn btn-sm btn-outline-primary pg-copy", `data-copy` = target, label)
}
