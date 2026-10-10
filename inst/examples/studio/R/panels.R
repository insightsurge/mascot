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
  groups
}

# ---- Inspector controls, grouped by function -----------------------------------------------

role_picker <- function(mode, role, roles) {
  row <- roles[roles$role == role, ]
  follows <- if (is.na(row$follows)) "leader" else paste0("follows ", row$follows, " (", row$shade, ")")
  div(
    class = "pg-role",
    colour_input(paste0(mode, "_", role), row$colour, paste(role, "in", mode, "mode")),
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

role_pickers <- function(mode, roles) {
  role_groups <- colour_groups(roles)
  tagList(
    div(
      class = "pg-hint",
      "Each picker starts at Tessa's own colour. Change one to add it to the theme; \u00d7 takes it out again.
      The round swatch shows the colour in use now."
    ),
    do.call(
      bslib::accordion,
      c(
        lapply(names(Filter(length, role_groups)), function(group) {
          bslib::accordion_panel(
            group,
            lapply(role_groups[[group]], function(role) role_picker(mode, role, roles)),
            value = group
          )
        }),
        list(open = "Body")
      )
    ),
    try_button("reset_mode", mode, paste("Reset", mode, "colours"), "btn-outline-primary")
  )
}

panel_look <- function(moods = mascot_moods()) {
  inspector_category(
    playground_categories$look$title,
    value = "look",
    fn_heading("mascot_character"),
    arg_field("mascot_character", "name", selectInput("character", "Character", c(Tessa = "tessa"))),
    fn_heading("mascot_mood"),
    arg_field(
      "mascot_mood",
      "name",
      mood_cards(moods)
    ),
    fn_heading("mascot_moods"),
    div(class = "pg-hint", "No arguments. Its table is in the Learn card; choose mascot_mood() to try a mood.")
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
        sliderInput("bubble_duration", "Seconds", min = 1, max = 30, value = 5),
        input_switch("bubble_forever", "Until closed (Inf)", FALSE)
      )
    ),
    arg_field("mascot_bubble", "closable", input_switch("bubble_closable", "Show a close button", TRUE)),
    div(
      class = "pg-actions",
      actionButton("bubble_show", "Show bubble", class = "btn-primary btn-sm"),
      actionButton("bubble_clear", "Clear bubble", class = "btn-outline-primary btn-sm")
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
    div(class = "pg-hint", "No arguments. Its table is shown as the gesture cards in the Learn card.")
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

panel_colours <- function(roles = mascot_colour_roles()) {
  tagList(
    inspector_function(
      "mascot_theme",
      radioButtons(
        "theme_source",
        "Where the colours come from",
        c(
          "Tessa's own colours: mascot_theme()" = "own",
          "Your colours: mascot_theme(light, dark, ...)" = "mascot",
          "Your app's brand: bslib::bs_theme()" = "bslib"
        )
      ),
      arg_field(
        "mascot_theme",
        "mode",
        radioButtons(
          "theme_mode",
          NULL,
          c("Follow the page switch (auto)" = "auto", "Always light" = "light", "Always dark" = "dark")
        ),
        note = div(class = "pg-note", "The page switch is the moon or sun button at the top right.")
      ),
      arg_field("mascot_theme", "light", role_pickers("light", roles)),
      arg_field("mascot_theme", "dark", role_pickers("dark", roles)),
      arg_field(
        "mascot_theme",
        "css",
        tagList(
          div(
            class = "pg-css",
            colour_input("css_accent", "#7b4fd6", "Value of --studio-accent", `data-css-var` = "--studio-accent"),
            div(tags$code("--studio-accent"), div(class = "pg-muted", "a CSS variable this page defines"))
          ),
          checkboxGroupInput("css_roles", "Parts that read the variable", roles$role, inline = TRUE)
        )
      ),
      div(class = "pg-note", "Light, dark and CSS settings apply when you choose Your colours above."),
      conditionalPanel(
        "input.theme_source == 'bslib'",
        div(class = "pg-fn-what", "A bslib theme passed as theme: primary colours body, secondary colours rim."),
        div(class = "pg-css", colour_input("bs_primary", "#1f6feb", "Primary colour"), tags$code("primary")),
        div(class = "pg-css", colour_input("bs_secondary", "#966600", "Secondary colour"), tags$code("secondary"))
      ),
      actionButton("contrast_check", "Check contrast", class = "btn-outline-primary btn-sm"),
      uiOutput("contrast")
    ),
    inspector_function(
      "mascot_colour_roles",
      arg_field(
        "mascot_colour_roles",
        "character",
        selectInput("roles_character", "Character", c(Tessa = "tessa")),
        note = div(class = "pg-note", "Its table is in the Learn card, with every part's colour and what it follows.")
      )
    )
  )
}

panel_menu <- function() {
  inspector_category(
    playground_categories$menu$title,
    value = "menu",
    fn_heading("mascot_popup_menu"),
    arg_field(
      "mascot_popup_menu",
      "items",
      tagList(
        input_switch("menu_on", "Show the menu", TRUE),
        textAreaInput("menu_items", "One item per line: id = Label", menu_lines, rows = 4, resize = "vertical"),
        uiOutput("menu_problem")
      ),
      note = div(class = "pg-note", "Open the menu with the button on Tessa, then pick an item.")
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

panel_wiring <- function() {
  inspector_category(
    playground_categories$wiring$title,
    value = "wiring",
    fn_heading("mascot"),
    arg_field(
      "mascot",
      "id",
      code_block("mascot(id = \"helper\")", "pg-code-small"),
      note = div(class = "pg-note", "Tessa always uses id = \"helper\" in this studio.")
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
          "A slow step: thinking now, then happy (or worried) two seconds later. The second call runs
          outside the reactive context, so it passes session = session."
        ),
        input_switch("task_fail", "Make the task fail", FALSE),
        actionButton("task_run", "Run a 2-second task", class = "btn-outline-primary btn-sm")
      )
    )
  )
}
