# Inspector controls: one mounted input per argument, folded by function when showing all controls.
# Shiny sources this before app.R attaches mascot, so everything here is a function, called
# from app.R once the packages are attached.

# ---- Inspector controls, grouped by function -----------------------------------------------

panel_character_bar <- function(moods = mascot_moods(character), character = formals(mascot::mascot)$character) {
  checkmate::assert_data_frame(moods)
  checkmate::assert_string(character)
  # The shared sentence bar (R/shared-layout.R), with the studio's search and utility buttons after the sentence.
  bar <- sentence_bar(
    "studio_character_bar",
    "Quick controls",
    "Character, palette, mood and one-off gesture",
    list(
      "Showing",
      selectInput("character", NULL, studio_characters(), selected = character, selectize = FALSE),
      tags$span(id = "palette_prefix", "in"),
      selectInput(
        "palette",
        NULL,
        studio_palette_labels(character),
        selected = "original",
        selectize = FALSE
      ),
      tags$span(id = "palette_suffix", ","),
      tags$span(id = "mood_article", "in an"),
      selectInput(
        "mood",
        NULL,
        stats::setNames(moods$name, tools::toTitleCase(moods$name)),
        selected = "idle",
        selectize = FALSE
      ),
      tags$span("mood, with"),
      div(
        id = "quick_gestures",
        class = "pg-quick-gestures",
        selectInput(
          "gesture",
          NULL,
          studio_gesture_choices(character),
          selected = "",
          selectize = FALSE
        ),
        tags$span(class = "pg-sentence-stop", ".", .noWS = "outside"),
        studio_button("gesture_play", "Play it again", "Replay the selected gesture, or wave when none is selected")
      )
    ),
    div(
      class = "pg-search-field",
      tags$svg(
        viewBox = "0 0 20 20",
        width = 16,
        height = 16,
        `aria-hidden` = "true",
        tags$circle(cx = 8, cy = 8, r = 5, fill = "none", stroke = "currentColor", `stroke-width` = 1.5),
        tags$path(d = "M12 12L17 17", stroke = "currentColor", `stroke-width` = 1.5)
      ),
      tags$input(
        id = "open_search",
        type = "search",
        readonly = NA,
        placeholder = "Search functions and arguments",
        `aria-label` = "Search functions and arguments",
        `aria-haspopup` = "dialog"
      ),
      tags$kbd(`aria-hidden` = "true", "Ctrl K")
    ),
    bslib::input_dark_mode(id = "dark_mode", mode = "light"),
    actionButton("reset_all", "Start again", class = "btn-outline-primary btn-sm"),
    studio_topright()
  )
  choices <- studio_palette_choices(character)
  labels <- studio_palette_labels(character)
  bar <- htmltools::tagQuery(bar)$find("#palette")$empty()$append(lapply(seq_along(choices), function(i) {
    tags$option(
      value = choices[[i]],
      title = names(choices)[[i]],
      selected = if (choices[[i]] == "original") NA,
      names(labels)[[i]]
    )
  }))$addAttrs(title = studio_palette_sentence(character)$id)$allTags()
  tooltips <- lapply(stats::setNames(nm = c("character", "palette", "mood", "gesture")), function(id) {
    fn <- if (id == "palette") "mascot_palettes" else paste0("mascot_", id)
    shiny::tagList(
      tags$code(paste0(fn, "()")),
      tags$span(help_page(fn)$title),
      if (id == "palette") tags$code(id = "palette_id", studio_palette_sentence(character)$id)
    )
  })
  bar <- sentence_words(bar, tooltips)
  bar
}

