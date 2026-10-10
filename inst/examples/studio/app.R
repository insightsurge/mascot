# The mascot studio: every exported function and argument, live, with explanations.
# Run it with mascot::mascot_example("studio"). Shiny first loads the files in R/ (the
# explanations, data, code builders, inspector controls and guide pieces) and serves www/ (styles
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

moods <- mascot_moods()
roles <- mascot_colour_roles()
examples <- mascot_examples()

start <- lapply(defaults, code_pair)
start$bubble <- code_bubble(welcome, FALSE, 8, TRUE)
start$popup_menu <- code_menu(default_menu)

# The mascot() call for a state: only the arguments that differ from the defaults.
ui_args <- function(state, style) {
  changed <- Filter(function(field) !identical(state[[field]]$short, defaults[[field]]), names(defaults))
  c(list(id = "helper"), pick_style(state[changed], style))
}

# The updateMascot() call that brings a plain mascot to a state.
server_args <- function(state, style) {
  c(list("helper"), ui_args(state, style)[-1])
}

# ---- Pages -------------------------------------------------------------------------------

start_mascot <- do.call(mascot, lapply(ui_args(start, "short"), eval))

studio_page <- div(
  class = "pg-studio",
  id = "studio_shell",
  function_index(),
  div(
    class = "pg-centre",
    id = "studio_centre",
    div(
      class = "pg-toolbar pg-card-head",
      actionButton("reset_all", "Start again", class = "btn-outline-primary btn-sm"),
      div(
        class = "pg-code-style",
        popover(
          tags$button(
            type = "button",
            class = "pg-arg-chip",
            `aria-label` = "Shortcuts or helpers?",
            "Code style",
            tags$span(class = "pg-info", "i")
          ),
          p("Shortcuts are plain values: mood = \"happy\"."),
          p(
            "Helpers are mascot_*() calls: mood = mascot_mood(\"happy\"). Use them for settings beyond the main value, such as a bubble's duration. Both give the same mascot."
          ),
          title = "Shortcuts or helpers?"
        ),
        radioButtons("code_style", NULL, c(Shortcuts = "short", Helpers = "helper"), inline = TRUE)
      )
    ),
    div(
      class = "pg-canvas",
      id = "studio_canvas",
      div(class = "pg-stage", start_mascot),
      uiOutput("stage_note"),
      div(class = "pg-canvas-caption pg-muted", "Tessa follows the arguments in the inspector.")
    ),
    div(
      class = "pg-dock",
      id = "studio_dock",
      tags$div(
        id = "dock_grip",
        class = "pg-grip",
        role = "separator",
        tabindex = "0",
        `aria-label` = "Resize the guide and code dock",
        `aria-orientation` = "horizontal",
        `aria-valuemin` = "25",
        `aria-valuemax` = "80",
        `aria-valuenow` = "42",
        title = "Drag to resize, or use the up and down arrow keys"
      ),
      tags$button(
        id = "guide_expand",
        type = "button",
        class = "btn btn-outline-primary btn-sm pg-expand",
        `aria-expanded` = "false",
        `aria-controls` = "studio_dock",
        "Expand guide"
      ),
      navset_underline(
        id = "code_tabs",
        nav_panel("Guide", value = "Guide", uiOutput("guide")),
        nav_panel(
          "UI",
          div(class = "pg-hint", "A mascot() call that starts the way Tessa looks now."),
          div(class = "pg-code-wrap", code_output("code_ui"), copy_button("code_ui"))
        ),
        nav_panel(
          "Server",
          div(class = "pg-hint", "One updateMascot() call that turns a plain mascot into Tessa as she is now."),
          div(class = "pg-code-wrap", code_output("code_server"), copy_button("code_server"))
        ),
        nav_panel(
          "App",
          div(class = "pg-hint", "A complete app.R: paste it into a new file and run it."),
          div(class = "pg-code-wrap", code_output("code_app"), copy_button("code_app"))
        ),
        nav_panel(
          "Last",
          div(class = "pg-hint", "The call the studio just ran in its server."),
          div(class = "pg-code-wrap", code_output("code_last"), copy_button("code_last"))
        ),
        nav_panel(
          "Log",
          div(
            class = "pg-card-head",
            div(class = "pg-hint", "Every call and menu choice, newest first, with warnings and errors."),
            actionButton("log_clear", "Clear", class = "btn-outline-primary btn-sm")
          ),
          uiOutput("log")
        )
      )
    )
  ),
  tags$aside(
    class = "pg-inspector",
    id = "studio_inspector",
    `aria-label` = "Function controls",
    input_switch("show_all_controls", "Show all controls", FALSE),
    div(class = "pg-hint", "Show every function's controls, folded by function."),
    panel_look(),
    panel_messages(),
    panel_motion(),
    panel_layout(),
    panel_colours(),
    panel_menu(),
    panel_wiring()
  )
)

