# The app's views: one per ?view= value and per mascot_studio(view =) choice, with the title of its page.
# mascot_studio() reads the names from this vector, so a new view is added here first.
studio_view_titles <- c(studio = "mascot studio", examples = "mascot studio", theme = "Theme a mascot")

# Each view has a ui(query), which builds its page from the parsed query string, and a server(input, output,
# session). The studio and examples views share the studio's page and server, which app.R defines and passes in:
# files in R/ cannot see the functions app.R defines. Every other view keeps its parts in R/ files, and its session
# starts none of the studio's observers.
studio_views <- function(studio_ui, studio_server) {
  checkmate::assert_function(studio_ui, args = c("query", "view"))
  checkmate::assert_function(studio_server, args = c("input", "output", "session"))
  views <- list(
    studio = list(ui = function(query) studio_ui(query, "studio"), server = studio_server),
    examples = list(ui = function(query) studio_ui(query, "examples"), server = studio_server),
    theme = list(ui = theme_view_ui, server = theme_view_server)
  )
  stopifnot(identical(names(views), names(studio_view_titles)))
  for (view in names(views)) {
    views[[view]]$title <- studio_view_titles[[view]]
  }
  views
}

# The view a session serves: the address bar's ?view= when it names a view, else the view the page was built for
# (mascot_studio(view =) chooses it in the page request, which the address bar does not show), else the studio.
view_from_client <- function(search, routed = NULL) {
  checkmate::assert_string(search, null.ok = TRUE)
  checkmate::assert_string(routed, null.ok = TRUE)
  query <- shiny::parseQueryString(if (is.null(search)) "" else search)
  for (view in list(query$view, routed)) {
    if (isTRUE(view %in% names(studio_view_titles))) {
      return(view)
    }
  }
  "studio"
}

# The character named by ?character=, when the studio offers it.
view_character <- function(query) {
  checkmate::assert_list(query)
  if (isTRUE(query$character %in% unname(studio_characters()))) query$character else defaults$character
}

# The theme view's page and server are in theme-ui.R and theme-server.R.
