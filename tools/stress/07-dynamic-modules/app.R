# Cards added and removed at run time, each a module with its own mascot and a fresh id.
card_ui <- function(id) {
  checkmate::assert_string(id)
  shiny::div(id = id, mascot::mascot(shiny::NS(id)("helper"), placement = "inline", status = id))
}
card_server <- function(id, round) {
  checkmate::assert_string(id)
  checkmate::assert_class(round, "reactive")
  shiny::moduleServer(id, function(input, output, session) {
    # Sent in the same flush as the card's UI, so it waits until the mascot appears.
    mascot::update_mascot("helper", mood = "happy", status = paste(id, "ready"))
    shiny::observeEvent(
      round(),
      mascot::update_mascot("helper", mood = "thinking", status = paste(id, "round", round())),
      ignoreInit = TRUE
    )
  })
}
ui <- shiny::fluidPage(
  shiny::actionButton("add", "Add 10 cards"),
  shiny::actionButton("remove", "Remove the 5 oldest"),
  shiny::actionButton("everyone", "Update every card"),
  shiny::div(id = "cards")
)
server <- function(input, output, session) {
  created <- shiny::reactiveVal(0)
  live <- shiny::reactiveVal(character())
  round <- shiny::reactive(input$everyone)
  shiny::observeEvent(input$add, {
    first <- created() + 1
    ids <- paste0("card", seq(first, first + 9))
    for (id in ids) {
      shiny::insertUI("#cards", where = "beforeEnd", ui = card_ui(id))
      card_server(id, round)
    }
    created(first + 9)
    live(c(live(), ids))
  })
  shiny::observeEvent(input$remove, {
    gone <- utils::head(live(), 5)
    for (id in gone) {
      shiny::removeUI(paste0("#", id), immediate = TRUE)
    }
    live(setdiff(live(), gone))
  })
  shiny::exportTestValues(
    records = length(ls(session$userData$mascot_protocol$states)),
    live = length(live()),
    created = created()
  )
}
shiny::shinyApp(ui, server)
