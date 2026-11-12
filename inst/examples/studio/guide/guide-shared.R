# Functions that both the studio (R/data.R, R/ui.R) and the guide pages (guide-helpers.R) use, so each exists once.
# Standalone: base R, htmltools::, checkmate:: and mascot:: only.

# Which bslib colour slots (primary, secondary, ...) a character's colour roles feed, as slot = role.
guide_brand_roles <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  roles <- mascot::mascot_colour_roles(character)
  roles <- roles[!is.na(roles$brand), ]
  result <- list()
  for (i in seq_len(nrow(roles))) {
    for (slot in strsplit(roles$brand[i], ", ", fixed = TRUE)[[1]]) {
      result[[slot]] <- roles$role[i]
    }
  }
  result
}

# Small data-frame table shared by the studio and the guide pages.
guide_data_table <- function(df, cells = NULL, coerce = FALSE) {
  checkmate::assert_data_frame(df)
  checkmate::assert_list(cells, types = "function", names = "unique", null.ok = TRUE)
  checkmate::assert_flag(coerce)
  htmltools::tags$table(
    class = "table table-sm pg-table",
    htmltools::tags$thead(htmltools::tags$tr(lapply(names(df), htmltools::tags$th))),
    htmltools::tags$tbody(lapply(seq_len(nrow(df)), function(i) {
      htmltools::tags$tr(lapply(names(df), function(column) {
        value <- df[[column]][i]
        cell <- if (!is.null(cells[[column]])) {
          cells[[column]](value)
        } else if (coerce) {
          as.character(value)
        } else {
          value
        }
        htmltools::tags$td(cell)
      }))
    }))
  )
}

# Placement diagram shared by the studio (interactive corner selection) and the website guide (static overview).
guide_placement_map_html <- function(
  active = formals(mascot::mascot_placement)$position,
  name = mascot::mascot_character()$name,
  interactive = FALSE,
  caption = NULL
) {
  checkmate::assert_string(active, min.chars = 1)
  checkmate::assert_string(name, min.chars = 1)
  checkmate::assert_flag(interactive)
  checkmate::assert_string(caption, min.chars = 1, null.ok = TRUE)
  corners <- c("top-left", "top-right", "bottom-left", "bottom-right")
  inline_active <- identical(active, "inline")
  inline_label <- if (interactive && inline_active) paste0(name, ", inline") else "inline"
  corner <- function(corner_id) {
    is_active <- identical(active, corner_id)
    label <- if (interactive) {
      if (is_active) name else NULL
    } else {
      corner_id
    }
    htmltools::tags$span(
      class = paste("pg-map-corner", paste0("pg-", corner_id), if (is_active) "is-active"),
      `data-value` = if (interactive) corner_id else NULL,
      label
    )
  }
  htmltools::div(
    class = "pg-map",
    htmltools::div(class = "pg-map-bar"),
    htmltools::div(
      class = "pg-map-page",
      htmltools::div(class = "pg-map-line"),
      htmltools::tags$span(
        class = paste("pg-map-inline", if (inline_active) "is-active"),
        `data-value` = if (interactive) "inline" else NULL,
        inline_label
      ),
      htmltools::div(class = "pg-map-line short"),
      htmltools::div(class = "pg-map-line")
    ),
    lapply(corners, corner),
    if (!is.null(caption)) htmltools::div(class = "pg-muted pg-map-caption", caption)
  )
}

# Roles table shared by the studio and the website guide; callers wrap their code preview header and dependencies.
guide_roles_table_html <- function(character, palette = NULL, outline_extra = NULL) {
  checkmate::assert_string(character, min.chars = 1)
  checkmate::assert_string(palette, min.chars = 1, null.ok = TRUE)
  checkmate::assert(
    checkmate::check_null(outline_extra),
    checkmate::check_string(outline_extra, min.chars = 1),
    checkmate::check_class(outline_extra, "shiny.tag"),
    .var.name = "outline_extra"
  )
  roles <- mascot::mascot_colour_roles(character, palette = palette)
  swatch <- function(colour) {
    htmltools::tagList(
      htmltools::tags$span(class = "pg-swatch", style = paste0("background:", colour)),
      htmltools::tags$code(colour)
    )
  }
  follows <- function(value) {
    if (is.na(value)) htmltools::tags$span(class = "pg-muted", "leader") else paste("\u2190", value)
  }
  shade <- function(value) if (is.na(value)) "" else value
  outline_text <- roles$description[roles$role == "outline"]
  description <- function(value) {
    if (!is.null(outline_extra) && length(outline_text) == 1L && identical(value, outline_text)) {
      if (is.character(outline_extra)) {
        paste(value, outline_extra)
      } else {
        htmltools::tagList(value, " ", outline_extra)
      }
    } else {
      value
    }
  }
  guide_data_table(
    roles,
    cells = list(colour = swatch, follows = follows, shade = shade, description = description),
    coerce = TRUE
  )
}
