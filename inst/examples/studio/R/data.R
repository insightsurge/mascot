# Plain data for the studio: bubble examples, the starting menu, the mistakes to try and the
# defaults of mascot(). Shiny sources this before app.R attaches mascot, so it calls no mascot code.

# Base R has %||% only from R 4.4; the package supports R 4.1, so the studio keeps its own copy.
`%||%` <- function(x, y) if (is.null(x)) y else x

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
    text = "Press <kbd>Ctrl</kbd> + <kbd>Enter</kbd> to run <code>update_mascot()</code>."
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
welcome <- "Hello! Open the function index (the m button) to pick a function, change its controls, and I will follow."

# What mascot() uses when an argument is left out, as shortcut code.
defaults <- list(
  character = formals(mascot::mascot)$character,
  mood = formals(mascot::mascot)$mood,
  status = quote(mascot_status()),
  bubble = quote(mascot_bubble()),
  size = formals(mascot::mascot)$size,
  placement = formals(mascot::mascot)$placement,
  theme = quote(mascot_theme()),
  motion = formals(mascot::mascot)$motion,
  # The empty helper, so a removal reads as the reset it is (click = NULL in an update changes nothing).
  click = quote(mascot_action())
)
mistakes <- list(
  `Borrow another character's palette` = list(
    code = NULL,
    why = "mascot() errors and lists this character's palettes. The hint names another character that has this id; palettes cannot be borrowed between characters yet."
  ),
  `A made-up palette id` = list(
    code = NULL,
    why = "mascot() errors and lists this character's palettes. No character has this id, so there is no borrowed-palette hint."
  ),
  `An unknown palette in an update` = list(
    code = NULL,
    why = "update_mascot() warns (class mascot_update_ignored) and ignores the whole update. The mascot and its current palette stay unchanged; nothing is dropped."
  ),
  `Leave out an argument name` = list(
    code = "update_mascot(\"helper\", \"happy\")",
    why = "Arguments after id must be named. An unnamed argument reports \"an unnamed argument\" and lists the valid names."
  ),
  `A mood that does not exist` = list(
    code = "update_mascot(\"helper\", mood = \"sleepy\")",
    why = "Displays a warning listing valid moods. The mascot keeps its current mood."
  ),
  `Misspell an argument` = list(
    code = "update_mascot(\"helper\", moood = \"happy\")",
    why = "... must be empty, so typos produce an error listing the valid argument names."
  ),
  `Invalid helper value` = list(
    code = "update_mascot(\"helper\", size = mascot_size(10))",
    why = "A helper that errors gives a warning (class mascot_update_ignored); the whole update is ignored and the mascot stays unchanged."
  ),
  `Too small` = list(code = "update_mascot(\"helper\", size = 10)", why = "Sizes must be at least 24 pixels."),
  `Minimise an inline mascot` = list(
    code = "update_mascot(\"helper\", placement = mascot_placement(\"inline\", minimise = TRUE))",
    why = "An inline mascot ignores minimise. An informational message explains this, and the mascot sits inline."
  ),
  `A bubble that never shows` = list(
    code = "update_mascot(\"helper\", bubble = mascot_bubble(\"Hi\", duration = 0))",
    why = "duration must be greater than zero. Use Inf to keep the bubble open."
  ),
  `Not a colour` = list(
    code = "update_mascot(\"helper\", theme = list(body = \"not-a-colour\"))",
    why = "Colours are validated in R before sending to the browser."
  ),
  `Low contrast` = list(
    code = "update_mascot(\"helper\", theme = list(body = \"#f8f9fa\"))",
    why = "The colour is applied, with a warning if contrast against the page is low."
  ),
  `The wrong id` = list(
    code = "update_mascot(\"helpr\", mood = \"happy\")",
    why = paste(
      "No error and no change: the server cannot see browser elements. With shiny::devmode(TRUE), the browser",
      "console reports the missing element."
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
  mascot_character = list(id = input_id("character")),
  mascot_mood = list(name = input_id("mood")),
  mascot_status = list(text = input_id("status_text")),
  mascot_bubble = list(
    ... = fixed_arg("Must be empty: optional arguments are named."),
    text = input_id("bubble_text", "bubble_example", "bubble_html"),
    duration = input_id("bubble_duration", "bubble_forever"),
    closable = input_id("bubble_closable")
  ),
  mascot_motion_settings = list(
    ... = fixed_arg("Must be empty: all settings are named."),
    idle = input_id("idle"),
    mood_change = input_id("mood_change"),
    gestures = input_id("gestures"),
    swap = input_id("swap"),
    minimising = input_id("minimising"),
    restoring = input_id("restoring"),
    messages = input_id("messages"),
    others = input_id("others")
  ),
  mascot_gesture = list(name = input_id("gesture", "gesture_play")),
  mascot_size = list(
    ... = fixed_arg("Must be empty: optional arguments are named."),
    size = input_id("size_px", "size_unit", "size_pct"),
    small_screen = input_id("small_mode", "small_px")
  ),
  mascot_placement = list(
    position = input_id("position"),
    ... = fixed_arg("Must be empty: optional arguments are named."),
    minimise = input_id("minimise"),
    drag = input_id("drag")
  ),
  mascot_colour_roles = list(
    character = input_id("character"),
    ... = fixed_arg("Must be empty: the palette is named."),
    palette = input_id("palette")
  ),
  mascot_palettes = list(character = input_id("character")),
  mascot_moods = list(character = input_id("character")),
  mascot_gestures = list(character = input_id("character")),
  mascot_anchors = list(character = input_id("character")),
  mascot_characters = list(
    ... = fixed_arg("Must be empty: the family filter is named."),
    family = input_id("list_family")
  ),
  mascot_families = list(),
  mascot_theme = list(
    palette = input_id("palette"),
    ... = fixed_arg("Must be empty: optional arguments are named."),
    light = fixed_arg("Pickers are built from the selected character roles in theme_light."),
    dark = fixed_arg("Pickers are built from the selected character roles in theme_dark."),
    mode = input_id("theme_mode"),
    css = fixed_arg("CSS role checkboxes are built from the selected character; css_accent sets their variable.")
  ),
  mascot_action = list(
    label = input_id("action_on", "action_label"),
    ... = fixed_arg("Must be empty: the controls name every optional argument."),
    tooltip = input_id("action_tooltip"),
    disabled = input_id("action_disabled")
  ),
  mascot_popup_menu = list(
    items = input_id("menu_on", "menu_items"),
    ... = fixed_arg("Must be empty: the controls name every optional argument."),
    direction = input_id("menu_direction"),
    label = input_id("menu_label"),
    tooltip = input_id("menu_tooltip"),
    disabled = input_id("menu_disabled")
  ),
  mascot = list(
    ... = fixed_arg("Must be empty: optional arguments are named."),
    character = input_id("character"),
    id = fixed_arg("The studio's mascot is always mascot(\"helper\")."),
    mood = input_id("mood"),
    status = input_id("status_text"),
    bubble = input_id("bubble_text"),
    size = input_id("size_px"),
    placement = input_id("position"),
    theme = input_id("theme_source"),
    motion = input_id("idle"),
    click = input_id("action_on", "menu_on")
  ),
  update_mascot = list(
    id = input_id("mistake"),
    character = input_id("character"),
    mood = input_id("mood"),
    status = input_id("status_text"),
    bubble = input_id("bubble_text"),
    size = input_id("size_px"),
    placement = input_id("position"),
    theme = input_id("theme_source"),
    motion = input_id("idle"),
    click = input_id("action_on", "menu_on"),
    ... = input_id("mistake", "mistake_run"),
    gesture = input_id("gesture", "gesture_play"),
    session = input_id("task_run")
  ),
  mascot_preview = list(
    ... = fixed_arg("Must be empty: optional arguments are named."),
    character = input_id("character"),
    mood = input_id("preview_mood"),
    status = input_id("preview_status"),
    bubble = input_id("preview_bubble"),
    size = input_id("preview_size", "preview_width"),
    theme = input_id("preview_theme_source"),
    motion = input_id("preview_motion")
  ),
  mascot_example = list(
    ... = fixed_arg("Must be empty: optional arguments are named."),
    name = input_id("example_name"),
    run = input_id("example_run")
  )
)

# Characters the studio can mount: the shipped ones, from the public listing.
studio_characters <- function() {
  listing <- mascot::mascot_characters()
  listing <- listing[listing$built_in, ]
  # Only experimental characters carry a marker; stable ones show their plain name.
  labels <- ifelse(listing$lifecycle %in% "experimental", paste0(listing$name, " (experimental)"), listing$name)
  stats::setNames(listing$id, labels)
}

# The family filter's choices: every family, with "all characters" first.
studio_families <- function() {
  listing <- mascot::mascot_families()
  c(`All characters` = "", stats::setNames(listing$id, listing$name))
}

# Count shipped characters rather than the selector's current discovery adapter.
studio_character_hint <- function(
  directory = system.file("format", "characters", package = "mascot", mustWork = TRUE)
) {
  checkmate::assert_directory_exists(directory)
  files <- list.files(directory, pattern = "[.]json$")
  if (length(files) != 1) {
    return(NULL)
  }
  id <- sub("[.]json$", "", files)
  paste(mascot::mascot_character(id)$name, "is the only built-in character so far.")
}

# The brand slots of a character, read from the public colour-role listing: slot name to role.
studio_brand <- function(character) {
  checkmate::assert_string(character)
  roles <- mascot::mascot_colour_roles(character)
  roles <- roles[!is.na(roles$brand), ]
  result <- list()
  for (i in seq_len(nrow(roles))) {
    for (slot in strsplit(roles$brand[i], ", ", fixed = TRUE)[[1]]) {
      result[[slot]] <- roles$role[i]
    }
  }
  result
}

character_mistakes <- function(character) {
  checkmate::assert_string(character)
  role <- mascot::mascot_colour_roles(character)$role[1]
  result <- mistakes
  palettes <- studio_mistake_palettes(character)
  for (name in c("Borrow another character's palette", "A made-up palette id", "An unknown palette in an update")) {
    updating <- identical(name, "An unknown palette in an update")
    palette <- if (name == "A made-up palette id") palettes$invented else palettes$borrowed
    if (is.null(palette)) {
      # No borrowed example is possible if all shipped characters ever share exactly the same ids.
      result[[name]] <- NULL
      next
    }
    result[[name]]$code <- format_call(
      if (updating) "update_mascot" else "mascot",
      list("helper", character = character, theme = palette)
    )
  }
  for (name in c("Not a colour", "Low contrast")) {
    result[[name]]$code <- sub("body =", paste0(arg_name(role), " ="), result[[name]]$code, fixed = TRUE)
  }
  result
}

# Internal authoring coverage is separate from the exported function map until R4b.
studio_character_controls <- list(
  mascot_read_character = list(path = input_id("your_character_file", "your_character_example")),
  mascot_check_character = list(x = input_id("your_character_check")),
  mascot_register_character = list(x = fixed_arg("App start-up only; generated code shows registration.")),
  mascot_save_character = list(
    x = input_id("your_character_save"),
    path = input_id("your_character_save"),
    ... = fixed_arg("Must be empty."),
    overwrite = fixed_arg("Download replaces only Shiny's supplied temporary destination.")
  )
)

# Temporary until #375 removes resting-only animations from the gesture listing.
studio_resting_gestures <- c(tessa = "shimmer")

studio_gesture_choices <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  gestures <- mascot::mascot_gestures(character)$name
  resting <- gestures %in% studio_resting_gestures[character]
  gestures <- c(gestures[!resting], gestures[resting])
  labels <- ifelse(
    gestures %in% studio_resting_gestures[character],
    paste(gestures, "(resting animation)"),
    paste("a", tools::toTitleCase(gestures))
  )
  c("no gesture" = "", stats::setNames(gestures, labels))
}

# Keep the API names in studio_palette_choices(); humanise only the sentence's labels.
studio_palette_labels <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  choices <- studio_palette_choices(character)
  labels <- gsub("_", " ", names(choices), fixed = TRUE)
  names(choices) <- paste0(toupper(substr(labels, 1L, 1L)), substring(labels, 2L))
  native <- names(studio_palette_choices(character))[[1L]]
  names(choices)[[1L]] <- paste0(
    mascot::mascot_character(character)$name,
    "'s own colours",
    if (native != "original") paste0(" (", native, ")")
  )
  choices
}

