library(shiny)
if (!requireNamespace("bslib", quietly = TRUE)) {
  stop("This example needs bslib. Install it before running the app.")
}
library(bslib)
library(mascot)

brand <- bslib::bs_theme(version = 5, primary = "#1f6feb", secondary = "#966600")
# Full control: choose different leaders per mode; followers fill automatically.
rose <- mascot_theme(
  light = list(body = "#B53D78", rim = "#A94A82"),
  dark = list(body = "#F2A6CF", rim = "#C5B0EB")
)
ui <- bslib::page_fluid(
  theme = brand,
  shiny::h1("Personalise Tessa"),
  bslib::input_dark_mode(id = "dark_mode"),
  bslib::layout_columns(
    bslib::card(
      shiny::h2("Your colours and words"),
      shiny::radioButtons("palette", "Mascot colours", c("App brand" = "brand", "Pink and lilac" = "rose")),
      shiny::textInput("status", "Status text", "Ready for your team's review"),
      shiny::textInput("message", "Bubble text", "I can help you find the next step."),
      shiny::actionButton("personalise", "Use my words"),
      shiny::actionButton("celebrate", "Celebrate a finished review"),
      shiny::actionButton("original", "Use Tessa's own colours"),
      shiny::actionButton("brand", "Use selected colours")
    ),
    bslib::card(
      shiny::h2("Personalise Tessa"),
      mascot(
        id = "helper",
        theme = brand,
        status = "Ready for your team's review",
        popup_menu = c(finish = "Finish review", reset = "Reset helper", about = "About this example")
      ),
      shiny::p("The page switch controls the mascot's mode. Enter or Space opens its menu.")
    )
  )
)
server <- function(input, output, session) {
  shiny::observeEvent(
    input$palette,
    {
      updateMascot("helper", theme = if (input$palette == "rose") rose else brand)
    },
    ignoreInit = TRUE
  )
  shiny::observeEvent(input$personalise, {
    shiny::req(nzchar(trimws(input$status)), nzchar(trimws(input$message)))
    updateMascot("helper", status = mascot_status(input$status), bubble = mascot_bubble(input$message, Inf))
  })
  shiny::observeEvent(input$celebrate, updateMascot("helper", mood = "celebrating", status = "Review complete"))
  shiny::observeEvent(input$original, updateMascot("helper", theme = mascot_theme()))
  shiny::observeEvent(input$brand, {
    updateMascot("helper", theme = if (input$palette == "rose") rose else brand)
  })
  shiny::observeEvent(input$helper_menu, {
    if (input$helper_menu == "finish") {
      updateMascot(
        "helper",
        mood = "happy",
        status = "Review complete",
        bubble = mascot_bubble("All checks finished.", Inf),
        gesture = mascot_gesture("nod")
      )
    }
    if (input$helper_menu == "reset") {
      updateMascot("helper", mood = "idle", status = "Ready for your team's review", bubble = mascot_bubble())
    }
    if (input$helper_menu == "about") {
      shiny::showModal(shiny::modalDialog(
        title = "About this example",
        "Your app owns the menu action. Tessa supplies the entry point.",
        easyClose = TRUE
      ))
    }
  })
}
shiny::shinyApp(ui, server)
