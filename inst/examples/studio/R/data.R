# Plain data for the studio: bubble examples, the starting menu, the mistakes to try and the
# defaults of mascot(). Shiny sources this before app.R attaches mascot, so it calls no mascot code.

corners <- c("top-left", "top-right", "bottom-left", "bottom-right")

bubble_examples <- list(
  `Plain text` = list(html = FALSE, text = "Three rows need a second look."),
  `Bold and italic` = list(
    html = TRUE,
    text = "<strong>Saved.</strong> Your <em>draft</em> is safe until you submit it."
  ),
  Checklist = list(
    html = TRUE,
    text = paste0(
      "<strong>Before you submit</strong>\n<ul class='list-unstyled mb-0'>\n",
      "  <li>\u2705 Sample ID</li>\n  <li>\u2705 Quantity</li>\n  <li>\u26a0\ufe0f Batch date is missing</li>\n</ul>"
    )
  ),
  `Small table` = list(
    html = TRUE,
    text = paste0(
      "<table class='table table-sm mb-0'>\n",
      "  <thead><tr><th>Check</th><th>Result</th></tr></thead>\n",
      "  <tbody>\n    <tr><td>Rows</td><td>120</td></tr>\n",
      "    <tr><td>Missing</td><td><span class='badge text-bg-warning'>3</span></td></tr>\n  </tbody>\n</table>"
    )
  ),
  `Progress bar` = list(
    html = TRUE,
    text = paste0(
      "Uploading <strong>batch 2 of 3</strong>\n",
      "<div class='progress mt-1' role='progressbar' aria-label='Upload progress' ",
      "aria-valuenow='66' aria-valuemin='0' aria-valuemax='100'>\n",
      "  <div class='progress-bar' style='width: 66%'>66%</div>\n</div>"
    )
  ),
  `Keys and code` = list(
    html = TRUE,
    text = "Press <kbd>Ctrl</kbd> + <kbd>Enter</kbd> to run <code>updateMascot()</code>."
  ),
  Badges = list(
    html = TRUE,
    text = paste0(
      "<span class='badge text-bg-success'>QC passed</span> ",
      "<span class='badge text-bg-secondary'>v1.2</span>\n",
      "<div class='small text-body-secondary mt-1'>Reviewed by the study team</div>"
    )
  ),
  `Your own HTML` = list(html = TRUE, text = "<p class='mb-1'>Write your own <mark>HTML</mark> here.</p>")
)

default_menu <- c(finish = "Finish review", reset = "Reset helper", about = "About this studio")
menu_lines <- paste(names(default_menu), "=", default_menu, collapse = "\n")
welcome <- "Hello! Choose a function and change its controls and I will follow."

# What mascot() uses when an argument is left out, as shortcut code.
defaults <- list(
  character = formals(mascot::mascot)$character,
  mood = "idle",
  status = quote(mascot_status()),
  bubble = quote(mascot_bubble()),
  size = 160,
  placement = "bottom-right",
  theme = quote(mascot_theme()),
  motion = TRUE,
  popup_menu = quote(mascot_popup_menu())
)
mistakes <- list(
  `Leave out an argument name` = list(
    code = "updateMascot(\"helper\", \"happy\")",
    why = "The second argument is character, not mood, so \"happy\" is read as a character name: a warning, no change."
  ),
  `A mood that does not exist` = list(
    code = "updateMascot(\"helper\", mood = \"sleepy\")",
    why = "A warning that lists the valid moods; the mascot keeps its mood."
  ),
  `Misspell an argument` = list(
    code = "updateMascot(\"helper\", moood = \"happy\")",
    why = "... must be empty, so a typo is an error instead of being silently ignored."
  ),
  `Too small` = list(code = "updateMascot(\"helper\", size = 10)", why = "Sizes start at 24 pixels."),
  `Minimise an inline mascot` = list(
    code = "updateMascot(\"helper\", placement = mascot_placement(\"inline\", minimise = TRUE))",
    why = "An inline mascot ignores minimise. Not an error: a message says so, and the mascot moves inline."
  ),
  `A bubble that never shows` = list(
    code = "updateMascot(\"helper\", bubble = mascot_bubble(\"Hi\", duration = 0))",
    why = "duration must be more than zero; use Inf to keep a bubble."
  ),
  `Not a colour` = list(
    code = "updateMascot(\"helper\", theme = list(body = \"not-a-colour\"))",
    why = "Colours are checked in R before anything is sent."
  ),
  `Low contrast` = list(
    code = "updateMascot(\"helper\", theme = list(body = \"#f8f9fa\"))",
    why = "The colour is applied, with a warning that it is hard to see on a light page."
  ),
  `The wrong id` = list(
    code = "updateMascot(\"helpr\", mood = \"happy\")",
    why = paste(
      "No error and no change: R cannot see the page. With shiny::devmode(TRUE), the browser console",
      "names the likely slip."
    )
  )
)

