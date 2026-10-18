# Inspector controls: one mounted input per argument, folded by function when showing all controls.
# Shiny sources this before app.R attaches mascot, so everything here is a function, called
# from app.R once the packages are attached.

# Groups for the colour pickers; parts a future character adds appear under "Other parts".
colour_groups <- function(roles) {
  groups <- list(
    Body = c("body", "body_highlight", "rim", "shadow", "outline"),
    Face = c("feature", "eye_white", "shine", "eyelid", "teeth", "tongue", "blush", "blush_strong"),
    `Arms and accessories` = c("limb", "sleeve", "accessory", "accessory_detail"),
    Effects = c("sparkle", "sparkle_outline", "sweat")
  )
  groups <- lapply(groups, intersect, roles$role)
  groups$`Other parts` <- setdiff(roles$role, unlist(groups))
  Filter(length, groups)
}

# ---- Inspector controls, grouped by function -----------------------------------------------

role_picker <- function(mode, role, roles, value = NULL) {
  row <- roles[roles$role == role, ]
  follows <- if (is.na(row$follows)) "leader" else paste0("follows ", row$follows, " (", row$shade, ")")
  div(
    class = "pg-role",
    colour_input(paste0(mode, "_", role), value %||% row$colour, paste(role, "in", mode, "mode")),
    div(class = "pg-role-text", tags$code(role), div(class = "pg-muted", follows)),
    tags$span(
      class = "pg-resolved",
      `data-role` = role,
      `data-mode` = mode,
      `data-default` = row$colour,
      title = "In use now"
    ),
    tags$button(
      type = "button",
      class = "btn btn-link btn-sm pg-role-reset",
      `data-event` = "reset_colour",
      `data-value` = paste0(mode, ":", role),
      `aria-label` = paste("Reset", role, "in", mode, "mode"),
      "\u00d7"
    )
  )
}

role_pickers <- function(mode, roles, values = list(), name = mascot_character()$name) {
  role_groups <- colour_groups(roles)
  tagList(
    div(
      class = "pg-hint",
      paste0(
        "Each picker starts at ",
        name,
        "'s colour. Change one to add it to the theme. Click \u00d7 to remove it. The round swatch shows the colour in use now."
      )
    ),
    do.call(
      bslib::accordion,
      c(
        lapply(names(Filter(length, role_groups)), function(group) {
          bslib::accordion_panel(
            group,
            lapply(role_groups[[group]], function(role) role_picker(mode, role, roles, values[[role]])),
            value = group
          )
        }),
        list(open = names(role_groups)[1])
      )
    ),
    try_button("reset_mode", mode, paste("Reset", mode, "colours"), "btn-outline-primary")
  )
}

panel_character_bar <- function(moods = mascot_moods(character), character = formals(mascot::mascot)$character) {
  checkmate::assert_data_frame(moods)
  checkmate::assert_string(character)
  div(
    id = "studio_character_bar",
    class = "pg-toolbar pg-card-head pg-character-bar",
    div(
      class = "d-flex flex-wrap align-items-end gap-2 w-100 pg-character-bar-controls",
      selectInput("character", "Character", studio_characters(), selected = character),
      selectInput("palette", "Palette", mascot_palettes(character)$name, selected = "original"),
      selectInput("mood", "Mood", stats::setNames(moods$name, tools::toTitleCase(moods$name)), selected = "idle"),
      selectInput("gesture", "Gesture", mascot_gestures(character)$name, selected = "nod"),
      actionButton("gesture_play", "Play", class = "btn-outline-primary btn-sm"),
      if (!is.null(studio_character_hint())) div(class = "pg-hint", studio_character_hint())
    ),
    actionButton("reset_all", "Start again", class = "btn-outline-primary btn-sm")
  )
}

