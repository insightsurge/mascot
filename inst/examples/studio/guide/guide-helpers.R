# Helpers shared by the guide pages (guide/*.Rmd). The studio and the package website both knit those
# pages, so everything here works with plain R and htmltools: no Shiny and no studio functions.
# Set `guide_dir` to the folder that holds this file and guide.css before sourcing it (the studio and the
# website stubs do); `guide_dependency()` ships guide.css with every diagram, so a site styles them itself.

# FALSE on the website; the studio replaces it with a function that returns TRUE, so the pages can
# guard live demos (buttons, mounted mascots) that need a running Shiny app.
in_studio <- function() FALSE

if (!exists("guide_dir")) {
  # Without a `guide_dir`, this file's own folder: the working directory when it is there, else the installed one.
  guide_dir <- if (file.exists("guide-helpers.R")) {
    "."
  } else {
    system.file("examples", "studio", "guide", package = "mascot")
  }
}

# The calls and messages of the "common mistakes" sections (also loaded by the studio's R/data.R).
if (!exists("guide_mistake_cases")) {
  sys.source(file.path(guide_dir, "guide-mistakes.R"), envir = environment())
}
# Small functions the studio and the pages both use (also loaded by the studio's R/data.R).
if (!exists("guide_brand_roles")) {
  sys.source(file.path(guide_dir, "guide-shared.R"), envir = environment())
}

# The stylesheet of the diagrams below. Bump the version when guide.css changes.
guide_dependency <- function(dir = guide_dir) {
  checkmate::assert_directory_exists(dir)
  checkmate::assert_file_exists(file.path(dir, "guide.css"))
  htmltools::htmlDependency(
    name = "mascot-guide",
    version = "1.3.0",
    src = c(file = normalizePath(dir)),
    stylesheet = "guide.css",
    all_files = FALSE
  )
}

# One box of a flow; put text, `code` or a div with a second line inside.
guide_step <- function(...) {
  htmltools::div(class = "pg-flow-step", ...)
}

# A line break inside a flow: no arrow is drawn across it.
guide_gap <- function() {
  htmltools::div(class = "pg-flow-gap")
}

# Steps with an arrow between each two neighbours (not across a gap).
guide_flow <- function(..., arrow = "\u2192") {
  checkmate::assert_string(arrow, min.chars = 1)
  items <- list(...)
  is_step <- vapply(items, function(item) identical(item$attribs$class, "pg-flow-step"), logical(1))
  parts <- list()
  for (i in seq_along(items)) {
    parts <- c(parts, list(items[[i]]))
    if (is_step[[i]] && i < length(items) && is_step[[i + 1L]]) {
      parts <- c(parts, list(htmltools::div(class = "pg-flow-arrow", arrow)))
    }
  }
  htmltools::attachDependencies(htmltools::div(class = "pg-flow", parts), guide_dependency())
}

# A highlighted note. `warn = TRUE` is the amber version for things that can go wrong.
guide_callout <- function(..., warn = FALSE) {
  checkmate::assert_flag(warn)
  htmltools::attachDependencies(
    htmltools::div(class = paste(c("pg-callout", if (warn) "pg-callout-warn"), collapse = " "), ...),
    guide_dependency()
  )
}

# A bar with one label under it per argument, spread across the width (the fill is drawn to 60%).
guide_timeline <- function(...) {
  labels <- list(...)
  htmltools::attachDependencies(
    htmltools::div(
      class = "pg-timeline",
      htmltools::div(class = "pg-timeline-bar", htmltools::div(class = "pg-timeline-fill")),
      htmltools::div(class = "pg-timeline-labels", lapply(labels, htmltools::tags$span))
    ),
    guide_dependency()
  )
}

# A data frame as a small table; `wrap` is a class for a scrolling wrapper around it (or NULL).
guide_table <- function(df, wrap = NULL) {
  checkmate::assert_data_frame(df)
  checkmate::assert_string(wrap, min.chars = 1, null.ok = TRUE)
  table <- htmltools::tags$table(
    class = "table table-sm pg-table",
    htmltools::tags$thead(htmltools::tags$tr(lapply(names(df), htmltools::tags$th))),
    htmltools::tags$tbody(lapply(seq_len(nrow(df)), function(i) {
      htmltools::tags$tr(lapply(names(df), function(column) htmltools::tags$td(as.character(df[[column]][i]))))
    }))
  )
  htmltools::attachDependencies(if (is.null(wrap)) table else htmltools::div(class = wrap, table), guide_dependency())
}

