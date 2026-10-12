# The tests run a function-built UI, two nested modules and a late dependency.
review_ui <- function(id, dynamic = FALSE) {
  ns <- shiny::NS(id)
  htmltools::tagList(
    shiny::actionButton(ns("go"), "Complete"),
    shiny::actionButton(ns("move"), "Move and stop motion"),
    if (dynamic) shiny::actionButton(ns("rebuild"), "Rebuild helper"),
    if (dynamic) {
      shiny::uiOutput(ns("late"))
    } else {
      mascot::mascot(
        ns("helper"),
        size = 80,
        placement = mascot::mascot_placement("bottom-right", drag = "snap"),
        click = mascot::mascot_popup_menu(c(about = "About"))
      )
    },
    shiny::textOutput(ns("events"))
  )
}
review_server <- function(id, dynamic = FALSE, prefixed = FALSE) {
  shiny::moduleServer(id, function(input, output, session) {
    target <- if (prefixed) session$ns("helper") else "helper"
    if (dynamic) {
      generation <- shiny::reactiveVal(1L)
      shiny::observeEvent(input$rebuild, generation(generation() + 1L))
      output$late <- shiny::renderUI(htmltools::tagAppendAttributes(
        mascot::mascot(
          session$ns("helper"),
          size = 80,
          placement = mascot::mascot_placement("bottom-left", drag = "free"),
          motion = mascot::mascot_motion_settings(idle = FALSE),
          click = mascot::mascot_popup_menu(c(about = "About"))
        ),
        `data-generation` = generation()
      ))
      shiny::outputOptions(output, "late", suspendWhenHidden = FALSE)
    }
    shiny::observeEvent(input$go, mascot::update_mascot(target, mood = "happy", status = "Complete"))
    shiny::observeEvent(
      input$move,
      mascot::update_mascot(
        target,
        placement = mascot::mascot_placement("top-right", drag = "free"),
        motion = FALSE
      )
    )
    output$events <- shiny::renderText(jsonlite::toJSON(
      list(
        menu = input$helper_menu,
        click = input$helper_click,
        position = input$helper_position,
        minimised = input$helper_minimised
      ),
      auto_unbox = TRUE,
      null = "null"
    ))
    shiny::outputOptions(output, "events", suspendWhenHidden = FALSE)
  })
}
section_ui <- function(id, dynamic = FALSE) review_ui(shiny::NS(id)("review"), dynamic)
section_server <- function(id, dynamic = FALSE, prefixed = FALSE) {
  shiny::moduleServer(id, function(input, output, session) {
    review_server("review", dynamic, prefixed)
  })
}
app_ui <- function(request) {
  bslib::page_fluid(
    shiny::actionButton("hidden_update", "Update second review"),
    bslib::navset_tab(
      id = "tabs",
      bslib::nav_panel("First", section_ui("first")),
      bslib::nav_panel("Second", section_ui("second", dynamic = TRUE))
    )
  )
}
app_server <- function(input, output, session) {
  section_server("first", prefixed = TRUE)
  section_server("second", dynamic = TRUE)
  # Exercise an update while the second tab is hidden.
  shiny::observeEvent(input$hidden_update, {
    mascot::update_mascot("second-review-helper", mood = "thinking")
  })
}
shiny::shinyApp(app_ui, app_server)
