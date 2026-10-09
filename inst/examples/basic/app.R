# Open with mascot_example("basic"). Source this file to read/run the same app.
# Standalone app: attach the package as a user would.
library(mascot) # nolint: undesirable_function_linter.
# Share presentation while keeping the scenario code here.
# nolint start: undesirable_function_linter.
source(
  system.file("examples", "shared", "shell.R", package = "mascot"),
  local = TRUE
)
# nolint end

# Each setting accepts a shortcut or its mascot_* helper.
ui <- shiny::tagList(shiny::tags$div(
  class = "example-grid",
  shiny::tags$section(
    class = "example-panel",
    shiny::tags$h2("Tell the helper what changed"),
    shiny::tags$div(
      class = "example-buttons",
      lapply(mascot_moods()$name, function(mood) {
        shiny::actionButton(paste0("mood_", mood), tools::toTitleCase(mood))
      })
    ),
    shiny::textInput("status", "Your status text", "Ready to review"),
    shiny::actionButton("set_status", "Use this status"),
    shiny::actionButton("clear_status", "Follow the mood again"),
    shiny::textInput("message", "Bubble text", "Three rows need a second look."),
    shiny::checkboxInput("keep", "Keep the bubble until closed", FALSE),
    shiny::actionButton("show_bubble", "Show bubble"),
    shiny::actionButton("clear_bubble", "Clear bubble"),
    shiny::selectInput("gesture", "One-off gesture", mascot_gestures()$name),
    shiny::actionButton("play_gesture", "Play gesture"),
    shiny::tags$details(
      shiny::tags$summary("Size, placement and motion"),
      shiny::sliderInput("size", "Size in pixels", min = 48, max = 240, value = 160),
      shiny::checkboxInput("floating", "Float in the bottom-right corner", FALSE),
      shiny::checkboxInput("animate", "Allow animation", TRUE),
      shiny::actionButton("reset", "Reset helper settings")
    )
  ),
  shiny::tags$section(
    class = "example-panel example-stage",
    shiny::tags$h2("Your helper"),
    mascot(character = mascot_character("tessa"), id = "helper"),
    shiny::tags$p(class = "example-note", "Status stays readable when movement is off.")
  )
))

server <- function(input, output, session) {
  lapply(mascot_moods()$name, function(mood) {
    shiny::observeEvent(input[[paste0("mood_", mood)]], {
      updateMascot("helper", mood = mascot_mood(mood))
    })
  })
  shiny::observeEvent(input$set_status, {
    shiny::req(nzchar(trimws(input$status)))
    updateMascot("helper", status = mascot_status(input$status))
  })
  shiny::observeEvent(input$clear_status, updateMascot("helper", status = mascot_status()))
  shiny::observeEvent(input$show_bubble, {
    shiny::req(nzchar(trimws(input$message)))
    updateMascot("helper", bubble = mascot_bubble(input$message, duration = if (input$keep) Inf else 5))
  })
  shiny::observeEvent(input$clear_bubble, updateMascot("helper", bubble = mascot_bubble()))
  shiny::observeEvent(input$play_gesture, updateMascot("helper", gesture = mascot_gesture(input$gesture)))
  shiny::observeEvent(input$size, updateMascot("helper", size = mascot_size(input$size, small_screen = 72)))
  shiny::observeEvent(input$floating, {
    placement <- if (input$floating) {
      mascot_placement(floating = TRUE, position = "bottom-right", minimise = TRUE)
    } else {
      mascot_placement()
    }
    updateMascot("helper", placement = placement)
  })
  shiny::observeEvent(input$animate, updateMascot("helper", motion = mascot_motion(animate = input$animate)))
  shiny::observeEvent(input$reset, {
    shiny::updateSliderInput(session, "size", value = 160)
    shiny::updateCheckboxInput(session, "floating", value = FALSE)
    shiny::updateCheckboxInput(session, "animate", value = TRUE)
    updateMascot(
      "helper",
      mood = "idle",
      status = mascot_status(),
      bubble = mascot_bubble(),
      theme = mascot_theme(),
      motion = mascot_motion(),
      placement = mascot_placement()
    )
  })
}

example_app("Meet your helper", "Change a mascot with ordinary Shiny inputs, one setting at a time.", ui, server)