# Gesture cards use the same classes as the studio, without requiring bslib on a website.
guide_gesture_cards <- function(gestures) {
  checkmate::assert_data_frame(gestures)
  checkmate::assert_subset(c("name", "description"), names(gestures))
  htmltools::attachDependencies(
    htmltools::div(
      class = "pg-cards",
      lapply(seq_len(nrow(gestures)), function(i) {
        htmltools::div(
          class = "card bslib-card pg-card-mini",
          htmltools::div(
            class = "card-body bslib-gap-spacing html-fill-item html-fill-container",
            htmltools::div(class = "pg-card-title", tools::toTitleCase(gestures$name[i])),
            htmltools::div(class = "pg-muted", gestures$description[i]),
            htmltools::div(class = "pg-card-foot", htmltools::tags$code(sprintf('gesture = "%s"', gestures$name[i])))
          )
        )
      })
    ),
    guide_dependency()
  )
}

# Static placement overview, with the package's default corner emphasised.
guide_placement_map <- function() {
  corners <- c("top-left", "top-right", "bottom-left", "bottom-right")
  default <- formals(mascot::mascot_placement)$position
  htmltools::attachDependencies(
    htmltools::div(
      class = "pg-map",
      htmltools::div(class = "pg-map-bar"),
      htmltools::div(
        class = "pg-map-page",
        htmltools::div(class = "pg-map-line"),
        htmltools::tags$span(class = "pg-map-inline", "inline"),
        htmltools::div(class = "pg-map-line short"),
        htmltools::div(class = "pg-map-line")
      ),
      lapply(corners, function(corner) {
        htmltools::tags$span(
          class = paste("pg-map-corner", paste0("pg-", corner), if (identical(corner, default)) "is-active"),
          corner
        )
      })
    ),
    guide_dependency()
  )
}

# Same columns as the live roles table; the website points to the outline tip without a studio link.
guide_roles_table <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  roles <- mascot::mascot_colour_roles(character)
  htmltools::attachDependencies(
    htmltools::tagList(
      htmltools::tags$pre(htmltools::tags$code(sprintf('mascot_colour_roles("%s")', character))),
      htmltools::tags$table(
        class = "table table-sm pg-table",
        htmltools::tags$thead(htmltools::tags$tr(lapply(names(roles), htmltools::tags$th))),
        htmltools::tags$tbody(lapply(seq_len(nrow(roles)), function(i) {
          htmltools::tags$tr(lapply(names(roles), function(column) {
            value <- roles[[column]][i]
            cell <- if (column == "colour") {
              htmltools::tagList(
                htmltools::tags$span(class = "pg-swatch", style = paste0("background:", value)),
                htmltools::tags$code(value)
              )
            } else if (column == "follows") {
              if (is.na(value)) htmltools::tags$span(class = "pg-muted", "leader") else paste("\u2190", value)
            } else if (column == "shade" && is.na(value)) {
              ""
            } else if (column == "description" && roles$role[i] == "outline") {
              paste(value, "See the dark-mode outline tip on the mascot_theme page.")
            } else {
              as.character(value)
            }
            htmltools::tags$td(cell)
          }))
        }))
      )
    ),
    guide_dependency()
  )
}

# UI/server pairs for a whole app and for a module, sharing the same local id.
guide_wiring <- function() {
  pair <- function(ui_label, ui_code, server_label) {
    checkmate::assert_string(ui_label)
    checkmate::assert_string(ui_code)
    checkmate::assert_string(server_label)
    htmltools::div(
      class = "pg-wire",
      htmltools::div(
        class = "pg-wire-box",
        htmltools::div(class = "pg-muted", ui_label),
        htmltools::tags$pre(htmltools::tags$code(ui_code))
      ),
      htmltools::div(class = "pg-flow-arrow", "\u2194"),
      htmltools::div(
        class = "pg-wire-box",
        htmltools::div(class = "pg-muted", server_label),
        htmltools::tags$pre(htmltools::tags$code('update_mascot("helper", mood = "happy")'))
      )
    )
  }
  htmltools::attachDependencies(
    htmltools::tagList(
      pair("UI", 'mascot("helper")', "server"),
      pair("module UI", 'mascot(ns("helper"))', "module server")
    ),
    guide_dependency()
  )
}

