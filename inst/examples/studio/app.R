# The mascot studio: every exported function and argument, live, with explanations.
# Run it with mascot::mascot_example("studio"). Shiny first loads the files in R/ (the
# explanations, data, code builders, Controls and guide pieces) and serves www/ (styles
# and the colour picker).
library(shiny)
if (!requireNamespace("bslib", quietly = TRUE)) {
  stop("This example needs bslib. Install it before running the app.")
}
library(bslib)
library(mascot)

# Shiny loads R/ before this file; this covers sessions that turned that off with
# options(shiny.autoload.r = FALSE). Shiny runs this file from the app's folder.
if (!exists("playground_guide")) {
  for (file in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
    source(file, local = TRUE)
  }
}

examples <- mascot_examples()

start <- lapply(defaults, code_pair)
# The canvas opts into inline placement; a plain mascot() now floats in the bottom-right corner.
start$placement <- code_placement(position = "inline")
start$bubble <- code_bubble(welcome, FALSE, 8, TRUE)
start$click <- code_menu(default_menu)

# The mascot() call for a state: only the arguments that differ from the defaults.
ui_args <- function(state, style) {
  changed <- Filter(function(field) !identical(state[[field]]$short, defaults[[field]]), names(defaults))
  c(list("helper"), pick_style(state[changed], style))
}

# The update_mascot() call that brings a plain mascot to a state.
server_args <- function(state, style) {
  c(list("helper"), ui_args(state, style)[-1])
}

# ---- Pages -------------------------------------------------------------------------------

studio_page <- function(character, fn, view = "studio", open_guide = FALSE) {
  checkmate::assert_string(character)
  checkmate::assert_string(fn)
  checkmate::assert_flag(open_guide)
  checkmate::assert_choice(view, c("studio", "examples"))
  div(
    id = "studio_shell",
    class = "pg-studio",
    studio_rail(),
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
    ),
    studio_search(),
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
      `data-initial-open` = if (open_guide) "guide",
      panel_character_bar(character = character),
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
          if (!is.null(studio_character_hint())) tags$span(class = "pg-hint", studio_character_hint()),
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
      ),
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
    ),
    studio_right_rail(),
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
          panel_your_character(),
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
        class = "pg-code-pin",
        div(class = "pg-eyebrow", "R code for this function"),
        div(class = "pg-code-wrap", code_output("code_function"), copy_button("code_function"))
      )
    ),
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
    ),
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
  )
}

