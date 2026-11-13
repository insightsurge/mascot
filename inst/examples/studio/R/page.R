# Page layout builders for the mascot studio (`app.R` composes these into the studio view).

studio_function_flyout <- function() {
  div(
    id = "function_flyout",
    class = "pg-flyout pg-float",
    hidden = NA,
    div(
      class = "pg-surface-head",
      tags$strong("Functions"),
      studio_button("close_functions", "Close", "Close functions")
    ),
    function_index()
  )
}

example_browser <- function(examples = mascot::mascot_examples()) {
  checkmate::assert_data_frame(examples)
  div(
    class = "pg-example-browser",
    arg_field(
      "mascot_example",
      "name",
      selectInput(
        "example_name",
        "Example",
        stats::setNames(examples$name, paste0(examples$title, " (", examples$name, ")"))
      )
    ),
    arg_field(
      "mascot_example",
      "run",
      input_switch("example_run", "run = TRUE: show the command that launches it", FALSE)
    ),
    uiOutput("example_result")
  )
}

studio_canvas <- function() {
  div(
    id = "studio_canvas",
    class = "pg-host pg-float",
    `data-mode` = "mascot",
    # The shared window frame (R/shared-layout.R).
    window_bar(
      "Host container",
      tags$span(class = "pg-muted", "Contained preview"),
      tagAppendAttributes(studio_button("back_to_studio", "Back to studio"), hidden = NA),
      div(id = "examples_phone_tools", class = "pg-topright")
    ),
    div(
      class = "pg-host-options",
      selectInput(
        "host_mode",
        "Host mode",
        c("Live mascot" = "mascot", "Preview page" = "preview")
      ),
      studio_button("phone_width", "Phone width", pressed = FALSE),
      studio_button("show_anchors", "Anchors", pressed = FALSE),
      tags$span(id = "no_anchors", role = "status", hidden = NA),
      tags$button(
        type = "button",
        id = "reset_anchors",
        class = "btn btn-link btn-sm",
        hidden = NA,
        "Reset anchors"
      ),
      tags$span(id = "reduced_motion", role = "status"),
      uiOutput("stage_note", inline = TRUE, class = "pg-stage-note")
    ),
    div(class = "pg-stage", `data-canvas` = "mascot", uiOutput("live_host", class = "pg-live-host")),
    div(
      class = "pg-preview-stage",
      `data-canvas` = "preview",
      hidden = NA,
      div(class = "pg-preview-head", uiOutput("preview_status_badge", inline = TRUE)),
      bslib::card(id = "preview_card", full_screen = TRUE, uiOutput("preview_frame", class = "pg-preview-frame"))
    ),
    div(class = "pg-example-stage", `data-canvas` = "examples", hidden = NA, example_browser()),
    window_footer(tags$code('id = "helper"'), textOutput("host_event", inline = TRUE))
  )
}

studio_dock <- function() {
  div(
    id = "studio_dock",
    class = "pg-call-dock pg-float",
    div(
      class = "pg-surface-head",
      tags$span(class = "pg-eyebrow", "Current configuration"),
      tags$span(class = "pg-call-hint", "Click an argument to edit it"),
      div(
        class = "pg-actions",
        div(
          title = paste(
            "Shortcuts are plain values, for example mood = \"happy\".",
            "Helpers are mascot_*() calls, for example mood = mascot_mood(\"happy\").",
            "Both give the same mascot."
          ),
          radioButtons(
            "code_style",
            "Style",
            c(Shortcuts = "short", Helpers = "helper"),
            selected = "short",
            inline = TRUE
          )
        ),
        copy_button("code_ui", "Copy your settings"),
        studio_button("open_code", "Code views")
      )
    ),
    uiOutput("live_call", class = "pg-live-call")
  )
}

studio_centre <- function(character, fn, view, open_guide) {
  checkmate::assert_string(character)
  checkmate::assert_string(fn)
  checkmate::assert_choice(view, c("studio", "examples"))
  checkmate::assert_flag(open_guide)
  div(
    id = "studio_centre",
    class = "pg-centre",
    `data-initial-function` = fn,
    `data-initial-mode` = if (view == "examples" || fn %in% c("mascot_example", "mascot_examples")) {
      "examples"
    } else if (fn == "mascot_preview") {
      "preview"
    } else {
      "mascot"
    },
    `data-initial-character` = character,
    `data-click-routes` = jsonlite::toJSON(studio_click_routes(), auto_unbox = TRUE),
    `data-initial-open` = if (open_guide) "guide",
    panel_character_bar(character = character),
    studio_canvas(),
    studio_dock()
  )
}