panel_look <- function() {
  inspector_category(
    playground_categories$look$title,
    value = "look",
    fn_heading("mascot_character"),
    arg_field(
      "mascot_character",
      "id",
      NULL,
      note = div(class = "pg-note", "Choose the character in the top bar.")
    ),
    fn_heading("mascot_mood"),
    arg_field(
      "mascot_mood",
      "name",
      NULL,
      note = div(class = "pg-note", "Choose the mood in the top bar.")
    ),
    fn_heading("mascot_moods"),
    arg_field(
      "mascot_moods",
      "character",
      div(
        class = "pg-note",
        "Uses the character chosen under mascot_character(). Its table, with the status text of each mood,
        appears in the Guide."
      )
    ),
    fn_heading("mascot_characters"),
    arg_field("mascot_characters", "...", NULL),
    arg_field(
      "mascot_characters",
      "family",
      selectInput("list_family", "Family", studio_families()),
      note = div(class = "pg-hint", "The table of characters appears in the Guide.")
    ),
    fn_heading("mascot_families"),
    div(class = "pg-hint", "No arguments. See its table in the Guide."),
    fn_heading("mascot_anchors"),
    arg_field(
      "mascot_anchors",
      "character",
      div(
        class = "pg-note",
        "Uses the character chosen under mascot_character(). Its anchors appear in the Guide."
      )
    )
  )
}

panel_messages <- function() {
  inspector_category(
    playground_categories$messages$title,
    value = "messages",
    fn_heading("mascot_status"),
    arg_field(
      "mascot_status",
      "text",
      textInput("status_text", "Status text", placeholder = "Empty: follow the mood"),
      note = try_button("status_clear", "1", "Follow the mood again", "btn-outline-primary")
    ),
    fn_heading("mascot_bubble"),
    arg_field("mascot_bubble", "...", NULL),
    arg_field(
      "mascot_bubble",
      "text",
      tagList(
        selectInput("bubble_example", "Start from an example", names(bubble_examples)),
        textAreaInput("bubble_text", "Bubble content", bubble_examples[[1]]$text, rows = 5, resize = "vertical"),
        # Right under the message box, so the next step after typing is in view.
        div(
          class = "pg-actions",
          actionButton("bubble_show", "Show bubble", class = "btn-primary btn-sm"),
          actionButton("bubble_clear", "Clear bubble", class = "btn-outline-primary btn-sm")
        ),
        input_switch("bubble_html", "Treat as HTML (wraps it in HTML())", FALSE)
      ),
      note = div(
        class = "pg-hint",
        "The HTML switch, duration and close button below apply the next time you click Show bubble."
      )
    ),
    arg_field(
      "mascot_bubble",
      "duration",
      tagList(
        div(id = "bubble_seconds", sliderInput("bubble_duration", "Seconds", min = 1, max = 30, value = 5)),
        input_switch("bubble_forever", "Until closed (Inf)", FALSE)
      )
    ),
    arg_field("mascot_bubble", "closable", input_switch("bubble_closable", "Show a close button", TRUE)),
    fn_heading("mascot_action"),
    arg_field(
      "mascot_action",
      "label",
      tagList(
        input_switch("action_on", "Make the mascot a button", FALSE),
        textInput("action_label", "Label: what a click does", "Open help"),
        uiOutput("action_problem")
      ),
      note = div(
        class = "pg-note",
        "Click or tap the mascot, or Tab to it and press Enter: each one sets input$helper_click. ",
        "This studio answers with a wave; your app decides what happens."
      )
    ),
    arg_field("mascot_action", "...", NULL),
    arg_field(
      "mascot_action",
      "tooltip",
      input_switch("action_tooltip", "Show the label in a tooltip", TRUE),
      note = div(class = "pg-hint", "Rest the pointer on the mascot, or Tab to it. Escape hides the tooltip.")
    ),
    arg_field("mascot_action", "disabled", input_switch("action_disabled", "Disabled: clicks send nothing", FALSE)),
    div(
      class = "pg-field",
      id = "click_field",
      div(class = "pg-field-head", tags$strong("Action clicks reach your server")),
      div(
        class = "pg-hint",
        "With an action, each activation sets input$helper_click: a click or tap, Enter or Space. ",
        "Menu toggles send no clicks; choosing an item sets input$helper_menu. Without a click, the mascot is a picture."
      ),
      div(class = "pg-live", tags$code("input$helper_click"), textOutput("click_last"))
    ),
    fn_heading("mascot_popup_menu"),
    arg_field(
      "mascot_popup_menu",
      "items",
      tagList(
        # The controls start with the menu the mascot starts with (start$click in app.R).
        input_switch("menu_on", "Show the menu", TRUE),
        textAreaInput(
          "menu_items",
          "One item per line: id = Label",
          paste(names(default_menu), "=", default_menu, collapse = "\n"),
          rows = 4,
          resize = "vertical"
        ),
        uiOutput("menu_problem")
      ),
      note = div(class = "pg-note", "Click or tap the mascot to open its menu, then choose an item.")
    ),
    arg_field("mascot_popup_menu", "...", NULL),
    arg_field(
      "mascot_popup_menu",
      "direction",
      radioButtons(
        "menu_direction",
        NULL,
        c(
          "Auto (open where there is room)" = "auto",
          "Top" = "top",
          "Bottom" = "bottom",
          "Left" = "left",
          "Right" = "right"
        ),
        selected = "auto"
      ),
      note = div(
        class = "pg-note",
        "Open the menu and watch the eyes: the mascot looks towards the side the menu opened on, ",
        "which can differ from the one chosen when that side has no room. It also looks towards a bubble."
      )
    ),
    arg_field(
      "mascot_popup_menu",
      "label",
      textInput("menu_label", "Name for screen readers", "", placeholder = "Help and settings"),
      note = div(
        class = "pg-hint",
        "Screen readers announce the mascot as a button with this name. Empty: the character's name and \"menu\"."
      )
    ),
    arg_field(
      "mascot_popup_menu",
      "tooltip",
      input_switch("menu_tooltip", "Show the label in a tooltip", TRUE),
      note = div(class = "pg-hint", "Rest the pointer on the mascot, or Tab to it. Escape hides the tooltip.")
    )
  )
}

