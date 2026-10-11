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
        "'s own colour. Change one to add it to the theme; \u00d7 takes it out again. The round swatch shows the colour in use now."
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

panel_look <- function(moods = mascot_moods(), character = formals(mascot::mascot)$character) {
  inspector_category(
    playground_categories$look$title,
    value = "look",
    fn_heading("mascot_character"),
    arg_field(
      "mascot_character",
      "name",
      selectInput("character", "Character", studio_characters(), selected = character)
    ),
    fn_heading("mascot_mood"),
    arg_field(
      "mascot_mood",
      "name",
      mood_cards(moods)
    ),
    fn_heading("mascot_moods"),
    div(class = "pg-hint", "No arguments. Its table is in the Guide; choose mascot_mood() to try a mood.")
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
    arg_field(
      "mascot_bubble",
      "text",
      tagList(
        selectInput("bubble_example", "Start from an example", names(bubble_examples)),
        textAreaInput("bubble_text", "Bubble content", bubble_examples[[1]]$text, rows = 5, resize = "vertical"),
        input_switch("bubble_html", "Treat as HTML (wraps it in HTML())", FALSE)
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
    div(
      class = "pg-actions",
      actionButton("bubble_show", "Show bubble", class = "btn-primary btn-sm"),
      actionButton("bubble_clear", "Clear bubble", class = "btn-outline-primary btn-sm")
    ),
    fn_heading("mascot_popup_menu"),
    arg_field(
      "mascot_popup_menu",
      "items",
      tagList(
        input_switch("menu_on", "Show the menu", TRUE),
        textAreaInput("menu_items", "One item per line: id = Label", menu_lines, rows = 4, resize = "vertical"),
        uiOutput("menu_problem")
      ),
      note = div(class = "pg-note", "Open the menu with the button on the mascot, then pick an item.")
    ),
    arg_field(
      "mascot_popup_menu",
      "direction",
      radioButtons(
        "menu_direction",
        NULL,
        c(
          "Auto (pick the side with room)" = "auto",
          "Top" = "top",
          "Bottom" = "bottom",
          "Left" = "left",
          "Right" = "right"
        ),
        selected = "auto"
      )
    )
  )
}

panel_motion <- function(gestures = mascot_gestures()) {
  inspector_category(
    playground_categories$motion$title,
    value = "motion",
    fn_heading("mascot_motion"),
    arg_field("mascot_motion", "animate", input_switch("animate", "Animate changes", TRUE)),
    arg_field("mascot_motion", "swap", input_switch("swap", "Animate character swaps", TRUE)),
    fn_heading("mascot_gesture"),
    arg_field(
      "mascot_gesture",
      "name",
      div(
        class = "pg-actions",
        lapply(gestures$name, function(name) try_button("gesture", name, tools::toTitleCase(name)))
      )
    ),
    fn_heading("mascot_gestures"),
    div(class = "pg-hint", "No arguments. Its table is shown as the gesture cards in the Guide.")
  )
}

panel_layout <- function() {
  inspector_category(
    playground_categories$layout$title,
    value = "layout",
    fn_heading("mascot_size"),
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
        input_switch("small_on", "Use a different size on small screens", FALSE),
        conditionalPanel("input.small_on", sliderInput("small_px", "Pixels", min = 24, max = 160, value = 72, step = 4))
      )
    ),
    fn_heading("mascot_placement"),
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
          div(class = "pg-note", "An inline mascot ignores minimise: pick a corner to try it.")
        )
      )
    ),
    arg_field(
      "mascot_placement",
      "drag",
      tagList(
        selectInput("drag", "When dropped", c("No dragging (FALSE)" = "FALSE", Snap = "snap", Free = "free")),
        conditionalPanel(
          "input.position == 'inline'",
          div(class = "pg-note", "An inline mascot ignores drag: pick a corner to try it.")
        ),
        div(class = "pg-live", tags$code("input$helper_position"), textOutput("position_last"))
      )
    )
  )
}