preview_page <- layout_sidebar(
  sidebar = sidebar(
    title = "mascot_preview() arguments",
    width = 380,
    arg_field("mascot_preview", "character", selectInput("preview_character", "Character", c(Tessa = "tessa"))),
    arg_field(
      "mascot_preview",
      "mood",
      selectInput("preview_mood", "Mood", c("Every mood (NULL)" = "", stats::setNames(moods$name, moods$name)))
    ),
    arg_field("mascot_preview", "status", textInput("preview_status", "Status text", placeholder = "Empty: each mood")),
    arg_field("mascot_preview", "bubble", textInput("preview_bubble", "Bubble text", placeholder = "Empty: no bubble")),
    arg_field(
      "mascot_preview",
      "size",
      tagList(
        sliderInput("preview_size", "Pixels", min = 48, max = 240, value = 120, step = 8),
        radioButtons(
          "preview_width",
          "Show the page at",
          c("Full width" = "full", "Phone width (375 px)" = "phone"),
          inline = TRUE
        )
      ),
      note = div(class = "pg-note", "At phone width, small_screen sizes apply, as on a real phone.")
    ),
    arg_field(
      "mascot_preview",
      "placement",
      selectInput("preview_placement", "Placement", c("inline", corners))
    ),
    arg_field("mascot_preview", "theme", input_switch("preview_theme", "Use the studio's colours", TRUE)),
    arg_field("mascot_preview", "motion", input_switch("preview_motion", "Animate", FALSE)),
    arg_field("mascot_preview", "popup_menu", input_switch("preview_menu", "Use the studio's menu", FALSE)),
    actionButton("preview_build", "Build the preview", class = "btn-primary")
  ),
  card(
    card_header(class = "pg-card-head", "The preview page", uiOutput("preview_open", inline = TRUE)),
    div(
      class = "pg-code-wrap",
      code_output("code_preview"),
      copy_button("code_preview")
    ),
    uiOutput("preview_frame"),
    uiOutput("preview_contrast")
  ),
  card(card_header("Guide"), card_body(guide_content("preview")))
)