# A link to another function's guide: in the studio it opens that function, on the website it goes to the
# function's page (guide-<function>.html, written by the site build).
guide_fn_link <- function(fn, label = paste0(fn, "()")) {
  checkmate::assert_string(fn, min.chars = 1)
  checkmate::assert_string(label, min.chars = 1)
  if (in_studio()) {
    htmltools::tags$a(href = "#", `data-event` = "select_function", `data-value` = fn, htmltools::tags$code(label))
  } else {
    htmltools::tags$a(href = paste0("guide-", fn, ".html"), htmltools::tags$code(label))
  }
}

# A short box that tells the website reader how to see the page live; the pages put it behind
# `if (!in_studio())`, because in the studio they are already there.
guide_try_live <- function(fn) {
  checkmate::assert_string(fn, min.chars = 1)
  tags <- htmltools::tags
  guide_callout(
    tags$strong("Try it live. "),
    "The mascot studio shows this function with live controls and the generated code. In an R session with the optional packages bslib and knitr installed, run:",
    tags$pre(tags$code(sprintf('mascot::mascot_studio(fn = "%s")', fn))),
    "It opens on this function's guide; change a control and watch the mascot."
  )
}

# A heading written by a chunk (results = "asis"): the studio names the selected character, the website, which
# has no selector, uses a general title above its tabs.
guide_heading <- function(studio, site = studio) {
  checkmate::assert_string(studio, min.chars = 1)
  checkmate::assert_string(site, min.chars = 1)
  cat("\n\n### ", if (in_studio()) studio else site, "\n\n", sep = "")
}

# Per-character content. `render` takes a character id and returns tags. The studio shows the selected
# character, exactly as the page always did. The website has no selector, so it shows every character in
# tabs (Bootstrap's own markup, so pkgdown and the studio's theme style them).
guide_state <- new.env(parent = emptyenv())
guide_each_character <- function(render, id = "guide-character") {
  checkmate::assert_function(render)
  checkmate::assert_string(id, min.chars = 1)
  if (in_studio()) {
    return(render(studio_character))
  }
  tags <- htmltools::tags
  listing <- mascot::mascot_characters()
  guide_state$count <- (if (is.null(guide_state$count)) 0L else guide_state$count) + 1L
  base <- paste0(id, "-", guide_state$count)
  ids <- paste0(base, "-", listing$id)
  nav <- lapply(seq_len(nrow(listing)), function(i) {
    first <- i == 1L
    tags$li(
      class = "nav-item",
      role = "presentation",
      tags$button(
        class = paste("nav-link", if (first) "active"),
        id = paste0(ids[[i]], "-tab"),
        type = "button",
        role = "tab",
        `data-toggle` = "tab",
        `data-bs-toggle` = "tab",
        `data-target` = paste0("#", ids[[i]]),
        `data-bs-target` = paste0("#", ids[[i]]),
        `aria-controls` = ids[[i]],
        `aria-selected` = if (first) "true" else "false",
        listing$name[[i]]
      )
    )
  })
  panes <- lapply(seq_len(nrow(listing)), function(i) {
    tags$div(
      class = paste("tab-pane fade", if (i == 1L) "show active"),
      id = ids[[i]],
      role = "tabpanel",
      `aria-labelledby` = paste0(ids[[i]], "-tab"),
      tabindex = "0",
      render(listing$id[[i]])
    )
  })
  htmltools::attachDependencies(
    tags$div(
      class = "pg-character-tabs",
      tags$ul(class = "nav nav-tabs", role = "tablist", nav),
      tags$div(class = "tab-content", panes)
    ),
    guide_dependency()
  )
}