panel_colours <- function() {
  tagList(
    inspector_function(
      "mascot_theme",
      radioButtons(
        "theme_source",
        "Where the colours come from",
        c("Character's own colours" = "own", "Your colours" = "mascot", "Your app's brand" = "bslib")
      ),
      div(
        class = "pg-hint",
        "The settings below change with your choice: pick a source to see only the controls for it."
      ),
      conditionalPanel(
        "input.theme_source == 'own'",
        div(class = "pg-note", "Uses the character's own colours in light and dark mode.")
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
      conditionalPanel("input.theme_source == 'bslib'", uiOutput("theme_brand")),
      conditionalPanel(
        "input.theme_source != 'own'",
        actionButton("contrast_check", "Check contrast", class = "btn-outline-primary btn-sm"),
        uiOutput("contrast")
      )
    ),
    inspector_function(
      "mascot_colour_roles",
      arg_field(
        "mascot_colour_roles",
        "character",
        div(
          class = "pg-note",
          "Uses the character selected under mascot_character(). Its parts are listed in the Guide."
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
    arg_field(
      "mascot",
      "id",
      code_block("mascot(id = \"helper\")", "pg-code-small"),
      note = div(class = "pg-note", "The mascot always uses id = \"helper\" in this studio.")
    ),
    wiring_links("mascot"),
    fn_heading("updateMascot"),
    arg_field(
      "updateMascot",
      "id",
      code_block("updateMascot(\"helper\", ...)", "pg-code-small")
    ),
    wiring_links("updateMascot"),
    div(
      class = "pg-field",
      div(class = "pg-field-head", tags$strong("Several changes in one call")),
      div(class = "pg-hint", "One message to the browser: mood, status, bubble and a gesture together."),
      actionButton("send_many", "Celebrate a finished review", class = "btn-outline-primary btn-sm")
    ),
    arg_field(
      "updateMascot",
      "...",
      tagList(
        selectInput("mistake", "Try a mistake", names(mistakes)),
        uiOutput("mistake_code"),
        actionButton("mistake_run", "Run it", class = "btn-outline-danger btn-sm")
      ),
      note = div(class = "pg-note", "The result appears in the Log tab of the dock.")
    ),
    arg_field(
      "updateMascot",
      "session",
      tagList(
        div(
          class = "pg-hint",
          "A slow step: thinking now, then happy (or worried) two seconds later. The second call names session = session explicitly, as a callback outside a reactive context would."
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
    arg_field("mascot_studio", "view", selectInput("studio_view", "Start in", c("studio", "examples"))),
    arg_field(
      "mascot_studio",
      "fn",
      selectInput(
        "studio_fn",
        "First function",
        c("Default (NULL)" = "", stats::setNames(names(playground_guide), names(playground_guide)))
      )
    ),
    arg_field(
      "mascot_studio",
      "character",
      div(class = "pg-note", "Uses the character selected under mascot_character().")
    ),
    arg_field("mascot_studio", "run", input_switch("studio_run", "Launch interactively (TRUE)", TRUE)),
    arg_field(
      "mascot_studio",
      "...",
      div(
        class = "pg-note",
        "Name every argument after view. The studio shows the call; paste it into your R console to launch a new app."
      )
    )
  )
}

# mascot_preview(): its arguments, read from the package for the selected character. The canvas shows
# the page the call returns while this function is selected; the Code tray shows the call.
panel_preview <- function(moods = mascot_moods()) {
  fn <- "mascot_preview"
  inspector_function(
    fn,
    arg_field(
      fn,
      "character",
      div(class = "pg-note", "Uses the character selected under mascot_character().")
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
      note = div(class = "pg-note", "Phone width changes the page width; the selected pixel size stays the same.")
    ),
    arg_field(fn, "placement", selectInput("preview_placement", "Placement", c("inline", corners))),
    arg_field(
      fn,
      "theme",
      tagList(
        radioButtons(
          "preview_theme_source",
          "Colours",
          c("Character's own colours" = "own", "Your colours" = "custom")
        ),
        conditionalPanel("input.preview_theme_source == 'custom'", uiOutput("preview_pickers"))
      )
    ),
    arg_field(fn, "motion", input_switch("preview_motion", "Animate", FALSE)),
    arg_field(
      fn,
      "popup_menu",
      textAreaInput("preview_menu_items", "One item per line: id = Label", "", rows = 3),
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
