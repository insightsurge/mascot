# Checking a theme, for every view of the studio app: a folder for built pages, the contrast check and the
# character swap with a palette. Plain R; each view shows the results in its own way.

# A folder for one session's built pages (mascot_preview() pages), served at prefix-<session token> and removed when
# the session ends. Returns the served prefix and the folder.
preview_folder <- function(session, prefix) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(prefix, pattern = "^[a-z][a-z-]*$")
  name <- paste0(prefix, "-", session$token)
  dir <- file.path(tempdir(), name)
  dir.create(dir, showWarnings = FALSE)
  shiny::addResourcePath(name, dir)
  session$onSessionEnded(function() {
    shiny::removeResourcePath(name)
    unlink(dir, recursive = TRUE)
  })
  list(prefix = name, dir = dir)
}

# The contrast table mascot_preview() builds for a character and a theme (attr(page, "contrast")): the colours the
# user supplied that have less than 3:1 contrast against the page. Its warnings are the table's rows, so they are not
# repeated. Returns the table, or the error's message when the theme cannot be drawn.
contrast_check <- function(character, theme = NULL) {
  checkmate::assert_string(character, min.chars = 1)
  page <- tryCatch(
    suppressWarnings(mascot::mascot_preview(character = character, theme = theme)),
    error = function(e) e
  )
  if (inherits(page, "error")) {
    return(list(error = cli::ansi_strip(conditionMessage(page)), findings = NULL))
  }
  list(error = NULL, findings = attr(page, "contrast"))
}

# A contrast_check() result as a note and, when colours are hard to see, a table. css names the roles that read a CSS
# variable (NULL or empty for none): only the browser knows their value, so they are not checked here. chosen says
# whether any colour was chosen in R (light, dark or a bs_theme()); palette colours are never checked.
contrast_result_ui <- function(result, css = character(), chosen = TRUE) {
  checkmate::assert_list(result)
  checkmate::assert_names(names(result), must.include = c("error", "findings"))
  checkmate::assert_character(css, any.missing = FALSE, null.ok = TRUE)
  checkmate::assert_flag(chosen)
  if (!is.null(result$error)) {
    return(shiny::div(class = "pg-note pg-warn", "The check failed: ", result$error))
  }
  css_note <- if (length(css)) {
    shiny::div(
      class = "pg-note",
      "Parts tied to a CSS variable (",
      paste(css, collapse = ", "),
      ") are not checked here: only the browser knows their value. It warns in its console."
    )
  }
  findings <- result$findings
  if (!nrow(findings)) {
    return(shiny::tagList(
      if (chosen) {
        shiny::div(
          class = "pg-note pg-ok",
          "Every colour you chose in R has at least 3:1 contrast against the page, in light and dark mode."
        )
      } else {
        shiny::div(
          class = "pg-note",
          "No colour of your own was chosen in R, so nothing was checked here. Palette colours are not checked."
        )
      },
      css_note
    ))
  }
  findings$ratio <- format(round(findings$ratio, 2), nsmall = 2)
  shiny::tagList(
    shiny::div(class = "pg-note pg-warn", "These colours are hard to see on the page background. They are kept."),
    css_note,
    # The studio's table layout (data_table() in ui.R), with a swatch beside each colour.
    shiny::tags$table(
      class = "table table-sm pg-table",
      shiny::tags$thead(shiny::tags$tr(lapply(names(findings), shiny::tags$th))),
      shiny::tags$tbody(lapply(seq_len(nrow(findings)), function(i) {
        shiny::tags$tr(lapply(names(findings), function(column) {
          value <- findings[[column]][[i]]
          shiny::tags$td(
            if (column == "colour") {
              shiny::tagList(
                shiny::tags$span(class = "pg-swatch", style = paste0("background:", value)),
                shiny::tags$code(value)
              )
            } else {
              value
            }
          )
        }))
      }))
    )
  )
}

# The note shown when the settings changed after the last contrast check.
contrast_stale_ui <- function() {
  shiny::div(class = "pg-note", "The settings changed since the last check. Check contrast again.")
}

# A character swap as an app would make it: the mascot shows `from` in `palette`, then becomes `to`. Both calls run
# through run_real_call() in envir; the result is the swap's, with the two calls as code and step = "swap". When the
# first call fails or is left unchanged (ok is FALSE), the swap is not run: the result is the first call's, with
# step = "setup". The package keeps the palette when `to` has one of that name, and otherwise warns
# (mascot_palette_dropped) and uses its own colours.
palette_swap_run <- function(id, from, to, palette, envir) {
  checkmate::assert_string(id, min.chars = 1)
  checkmate::assert_string(from, min.chars = 1)
  checkmate::assert_string(to, min.chars = 1)
  checkmate::assert_string(palette, min.chars = 1)
  checkmate::assert_environment(envir)
  first <- call("update_mascot", id, character = from, theme = palette, motion = FALSE)
  swap <- call("update_mascot", id, character = to)
  setup <- run_real_call(first, envir)
  if (!setup$ok) {
    setup$code <- deparse1(first)
    setup$step <- "setup"
    return(setup)
  }
  result <- run_real_call(swap, envir)
  result$code <- paste(deparse1(first), deparse1(swap), sep = "\n")
  result$step <- "swap"
  result
}