# Where each argument can be tried: the HTML that must be on the page (an input id, or the
# data-event of a button), or the reason it has no control. tests/testthat/test-examples.R checks
# that every exported argument has an entry and that its control is on the page.
input_id <- function(...) paste0("id=\"", c(...), "\"")
input_event <- function(...) paste0("data-event=\"", c(...), "\"")
fixed_arg <- function(reason) list(fixed = reason)

playground_controls <- list(
  mascot_character = list(name = input_id("character")),
  mascot_mood = list(name = input_id("mood")),
  mascot_status = list(text = input_id("status_text")),
  mascot_bubble = list(
    text = input_id("bubble_text", "bubble_example", "bubble_html"),
    duration = input_id("bubble_duration", "bubble_forever"),
    closable = input_id("bubble_closable")
  ),
  mascot_motion = list(animate = input_id("animate"), swap = input_id("swap")),
  mascot_gesture = list(name = input_event("gesture")),
  mascot_size = list(
    size = input_id("size_unit", "size_px", "size_pct"),
    small_screen = input_id("small_on", "small_px")
  ),
  mascot_placement = list(position = input_id("position"), minimise = input_id("minimise"), drag = input_id("drag")),
  mascot_colour_roles = list(character = input_id("character")),
  mascot_theme = list(
    light = fixed_arg("Pickers are built from the selected character roles in theme_light."),
    dark = fixed_arg("Pickers are built from the selected character roles in theme_dark."),
    mode = input_id("theme_mode"),
    css = fixed_arg("CSS role checkboxes are built from the selected character; css_accent sets their variable.")
  ),
  mascot_popup_menu = list(
    items = input_id("menu_on", "menu_items"),
    direction = input_id("menu_direction")
  ),
  mascot = list(
    character = input_id("character"),
    id = fixed_arg("The studio's mascot is always mascot(id = \"helper\")."),
    mood = input_id("mood"),
    status = input_id("status_text"),
    bubble = input_id("bubble_text"),
    size = input_id("size_px"),
    placement = input_id("position"),
    theme = input_id("theme_source"),
    motion = input_id("animate"),
    popup_menu = input_id("menu_items")
  ),
  updateMascot = list(
    id = input_id("mistake"),
    character = input_id("character"),
    mood = input_id("mood"),
    status = input_id("status_text"),
    bubble = input_id("bubble_text"),
    size = input_id("size_px"),
    placement = input_id("position"),
    theme = input_id("theme_source"),
    motion = input_id("animate"),
    popup_menu = input_id("menu_items"),
    ... = input_id("mistake", "mistake_run"),
    gesture = input_event("gesture"),
    session = input_id("task_run")
  ),
  mascot_preview = list(
    character = input_id("preview_character"),
    mood = input_id("preview_mood"),
    status = input_id("preview_status"),
    bubble = input_id("preview_bubble"),
    size = input_id("preview_size", "preview_width"),
    placement = input_id("preview_placement"),
    theme = input_id("preview_theme_source"),
    motion = input_id("preview_motion"),
    popup_menu = input_id("preview_menu_items")
  ),
  mascot_example = list(name = input_id("example_name"), run = input_id("example_run"))
)

# Change only this helper when public character discovery becomes available (#162).
studio_characters <- function() {
  id <- formals(mascot::mascot)$character
  stats::setNames(id, mascot::mascot_character(id)$name)
}

# The public listing has no brand column yet. Read the package's shipped data,
# keeping this adaptation in one place until a public brand mapping is available.
studio_brand <- function(character) {
  checkmate::assert_string(character)
  id <- mascot::mascot_character(character)$id
  file <- system.file("characters", paste0(id, ".json"), package = "mascot", mustWork = TRUE)
  jsonlite::fromJSON(file)$brand
}

character_mistakes <- function(character) {
  checkmate::assert_string(character)
  role <- mascot::mascot_colour_roles(character)$role[1]
  result <- mistakes
  for (name in c("Not a colour", "Low contrast")) {
    result[[name]]$code <- sub("body =", paste0(arg_name(role), " ="), result[[name]]$code, fixed = TRUE)
  }
  result
}

playground_controls$mascot_studio <- list(
  view = input_id("studio_view"),
  ... = fixed_arg("Empty; later arguments are named."),
  fn = input_id("studio_fn"),
  character = input_id("character"),
  run = input_id("studio_run")
)