panel_motion <- function(gestures = mascot_gestures()) {
  inspector_category(
    playground_categories$motion$title,
    value = "motion",
    fn_heading("mascot_motion_settings"),
    arg_field("mascot_motion_settings", "...", NULL),
    lapply(c("idle", "mood_change", "gestures", "swap", "minimising", "restoring"), function(name) {
      arg_field(
        "mascot_motion_settings",
        name,
        selectInput(
          name,
          tools::toTitleCase(gsub("_", " ", name)),
          choices = c("Follow others" = "follow", "On" = "true", "Off" = "false"),
          selected = "follow"
        )
      )
    }),
    arg_field(
      "mascot_motion_settings",
      "messages",
      selectInput(
        "messages",
        "Moving panels",
        choices = c(
          "Follow others" = "follow",
          "All" = "all",
          "Bubble" = "bubble",
          "Tooltip" = "tooltip",
          "Menu" = "menu"
        ),
        selected = "follow",
        multiple = TRUE
      )
    ),
    arg_field(
      "mascot_motion_settings",
      "others",
      input_switch("others", "Other movement", TRUE),
      note = div(
        class = "pg-note",
        "Turn this off with all switches following it to try motion = FALSE, including reduced poses and instant drag transitions."
      )
    ),
    fn_heading("mascot_gesture"),
    arg_field(
      "mascot_gesture",
      "name",
      div(class = "pg-note", "Choose a gesture in the top bar, then press Play.")
    ),
    div(
      class = "pg-note",
      "One-off gestures appear in the Last tab of the Code tray, not in UI, Server, or App."
    ),
    fn_heading("mascot_gestures"),
    arg_field(
      "mascot_gestures",
      "character",
      div(
        class = "pg-note",
        "Uses the character chosen under mascot_character(). Its gestures, with the length that plays, appear in the Guide."
      )
    )
  )
}