studio_inspector <- function(fn) {
  checkmate::assert_string(fn)
  div(
    id = "inspector_sidebar",
    class = "pg-inspector-shell pg-float",
    hidden = NA,
    `aria-label` = "Function inspector",
    tabindex = "-1",
    div(
      class = "pg-surface-head",
      tags$strong(id = "inspector_title", paste0(fn, "()")),
      studio_button("close_inspector", "Close", "Close inspector")
    ),
    div(
      class = "pg-inspector-tabs",
      role = "tablist",
      `aria-label` = "Inspector views",
      lapply(c("Controls", "Help", "Guide"), function(tab) {
        tags$button(
          type = "button",
          id = paste0("inspector_tab_", tolower(tab)),
          role = "tab",
          `data-inspector-tab` = tolower(tab),
          `aria-controls` = paste0("inspector_", tolower(tab)),
          `aria-selected` = if (tab == "Controls") "true" else "false",
          tab
        )
      })
    ),
    div(
      id = "inspector_controls",
      role = "tabpanel",
      `aria-labelledby` = "inspector_tab_controls",
      div(
        class = "pg-inspector",
        id = "studio_inspector",
        panel_look(),
        panel_messages(),
        panel_motion(),
        panel_layout(),
        panel_colours(),
        panel_wiring(),
        panel_studio(),
        panel_preview(),
        inspector_function("mascot_examples", uiOutput("example_listing")),
        inspector_function(
          "mascot_example",
          arg_field("mascot_example", "name", NULL),
          arg_field("mascot_example", "run", NULL),
          arg_field("mascot_example", "...", NULL)
        )
      )
    ),
    div(
      id = "inspector_help",
      role = "tabpanel",
      `aria-labelledby` = "inspector_tab_help",
      hidden = NA,
      uiOutput("function_help")
    ),
    div(
      id = "inspector_guide",
      role = "tabpanel",
      `aria-labelledby` = "inspector_tab_guide",
      hidden = NA,
      uiOutput("guide")
    ),
    div(
      id = "code_pin",
      class = "pg-code-pin",
      div(class = "pg-eyebrow", "R code for this function"),
      div(class = "pg-code-wrap", code_output("code_function"), copy_button("code_function"))
    )
  )
}

studio_chip_editor <- function() {
  div(
    id = "chip_editor",
    class = "pg-chip-editor pg-float",
    role = "dialog",
    `aria-label` = "Edit argument",
    hidden = NA,
    div(
      class = "pg-surface-head",
      div(
        class = "pg-chip-title-row",
        tags$span(id = "chip_title", class = "pg-chip-title"),
        lapply(c(setdiff(names(formals(mascot)), "..."), "gesture"), function(arg) {
          fn <- if (arg == "gesture") "mascot_gesture" else "mascot"
          field <- if (arg == "gesture") "name" else arg
          tags$span(
            `data-chip-overview` = arg,
            hidden = NA,
            tags$button(
              type = "button",
              class = "pg-info pg-chip-question",
              `aria-label` = paste("About", arg),
              `aria-expanded` = "false",
              "?"
            ),
            div(class = "pg-overview-content", hidden = NA, arg_popover_body(fn, field))
          )
        })
      ),
      studio_button("close_chip", "Close")
    ),
    div(
      id = "chip_style",
      hidden = NA,
      tags$button(type = "button", `data-chip-style` = "short", "Plain value"),
      tags$button(type = "button", `data-chip-style` = "helper", "Helper")
    ),
    div(
      id = "chip_editor_scroll",
      div(id = "chip_editor_body"),
      div(
        class = "pg-chip-context",
        tags$div(id = "chip_hint"),
        "Default: ",
        tags$code(id = "chip_default"),
        tags$div("Current: ", tags$code(id = "chip_current")),
        tags$span(id = "chip_changed", " Changed"),
        tags$button(type = "button", id = "chip_reset", class = "btn btn-link btn-sm", "Reset")
      )
    ),
    div(
      class = "pg-chip-footer",
      tags$button(type = "button", id = "chip_inspector", class = "btn btn-primary btn-sm", "Advanced controls"),
      studio_button("chip_help", "Help"),
      studio_button("chip_guide", "Guide")
    )
  )
}

studio_code_drawer <- function() {
  div(
    id = "code_drawer",
    class = "pg-code-drawer pg-float",
    hidden = NA,
    div(class = "pg-surface-head", tags$strong("Code views"), studio_button("close_code", "Close")),
    div(
      id = "code_tray_body",
      class = "pg-tray-body",
      div(
        id = "studio_panels_card",
        div(
          class = "pg-code-intro",
          textOutput("code_caption", inline = TRUE)
        ),
        navset_underline(
          id = "code_tabs",
          nav_panel(
            "UI",
            div(class = "pg-hint", "Current configuration: mascot() in your UI."),
            div(class = "pg-code-wrap", code_output("code_ui"), copy_button("code_ui"))
          ),
          nav_panel("Server", div(class = "pg-code-wrap", code_output("code_server"), copy_button("code_server"))),
          nav_panel("App", div(class = "pg-code-wrap", code_output("code_app"), copy_button("code_app"))),
          nav_panel(
            "Last",
            div(class = "pg-hint", "Last executed call, including one-off gestures."),
            div(class = "pg-code-wrap", code_output("code_last"), copy_button("code_last"))
          ),
          nav_panel(
            "Preview",
            value = "preview",
            div(class = "pg-code-wrap", code_output("code_preview"), copy_button("code_preview")),
            uiOutput("preview_contrast")
          ),
          nav_panel(
            "Log",
            actionButton("log_clear", "Clear log", class = "btn-outline-primary btn-sm"),
            uiOutput("log")
          )
        )
      )
    )
  )
}

studio_page <- function(character, fn, view = "studio", open_guide = FALSE) {
  checkmate::assert_string(character)
  checkmate::assert_string(fn)
  checkmate::assert_flag(open_guide)
  checkmate::assert_choice(view, c("studio", "examples"))
  div(
    id = "studio_shell",
    class = "pg-studio",
    studio_rail(),
    studio_function_flyout(),
    studio_search(),
    studio_centre(character, fn, view, open_guide),
    studio_right_rail(),
    studio_inspector(fn),
    studio_chip_editor(),
    studio_code_drawer()
  )
}
