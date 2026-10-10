library(shiny)
if (!requireNamespace("bslib", quietly = TRUE)) {
  stop("This example needs bslib. Install it before running the app.")
}
library(bslib)
library(mascot)

ui <- page_fluid(
  title = "Meet your helper",
  input_dark_mode(id = "dark_mode", mode = "light"),
  h1("Meet your helper"),
  p("Change a mascot with ordinary Shiny inputs, one setting at a time."),
  layout_columns(
    card(
      h2("Tell the helper what changed"),
      lapply(mascot_moods()$name, function(mood) {
        actionButton(paste0("mood_", mood), tools::toTitleCase(mood))
      }),
      textInput("status", "Your status text", "Ready to review"),
      actionButton("set_status", "Use this status"),
      actionButton("clear_status", "Follow the mood again"),
      textInput("message", "Bubble text", "Three rows need a second look."),
      checkboxInput("keep", "Keep the bubble until closed", FALSE),
      actionButton("show_bubble", "Show bubble"),
      actionButton("clear_bubble", "Clear bubble"),
      selectInput("gesture", "One-off gesture", mascot_gestures()$name),
      actionButton("play_gesture", "Play gesture"),
      tags$details(
        tags$summary("Size, placement and motion"),
        sliderInput("size", "Size in pixels", min = 48, max = 240, value = 160),
        checkboxInput("floating", "Float in the bottom-right corner", FALSE),
        checkboxInput("animate", "Allow animation", TRUE),
        actionButton("reset", "Reset helper settings")
      )
    ),
    card(
      h2("Your helper"),
      mascot(id = "helper", placement = "inline"),
      p("Status stays readable when movement is off.")
    )
  )
)

server <- function(input, output, session) {
  lapply(mascot_moods()$name, function(mood) {
    observeEvent(input[[paste0("mood_", mood)]], updateMascot("helper", mood = mood))
  })
  observeEvent(input$set_status, {
    req(nzchar(trimws(input$status)))
    updateMascot("helper", status = input$status)
  })
  observeEvent(input$clear_status, updateMascot("helper", status = mascot_status()))
  observeEvent(input$show_bubble, {
    req(nzchar(trimws(input$message)))
    updateMascot("helper", bubble = mascot_bubble(input$message, duration = if (input$keep) Inf else 5))
  })
  observeEvent(input$clear_bubble, updateMascot("helper", bubble = mascot_bubble()))
  observeEvent(input$play_gesture, updateMascot("helper", gesture = input$gesture))
  # ignoreInit: the mascot already starts with these settings.
  observeEvent(input$size, updateMascot("helper", size = mascot_size(input$size, small_screen = 72)), ignoreInit = TRUE)
  observeEvent(
    input$floating,
    {
      updateMascot(
        "helper",
        placement = mascot_placement(if (input$floating) "bottom-right" else "inline", minimise = input$floating)
      )
    },
    ignoreInit = TRUE
  )
  observeEvent(input$animate, updateMascot("helper", motion = input$animate), ignoreInit = TRUE)
  observeEvent(input$reset, {
    updateSliderInput(session, "size", value = 160)
    updateCheckboxInput(session, "floating", value = FALSE)
    updateCheckboxInput(session, "animate", value = TRUE)
    updateMascot(
      "helper",
      mood = "idle",
      status = mascot_status(),
      bubble = mascot_bubble(),
      theme = mascot_theme(),
      motion = mascot_motion(),
      placement = mascot_placement("inline")
    )
  })
}

shinyApp(ui, server)
