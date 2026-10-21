# A bslib page switched between light and dark from the server, as a dark-mode toggle does.
ui <- bslib::page_fillable(
  bslib::input_dark_mode(id = "mode", mode = "light"),
  shiny::actionButton("dark", "Dark"),
  shiny::actionButton("light", "Light"),
  shiny::actionButton("change", "Update"),
  mascot::mascot(
    "follows",
    placement = "inline",
    status = "Follows the page",
    # Built-in characters have one colour set; light and dark body colours make the switch visible.
    theme = mascot::mascot_theme(light = list(body = "#F2C14E"), dark = list(body = "#3A6EA5"))
  ),
  mascot::mascot("fixed", placement = "inline", status = "Always light", theme = mascot::mascot_theme(mode = "light"))
)
server <- function(input, output, session) {
  shiny::observeEvent(input$dark, bslib::toggle_dark_mode("dark"))
  shiny::observeEvent(input$light, bslib::toggle_dark_mode("light"))
  shiny::observeEvent(input$change, {
    mascot::update_mascot("follows", mood = "happy", status = paste("Update", input$change))
  })
}
shiny::shinyApp(ui, server)