panel_layout <- function() {
  inspector_category(
    playground_categories$layout$title,
    value = "layout",
    fn_heading("mascot_size"),
    arg_field("mascot_size", "...", NULL),
    arg_field(
      "mascot_size",
      "size",
      tagList(
        radioButtons("size_unit", NULL, c(Pixels = "px", Percentage = "pct"), inline = TRUE),
        conditionalPanel(
          "input.size_unit == 'px'",
          sliderInput("size_px", "Pixels", min = 24, max = 320, value = 160, step = 4)
        ),
        conditionalPanel(
          "input.size_unit == 'pct'",
          sliderInput("size_pct", "Percentage of the container", min = 10, max = 100, value = 30, post = "%")
        )
      )
    ),
    arg_field(
      "mascot_size",
      "small_screen",
      tagList(
        radioButtons(
          "small_mode",
          NULL,
          c(
            "Auto (phone size when floating)" = "auto",
            "Same size on every screen (NULL)" = "same",
            "Specific size (pixels)" = "number"
          ),
          selected = "auto"
        ),
        conditionalPanel(
          "input.small_mode == 'number'",
          sliderInput("small_px", "Pixels", min = 24, max = 160, value = 72, step = 4)
        )
      )
    ),
    fn_heading("mascot_placement"),
    arg_field("mascot_placement", "...", NULL),
    div(
      class = "pg-note",
      "A floating mascot sits above the page, so here it can cover the Controls panel; ",
      "turn on dragging to move it aside."
    ),
    arg_field(
      "mascot_placement",
      "position",
      radioButtons(
        "position",
        "Position",
        c(Inline = "inline", stats::setNames(corners, tools::toTitleCase(sub("-", " ", corners, fixed = TRUE)))),
        selected = "inline"
      )
    ),
    arg_field(
      "mascot_placement",
      "minimise",
      tagList(
        input_switch("minimise", "Show a minimise button", TRUE),
        conditionalPanel(
          "input.position == 'inline'",
          div(class = "pg-note", "An inline mascot ignores minimise. Pick a corner position to try it.")
        )
      )
    ),
    arg_field(
      "mascot_placement",
      "drag",
      tagList(
        selectInput("drag", "When dropped", c("No dragging" = "none", Snap = "snap", Free = "free")),
        conditionalPanel(
          "input.position == 'inline'",
          div(class = "pg-note", "An inline mascot ignores drag. Pick a corner position to try it.")
        ),
        div(class = "pg-live", tags$code("input$helper_position"), textOutput("position_last"))
      )
    )
  )
}

panel_colours <- function() {
  styling <- help_rd("mascot_styling")
  tagList(
    inspector_function(
      "mascot_theme",
      tags$details(
        tags$summary("Styling panels and the restore button with CSS"),
        div(
          class = "pg-help",
          lapply(rd_sections(styling, "\\section"), function(section) {
            tagList(tags$h4(rd_text(section[[1]])), rd_html(section[[2]]))
          })
        )
      ),
      arg_field("mascot_theme", "...", NULL),
      arg_field("mascot_theme", "palette", div(class = "pg-note", "Choose a palette in the top bar.")),
      radioButtons(
        "theme_source",
        "Where the colours come from",
        c(
          "Palette from the top bar" = "own",
          "Your colours" = "mascot",
          "Your app's brand: bslib::bs_theme() instead of mascot_theme()" = "bslib"
        )
      ),
      div(
        class = "pg-hint",
        "The settings below change with your choice: pick a source to see only the controls for it."
      ),
      conditionalPanel(
        "input.theme_source == 'own'",
        div(class = "pg-note", "Uses the palette from the top bar; original keeps the character's own colours.")
      ),
      conditionalPanel(
        "input.theme_source == 'mascot'",
        arg_field(
          "mascot_theme",
          "mode",
          radioButtons(
            "theme_mode",
            "Colour mode",
            c("Follow the page switch (auto)" = "auto", "Always light" = "light", "Always dark" = "dark")
          )
        ),
        bslib::navset_tab(
          bslib::nav_panel("Light", uiOutput("theme_light")),
          bslib::nav_panel("Dark", uiOutput("theme_dark")),
          bslib::nav_panel("CSS variables", uiOutput("theme_css"))
        )
      ),
      conditionalPanel(
        "input.theme_source == 'bslib'",
        div(class = "pg-note", "mascot(theme = ) also accepts a bslib theme; it colours the character's brand parts."),
        uiOutput("theme_brand")
      ),
      conditionalPanel(
        "input.theme_source != 'own'",
        actionButton("contrast_check", "Check contrast", class = "btn-outline-primary btn-sm"),
        uiOutput("contrast")
      )
    ),
    inspector_function(
      "mascot_colour_roles",
      arg_field("mascot_colour_roles", "...", NULL),
      arg_field("mascot_colour_roles", "palette", div(class = "pg-note", "Choose a palette in the top bar.")),
      arg_field(
        "mascot_colour_roles",
        "character",
        div(
          class = "pg-note",
          "Uses the character chosen under mascot_character(). Its colour parts appear in the Guide."
        )
      )
    ),
    inspector_function(
      "mascot_palettes",
      arg_field(
        "mascot_palettes",
        "character",
        div(
          class = "pg-note",
          "Uses the character chosen under mascot_character(). Its palettes appear in the Guide."
        )
      )
    )
  )
}