example_browser <- function() {
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
examples_page <- example_browser()

view_from_request <- function(request) {
  checkmate::assert(checkmate::check_list(request), checkmate::check_environment(request), .var.name = "request")
  query <- shiny::parseQueryString(if (is.null(request$QUERY_STRING)) "" else request$QUERY_STRING)
  if (is.null(query$view) || !query$view %in% names(views)) "studio" else query$view
}

view_link <- function(label, view, new_tab = TRUE) {
  checkmate::assert_string(label)
  checkmate::assert_string(view)
  checkmate::assert_flag(new_tab)
  bslib::nav_item(tags$a(
    class = "nav-link",
    href = paste0("?view=", view),
    target = if (new_tab) "_blank",
    rel = "noopener",
    label,
    if (new_tab) shiny::icon("arrow-up-right-from-square", class = "small ms-1")
  ))
}

# The page of the studio and examples views; the query string chooses what it opens on.
studio_view_ui <- function(query, view) {
  checkmate::assert_list(query)
  checkmate::assert_choice(view, c("studio", "examples"))
  # The guide pages are R Markdown files (guide/<function>.Rmd), knitted when a guide is opened. Only this page
  # has them, so the other views start without knitr.
  if (!requireNamespace("knitr", quietly = TRUE)) {
    stop("The studio needs knitr for its guide pages. Install it before running the app.")
  }
  fn <- if (!is.null(query$fn) && query$fn %in% names(playground_guide)) query$fn else "mascot_mood"
  tagList(
    tags$head(
      tags$link(rel = "stylesheet", href = "tokens.css"),
      tags$link(rel = "stylesheet", href = "shared.css"),
      tags$link(rel = "stylesheet", href = "studio.css"),
      tags$script(src = "inputs.js"),
      tags$script(src = "studio.js")
    ),
    studio_page(view_character(query), fn, view, identical(query$open, "guide"))
  )
}

ui <- function(request) {
  view <- view_from_request(request)
  query <- shiny::parseQueryString(request$QUERY_STRING %||% "")
  bslib::page_fillable(
    title = views[[view]]$title,
    theme = bs_theme(version = 5),
    padding = 0,
    # The server reads the view from here when the address bar does not name it (see view_from_client()).
    div(class = "pg-routing", hidden = NA, selectInput("tabs", NULL, names(views), selected = view)),
    views[[view]]$ui(query)
  )
}

# ---- Server ------------------------------------------------------------------------------

studio_server <- function(input, output, session) {
  # Welcome content belongs to the live studio; copied code starts with empty user messages and no click.
  settings <- start
  settings$bubble <- code_pair(defaults$bubble)
  settings$click <- code_pair(defaults$click)
  state <- do.call(reactiveValues, settings)
  live_demo <- reactiveValues(click = start$click, bubble = start$bubble)
  last_gesture <- reactiveVal(NULL)
  last_call <- reactiveVal("No update yet. Change a setting in Controls.")
  log <- reactiveVal(list())
  selected_function <- reactiveVal("mascot_mood")
  # R4a authoring stays session-local; this panel never registers visitor data.
  uploaded_character <- reactiveVal(NULL)
  uploaded_filename <- reactiveVal("study_bot.json")
  mascot_read_character <- function(path) {
    checkmate::assert_string(path)
    if (identical(path, uploaded_filename()) && !is.null(uploaded_character())) {
      return(uploaded_character())
    }
    mascot:::mascot_read_character(path)
  }
  if (isTRUE(getOption("mascot.internal.character_panel", FALSE))) {
    your_character <- uploaded_character
    your_filename <- uploaded_filename
    your_revision <- reactiveVal(0L)
    your_live_id <- reactive(paste0("your_character_live_mascot_", your_revision()))
    your_problem <- reactiveVal("Choose a JSON file or load the example.")
    load_your_character <- function(path, name) {
      checkmate::assert_string(path)
      checkmate::assert_string(name)
      result <- tryCatch(mascot:::mascot_read_character(path), error = identity)
      if (inherits(result, "error")) {
        your_character(NULL)
        your_problem(cli::ansi_strip(conditionMessage(result)))
        return(invisible(NULL))
      }
      your_revision(isolate(your_revision()) + 1L)
      your_character(result)
      your_filename(basename(name))
      your_problem(paste("Checked:", result$name))
      updateSelectInput(session, "your_character_mood", choices = c("Every mood" = "", names(result$moods)))
      updateSelectInput(session, "your_character_gesture", choices = names(result$gestures))
      updateSelectInput(
        session,
        "preview_mood",
        choices = c("Every mood (NULL)" = "", names(result$moods)),
        selected = ""
      )
      last_preview_attempt(NULL)
      if (isolate(preview_selected())) build_preview()
    }
    observeEvent(input$your_character_file, {
      load_your_character(input$your_character_file$datapath, input$your_character_file$name)
    })
    observeEvent(input$your_character_example, {
      load_your_character(system.file("examples", "characters", "study_bot.json", package = "mascot"), "study_bot.json")
    })
    output$your_character_check <- renderText(your_problem())
    output$your_character_code <- renderText({
      req(your_character())
      file_name <- encodeString(your_filename(), quote = '"')
      paste0(
        "bot <- mascot_read_character(",
        file_name,
        ")\n",
        "bot <- mascot_check_character(bot)\nmascot_preview(bot)\n",
        "# Alternative check inputs: a parsed list or JSON text\n",
        "mascot_check_character(jsonlite::read_json(",
        file_name,
        "))\n",
        "mascot_check_character(paste(readLines(",
        file_name,
        "), collapse = \"\\n\"))\n",
        "# At app start-up only: mascot_register_character(bot)\n",
        "# Save to your chosen path: mascot_save_character(bot, \"resolved.json\")"
      )
    })
    output$your_character_live <- renderUI({
      req(your_character())
      mascot(
        your_live_id(),
        character = your_character(),
        motion = TRUE,
        mood = if (is.null(input$your_character_mood) || !nzchar(input$your_character_mood)) {
          "idle"
        } else {
          input$your_character_mood
        },
        size = input$your_character_size %||% 160
      )
    })
    observeEvent(input$your_character_play, {
      req(your_character(), input$your_character_gesture)
      update_mascot(your_live_id(), gesture = input$your_character_gesture)
    })
    output$your_character_grid <- renderUI({
      req(your_character())
      page <- mascot_preview(
        your_character(),
        mood = if (is.null(input$your_character_mood) || !nzchar(input$your_character_mood)) {
          NULL
        } else {
          input$your_character_mood
        },
        size = input$your_character_size %||% 160
      )
      # Reuse the preview grid; select a mode without changing the file's colours.
      mode <- input$your_character_mode %||% "both"
      if (mode != "both") {
        page <- htmltools::tagAppendChild(
          page,
          tags$style(paste0(
            "#",
            page[[1]]$attribs$id,
            " .mascot-preview-mode[data-bs-theme=",
            if (mode == "light") "dark" else "light",
            "]{display:none}"
          ))
        )
      }
      page
    })
    output$your_character_save <- downloadHandler(
      filename = function() paste0(tools::file_path_sans_ext(your_filename()), "-resolved.json"),
      content = function(file) {
        checkmate::assert_string(file)
        req(your_character())
        mascot:::mascot_save_character(your_character(), file, overwrite = TRUE)
      }
    )
  }
  current_character <- reactive(input$character %||% defaults$character)
  observeEvent(current_character(), {
    listing <- mascot_anchors(current_character())
    session$sendCustomMessage(
      "studio:anchors",
      list(
        character = current_character(),
        name = mascot_character(current_character())$name,
        anchors = lapply(seq_len(nrow(listing)), function(i) as.list(listing[i, , drop = FALSE]))
      )
    )
  })
  character_name <- reactive(mascot_character(current_character())$name)
  roles <- reactive(mascot_colour_roles(current_character(), palette = selected_palette()))
  output$code_caption <- renderText(paste("Code for", character_name(), "with the current settings."))
  observeEvent(input$initial_function, selected_function(input$initial_function), once = TRUE)
  observeEvent(
    input$initial_character,
    {
      updateSelectInput(session, "character", selected = input$initial_character)
      state$character <- code_character(input$initial_character)
    },
    once = TRUE
  )
  menu_last <- reactiveVal("nothing yet")
  menu_error <- reactiveVal(NULL)

  argument_styles <- reactiveVal(list())
  style <- reactive(unlist(c(list(.default = input$code_style %||% "short"), argument_styles())))
  observeEvent(input$chip_style, {
    value <- input$chip_style
    req(value$arg %in% names(defaults), value$style %in% c("short", "helper"))
    overrides <- argument_styles()
    overrides[[value$arg]] <- value$style
    argument_styles(overrides)
  })

  add_log <- function(code, outcome, message = NULL) {
    entry <- list(code = code, outcome = outcome, message = message)
    log(utils::head(c(list(entry), log()), 30))
  }

  # Runs a call with run_real_call(), then logs it and shows any error, warning or message. Returns TRUE when the
  # mascot changed: a wrong value warns and leaves the mascot unchanged; a low-contrast colour warns and is kept.
  run_logged <- function(call, code) {
    result <- run_real_call(call, environment())
    if (result$class == "ok") {
      add_log(code, "ok")
    } else {
      add_log(code, result$class, result$message)
      showNotification(
        result$message,
        type = switch(result$class, error = "error", warning = "warning", "default"),
        duration = 8
      )
    }
    result$ok
  }

  sync_bubble_controls <- function(pair) {
    checkmate::assert_list(pair)
    bubble <- eval(pair$helper)
    # Show reads the draft (see bubble_draft below), so it follows the controls at once too.
    bubble_draft$text <- as.character(bubble$text %||% "")
    bubble_draft$html <- isTRUE(bubble$html)
    updateTextAreaInput(session, "bubble_text", value = as.character(bubble$text %||% ""))
    update_switch("bubble_html", value = isTRUE(bubble$html), session = session)
    update_switch("bubble_forever", value = is.infinite(bubble$duration), session = session)
    updateSliderInput(session, "bubble_duration", value = if (is.finite(bubble$duration)) bubble$duration else 5)
    update_switch("bubble_closable", value = bubble$closable, session = session)
  }

  # Sends the changed settings in one update_mascot() call; TRUE when it ran, FALSE on an error,
  # NA when nothing changed. force sends unchanged ones too (a bubble shown twice, a gesture);
  # with_session names the session, for calls that run outside the reactive context.
  send <- function(pairs, force = FALSE, with_session = FALSE, remember = TRUE) {
    if (!force) {
      pairs <- Filter(
        Negate(is.null),
        lapply(stats::setNames(names(pairs), names(pairs)), function(field) {
          if (identical(isolate(state[[field]]), pairs[[field]])) NULL else pairs[[field]]
        })
      )
    }
    if (!length(pairs)) {
      return(invisible(NA))
    }
    args <- c(list("helper"), pick_style(pairs, isolate(style())), if (with_session) list(session = quote(session)))
    code <- format_call("update_mascot", args)
    last_call(code)
    ok <- run_logged(as.call(c(as.name("update_mascot"), args)), code)
    if (ok && !is.null(pairs$gesture)) {
      last_gesture(eval(pairs$gesture$short))
    }
    if (ok && remember) {
      for (field in intersect(names(pairs), names(defaults))) {
        state[[field]] <- pairs[[field]]
        if (field %in% c("click", "bubble")) {
          live_demo[[field]] <- pairs[[field]]
        }
        if (field == "mood") {
          updateSelectInput(session, "mood", selected = eval(pairs[[field]]$short))
        }
        if (field == "bubble") {
          sync_bubble_controls(pairs[[field]])
        }
        if (field == "status") {
          value <- eval(pairs[[field]]$helper)$text
          updateTextInput(session, "status_text", value = value %||% "")
        }
      }
    }
    invisible(ok)
  }

  observeEvent(input$chip_argument, {
    if (identical(input$chip_argument, "bubble")) sync_bubble_controls(live_demo$bubble)
  })

  # Clicks on buttons that carry data-event and data-value arrive as input$<event>.
  observeEvent(input$select_function, {
    req(input$select_function %in% names(playground_guide))
    selected_function(input$select_function)
  })
  observeEvent(input$open_guide, {
    selected_function(input$open_guide)
    showModal(tagAppendAttributes(
      modalDialog(
        title = paste0("Guide: ", input$open_guide, "()"),
        uiOutput("guide"),
        size = "l",
        easyClose = TRUE,
        footer = actionButton("close_guide", "Close", class = "btn-primary")
      ),
      class = "pg-guide-modal"
    ))
  })
  observeEvent(input$close_guide, removeModal())
  observeEvent(input$reset_all, session$reload())
  observeEvent(input$chip_reset, {
    arg <- input$chip_reset
    req(arg %in% names(defaults))
    switch(
      arg,
      character = updateSelectInput(session, "character", selected = defaults$character),
      mood = updateSelectInput(session, "mood", selected = defaults$mood),
      status = updateTextInput(session, "status_text", value = ""),
      bubble = sync_bubble_controls(code_pair(defaults$bubble)),
      size = {
        updateRadioButtons(session, "size_unit", selected = "px")
        updateSliderInput(session, "size_px", value = defaults$size)
        updateRadioButtons(session, "small_mode", selected = "auto")
      },
      placement = {
        updateRadioButtons(session, "position", selected = defaults$placement)
        update_switch("minimise", value = TRUE, session = session)
        updateSelectInput(session, "drag", selected = "none")
      },
      theme = {
        updateSelectInput(session, "palette", selected = "original")
        updateSelectInput(session, "theme_source", selected = "own")
        updateRadioButtons(session, "theme_mode", selected = "auto")
        colours$reset()
      },
      motion = {
        update_switch("motion_on", value = TRUE, session = session)
        for (id in c("idle", "mood_change", "gestures", "swap", "minimising", "restoring", "messages")) {
          updateSelectInput(session, id, selected = "follow")
        }
        update_switch("others", value = TRUE, session = session)
      },
      click = {
        click_kind("none")
        update_switch("action_on", value = FALSE, session = session)
        update_switch("menu_on", value = FALSE, session = session)
      }
    )
    send(stats::setNames(list(code_pair(defaults[[arg]])), arg), force = TRUE)
  })

  # Keep each top-bar choice when the incoming character supports it.
  selected_palette <- reactive({
    value <- input$palette %||% "original"
    if (value %in% studio_palette_choices(current_character())) value else "original"
  })
  observe({
    character <- current_character()
    sentence <- studio_palette_sentence(character, selected_palette())
    session$sendCustomMessage("studio:palette", c(sentence, list(ids = names(studio_palette_choices(character)))))
  })
  observeEvent(
    input$character,
    {
      character <- current_character()
      moods <- mascot_moods(character)$name
      gestures <- mascot_gestures(character)$name
      mood <- if (isTRUE(input$mood %in% moods)) input$mood else "idle"
      gesture <- if (isTRUE(input$gesture %in% gestures)) input$gesture else ""
      updateSelectInput(
        session,
        "palette",
        choices = studio_palette_labels(character),
        selected = selected_palette()
      )
      updateSelectInput(session, "mood", choices = stats::setNames(moods, tools::toTitleCase(moods)), selected = mood)
      updateSelectInput(
        session,
        "gesture",
        choices = studio_gesture_choices(character),
        selected = gesture
      )
      # The colour module carries only the roles the user changed that the new character has too, so the new
      # character is not sent the old character's colours.
      send(
        list(
          character = code_character(character),
          theme = theme_with(colours$light(), colours$dark()),
          mood = code_mood(mood)
        ),
        force = TRUE
      )
    },
    ignoreInit = TRUE
  )
  observeEvent(input$mood, send(list(mood = code_mood(input$mood))), ignoreInit = TRUE)

  # Messages
  status_text <- debounce(reactive(input$status_text), 600)
  observeEvent(status_text(), send(list(status = code_status(status_text()))), ignoreInit = TRUE)
  observeEvent(input$status_clear, {
    updateTextInput(session, "status_text", value = "")
    send(list(status = code_status("")))
  })
  # The bubble content Show sends. An example fills it at once: the browser reports the example's text only after
  # it has filled the inputs, so a quick Show must not read the inputs and send the previous text (#249).
  bubble_draft <- reactiveValues(text = NULL, html = NULL)
  observeEvent(input$bubble_text, bubble_draft$text <- input$bubble_text)
  observeEvent(input$bubble_html, bubble_draft$html <- input$bubble_html)
  observeEvent(
    input$bubble_example,
    {
      example <- bubble_examples[[input$bubble_example]]
      bubble_draft$text <- example$text
      bubble_draft$html <- example$html
      updateTextAreaInput(session, "bubble_text", value = example$text)
      update_switch("bubble_html", value = example$html)
    },
    ignoreInit = TRUE,
    # Before Show when both arrive together.
    priority = 1
  )
  observeEvent(
    input$chip_bubble,
    {
      send(
        list(
          bubble = code_bubble(
            input$chip_bubble,
            isTRUE(input$bubble_html),
            if (isTRUE(input$bubble_forever)) Inf else input$bubble_duration %||% 5,
            isTRUE(input$bubble_closable)
          )
        ),
        force = TRUE
      )
    },
    ignoreInit = TRUE
  )
  observeEvent(input$bubble_show, {
    duration <- if (input$bubble_forever) Inf else as.numeric(input$bubble_duration)
    text <- bubble_draft$text %||% input$bubble_text
    html <- bubble_draft$html %||% input$bubble_html
    send(list(bubble = code_bubble(text, html, duration, input$bubble_closable)), force = TRUE)
  })
  observeEvent(input$bubble_clear, send(list(bubble = code_bubble("", FALSE, 5, TRUE)), force = TRUE))

  # Motion and gestures
  motion_code <- reactive({
    if (identical(input$motion_on, FALSE)) {
      return(code_pair(FALSE, helper_call("mascot_motion_settings", others = FALSE)))
    }
    code_motion(
      input$idle,
      input$mood_change,
      input$gestures,
      input$swap,
      input$minimising,
      input$restoring,
      input$messages,
      input$others
    )
  })
  observeEvent(
    motion_code(),
    send(list(motion = motion_code())),
    ignoreInit = TRUE
  )
  observeEvent(input$gesture, {
    if (nzchar(input$gesture)) send(list(gesture = code_gesture(input$gesture)), force = TRUE)
  })
  observeEvent(input$gesture_replay, {
    req(input$gesture_replay %in% mascot_gestures(current_character())$name)
    send(list(gesture = code_gesture(input$gesture_replay)), force = TRUE)
  })
  observeEvent(input$gesture_play, {
    gesture <- if (isTRUE(nzchar(input$gesture))) input$gesture else "wave"
    req(gesture %in% mascot_gestures(current_character())$name)
    send(list(gesture = code_gesture(gesture)), force = TRUE)
  })

  # Size and placement
  size_code <- reactive({
    # Sliders send whole numbers as integers; the code shows plain numbers.
    size <- if (input$size_unit == "pct") paste0(input$size_pct, "%") else as.numeric(input$size_px)
    mode <- input$small_mode %||% "auto"
    small_screen <- switch(
      mode,
      auto = "auto",
      same = NULL,
      number = as.numeric(input$small_px),
      "auto"
    )
    code_size(size, small_screen)
  })
  observeEvent(size_code(), send(list(size = size_code())), ignoreInit = TRUE)
  observeEvent(
    list(input$position, input$minimise, input$drag),
    {
      drag <- if (!is.null(input$drag) && input$drag != "none") input$drag else "none"
      send(list(placement = code_placement(input$position, minimise = isTRUE(input$minimise), drag = drag)))
    },
    ignoreInit = TRUE
  )
  position_last <- reactiveVal("Nothing yet: drag a floating mascot to receive an event.")
  observeEvent(input$helper_position, {
    if (is.character(input$helper_position) && input$helper_position %in% corners) {
      state$placement <- code_placement(input$helper_position, minimise = isTRUE(input$minimise), drag = "snap")
      updateRadioButtons(session, "position", selected = input$helper_position)
    }
    value <- format_expr(input$helper_position)
    position_last(value)
    add_log(paste0("input$helper_position  # ", value), "event", "The visitor dropped the mascot.")
  })
  output$position_last <- renderText(position_last())
  minimised_last <- reactiveVal("Not minimised.")
  observeEvent(input$helper_minimised, {
    minimised_last(if (isTRUE(input$helper_minimised)) "TRUE: minimised" else "FALSE: restored")
    add_log(
      paste0("input$helper_minimised  # ", input$helper_minimised),
      "event",
      if (isTRUE(input$helper_minimised)) "The visitor minimised the mascot." else "The visitor restored the mascot."
    )
  })
  output$minimised_last <- renderText(minimised_last())
  output$size_ruler <- renderUI({
    if (input$size_unit == "pct") {
      size_ruler(NULL, NULL)
    } else {
      size_ruler(input$size_px, paste(input$size_px, "px"))
    }
  })
  output$placement_map <- renderUI(placement_map(input$position, isTRUE(input$minimise), character_name()))
  output$stage_note <- renderUI({
    if (input$position == "inline") {
      return(NULL)
    }
    div(
      class = "pg-note",
      character_name(),
      " is floating in the ",
      sub("-", " ", input$position, fixed = TRUE),
      " corner of the preview. Choose Inline to bring the mascot back here."
    )
  })

  # Colour pickers for every role, light and dark, and the parts that read --studio-accent: the shared module
  # (R/shared-colours.R). They are drawn again when the character or palette changes; source switches keep them.
  colours <- colour_roles_server(
    "colours",
    current_character,
    selected_palette,
    css = c(`--studio-accent` = "#7b4fd6"),
    resolved = TRUE
  )
  output$theme_brand <- renderUI({
    brand <- studio_brand(current_character())
    tagList(lapply(c("primary", "secondary"), function(slot) {
      label <- paste0(
        tools::toTitleCase(slot),
        " colours: ",
        brand[[slot]] %||% "no mapped part",
        " (",
        character_name(),
        ")"
      )
      div(
        class = "pg-css",
        colour_input(
          paste0("bs_", slot),
          isolate(input[[paste0("bs_", slot)]]) %||% if (slot == "primary") "#1f6feb" else "#966600",
          label
        ),
        tags$span(label)
      )
    }))
  })
  outputOptions(output, "theme_brand", suspendWhenHidden = FALSE)

  # Colours and theme
  theme_with <- function(light, dark) {
    code_theme(
      input$theme_source %||% "own",
      light,
      dark,
      input$theme_mode %||% "auto",
      colours$css(),
      input$bs_primary %||% "#1f6feb",
      input$bs_secondary %||% "#966600",
      selected_palette()
    )
  }
  theme_now <- reactive(theme_with(colours$light(), colours$dark()))
  observeEvent(
    input$theme_source,
    {
      if (identical(input$theme_source, "bslib")) updateSelectInput(session, "palette", selected = "original")
    },
    ignoreInit = TRUE
  )
  observeEvent(
    input$palette,
    {
      if (input$palette != "original" && identical(input$theme_source, "bslib")) {
        updateSelectInput(session, "theme_source", selected = "own")
      }
    },
    ignoreInit = TRUE
  )
  theme_code <- debounce(theme_now, 300)
  observeEvent(theme_code(), send(list(theme = theme_code())), ignoreInit = TRUE)
  # The browser reads the variable again only when the theme is sent, so resend it.
  observeEvent(
    colours$css_values(),
    if (length(colours$css())) send(list(theme = theme_code()), force = TRUE),
    ignoreInit = TRUE
  )
  contrast_settings <- reactive(list(
    character = current_character(),
    theme = theme_now(),
    accepted_theme = state$theme,
    css = colours$css_values()
  ))
  checked_contrast <- eventReactive(input$contrast_check, contrast_settings())
  output$contrast <- renderUI({
    req(input$contrast_check)
    checked <- checked_contrast()
    if (!identical(checked, contrast_settings())) {
      return(contrast_stale_ui())
    }
    # The check and its result are shared with the theme view (R/shared-check.R).
    contrast_result_ui(
      contrast_check(checked$character, eval(checked$theme$short)),
      if (input$theme_source == "mascot") names(colours$css()) else character(),
      chosen = input$theme_source == "bslib" ||
        (input$theme_source == "mascot" && length(c(colours$light(), colours$dark())) > 0L)
    )
  })

  # Click: one action or a menu. The two switches take turns, because a mascot has one click.
  click_kind <- reactiveVal("menu")
  observeEvent(
    input$click_type,
    {
      req(input$click_type %in% c("none", "action", "menu"))
      click_kind(input$click_type)
      update_switch("action_on", value = input$click_type == "action", session = session)
      update_switch("menu_on", value = input$click_type == "menu", session = session)
    },
    ignoreInit = TRUE
  )
  observeEvent(click_kind(), updateSelectInput(session, "click_type", selected = click_kind()))
  observeEvent(
    input$action_on,
    {
      if (isTRUE(input$action_on)) {
        click_kind("action")
        if (isTRUE(input$menu_on)) update_switch("menu_on", value = FALSE, session = session)
      } else if (click_kind() == "action") {
        click_kind(if (isTRUE(input$menu_on)) "menu" else "none")
      }
    },
    ignoreInit = TRUE
  )
  observeEvent(
    input$menu_on,
    {
      if (isTRUE(input$menu_on)) {
        click_kind("menu")
        if (isTRUE(input$action_on)) update_switch("action_on", value = FALSE, session = session)
      } else if (click_kind() == "menu") {
        click_kind(if (isTRUE(input$action_on)) "action" else "none")
      }
    },
    ignoreInit = TRUE
  )
  menu_parsed <- reactive({
    lines <- trimws(strsplit(input$menu_items %||% "", "\n", fixed = TRUE)[[1]])
    lines <- lines[nzchar(lines)]
    bad <- !grepl("=", lines, fixed = TRUE)
    if (any(bad)) {
      return(list(problem = paste0("Write each item as id = Label: \"", lines[bad][1], "\"")))
    }
    ids <- trimws(sub("=.*$", "", lines))
    labels <- trimws(sub("^[^=]*=", "", lines))
    list(items = stats::setNames(labels, ids))
  })
  output$menu_problem <- renderUI({
    problem <- menu_parsed()$problem
    if (is.null(problem)) {
      problem <- menu_error()
    }
    if (!is.null(problem)) div(class = "pg-note pg-warn", problem)
  })
  action_problem <- reactive({
    if (!nzchar(trimws(input$action_label %||% ""))) "Write a label: it names the button for screen readers."
  })
  output$action_problem <- renderUI({
    problem <- action_problem() %||% if (click_kind() == "action") menu_error()
    if (!is.null(problem)) div(class = "pg-note pg-warn", problem)
  })
  # The click as code, from whichever switch is on; with both off, the empty helper removes it.
  click_code <- reactive({
    switch(
      click_kind(),
      action = code_action(input$action_label %||% "", isTRUE(input$action_tooltip), isTRUE(input$action_disabled)),
      menu = code_menu(
        menu_parsed()$items,
        input$menu_direction %||% "auto",
        input$menu_label %||% "",
        isTRUE(input$menu_tooltip),
        isTRUE(input$menu_disabled)
      ),
      code_pair(defaults$click)
    )
  })
  click_problem <- reactive({
    switch(click_kind(), action = action_problem(), menu = menu_parsed()$problem, NULL)
  })
  click_text <- debounce(
    reactive(list(
      click_kind(),
      input$action_label,
      input$action_tooltip,
      input$action_disabled,
      input$menu_items,
      input$menu_direction,
      input$menu_label,
      input$menu_tooltip,
      input$menu_disabled
    )),
    600
  )
  observeEvent(
    click_text(),
    {
      # Switching the click off works even while the text has a problem.
      req(is.null(click_problem()))
      ok <- send(list(click = click_code()), force = TRUE)
      menu_error(if (identical(ok, FALSE) && length(log())) log()[[1]]$message)
    },
    ignoreInit = TRUE
  )
  observeEvent(input$helper_menu, {
    items <- eval(state$click$helper)$items
    label <- if (input$helper_menu %in% names(items)) items[[input$helper_menu]] else input$helper_menu
    menu_last(sprintf("\"%s\" (%s)", input$helper_menu, label))
    add_log(
      sprintf("input$helper_menu  # \"%s\"", input$helper_menu),
      "event",
      paste0("The visitor chose ", label, ".")
    )
    if (input$helper_menu == "about") {
      showModal(modalDialog(
        title = "About this studio",
        p(
          "Every exported function and argument of mascot, live. Each change runs update_mascot() in this app's server."
        ),
        p("This dialog is the app's answer to the menu choice \"about\": your app decides what each item does."),
        easyClose = TRUE
      ))
    } else {
      send(
        list(
          bubble = code_bubble(paste0("You chose \"", label, "\"."), FALSE, 4, TRUE),
          gesture = code_gesture("nod")
        ),
        force = TRUE,
        remember = FALSE
      )
    }
  })
  output$menu_last <- renderText(menu_last())
  click_last <- reactiveVal("Nothing yet: turn on an action, then click or tap the mascot.")
  observeEvent(input$helper_click, {
    click_last(paste(input$helper_click, if (input$helper_click == 1) "click" else "clicks"))
    action <- eval(state$click$helper)
    if (inherits(action, "mascot_action") && !is.null(action$label)) {
      add_log(
        sprintf("input$helper_click  # %s", input$helper_click),
        "event",
        paste0("The visitor clicked the mascot: ", action$label, ".")
      )
      send(list(gesture = code_gesture("wave")), force = TRUE, remember = FALSE)
    }
  })
  output$click_last <- renderText(click_last())
  output$menu_code <- renderText({
    # Rejected items (a missing "=", or ids the package refuses) get a comment, never runnable code.
    problem <- menu_parsed()$problem %||% menu_error()
    if (!is.null(problem)) {
      return(problem_comment(problem))
    }
    code <- menu_handler_code(menu_parsed()$items)
    if (is.null(code)) "# Add items to see the server code." else code
  })

  # Wiring
  observeEvent(input$send_many, {
    send(
      list(
        mood = code_mood("celebrating"),
        status = code_status("Review complete"),
        bubble = code_bubble("All 120 rows passed.", FALSE, Inf, TRUE),
        gesture = code_gesture("wave")
      ),
      force = TRUE
    )
    updateSelectInput(session, "mood", selected = "celebrating")
    updateTextInput(session, "status_text", value = "Review complete")
  })
  # A slow step: one job at a time, finished by a timer observer. The completion call
  # names the session explicitly, as a callback outside a reactive context would. For real slow work, see mascot_example("long-task").
  task <- reactiveVal(NULL)
  observeEvent(input$task_run, {
    if (!is.null(task())) {
      return()
    }
    send(list(mood = code_mood("thinking"), status = code_status("Checking 120 rows")), force = TRUE)
    task(list(fail = isTRUE(input$task_fail), ends = Sys.time() + 2))
    session$sendCustomMessage("studio:task", TRUE)
  })
  observe({
    job <- task()
    req(!is.null(job))
    remaining <- as.numeric(difftime(job$ends, Sys.time(), units = "secs"))
    if (remaining > 0) {
      invalidateLater(ceiling(remaining * 1000), session)
      return()
    }
    pairs <- if (job$fail) {
      list(
        mood = code_mood("worried"),
        status = code_status("Check failed"),
        bubble = code_bubble("Three rows have no batch date.", FALSE, Inf, TRUE)
      )
    } else {
      list(
        mood = code_mood("happy"),
        status = code_status("All 120 rows checked"),
        bubble = code_bubble("", FALSE, 5, TRUE)
      )
    }
    send(pairs, force = TRUE, with_session = TRUE)
    task(NULL)
    session$sendCustomMessage("studio:task", FALSE)
  })
  output$mistake_code <- renderUI({
    mistake <- character_mistakes(current_character())[[input$mistake]]
    tagList(code_block(mistake$code, "pg-code-small"), div(class = "pg-hint", mistake$why))
  })
  observeEvent(input$mistake_run, {
    mistake <- character_mistakes(current_character())[[input$mistake]]
    call <- str2lang(mistake$code)
    last_call(mistake$code)
    # Store normalised builder output only for the two mistakes that really change state.
    if (run_logged(call, mistake$code) && identical(call[[2]], "helper")) {
      if (input$mistake == "Minimise an inline mascot") {
        state$placement <- code_placement("inline")
        updateRadioButtons(session, "position", selected = "inline")
        update_switch("minimise", value = TRUE)
        updateSelectInput(session, "drag", selected = "none")
      } else if (input$mistake == "Low contrast") {
        role <- roles()$role[1]
        light <- stats::setNames("#f8f9fa", role)
        # The call replaced the whole theme (a plain list has no palette), so the palette is cleared as well.
        state$theme <- code_theme("mascot", light, light, "auto", NULL, NULL, NULL, "original")
        updateSelectInput(session, "palette", selected = "original")
        updateSelectInput(session, "theme_source", selected = "mascot")
        updateRadioButtons(session, "theme_mode", selected = "auto")
        colours$reset()
        for (mode in c("light", "dark")) {
          colours$set(mode, role, "#f8f9fa")
        }
      }
    }
    nav_select("code_tabs", "Log")
  })

  # mascot_preview(): its arguments are the Controls panel's (the character is the studio's own
  # selection). While the function is selected the canvas shows the page the call returns, in place
  # of the live mascot, and the Preview tab of the Code tray shows the call that built it. A change
  # rebuilds the page after a short pause, with a "Building..." badge until it is shown.
  preview_selected <- reactive(
    identical(selected_function(), "mascot_preview") || identical(input$host_mode, "preview")
  )
  preview_roles <- reactive(mascot_colour_roles(
    uploaded_character() %||% current_character(),
    palette = if (is.null(uploaded_character())) selected_palette() else NULL
  ))
  output$preview_pickers <- renderUI({
    tagList(lapply(preview_roles()$role, function(role) {
      div(
        class = "pg-css",
        colour_input(
          paste0("preview_", role),
          preview_roles()$colour[match(role, preview_roles()$role)],
          paste("Preview", role)
        ),
        tags$code(role)
      )
    }))
  })
  outputOptions(output, "preview_pickers", suspendWhenHidden = FALSE)
  preview_colours <- reactive({
    values <- vapply(
      preview_roles()$role,
      function(role) input[[paste0("preview_", role)]] %||% preview_roles()$colour[match(role, preview_roles()$role)],
      character(1)
    )
    # Only the parts changed from the character's own colours go into the code.
    changed <- tolower(values) != tolower(preview_roles()$colour)
    stats::setNames(values[changed], preview_roles()$role[changed])
  })
  preview_args <- reactive({
    own <- formals(mascot::mascot_preview)
    mood <- input$preview_mood %||% ""
    status <- input$preview_status %||% ""
    bubble <- input$preview_bubble %||% ""
    size <- input$preview_size %||% own$size
    args <- list(
      character = if (!is.null(uploaded_character())) {
        helper_call("mascot_read_character", uploaded_filename())
      } else if (current_character() != own$character) {
        current_character()
      },
      mood = if (nzchar(mood)) mood,
      status = if (nzchar(trimws(status))) status,
      bubble = if (nzchar(trimws(bubble))) bubble,
      size = if (size != own$size) as.numeric(size),
      theme = if (identical(input$preview_theme_source, "custom") && length(preview_colours())) {
        if (selected_palette() == "original") {
          named_call("list", preview_colours())
        } else {
          helper_call(
            "mascot_theme",
            palette = selected_palette(),
            light = named_call("list", preview_colours()),
            dark = named_call("list", preview_colours())
          )
        }
      } else if (selected_palette() != "original") {
        selected_palette()
      },
      motion = if (isTRUE(input$preview_motion)) TRUE
    )
    Filter(Negate(is.null), args)
  })
  folder <- preview_folder(session, "studio-preview")
  prefix <- folder$prefix
  preview_dir <- folder$dir
  preview_request <- reactiveVal(0)
  preview_count <- reactiveVal(0)
  is_building <- reactiveVal(FALSE)
  last_built_call <- reactiveVal(NULL)
  last_preview_attempt <- reactiveVal(NULL)
  preview_inputs <- reactive(tryCatch(preview_args(), error = function(e) conditionMessage(e)))
  debounced_preview_inputs <- debounce(preview_inputs, 400)
  build_preview <- function() {
    is_building(TRUE)
    preview_request(preview_request() + 1)
  }
  # The page is built on the first visit, and again when the arguments changed since the last build.
  observeEvent(preview_selected(), {
    if (preview_selected()) {
      args <- preview_inputs()
      if (preview_request() == 0 || !identical(args, last_preview_attempt()$args)) {
        build_preview()
      }
    }
  })
  observeEvent(
    preview_inputs(),
    if (preview_selected() && preview_request() > 0) is_building(TRUE),
    ignoreInit = TRUE
  )
  observeEvent(
    debounced_preview_inputs(),
    {
      if (preview_selected() && preview_request() > 0) {
        args <- preview_inputs()
        if (!identical(args, last_preview_attempt()$args)) {
          preview_request(preview_request() + 1)
        } else {
          is_building(FALSE)
        }
      }
    },
    ignoreInit = TRUE
  )
  observeEvent(input$preview_build, build_preview())
  built_preview <- eventReactive(preview_request(), {
    req(preview_request() > 0)
    attempt <- preview_inputs()
    last_preview_attempt(list(args = attempt, outcome = "error"))
    args <- tryCatch(preview_args(), error = function(e) e)
    if (inherits(args, "error")) {
      is_building(FALSE)
      return(list(error = cli::ansi_strip(conditionMessage(args)), code = problem_comment(conditionMessage(args))))
    }
    page <- withCallingHandlers(
      tryCatch(eval(as.call(c(as.name("mascot_preview"), args))), error = function(e) e),
      warning = function(w) {
        if (inherits(w, "mascot_contrast")) invokeRestart("muffleWarning")
      }
    )
    is_building(FALSE)
    if (inherits(page, "error")) {
      return(list(error = cli::ansi_strip(conditionMessage(page)), code = problem_comment(conditionMessage(page))))
    }
    preview_count(isolate(preview_count()) + 1)
    file <- sprintf("preview-%s-%d.html", session$token, isolate(preview_count()))
    htmltools::save_html(page, file.path(preview_dir, file), libdir = "lib")
    # Leave the current and preceding page available while the iframe loads.
    older <- seq_len(max(0L, isolate(preview_count()) - 2L))
    if (length(older)) {
      unlink(file.path(preview_dir, sprintf("preview-%s-%d.html", session$token, older)))
    }
    last_preview_attempt(list(args = args, outcome = "ok"))
    last_built_call(args)
    list(file = file, contrast = attr(page, "contrast"), code = format_call("mascot_preview", args))
  })
  output$preview_status_badge <- renderUI({
    if (is_building()) tags$span(class = "badge text-bg-secondary pg-building", "Building\u2026")
  })
  output$preview_frame <- renderUI({
    if (preview_request() == 0) {
      return(div(class = "pg-hint", "Select mascot_preview() to build the page."))
    }
    result <- built_preview()
    if (!is.null(result$error)) {
      return(div(class = "pg-note pg-warn", result$error))
    }
    tags$iframe(
      class = paste("pg-preview", if (identical(input$preview_width, "phone")) "is-phone"),
      src = paste0(prefix, "/", result$file),
      title = "mascot_preview() page"
    )
  })
  preview_code <- reactive({
    problem <- tryCatch(
      {
        preview_args()
        NULL
      },
      error = function(e) conditionMessage(e)
    )
    if (!is.null(problem)) {
      return(problem_comment(problem))
    }
    if (preview_request() == 0) {
      return("# Select mascot_preview() in the index to build a preview.")
    }
    result <- built_preview()
    if (!identical(preview_inputs(), last_preview_attempt()$args)) {
      return("# Building preview for the current settings.")
    }
    result$code
  })
  output$code_preview <- renderText(preview_code())
  output$preview_contrast <- renderUI({
    req(preview_request() > 0)
    findings <- built_preview()$contrast
    if (is.null(findings)) {
      return(NULL)
    }
    if (!nrow(findings)) {
      return(div(class = "pg-note pg-ok", "attr(page, \"contrast\") is empty: no colour below 3:1."))
    }
    findings$ratio <- format(round(findings$ratio, 2), nsmall = 2)
    tagList(div(class = "pg-note pg-warn", "attr(page, \"contrast\") lists colours below 3:1:"), data_table(findings))
  })
  outputOptions(output, "code_preview", suspendWhenHidden = FALSE)
  # The Code tray follows the selected function: its Preview tab for mascot_preview(), the usual tabs otherwise.
  observeEvent(preview_selected(), {
    if (preview_selected()) {
      nav_show("code_tabs", "preview", select = TRUE)
    } else {
      if (identical(input$code_tabs, "preview")) {
        nav_select("code_tabs", "UI")
      }
      nav_hide("code_tabs", "preview")
    }
  })

  problem_comment <- function(problem) {
    checkmate::assert_string(problem)
    paste0("# ", gsub("[\r\n]+", " ", cli::ansi_strip(problem)))
  }
  settings_problem <- reactive({
    if (click_kind() != "none") click_problem() %||% menu_error()
  })

  # Code card
  output$code_ui <- renderText({
    if (!is.null(settings_problem())) {
      return(problem_comment(settings_problem()))
    }
    current <- reactiveValuesToList(state)
    format_call("mascot", ui_args(current, style()))
  })
  output$code_server <- renderText({
    if (!is.null(settings_problem())) {
      return(problem_comment(settings_problem()))
    }
    args <- server_args(reactiveValuesToList(state), style())
    if (length(args) == 1) {
      paste0("# ", character_name(), " is in the default state: nothing to update.")
    } else {
      format_call("update_mascot", args)
    }
  })
  output$code_app <- renderText({
    current <- reactiveValuesToList(state)
    if (!is.null(settings_problem())) {
      return(problem_comment(settings_problem()))
    }
    ui <- format_call("mascot", ui_args(current, style()))
    theme <- paste(deparse(current$theme$short), collapse = "")
    whole_app_code(
      ui,
      click_handler_code(current$click$helper),
      c("shiny", if (grepl("bs_theme", theme, fixed = TRUE)) "bslib", "mascot"),
      # The value of each CSS variable the theme reads.
      colours$css_values()[vapply(names(colours$css_values()), grepl, logical(1), x = theme, fixed = TRUE)]
    )
  })
  output$code_last <- renderText(last_call())
  observeEvent(input$log_clear, log(list()))
  # The copy buttons read hidden tabs too.
  outputOptions(output, "code_ui", suspendWhenHidden = FALSE)
  outputOptions(output, "code_last", suspendWhenHidden = FALSE)
  outputOptions(output, "code_server", suspendWhenHidden = FALSE)
  outputOptions(output, "code_app", suspendWhenHidden = FALSE)
  activity_log <- reactive({
    entries <- log()
    if (!length(entries)) {
      return(div(class = "pg-hint", "Nothing yet."))
    }
    div(
      class = "pg-log",
      lapply(entries, function(entry) {
        div(
          class = paste("pg-log-entry", paste0("is-", entry$outcome)),
          tags$span(class = "pg-log-badge", entry$outcome),
          code_block(entry$code),
          if (!is.null(entry$message)) code_block(entry$message, "pg-log-message")
        )
      })
    )
  })

  output$log <- renderUI(activity_log())
  output$wiring_log <- renderUI(activity_log())
  outputOptions(output, "log", suspendWhenHidden = FALSE)
  outputOptions(output, "wiring_log", suspendWhenHidden = FALSE)

  # A separate drawn example exercises retained palettes without changing the live host's controls.
  palette_swap_result <- reactiveVal("Choose a swap to run the calls below.")
  output$palette_swap_result <- renderText(palette_swap_result())
  observeEvent(input$palette_swap, {
    target <- unname(studio_palette_swap[input$palette_swap])
    req(input$palette_swap %in% c("kept", "dropped"))
    # The swap is shared with the theme view's Check tab (R/shared-check.R).
    result <- palette_swap_run(
      "palette_swap_demo",
      studio_palette_swap[["from"]],
      target,
      studio_palette_swap[["palette"]],
      environment()
    )
    palette_swap_result(
      if ("mascot_palette_dropped" %in% result$condition_classes) {
        paste("mascot_palette_dropped:", result$message)
      } else {
        paste("Palette", studio_palette_swap[["palette"]], "kept for", mascot_character(target)$name)
      }
    )
  })
  observeEvent(input$menu_long_status, {
    req(input$menu_long_status %in% c("top-right", "bottom-right"))
    updateRadioButtons(session, "position", selected = input$menu_long_status)
    updateTextInput(session, "status_text", value = studio_long_status)
    updateSelectInput(session, "click_type", selected = "menu")
    click_kind("menu")
    update_switch("menu_on", value = TRUE, session = session)
    update_switch("menu_disabled", value = FALSE, session = session)
    updateRadioButtons(session, "menu_direction", selected = "auto")
    updateTextAreaInput(session, "menu_items", value = paste(names(default_menu), "=", default_menu, collapse = "\n"))
    updateTextInput(session, "menu_label", value = "")
    update_switch("menu_tooltip", value = TRUE, session = session)
    send(
      list(
        placement = code_placement(
          input$menu_long_status,
          minimise = isTRUE(input$minimise),
          drag = input$drag %||% "none"
        ),
        status = code_status(studio_long_status),
        click = code_menu(default_menu, direction = "auto")
      ),
      force = TRUE
    )
  })

  # A reference for the selected function, with code made from its current controls.
  output$guide <- renderUI(selected_guide(selected_function(), current_character()))
  output$function_help <- renderUI(function_help(selected_function()))
  outputOptions(output, "function_help", suspendWhenHidden = FALSE)
  output$example_listing <- renderUI(data_table(mascot_examples()))
  output$host_event <- renderText({
    entries <- log()
    if (!length(entries)) "No event yet" else entries[[1]]$code
  })
  output$live_call <- renderUI({
    current <- reactiveValuesToList(state)
    # Welcome content is omitted from copied app code but belongs in the current
    # configuration. Retain the last accepted value when a draft is invalid.
    current$click <- live_demo$click
    current$bubble <- live_demo$bubble
    # The welcome bubble and menu are the studio's own demonstration; copied code leaves them out.
    demo <- c(
      if (!identical(live_demo$bubble$short, state$bubble$short)) "bubble",
      if (!identical(live_demo$click$short, state$click$short)) "click"
    )
    call_chips(current, style(), last_gesture(), demo)
  })
  # Readiness and events come from the isolated engine, not a second Shiny session.
  output$live_host <- renderUI({
    initial <- isolate(start)
    initial$character <- code_character(isolate(current_character()))
    live <- do.call(mascot, lapply(ui_args(initial, "short"), eval))
    bridge <- htmltools::htmlDependency(
      "studio-bridge",
      "1.0.0",
      src = c(href = ".."),
      script = "studio.js",
      stylesheet = c("tokens.css", "shared.css", "studio.css")
    )
    live <- htmltools::attachDependencies(live, c(list(bridge), htmltools::htmlDependencies(live)))
    page <- htmltools::tags$html(
      lang = "en-GB",
      `data-studio-host` = "true",
      htmltools::tags$head(htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1")),
      htmltools::tags$body(div(class = "pg-isolated-stage", live))
    )
    htmltools::save_html(page, file.path(preview_dir, "live.html"), libdir = "lib")
    tags$iframe(
      id = "live_frame",
      class = "pg-live-frame",
      src = paste0(prefix, "/live.html"),
      title = "Contained live mascot preview",
      tabindex = "0"
    )
  })
  outputOptions(output, "live_host", suspendWhenHidden = FALSE)
  output$roles_table <- renderUI(roles_table(current_character(), selected_palette()))
  family_listing <- reactive({
    family <- input$list_family %||% ""
    mascot_characters(family = if (nzchar(family)) family else NULL)
  })
  output$family_listing <- renderUI(data_table(family_listing()))
  output$characters_table <- renderUI(data_table(family_listing()))
  output$code_function <- renderText({
    fn <- selected_function()
    if (fn %in% c("mascot", "update_mascot", "mascot_action", "mascot_popup_menu") && !is.null(settings_problem())) {
      return(problem_comment(settings_problem()))
    }
    if (fn == "mascot_preview") {
      return(preview_code())
    }
    pair <- switch(
      fn,
      mascot_character = code_character(input$character),
      mascot_mood = code_mood(input$mood),
      mascot_status = code_status(input$status_text),
      mascot_bubble = code_bubble(
        input$bubble_text,
        input$bubble_html,
        if (input$bubble_forever) Inf else as.numeric(input$bubble_duration),
        input$bubble_closable
      ),
      mascot_motion_settings = motion_code(),
      mascot_gesture = code_gesture(if (!nzchar(input$gesture %||% "")) "nod" else input$gesture),
      mascot_size = size_code(),
      mascot_placement = code_placement(
        input$position,
        minimise = isTRUE(input$minimise),
        drag = if (isTRUE(input$drag != "none")) input$drag else "none"
      ),
      mascot_theme = theme_code(),
      mascot_action = code_action(
        input$action_label %||% "",
        isTRUE(input$action_tooltip),
        isTRUE(input$action_disabled)
      ),
      mascot_popup_menu = code_menu(
        menu_parsed()$items,
        input$menu_direction %||% "auto",
        input$menu_label %||% "",
        isTRUE(input$menu_tooltip),
        isTRUE(input$menu_disabled)
      ),
      NULL
    )
    if (!is.null(pair)) {
      # A bslib theme is a supported alternative to mascot_theme(), shown exactly as supplied.
      return(format_expr(if (fn == "mascot_theme" && !is.character(pair$short)) pair$short else pair$helper))
    }
    switch(
      fn,
      mascot = format_call("mascot", ui_args(reactiveValuesToList(state), style())),
      update_mascot = format_call("update_mascot", server_args(reactiveValuesToList(state), style())),
      mascot_colour_roles = format_call(fn, list(character = current_character(), palette = selected_palette())),
      mascot_moods = format_call(fn, list(character = current_character())),
      mascot_gestures = format_call(fn, list(character = current_character())),
      mascot_anchors = format_call(fn, list(character = current_character())),
      mascot_palettes = format_call(fn, list(character = current_character())),
      mascot_characters = format_call(
        fn,
        if (nzchar(input$list_family %||% "")) list(family = input$list_family) else list()
      ),
      mascot_example = format_call(
        fn,
        list(name = input$example_name %||% examples$name[1], run = isTRUE(input$example_run))
      ),
      mascot_studio = format_call(fn, list(fn = "mascot_theme")),
      format_call(fn, list())
    )
  })
  outputOptions(output, "code_function", suspendWhenHidden = FALSE)
}

examples_server <- function(input, output, session) {
  # Examples
  output$example_result <- renderUI({
    name <- input$example_name
    path <- mascot_example(name, run = FALSE)
    files <- list.files(dirname(path), recursive = TRUE)
    call <- if (input$example_run) {
      code_block(sprintf("mascot::mascot_example(\"%s\")", name), "pg-code", id = "example_call")
    } else {
      code_block(sprintf("mascot_example(\"%s\", run = FALSE)", name), "pg-code", id = "example_call")
    }
    tagList(
      div(class = "pg-code-wrap", call, copy_button("example_call")),
      if (input$example_run) {
        div(
          class = "pg-note",
          "Paste this into your R console: it opens the app and waits until you close it. The studio
          does not run it itself, because a running app cannot start another."
        )
      },
      if (length(files) > 1) {
        div(
          class = "pg-note",
          "This example is a folder: ",
          paste(files, collapse = ", "),
          ". Run the folder with shiny::runApp()."
        )
      },
      tags$h3(class = "pg-section-title", "app.R"),
      div(
        class = "pg-code-wrap",
        code_block(paste(readLines(path, warn = FALSE), collapse = "\n"), "pg-code pg-code-long", id = "example_code"),
        copy_button("example_code")
      )
    )
  })
}

# The studio and examples views use the same studio shell; the URL only chooses its initial host mode.
views <- studio_views(studio_view_ui, function(input, output, session) {
  studio_server(input, output, session)
  examples_server(input, output, session)
})

# A session runs only its own view's server, read once when it starts: Shiny sets the page's first input values
# and the address before it calls this function.
server <- function(input, output, session) {
  view <- view_from_client(isolate(session$clientData$url_search), isolate(input$tabs))
  views[[view]]$server(input, output, session)
}

shinyApp(ui, server)
