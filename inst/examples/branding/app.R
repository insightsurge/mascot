library(shiny)
if (!requireNamespace("bslib", quietly = TRUE)) {
  stop("This example needs bslib. Install it before running the app.")
}
library(bslib)
library(mascot)

brand <- bs_theme(version = 5, primary = "#1f6feb", secondary = "#966600")
# Full control: choose different leaders per mode; followers fill automatically.
rose <- mascot_theme(
  light = list(body = "#B53D78", rim = "#A94A82"),
  dark = list(body = "#F2A6CF", rim = "#C5B0EB")
)
ui <- page_fluid(
  theme = brand,
  input_dark_mode(id = "dark_mode", mode = "light"),
  h1("Personalise Tessa"),
  p("Brand colours, your own words and a click menu; the page switch changes light and dark."),
  layout_columns(
    card(
      h2("Your colours and words"),
      radioButtons("palette", "Mascot colours", c("App brand" = "brand", "Pink and lilac" = "rose")),
      textInput("status", "Status text", "Ready for your team's review"),
      textInput("message", "Bubble text", "I can help you find the next step."),
      actionButton("personalise", "Use my words"),
      actionButton("celebrate", "Celebrate a finished review"),
      actionButton("original", "Use Tessa's own colours"),
      actionButton("brand", "Use selected colours")
    ),
    card(
      h2("Personalise Tessa"),
      mascot(
        id = "helper",
        theme = brand,
        status = "Ready for your team's review",
        placement = "inline",
        click = mascot_popup_menu(c(finish = "Finish review", reset = "Reset helper", about = "About this example"))
      ),
      p("The page switch controls the mascot's mode. Enter or Space opens its menu.")
    )
  )
)
server <- function(input, output, session) {
  observeEvent(
    input$palette,
    {
      update_mascot("helper", theme = if (input$palette == "rose") rose else brand)
    },
    ignoreInit = TRUE
  )
  observeEvent(input$personalise, {
    req(nzchar(trimws(input$status)), nzchar(trimws(input$message)))
    update_mascot("helper", status = mascot_status(input$status), bubble = mascot_bubble(input$message, duration = Inf))
  })
  observeEvent(input$celebrate, update_mascot("helper", mood = "celebrating", status = "Review complete"))
  observeEvent(input$original, update_mascot("helper", theme = mascot_theme()))
  observeEvent(input$brand, {
    update_mascot("helper", theme = if (input$palette == "rose") rose else brand)
  })
  observeEvent(input$helper_menu, {
    if (input$helper_menu == "finish") {
      update_mascot(
        "helper",
        mood = "happy",
        status = "Review complete",
        bubble = mascot_bubble("All checks finished.", duration = Inf),
        gesture = mascot_gesture("nod")
      )
    }
    if (input$helper_menu == "reset") {
      update_mascot("helper", mood = "idle", status = "Ready for your team's review", bubble = mascot_bubble())
    }
    if (input$helper_menu == "about") {
      showModal(modalDialog(
        title = "About this example",
        "Your app owns the menu action. Tessa supplies the entry point.",
        easyClose = TRUE
      ))
    }
  })
}
shinyApp(ui, server)
