# Page parts that every view of the studio app shares: the sentence bar ("Showing <character> in an idle mood.") and the
# window frame around a preview. Their styles are in www/shared.css; www/inputs.js places the words' tooltips.

# The sentence bar: a toolbar whose first part reads as a sentence, its selects drawn as underlined words, followed by
# the page's other controls (...). label names the toolbar and sentence_label the sentence for screen readers.
sentence_bar <- function(id, label, sentence_label, sentence, ...) {
  checkmate::assert_string(id, min.chars = 1)
  checkmate::assert_string(label, min.chars = 1)
  checkmate::assert_string(sentence_label, min.chars = 1)
  checkmate::assert_list(sentence)
  shiny::div(
    id = id,
    class = "pg-toolbar pg-float",
    role = "toolbar",
    `aria-label` = label,
    do.call(shiny::div, c(list(class = "pg-sentence", role = "group", `aria-label` = sentence_label), sentence)),
    ...
  )
}

# Makes the sentence bar's selects words: each select named in tooltips gets an accessible name (its id in title
# case), a wrapper and a tooltip (the tooltip's content, by id), which describes it.
sentence_words <- function(bar, tooltips) {
  checkmate::assert_class(bar, "shiny.tag")
  checkmate::assert_list(tooltips, names = "unique", min.len = 1)
  ids <- names(tooltips)
  for (id in ids) {
    bar <- htmltools::tagQuery(bar)$find(paste0("#", id))$addAttrs(`aria-label` = tools::toTitleCase(id))$allTags()
  }
  for (id in ids) {
    bar <- htmltools::tagQuery(bar)$find(paste0("#", id))$parent()$addClass("pg-sentence-word")$append(
      shiny::tags$span(id = paste0(id, "_tooltip"), class = "pg-word-tooltip", role = "tooltip", tooltips[[id]])
    )$allTags()
    bar <- htmltools::tagQuery(bar)$find(paste0("#", id))$addAttrs(
      `aria-describedby` = paste0(id, "_tooltip")
    )$allTags()
  }
  bar
}

# The top of a window frame around a preview: three window dots, a title, then anything else (...).
window_bar <- function(title, ...) {
  checkmate::assert_string(title, min.chars = 1)
  shiny::div(
    class = "pg-host-bar",
    shiny::tags$span(
      class = "pg-window-dots",
      `aria-hidden` = "true",
      shiny::tags$i(class = "pg-light-red"),
      shiny::tags$i(class = "pg-light-yellow"),
      shiny::tags$i(class = "pg-light-green")
    ),
    shiny::tags$span(title),
    ...
  )
}

# The foot of a window frame: a caption line.
window_footer <- function(...) {
  shiny::div(class = "pg-host-footer", ...)
}
