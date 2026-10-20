ui <- bslib::page_sidebar(
  sidebar = bslib::sidebar(id = "side", "Sidebar"),
  shiny::actionButton("chaos", "Mutate page"),
  shiny::actionButton("modal", "Open modal"),
  shiny::actionButton("progress", "Progress"),
  shiny::actionButton("change", "Update"),
  shiny::tags$input(id = "custom", class = "stress-input", value = "0"),
  shiny::div(id = "noise", shiny::span("Mutable content")),
  shiny::div(id = "moved"),
  shiny::div(id = "fixed", "Fixed overlay"),
  shiny::tags$style("#fixed {position:fixed;bottom:0;right:0;width:240px;height:260px;z-index:999999;}"),
  mascot::mascot("helper", motion = FALSE, status = "Ready", click = mascot::mascot_popup_menu(c(about = "About"))),
  shiny::tags$script(src = "chaos.js")
)
server <- function(input, output, session) {
  shiny::observeEvent(input$chaos, {
    shiny::showNotification("Notification overlay", duration = NULL)
    bslib::toggle_sidebar("side")
  })
  shiny::observeEvent(input$modal, shiny::showModal(shiny::modalDialog("Modal overlay")))
  shiny::observeEvent(input$progress, {
    shiny::withProgress(message = "Working", {
      mascot::update_mascot("helper", mood = "thinking", status = "Progress")
      shiny::incProgress(1)
    })
  })
  shiny::observeEvent(input$change, {
    mascot::update_mascot("helper", mood = "happy", status = paste("Update", input$change))
  })
}
shiny::shinyApp(ui, server)