panel_wiring <- function() {
  inspector_category(
    playground_categories$wiring$title,
    value = "wiring",
    fn_heading("mascot"),
    arg_field("mascot", "...", NULL),
    arg_field(
      "mascot",
      "id",
      code_block("mascot(\"helper\")", "pg-code-small"),
      note = div(class = "pg-note", "The mascot always uses id = \"helper\" in this studio.")
    ),
    wiring_links("mascot"),
    fn_heading("update_mascot"),
    arg_field(
      "update_mascot",
      "id",
      code_block("update_mascot(\"helper\", ...)", "pg-code-small")
    ),
    wiring_links("update_mascot"),
    div(
      class = "pg-field",
      div(class = "pg-field-head", tags$strong("Several changes in one call")),
      div(class = "pg-hint", "Send one message to update mood, status, bubble, and gesture together."),
      actionButton("send_many", "Celebrate a finished review", class = "btn-outline-primary btn-sm")
    ),
    arg_field(
      "update_mascot",
      "...",
      tagList(
        selectInput("mistake", "Demonstration: try an invalid call in ...", names(mistakes)),
        uiOutput("mistake_code"),
        actionButton("mistake_run", "Run it", class = "btn-outline-danger btn-sm")
      ),
      note = div(class = "pg-note", "The result appears in the Log tab of the Code tray.")
    ),
    arg_field(
      "update_mascot",
      "session",
      tagList(
        div(
          class = "pg-hint",
          "Demonstrates a slow task using session: thinking now, then happy (or worried) two seconds later. ",
          "The second call passes session explicitly, as an asynchronous callback would."
        ),
        input_switch("task_fail", "Make the task fail", FALSE),
        actionButton("task_run", "Run a 2-second task", class = "btn-outline-primary btn-sm")
      )
    )
  )
}

panel_studio <- function() {
  inspector_function(
    "mascot_studio",
    div(class = "pg-hint", "Launches the mascot studio."),
    div(
      class = "pg-code-wrap",
      code_block('mascot_studio(fn = "mascot_theme")', "pg-code-small", id = "studio_example_call"),
      copy_button("studio_example_call")
    ),
    div(
      class = "pg-args",
      lapply(names(formals(mascot::mascot_studio)), function(arg) {
        arg_block("mascot_studio", arg)
      })
    )
  )
}