examples_page <- layout_columns(
  col_widths = breakpoints(sm = 12, lg = c(5, 7)),
  card(
    card_header("Guide"),
    card_body(
      guide_content("examples"),
      tags$h3(class = "pg-section-title", "The examples"),
      data_table(examples, cells = list(name = function(value) try_button("example_pick", value, value)))
    )
  ),
  card(
    card_header(class = "pg-card-head", "Read an example", tags$span(class = "pg-muted", "mascot_example()")),
    card_body(
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
  )
)

ui <- page_navbar(
  title = "mascot studio",
  id = "tabs",
  theme = bs_theme(version = 5),
  # The studio fills the window; each column and the dock scroll independently.
  fillable = "studio",
  window_title = "mascot studio",
  header = tags$head(
    tags$link(rel = "stylesheet", href = "studio.css"),
    tags$script(src = "studio.js")
  ),
  nav_panel("Studio", value = "studio", studio_page),
  nav_panel("Static preview", value = "preview", preview_page),
  nav_panel("Examples", value = "examples", examples_page),
  nav_spacer(),
  nav_item(input_dark_mode(id = "dark_mode", mode = "light"))
)

# ---- Server ------------------------------------------------------------------------------

server <- function(input, output, session) {
  state <- do.call(reactiveValues, start)
  last_call <- reactiveVal("No update yet. Change a setting in the inspector.")
  log <- reactiveVal(list())
  selected_function <- reactiveVal("mascot_mood")
  menu_last <- reactiveVal("nothing yet")
  menu_error <- reactiveVal(NULL)

  style <- reactive(if (is.null(input$code_style)) "short" else input$code_style)

  add_log <- function(code, outcome, message = NULL) {
    entry <- list(code = code, outcome = outcome, message = message)
    log(utils::head(c(list(entry), log()), 30))
  }

  # Evaluates a call and logs it with any warning or error. Returns TRUE when the mascot changed:
  # a wrong value warns and leaves the mascot unchanged; a low-contrast colour warns and is kept.
  run_logged <- function(call, code) {
    warnings <- character()
    unchanged <- FALSE
    error <- NULL
    tryCatch(
      withCallingHandlers(
        eval(call),
        warning = function(w) {
          warnings <<- c(warnings, cli::ansi_strip(conditionMessage(w)))
          if (!inherits(w, "mascot_contrast")) {
            unchanged <<- TRUE
          }
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) error <<- cli::ansi_strip(conditionMessage(e))
    )
    if (!is.null(error)) {
      add_log(code, "error", error)
      showNotification(error, type = "error", duration = 8)
      return(FALSE)
    }
    if (length(warnings)) {
      add_log(code, "warning", paste(warnings, collapse = "\n"))
      showNotification(paste(warnings, collapse = "\n"), type = "warning", duration = 8)
    } else {
      add_log(code, "ok")
    }
    !unchanged
  }

  # Sends the changed settings in one updateMascot() call; TRUE when it ran, FALSE on an error,
  # NA when nothing changed. force sends unchanged ones too (a bubble shown twice, a gesture);
  # with_session names the session, for calls that run outside the reactive context.
  send <- function(pairs, force = FALSE, with_session = FALSE) {
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
    code <- format_call("updateMascot", args)
    last_call(code)
    ok <- run_logged(as.call(c(as.name("updateMascot"), args)), code)
    if (ok) {
      for (field in intersect(names(pairs), names(defaults))) {
        state[[field]] <- pairs[[field]]
      }
    }
    invisible(ok)
  }

  # Clicks on buttons that carry data-event and data-value arrive as input$<event>.
  observeEvent(input$set_position, updateRadioButtons(session, "position", selected = input$set_position))
  observeEvent(input$select_function, {
    req(input$select_function %in% names(playground_guide))
    selected_function(input$select_function)
    nav_select("tabs", "studio")
    nav_select("code_tabs", "Guide")
  })
  observeEvent(input$reset_all, session$reload())

  # Character and mood
  observeEvent(input$character, send(list(character = code_character(input$character))), ignoreInit = TRUE)
  observeEvent(input$mood, send(list(mood = code_mood(input$mood))), ignoreInit = TRUE)

  # Messages
  status_text <- debounce(reactive(input$status_text), 600)
  observeEvent(status_text(), send(list(status = code_status(status_text()))), ignoreInit = TRUE)
  observeEvent(input$status_clear, {
    updateTextInput(session, "status_text", value = "")
    send(list(status = code_status("")))
  })
  observeEvent(
    input$bubble_example,
    {
      example <- bubble_examples[[input$bubble_example]]
      updateTextAreaInput(session, "bubble_text", value = example$text)
      update_switch("bubble_html", value = example$html)
    },
    ignoreInit = TRUE
  )
  observeEvent(input$bubble_show, {
    duration <- if (input$bubble_forever) Inf else as.numeric(input$bubble_duration)
    send(
      list(bubble = code_bubble(input$bubble_text, input$bubble_html, duration, input$bubble_closable)),
      force = TRUE
    )
  })
  observeEvent(input$bubble_clear, send(list(bubble = code_bubble("", FALSE, 5, TRUE)), force = TRUE))

  # Motion and gestures
  observeEvent(
    list(input$animate, input$swap),
    send(list(motion = code_motion(input$animate, input$swap))),
    ignoreInit = TRUE
  )
  observeEvent(input$gesture, send(list(gesture = code_gesture(input$gesture)), force = TRUE))

  # Size and placement
  size_code <- reactive({
    # Sliders send whole numbers as integers; the code shows plain numbers.
    size <- if (input$size_unit == "pct") paste0(input$size_pct, "%") else as.numeric(input$size_px)
    code_size(size, if (input$small_on) as.numeric(input$small_px), input$simplify)
  })
  observeEvent(size_code(), send(list(size = size_code())), ignoreInit = TRUE)
  observeEvent(
    list(input$position, input$minimise),
    {
      floating <- input$position != "inline"
      if (!floating && isTRUE(input$minimise)) {
        update_switch("minimise", value = FALSE)
      }
      send(list(placement = code_placement(input$position, floating && isTRUE(input$minimise))))
    },
    ignoreInit = TRUE
  )
  output$size_ruler <- renderUI({
    if (input$size_unit == "pct") {
      size_ruler(NULL, NULL)
    } else {
      size_ruler(input$size_px, paste(input$size_px, "px"))
    }
  })
  output$placement_map <- renderUI(placement_map(input$position, isTRUE(input$minimise)))
  output$stage_note <- renderUI({
    if (input$position == "inline") {
      return(NULL)
    }
    div(
      class = "pg-note",
      "Tessa is floating in the ",
      sub("-", " ", input$position, fixed = TRUE),
      " corner of the window. Choose Inline to bring her back here."
    )
  })

  # Colours and theme
  picked <- function(mode) {
    values <- vapply(
      roles$role,
      function(role) {
        value <- input[[paste0(mode, "_", role)]]
        if (is.null(value)) NA_character_ else value
      },
      character(1)
    )
    keep <- !is.na(values) & tolower(values) != tolower(roles$colour)
    stats::setNames(tolower(values[keep]), roles$role[keep])
  }
  theme_code <- debounce(
    reactive({
      code_theme(
        input$theme_source,
        picked("light"),
        picked("dark"),
        input$theme_mode,
        input$css_roles,
        input$bs_primary,
        input$bs_secondary
      )
    }),
    300
  )
  observeEvent(theme_code(), send(list(theme = theme_code())), ignoreInit = TRUE)
  # The browser reads the variable again only when the theme is sent, so resend it.
  observeEvent(
    input$css_accent,
    if (length(input$css_roles)) send(list(theme = theme_code()), force = TRUE),
    ignoreInit = TRUE
  )
  reset_colour <- function(mode, role) {
    session$sendInputMessage(paste0(mode, "_", role), list(value = roles$colour[roles$role == role]))
  }
  observeEvent(input$reset_colour, {
    parts <- strsplit(input$reset_colour, ":", fixed = TRUE)[[1]]
    reset_colour(parts[1], parts[2])
  })
  observeEvent(
    input$reset_mode,
    for (role in roles$role) {
      reset_colour(input$reset_mode, role)
    }
  )
  output$contrast <- renderUI({
    input$contrast_check
    theme <- isolate(state$theme)
    req(input$contrast_check)
    preview <- tryCatch(
      suppressWarnings(mascot_preview(theme = eval(theme$short))),
      error = function(e) e
    )
    if (inherits(preview, "error")) {
      return(div(class = "pg-note pg-warn", "The check failed: ", cli::ansi_strip(conditionMessage(preview))))
    }
    css_note <- if (length(input$css_roles) && input$theme_source == "mascot") {
      div(
        class = "pg-note",
        "Parts tied to a CSS variable (",
        paste(input$css_roles, collapse = ", "),
        ") are not checked here: only the browser knows their value. It warns in its console."
      )
    }
    findings <- attr(preview, "contrast")
    if (!nrow(findings)) {
      return(tagList(
        div(class = "pg-note pg-ok", "Every colour checked in R has at least 3:1 contrast in light and dark."),
        css_note
      ))
    }
    findings$ratio <- format(round(findings$ratio, 2), nsmall = 2)
    tagList(
      div(class = "pg-note pg-warn", "These colours are hard to see on the page background. They are kept."),
      css_note,
      data_table(
        findings,
        cells = list(colour = function(value) {
          tagList(tags$span(class = "pg-swatch", style = paste0("background:", value)), tags$code(value))
        })
      )
    )
  })

  # Popup menu
  menu_text <- debounce(reactive(list(input$menu_on, input$menu_items)), 600)
  menu_parsed <- reactive({
    lines <- trimws(strsplit(input$menu_items, "\n", fixed = TRUE)[[1]])
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
  observeEvent(
    menu_text(),
    {
      parsed <- menu_parsed()
      # Switching the menu off works even while the item text has a problem.
      req(!isTRUE(input$menu_on) || is.null(parsed$problem))
      items <- if (isTRUE(input$menu_on)) parsed$items else character()
      ok <- send(list(popup_menu = code_menu(items)))
      menu_error(if (identical(ok, FALSE) && length(log())) log()[[1]]$message)
    },
    ignoreInit = TRUE
  )
  observeEvent(input$helper_menu, {
    items <- menu_parsed()$items
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
          "Every exported function and argument of mascot, live. Each change runs updateMascot() in this app's server."
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
        force = TRUE
      )
    }
  })
  output$menu_last <- renderText(menu_last())
  output$menu_code <- renderText({
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
    session$sendInputMessage("mood", list(value = "celebrating"))
    updateTextInput(session, "status_text", value = "Review complete")
  })
  # A slow step: the first call runs now; the second runs two seconds later, outside the reactive
  # context, so it names the session. For real slow work, see mascot_example("long-task").
  observeEvent(input$task_run, {
    send(list(mood = code_mood("thinking"), status = code_status("Checking 120 rows")), force = TRUE)
    fail <- isTRUE(input$task_fail)
    later::later(
      function() {
        # isolate(): the callback reads reactive values outside any observer.
        withReactiveDomain(
          session,
          isolate({
            if (fail) {
              send(
                list(
                  mood = code_mood("worried"),
                  status = code_status("Check failed"),
                  bubble = code_bubble("Three rows have no batch date.", FALSE, Inf, TRUE)
                ),
                force = TRUE,
                with_session = TRUE
              )
            } else {
              send(
                list(mood = code_mood("happy"), status = code_status("All 120 rows checked")),
                force = TRUE,
                with_session = TRUE
              )
            }
          })
        )
      },
      2
    )
  })
  output$mistake_code <- renderUI({
    mistake <- mistakes[[input$mistake]]
    tagList(code_block(mistake$code, "pg-code-small"), div(class = "pg-hint", mistake$why))
  })
  observeEvent(input$mistake_run, {
    mistake <- mistakes[[input$mistake]]
    call <- str2lang(mistake$code)
    last_call(mistake$code)
    # A mistake that still changes Tessa (low contrast) updates the state the code card shows.
    if (run_logged(call, mistake$code) && identical(call[[2]], "helper")) {
      args <- as.list(call)[-(1:2)]
      for (field in intersect(names(args), names(defaults))) {
        state[[field]] <- code_pair(args[[field]])
      }
    }
    nav_select("code_tabs", "Log")
  })

  # Code card
  output$code_ui <- renderText({
    current <- reactiveValuesToList(state)
    format_call("mascot", ui_args(current, style()))
  })
  output$code_server <- renderText({
    args <- server_args(reactiveValuesToList(state), style())
    if (length(args) == 1) "# Tessa is in her default state: nothing to update." else format_call("updateMascot", args)
  })
  output$code_app <- renderText({
    current <- reactiveValuesToList(state)
    args <- server_args(current, style())
    update <- if (length(args) == 1) {
      "# Change a setting in the studio first."
    } else {
      format_call("updateMascot", args)
    }
    theme <- paste(deparse(current$theme$short), collapse = "")
    whole_app_code(
      update,
      menu_handler_code(menu_parsed()$items),
      c("shiny", if (grepl("bs_theme", theme, fixed = TRUE)) "bslib", "mascot"),
      if (grepl("--studio-accent", theme, fixed = TRUE)) input$css_accent
    )
  })
  output$code_last <- renderText(last_call())
  observeEvent(input$log_clear, log(list()))
  # The copy buttons read hidden tabs too.
  outputOptions(output, "code_ui", suspendWhenHidden = FALSE)
  outputOptions(output, "code_last", suspendWhenHidden = FALSE)
  outputOptions(output, "code_server", suspendWhenHidden = FALSE)
  outputOptions(output, "code_app", suspendWhenHidden = FALSE)
  output$log <- renderUI({
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

  # A reference for the selected function, with code made from its current controls.
  output$guide <- renderUI(selected_guide(selected_function()))
  output$roles_table <- renderUI(roles_table(input$roles_character))
  output$code_function <- renderText({
    fn <- selected_function()
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
      mascot_motion = code_motion(input$animate, input$swap),
      mascot_gesture = code_gesture(if (is.null(input$gesture)) "nod" else input$gesture),
      mascot_size = size_code(),
      mascot_placement = code_placement(input$position, input$position != "inline" && isTRUE(input$minimise)),
      mascot_theme = theme_code(),
      mascot_popup_menu = code_menu(if (isTRUE(input$menu_on)) menu_parsed()$items else character()),
      NULL
    )
    if (!is.null(pair)) {
      # A bslib theme is a supported alternative to mascot_theme(), shown exactly as supplied.
      return(format_expr(pair$helper))
    }
    switch(
      fn,
      mascot = format_call("mascot", ui_args(reactiveValuesToList(state), style())),
      updateMascot = format_call("updateMascot", server_args(reactiveValuesToList(state), style())),
      mascot_colour_roles = format_call(fn, list(character = input$roles_character)),
      format_call(fn, list())
    )
  })
  outputOptions(output, "code_function", suspendWhenHidden = FALSE)

  # Static preview
  preview_dir <- file.path(tempdir(), "mascot-studio-preview")
  dir.create(preview_dir, showWarnings = FALSE)
  addResourcePath("studio-preview", preview_dir)
  preview_count <- reactiveVal(0)
  preview_call <- reactive({
    current <- reactiveValuesToList(state)
    menu <- current$popup_menu$short
    args <- list(
      character = if (input$preview_character != "tessa") input$preview_character,
      mood = if (nzchar(input$preview_mood)) input$preview_mood,
      status = if (nzchar(trimws(input$preview_status))) input$preview_status,
      bubble = if (nzchar(trimws(input$preview_bubble))) input$preview_bubble,
      size = if (input$preview_size != 160) as.numeric(input$preview_size),
      placement = if (input$preview_placement != "inline") input$preview_placement,
      theme = if (input$preview_theme && !identical(current$theme$short, defaults$theme)) current$theme[[style()]],
      motion = if (input$preview_motion) TRUE,
      popup_menu = if (input$preview_menu && !identical(menu, defaults$popup_menu)) current$popup_menu[[style()]]
    )
    Filter(Negate(is.null), args)
  })
  output$code_preview <- renderText(format_call("mascot_preview", preview_call()))
  # The first visit to the tab builds a preview; the button builds a new one.
  preview_request <- reactiveVal(0)
  observeEvent(input$preview_build, preview_request(preview_request() + 1))
  observeEvent(input$tabs, {
    if (input$tabs == "preview" && preview_request() == 0) preview_request(1)
  })
  preview <- eventReactive(preview_request(), {
    req(preview_request() > 0)
    args <- preview_call()
    code <- format_call("mascot_preview", args)
    page <- withCallingHandlers(
      tryCatch(eval(as.call(c(as.name("mascot_preview"), args))), error = function(e) e),
      warning = function(w) {
        if (inherits(w, "mascot_contrast")) invokeRestart("muffleWarning")
      }
    )
    if (inherits(page, "error")) {
      add_log(code, "error", cli::ansi_strip(conditionMessage(page)))
      return(list(error = cli::ansi_strip(conditionMessage(page))))
    }
    preview_count(isolate(preview_count()) + 1)
    file <- sprintf("preview-%s-%d.html", session$token, isolate(preview_count()))
    # The preview is its own page: carry the studio's CSS variable over when a part reads it.
    if (grepl("--studio-accent", paste(deparse(args$theme), collapse = ""), fixed = TRUE)) {
      page <- tagList(tags$style(sprintf(":root { --studio-accent: %s; }", input$css_accent)), page)
    }
    htmltools::save_html(page, file.path(preview_dir, file), libdir = "lib")
    list(file = file, contrast = attr(page, "contrast"))
  })
  output$preview_frame <- renderUI({
    if (preview_request() == 0) {
      return(div(class = "pg-hint", "Choose the arguments on the left, then build the preview."))
    }
    result <- preview()
    if (!is.null(result$error)) {
      return(div(class = "pg-note pg-warn", result$error))
    }
    tags$iframe(
      class = paste("pg-preview", if (input$preview_width == "phone") "is-phone"),
      src = paste0("studio-preview/", result$file),
      title = "mascot_preview() page"
    )
  })
  output$preview_open <- renderUI({
    req(preview_request() > 0)
    result <- preview()
    req(result$file)
    tags$a(
      class = "btn btn-sm btn-outline-primary",
      href = paste0("studio-preview/", result$file),
      target = "_blank",
      rel = "noopener",
      "Open in a new tab"
    )
  })
  output$preview_contrast <- renderUI({
    req(preview_request() > 0)
    findings <- preview()$contrast
    if (is.null(findings)) {
      return(NULL)
    }
    if (!nrow(findings)) {
      return(div(class = "pg-note pg-ok", "attr(page, \"contrast\") is empty: no colour below 3:1."))
    }
    findings$ratio <- format(round(findings$ratio, 2), nsmall = 2)
    tagList(div(class = "pg-note pg-warn", "attr(page, \"contrast\") lists colours below 3:1:"), data_table(findings))
  })

  # Examples
  observeEvent(input$example_pick, updateSelectInput(session, "example_name", selected = input$example_pick))
  output$example_result <- renderUI({
    name <- input$example_name
    path <- mascot_example(name, run = FALSE)
    files <- list.files(dirname(path), recursive = TRUE)
    call <- if (input$example_run) {
      code_block(sprintf("mascot::mascot_example(\"%s\")", name), "pg-code", id = "example_call")
    } else {
      code_block(sprintf("mascot_example(\"%s\", run = FALSE)\n#> \"%s\"", name, path), "pg-code", id = "example_call")
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

shinyApp(ui, server)
