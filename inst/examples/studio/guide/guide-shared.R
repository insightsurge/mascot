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

# Worked example data for "Use a palette as a base", shared by the studio and website guides.
guide_palette_base_spec <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  palettes <- mascot::mascot_palettes(character)$name
  palette <- palettes[[if (length(palettes) > 1L) 2L else 1L]]
  roles <- mascot::mascot_colour_roles(character, palette = palette)
  # A role whose change is easy to see; the outline would contradict the table of the live mascot.
  role <- intersect(c("body", "accessory"), roles$role)[1L]
  if (is.na(role)) {
    role <- roles$role[[1L]]
  }
  base <- roles$colour[[match(role, roles$role)]]
  colour <- if (tolower(base) == "#b93664") "#2563eb" else "#b93664"
  list(
    palette = palette,
    role = role,
    base = base,
    colour = colour,
    code = sprintf('mascot_theme(palette = "%s", light = list(%s = "%s"))', palette, role, colour),
    sentence = paste(
      "The explicit light role wins over the palette.",
      "Other roles keep the palette or follow the changed leader."
    )
  )
}

# Finds two characters sharing a non-original palette and one lacking it without hardcoding character ids.
guide_default_swap <- function(preferred_palette = "coral_navy") {
  checkmate::assert_string(preferred_palette, min.chars = 1, null.ok = TRUE)
  ids <- mascot::mascot_characters()$id
  for (from in ids) {
    palettes <- setdiff(mascot::mascot_palettes(from)$name, "original")
    if (!is.null(preferred_palette) && preferred_palette %in% palettes) {
      palettes <- c(preferred_palette, setdiff(palettes, preferred_palette))
    }
    for (palette in palettes) {
      has_palette <- vapply(ids, function(id) palette %in% mascot::mascot_palettes(id)$name, logical(1))
      others <- setdiff(ids[has_palette], from)
      missing <- ids[!has_palette]
      if (length(others) && length(missing)) {
        return(c(from = from, kept = others[[1L]], dropped = missing[[1L]], palette = palette))
      }
    }
  }
  NULL
}

# Worked example data for "Character swap", shared by the studio and website guides.
guide_palette_swap_spec <- function(swap = guide_default_swap(), id = "helper") {
  checkmate::assert_character(swap, names = "named", min.len = 4)
  checkmate::assert_subset(c("from", "kept", "dropped", "palette"), names(swap))
  checkmate::assert_string(id, min.chars = 1)
  from <- mascot::mascot_character(swap[["from"]])$name
  kept <- mascot::mascot_character(swap[["kept"]])$name
  dropped <- mascot::mascot_character(swap[["dropped"]])$name
  palette <- swap[["palette"]]
  list(
    swap = swap,
    from_name = from,
    kept_name = kept,
    dropped_name = dropped,
    sentence = paste(
      "Both examples start with",
      from,
      "in",
      paste0(palette, "."),
      kept,
      "keeps the palette;",
      dropped,
      "drops it and returns to its own colours."
    ),
    code = paste(
      sprintf('update_mascot("%s", character = "%s", theme = "%s", motion = FALSE)', id, swap[["from"]], palette),
      sprintf('update_mascot("%s", character = "%s")', id, swap[["kept"]]),
      sprintf('update_mascot("%s", character = "%s")', id, swap[["dropped"]]),
      sep = "\n"
    )
  )
}
