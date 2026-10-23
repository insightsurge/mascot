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
# The calls of the guide's "common mistakes" lists live in guide/guide-mistakes.R, shared with the website;
# its functions are defined here too, and the studio's names point to them.
studio_guide_dir <- function() {
  # mascot_studio() names the app's folder; otherwise the app's own folder (Shiny runs it from there) or the
  # installed package.
  if (exists("studio_guide_root", inherits = TRUE)) {
    return(file.path(get("studio_guide_root", inherits = TRUE), "guide"))
  }
  local <- file.path(getwd(), "guide")
  if (file.exists(file.path(local, "guide-helpers.R"))) {
    return(normalizePath(local))
  }
  system.file("examples", "studio", "guide", package = "mascot")
}
sys.source(file.path(studio_guide_dir(), "guide-mistakes.R"), envir = environment())
sys.source(file.path(studio_guide_dir(), "guide-shared.R"), envir = environment())
mistakes <- guide_mistake_base
character_mistakes <- guide_character_mistakes

# Where each argument can be tried: the HTML that must be on the page (an input id), or the reason it
# has no control. tests/testthat/test-examples.R checks that every exported argument has an entry and
# that its control is on the page.
input_id <- function(...) paste0("id=\"", c(...), "\"")
fixed_arg <- function(reason) list(fixed = reason)

studio_controls <- list(
  mascot_read_character = list(path = fixed_arg("Bundled offline example; copy the call to read your own file.")),
  mascot_check_character = list(x = fixed_arg("Bundled offline example; copy the call to check your source list.")),
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
    light = fixed_arg("Pickers are built from the selected character's roles by the colour module (colours-light)."),
    dark = fixed_arg("Pickers are built from the selected character's roles by the colour module (colours-dark)."),
    mode = input_id("theme_mode"),
    css = fixed_arg("CSS role checkboxes are built from the selected character; colours-css_value sets their variable.")
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

# The family filter's choices: every family, with "all characters" first.
studio_families <- function() {
  listing <- mascot::mascot_families()
  c(`All characters` = "", stats::setNames(listing$id, listing$name))
}

# The brand slots of a character: slot name to role (the same function the guide pages use).
studio_brand <- guide_brand_roles

# The controls of the "Your character" panel (R/panels.R), kept apart from the function map above.
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

# Animations that play only at rest but appear in the gesture listing (#375): listed last and labelled.
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

studio_long_status <- "Review in progress: checking the submitted rows and recording the results before the next step."

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