# mascot_preview(): its arguments, read from the package for the selected character. The canvas shows
# the page the call returns while this function is selected; the Code tray shows the call.
panel_preview <- function(moods = mascot_moods()) {
  fn <- "mascot_preview"
  inspector_function(
    fn,
    arg_field(fn, "...", NULL),
    arg_field(
      fn,
      "character",
      div(class = "pg-note", "Uses the character chosen under mascot_character().")
    ),
    arg_field(
      fn,
      "mood",
      selectInput("preview_mood", "Mood", c("Every mood (NULL)" = "", stats::setNames(moods$name, moods$name)))
    ),
    arg_field(fn, "status", textInput("preview_status", "Status text", placeholder = "Empty: each mood")),
    arg_field(fn, "bubble", textInput("preview_bubble", "Bubble text", placeholder = "Empty: no bubble")),
    arg_field(
      fn,
      "size",
      tagList(
        sliderInput(
          "preview_size",
          "Pixels",
          min = 48,
          max = 240,
          value = formals(mascot::mascot_preview)$size,
          step = 8
        ),
        radioButtons(
          "preview_width",
          "Show the page at",
          c("Full width" = "full", "Phone width (375 px)" = "phone"),
          inline = TRUE
        )
      ),
      note = div(class = "pg-note", "Phone width narrows the page; the mascot pixel size stays unchanged.")
    ),
    arg_field(fn, "placement", selectInput("preview_placement", "Placement", c("inline", corners))),
    arg_field(
      fn,
      "theme",
      tagList(
        radioButtons(
          "preview_theme_source",
          "Colours",
          c("Palette from the top bar" = "own", "Your colours" = "custom")
        ),
        conditionalPanel("input.preview_theme_source == 'custom'", uiOutput("preview_pickers"))
      )
    ),
    arg_field(fn, "motion", input_switch("preview_motion", "Animate", FALSE)),
    arg_field(
      fn,
      "click",
      textAreaInput("preview_menu_items", "Menu items, one per line: id = Label", "", rows = 3),
      note = uiOutput("preview_problem")
    ),
    actionButton("preview_build", "Rebuild now", class = "btn-outline-primary btn-sm")
  )
}

# The two example functions open the Examples view, which has its own controls.
panel_views <- function() {
  tagList(lapply(c("mascot_examples", "mascot_example"), function(fn) {
    inspector_function(
      fn,
      tags$a(
        class = "btn btn-outline-primary btn-sm",
        href = "?view=examples",
        target = "_blank",
        rel = "noopener",
        "Open Examples"
      ),
      div(class = "pg-note", "This view has its own controls and opens in a new tab.")
    )
  }))
}

# Keep explicit overrides for shared roles; untouched pickers adopt the new palette.
reconcile_colour_values <- function(old_roles, roles, values) {
  checkmate::assert_data_frame(old_roles, null.ok = TRUE)
  checkmate::assert_data_frame(roles)
  checkmate::assert_list(values)
  stats::setNames(
    lapply(roles$role, function(role) {
      value <- values[[role]]
      if (is.null(old_roles) || !role %in% old_roles$role || is.null(value)) {
        return(NULL)
      }
      old <- old_roles$colour[match(role, old_roles$role)]
      if (tolower(value) == tolower(old)) NULL else value
    }),
    roles$role
  )
}

# Internal R4a review panel, omitted unless explicitly enabled before launch.
panel_your_character <- function() {
  if (!isTRUE(getOption("mascot.internal.character_panel", FALSE))) {
    return(NULL)
  }
  tags$details(
    tags$summary("Your character"),
    div(
      class = "pg-note",
      "The browser uploads the file to this studio's R session. Locally it stays on this computer; ",
      "when hosted it reaches that server. It is never sent to another service."
    ),
    fileInput("your_character_file", "Character JSON", accept = ".json"),
    actionButton("your_character_example", "Load Study Bot example"),
    textOutput("your_character_check"),
    tags$button(
      type = "button",
      class = "btn btn-outline-primary btn-sm",
      `data-event` = "select_function",
      `data-value` = "mascot_preview",
      "Open in the preview controls"
    ),
    selectInput("your_character_mood", "Mood", c("Every mood" = "")),
    selectInput("your_character_gesture", "Gesture", character()),
    actionButton("your_character_play", "Play gesture"),
    sliderInput("your_character_size", "Size in pixels", min = 24, max = 240, value = 160),
    selectInput("your_character_mode", "Mode", c("Both modes" = "both", Light = "light", Dark = "dark")),
    downloadButton("your_character_save", "Save resolved JSON"),
    verbatimTextOutput("your_character_code"),
    uiOutput("your_character_live"),
    uiOutput("your_character_grid")
  )
}
