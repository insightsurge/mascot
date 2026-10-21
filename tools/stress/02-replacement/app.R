# Motion stays on (the default) so replacements and swaps happen while the mascot animates.
ui <- shiny::fluidPage(
  shiny::actionButton("replace", "Re-render"),
  shiny::actionButton("remove", "Remove"),
  shiny::actionButton("insert", "Insert"),
  shiny::actionButton("duplicate", "Duplicate"),
  shiny::actionButton("change", "Update"),
  shiny::actionButton("rich", "Swap, bubble and nod"),
  shiny::actionButton("replace_float", "Re-render floating"),
  shiny::actionButton("change_float", "Update floating"),
  shiny::actionButton("remove_float", "Remove floating"),
  shiny::uiOutput("slot"),
  shiny::div(id = "extra"),
  shiny::uiOutput("float_slot"),
  mascot::mascot("other", placement = "inline", status = "Untouched")
)
server <- function(input, output, session) {
  output$slot <- shiny::renderUI({
    input$replace
    mascot::mascot("same", placement = "inline", status = "Baseline")
  })
  output$float_slot <- shiny::renderUI({
    input$replace_float
    mascot::mascot("floater", status = "Floating")
  })
  shiny::observeEvent(input$remove, shiny::removeUI("[id='same']", multiple = TRUE, immediate = TRUE))
  shiny::observeEvent(input$insert, {
    shiny::insertUI("#extra", ui = mascot::mascot("same", placement = "inline"))
  })
  shiny::observeEvent(input$duplicate, {
    shiny::insertUI("#extra", ui = mascot::mascot("same", placement = "inline"))
  })
  shiny::observeEvent(input$change, {
    mascot::update_mascot("same", mood = "happy", status = paste("Update", input$change))
  })
  shiny::observeEvent(input$rich, {
    mascot::update_mascot(
      "same",
      character = "sela",
      mood = "celebrating",
      status = "Rich",
      bubble = mascot::mascot_bubble("Saved", duration = Inf),
      gesture = "nod"
    )
  })
  shiny::observeEvent(input$change_float, {
    mascot::update_mascot("floater", mood = "thinking", status = paste("Float", input$change_float))
  })
  shiny::observeEvent(input$remove_float, shiny::removeUI("#float_slot", immediate = TRUE))
}
shiny::shinyApp(ui, server)
