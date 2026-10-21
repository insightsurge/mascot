# URL bookmarking: the restored session sets the mascot from the bookmarked note.
ui <- function(request) {
  shiny::fluidPage(
    shiny::textInput("note", "Note", "hello"),
    shiny::bookmarkButton(id = "bookmark"),
    shiny::actionButton("change", "Update"),
    mascot::mascot("helper", placement = "inline", status = "Fresh")
  )
}
server <- function(input, output, session) {
  # A bookmark button with its own id bookmarks only when asked. Buttons stay out of the bookmark,
  # as in most apps: a restored click count would replay their observers.
  shiny::setBookmarkExclude(c("bookmark", "change"))
  shiny::observeEvent(input$bookmark, session$doBookmark())
  shiny::observeEvent(input$change, {
    mascot::update_mascot("helper", mood = "worried", status = paste("Changed", input$change))
  })
  shiny::onBookmarked(function(url) shiny::updateQueryString(url))
  shiny::onRestore(function(state) {
    mascot::update_mascot("helper", mood = "happy", status = paste("Restored", state$input$note))
  })
}
shiny::shinyApp(ui, server, enableBookmarking = "url")