studio_long_status <- "Review in progress: checking the submitted rows and recording the results before the next step."

# Named examples, independent of the studio default character.
studio_palette_swap <- c(from = "tessa", kept = "sela", dropped = "knurl", palette = "peach")

# Use a real palette owned by another shipped character, and an id that no character owns.
studio_mistake_palettes <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  own <- mascot::mascot_palettes(character)$name
  others <- setdiff(unname(studio_characters()), character)
  available <- unique(unlist(lapply(others, function(id) mascot::mascot_palettes(id)$name)))
  borrowed <- setdiff(available, c("original", own))
  invented <- "zzzzzz"
  while (invented %in% c(own, available)) {
    invented <- paste0(invented, "z")
  }
  list(borrowed = if (length(borrowed)) borrowed[[1L]], invented = invented)
}

# The sentence keeps the selector's API value "original" while naming the character's own colours.
studio_palette_sentence <- function(character, palette = "original") {
  checkmate::assert_string(character, min.chars = 1)
  checkmate::assert_string(palette, min.chars = 1)
  choices <- studio_palette_choices(character)
  native <- names(choices)[match("original", choices)]
  labels <- studio_palette_labels(character)
  original <- identical(palette, "original")
  list(
    prefix = if (original) "in" else "in the",
    label = names(labels)[match(palette, choices)],
    suffix = if (original) "," else "palette,",
    id = if (original) native else palette
  )
}