panel_look <- function() {
  inspector_category(
    fn_heading("mascot_read_character"),
    arg_field(
      "mascot_read_character",
      "path",
      div(
        class = "pg-code-wrap",
        code_block(format_expr(code_read_character()), "pg-code", id = "read_character_call"),
        copy_button("read_character_call")
      ),
      note = div(
        class = "pg-note",
        "Copy this offline example into R, then pass the result to mascot() or mascot_preview()."
      )
    ),
    fn_heading("mascot_check_character"),
    arg_field(
      "mascot_check_character",
      "x",
      div(
        class = "pg-code-wrap",
        code_block(format_expr(code_check_character()), "pg-code", id = "check_character_call"),
        copy_button("check_character_call")
      )
    ),
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
      note = uiOutput("family_listing")
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
        # The mounted controls start with the live demonstration. Opening their chip only moves them;
        # it must not ask the server to replace a draft the visitor may already be editing.
        textAreaInput("bubble_text", "Bubble content", welcome_bubble$text, rows = 5, resize = "vertical"),
        # Right under the message box, so the next step after typing is in view.
        div(
          class = "pg-actions",
          actionButton("bubble_show", "Show bubble", class = "btn-primary btn-sm"),
          actionButton("bubble_clear", "Clear bubble", class = "btn-outline-primary btn-sm")
        ),
        input_switch("bubble_html", "Treat as HTML (wraps it in HTML())", welcome_bubble$html)
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
        div(
          id = "bubble_seconds",
          sliderInput("bubble_duration", "Seconds", min = 1, max = 30, value = welcome_bubble$duration)
        ),
        input_switch("bubble_forever", "Until closed (Inf)", is.infinite(welcome_bubble$duration))
      )
    ),
    arg_field(
      "mascot_bubble",
      "closable",
      input_switch("bubble_closable", "Show a close button", welcome_bubble$closable)
    ),
    fn_heading("mascot_action"),
    selectInput("click_type", "Click", c(None = "none", Action = "action", Menu = "menu"), selected = "menu"),
    try_button("select_function", "mascot_popup_menu", "Use a popup menu instead"),
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
      note = div(
        class = "pg-note",
        "Click or tap the mascot to open its menu, then choose an item. Choosing an item sets input$helper_menu; menus never set input$helper_click."
      )
    ),
    arg_field("mascot_popup_menu", "...", NULL),
    arg_field(
      "mascot_popup_menu",
      "disabled",
      input_switch("menu_disabled", "Disabled: menu opens nothing", FALSE),
      note = div(
        class = "pg-note",
        "A disabled menu stays reachable by keyboard and is announced as unavailable, but it opens nothing and sends nothing."
      )
    ),
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
    fn_heading("mascot_motion_settings"),
    input_switch("motion_on", "Animate", TRUE),
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
      tagList(
        div(class = "pg-note", "Choose a gesture in the top bar to play it, then use Play it again to repeat it."),
        tags$button(type = "button", class = "btn btn-sm", `data-focus-input` = "quick_gestures", "Focus gestures")
      )
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
      "A floating mascot stays inside this contained preview; ",
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
        selectInput(
          "drag",
          "When dropped",
          c("No dragging" = "none", Snap = "snap", `Free (experimental)` = "free")
        ),
        studio_experimental_notes("mascot_placement", "free dragging"),
        conditionalPanel(
          "input.position == 'inline'",
          div(class = "pg-note", "An inline mascot ignores drag. Pick a corner position to try it.")
        ),
        tagList(
          div(class = "pg-live", tags$code("input$helper_position"), textOutput("position_last")),
          div(class = "pg-live", tags$code("input$helper_minimised"), textOutput("minimised_last"))
        )
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
      selectInput(
        "theme_source",
        "Palette source",
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
      arg_field(
        "mascot_theme",
        "mode",
        radioButtons(
          "theme_mode",
          "Colour mode",
          c("Follow the page switch (auto)" = "auto", "Always light" = "light", "Always dark" = "dark")
        )
      ),
      conditionalPanel(
        "input.theme_source == 'own'",
        div(class = "pg-note", "Uses the palette from the top bar; original keeps the character's own colours.")
      ),
      conditionalPanel(
        "input.theme_source == 'mascot'",
        # The pickers are the colour_roles_server("colours") module's (app.R).
        local({
          colours <- colour_roles_ui("colours")
          bslib::navset_tab(
            bslib::nav_panel("Light", arg_field("mascot_theme", "light", colours$light)),
            bslib::nav_panel("Dark", arg_field("mascot_theme", "dark", colours$dark)),
            bslib::nav_panel(
              "CSS variables",
              arg_field(
                "mascot_theme",
                "css",
                tagList(studio_experimental_notes("mascot_theme", "CSS source"), colours$css)
              )
            )
          )
        })
      ),
      conditionalPanel(
        "input.theme_source == 'bslib'",
        div(class = "pg-note", "mascot(theme = ) also accepts a bslib theme; it colours the character's brand parts."),
        studio_bslib_experimental(),
        div(
          class = "pg-note",
          "The colour mode below does not apply here: a bs_theme() always follows the page switch."
        ),
        uiOutput("theme_brand")
      ),
      conditionalPanel(
        "input.theme_source != 'own'",
        # inputs.js shows "Checking..." on the button until the result is drawn. Its click sends a number of its own as
        # input$contrast_check, which the result carries back (busy_done_mark()), hence data-event, not actionButton().
        tags$button(
          id = "contrast_check",
          type = "button",
          class = "btn btn-outline-primary btn-sm",
          `data-event` = "contrast_check",
          `data-busy-label` = "Checking\u2026",
          `data-busy-output` = "contrast",
          "Check contrast"
        ),
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
    ),
    tags$details(
      open = NA,
      tags$summary("Activity log: calls, warnings, errors and visitor events"),
      uiOutput("wiring_log")
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
          min = 24,
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
      note = div(
        class = "pg-note",
        "Comparison columns are 160, 96 and 24 px. Phone width narrows the page; the mascot pixel size stays unchanged."
      )
    ),
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
    actionButton("preview_build", "Rebuild now", class = "btn-outline-primary btn-sm")
  )
}
