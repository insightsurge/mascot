# What the studio knows about each exported function that its help page does not: the category,
# the vignette section to read next and, per argument, the category where it can be tried. The
# words (description, arguments, details, returns) are read from the help pages at run time, see
# R/help.R. tests/testthat/test-examples.R fails when an export or an argument has no entry here,
# and when this file holds prose. Shiny sources this file before app.R attaches mascot, so it
# holds plain data only.

playground_categories <- list(
  look = list(
    title = "Character and mood",
    summary = "Who is drawn and how they feel. A mood changes the face, the pose and the default status text."
  ),
  messages = list(
    title = "Messages and clicks",
    summary = "Words and actions on the mascot: a status line that is always there, a speech bubble for news, and what a click does: one action or a menu."
  ),
  motion = list(
    title = "Motion and gestures",
    summary = "Whether changes animate, and one-off movements that leave the mood as it is."
  ),
  layout = list(
    title = "Size and placement",
    summary = "How big the mascot is, on wide and narrow screens, and whether it sits in the page or floats."
  ),
  colours = list(
    title = "Colours and theme",
    summary = "Recolour any part of the character, follow your app's brand, and choose light or dark."
  ),
  wiring = list(
    title = "Wiring it in Shiny",
    summary = "Where each call goes: mascot() in the UI, update_mascot() in the server, and modules."
  ),
  preview = list(
    title = "Preview page",
    summary = "An offline page that compares moods, colours and sizes without running Shiny. While it is selected, its page replaces the live mascot on the canvas."
  ),
  examples = list(
    title = "Bundled examples",
    summary = "Small apps that each teach one scenario. Copy one to start your own."
  )
)

# A heading of vignettes/mascot.Rmd ("Get started"); the Guide links to it and never copies it.
guide_entry <- function(category, vignette, args = character(), try = list()) {
  entries <- lapply(args, function(arg) if (is.null(try[[arg]])) list() else list(try = try[[arg]]))
  list(category = category, vignette = vignette, args = stats::setNames(entries, args))
}

playground_guide <- list(
  mascot_character = guide_entry("look", "Your first app", "id"),
  mascot_mood = guide_entry("look", "Moods and status", "name"),
  mascot_moods = guide_entry("look", "Moods and status", "character"),
  mascot_characters = guide_entry("look", "Your first app", c("...", "family")),
  mascot_families = guide_entry("look", "Your first app"),
  mascot_anchors = guide_entry("look", "Your first app", "character"),
  mascot_status = guide_entry("messages", "Moods and status", "text"),
  mascot_bubble = guide_entry("messages", "Message bubbles", c("text", "...", "duration", "closable")),
  mascot_motion_settings = guide_entry(
    "motion",
    "Motion",
    c("...", "idle", "mood_change", "gestures", "swap", "minimising", "restoring", "messages", "others")
  ),
  mascot_gesture = guide_entry("motion", "One-off gestures", c("name", "...")),
  mascot_gestures = guide_entry("motion", "One-off gestures", "character"),
  mascot_size = guide_entry("layout", "Size and placement", c("size", "...", "small_screen")),
  mascot_placement = guide_entry("layout", "Size and placement", c("position", "...", "minimise", "drag")),
  mascot_colour_roles = guide_entry("colours", "Theme and light/dark mode", "character"),
  mascot_palettes = guide_entry("colours", "Theme and light/dark mode", "character"),
  mascot_theme = guide_entry("colours", "Theme and light/dark mode", c("...", "light", "dark", "mode", "css")),
  mascot_action = guide_entry("messages", "Clicks and menus", c("label", "...", "tooltip", "disabled")),
  mascot_popup_menu = guide_entry("messages", "Clicks and menus", c("items", "...", "direction", "label", "tooltip")),
  mascot = guide_entry(
    "wiring",
    "Your first app",
    c("id", "...", "character", "mood", "status", "bubble", "size", "placement", "theme", "motion", "click"),
    try = list(
      character = "look",
      mood = "look",
      status = "messages",
      bubble = "messages",
      size = "layout",
      placement = "layout",
      theme = "colours",
      motion = "motion",
      click = "messages"
    )
  ),
  update_mascot = guide_entry(
    "wiring",
    "Leave unchanged or reset",
    c(
      "id",
      "...",
      "character",
      "mood",
      "status",
      "bubble",
      "size",
      "placement",
      "theme",
      "motion",
      "click",
      "gesture",
      "session"
    ),
    try = list(
      id = "wiring",
      character = "look",
      mood = "look",
      status = "messages",
      bubble = "messages",
      size = "layout",
      placement = "layout",
      theme = "colours",
      motion = "motion",
      click = "messages",
      gesture = "motion",
      session = "wiring"
    )
  ),
  mascot_preview = guide_entry(
    "preview",
    "Check a look before using it",
    c("character", "...", "mood", "status", "bubble", "size", "placement", "theme", "motion", "click")
  ),
  mascot_examples = guide_entry("examples", "Open an example"),
  mascot_example = guide_entry("examples", "Open an example", c("name", "...", "run")),
  mascot_studio = guide_entry("examples", "Open an example", c("view", "...", "fn", "character", "run"))
)
