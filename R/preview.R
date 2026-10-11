#' Preview a mascot in light and dark mode
#'
#' Compare moods and sizes on a single offline page. Creating the page starts no
#' Shiny app, opens no viewer and writes no files to disk. Printing the returned
#' page opens it in your IDE Viewer or default browser. It can also be embedded
#' directly in an R Markdown or Quarto document.
#' @inheritParams mascot
#' @param mood A mood name or [mascot_mood()] object, or `NULL` (the default)
#'   to show every mood from [mascot_moods()].
#' @param size Mascot size: a number of CSS pixels (at least `24`), a percentage
#'   string such as `"20%"`, or a [mascot_size()] object. Defaults to `160`.
#'   Percentages follow the comparison cell width. `NULL` is not accepted.
#' @param placement A placement shortcut, named list or [mascot_placement()]
#'   object, defaulting to `"inline"`. The preview shows every mascot inline in
#'   the comparison grid. `NULL` is not accepted.
#' @param popup_menu A named character vector or [mascot_popup_menu()] object,
#'   or `NULL` (the default) for no menu. The menu is validated, but stays
#'   inactive on this static page.
#' @param motion A logical flag or [mascot_motion()] object. Defaults to `FALSE`
#'   for steady faces; `TRUE` allows animation subject to the visitor's preference.
#'   `NULL` is not accepted.
#' @returns A browsable `htmltools` tag list. Its `contrast` attribute is a data
#'   frame with `role`, `colour`, `background`, `ratio` and `mode` columns, with
#'   one row for each supplied colour below 3:1 contrast.
#' @details
#' **Comparison grid.** Rows show moods; columns show your chosen `size`,
#' followed by reference sizes at 48, 32 and 24 CSS pixels. The first column
#' preserves percentage and `small_screen` settings; fixed comparison columns do
#' not change on narrow screens. Every size draws the complete character. Each
#' cell keeps its status text, making the meaning clear even when small faces
#' lose fine details.
#'
#' **Theme and contrast.** Both light and dark theme panels are shown side by
#' side. Backgrounds default to white and `#212529`, or the `bslib` theme's light
#' and dark background colours. Only supplied colour roles are checked for contrast.
#' Any colour below 3:1 contrast against the background produces a warning and is
#' recorded in the `contrast` attribute.
#'
#' Floating placement is displayed inline so every cell stays neatly in the
#' comparison grid. Click menus remain inactive on this static page.
#' @family mascot helpers
#' @seealso [mascot()], [mascot_colour_roles()], [mascot_theme()]
#' @export
#' @examples
#' page <- mascot_preview(mood = "happy", size = 96)
#' attr(page, "contrast")
#' @examplesIf interactive()
#' mascot_preview()
mascot_preview <- function(
  character = "tessa",
  mood = NULL,
  status = NULL,
  bubble = NULL,
  size = 160,
  placement = "inline",
  theme = NULL,
  motion = FALSE,
  popup_menu = NULL
) {
  # These union arguments share mascot()'s converters and checkmate boundaries.
  character <- as_character_arg(character, environment())
  moods <- if (is.null(mood)) mascot_moods()$name else as_mood_arg(mood, environment())$name
  status <- as_status_arg(status, environment())
  bubble <- as_bubble_arg(bubble, environment())
  size <- as_size_arg(size, environment())
  placement <- as_placement_arg(placement, environment())
  invisible(as_motion_arg(motion, environment()))
  menu <- as_popup_menu_arg(popup_menu, environment())
  # Resolve once. Replace only slice 4's per-role contrast warnings with one list.
  resolved <- withCallingHandlers(
    as_theme_arg(theme, environment(), character$id),
    warning = function(warning) {
      checkmate::assert_class(warning, "warning")
      if (inherits(warning, "mascot_contrast")) {
        invokeRestart("muffleWarning")
      }
    }
  )
  surfaces <- preview_surfaces(theme)
  contrast <- preview_contrast(resolved, surfaces$background)
  lines <- preview_contrast_labels(contrast)
  if (nrow(contrast)) {
    cli::cli_warn(
      c(
        "Preview colours have contrast below 3:1; the colours are kept.",
        "i" = "{paste(lines, collapse = '\n')}"
      ),
      class = "mascot_contrast"
    )
  }
  sizes <- c(
    list(size),
    lapply(c(48, 32, 24), function(pixels) {
      checkmate::assert_number(pixels, lower = 24)
      mascot_size(pixels)
    })
  )
  labels <- vapply(
    sizes,
    function(value) {
      checkmate::assert_class(value, "mascot_size")
      if (is.numeric(value$size)) paste(value$size, "px") else paste(value$size, "of cell width")
    },
    character(1)
  )
  # tempfile() supplies a unique name only: it does not create a file.
  prefix <- basename(tempfile("mascot-preview-"))
  panels <- lapply(c("light", "dark"), function(mode) {
    checkmate::assert_choice(mode, c("light", "dark"))
    preview_panel(character, moods, status, bubble, sizes, labels, resolved, motion, popup_menu, mode, prefix)
  })
  page <- htmltools::tagList(htmltools::tags$main(
    id = prefix,
    class = paste("mascot-preview", if (is.null(bubble$text)) "mascot-preview-no-bubble"),
    `aria-labelledby` = paste0(prefix, "-heading"),
    # Only safe converted colours go in custom properties; layout lives in CSS.
    style = paste0(
      "--mascot-preview-light-bg:",
      surfaces$background[["light"]],
      ";",
      "--mascot-preview-dark-bg:",
      surfaces$background[["dark"]],
      ";",
      "--mascot-preview-light-fg:",
      surfaces$foreground[["light"]],
      ";",
      "--mascot-preview-dark-fg:",
      surfaces$foreground[["dark"]],
      ";"
    ),
    htmltools::tags$h1(id = paste0(prefix, "-heading"), paste(character$name, "preview")),
    htmltools::tags$p("Compare each mood and size in both modes. Status text keeps the meaning readable."),
    if (placement$position != "inline") htmltools::tags$p("Floating placement is shown inline in this comparison."),
    if (length(menu$items)) htmltools::tags$p("Click menus need Shiny and are inactive in this static preview."),
    if (length(resolved$css)) {
      htmltools::tags$p("Experimental CSS colours are checked in the browser console, not the R contrast list.")
    },
    htmltools::tags$section(
      class = "mascot-preview-contrast",
      `aria-labelledby` = paste0(prefix, "-contrast"),
      htmltools::tags$h2(id = paste0(prefix, "-contrast"), "Colour contrast"),
      if (length(lines)) {
        htmltools::tags$ul(lapply(lines, htmltools::tags$li))
      } else {
        htmltools::tags$p("No supplied colours fall below 3:1 against the comparison backgrounds.")
      }
    ),
    htmltools::tags$div(class = "mascot-preview-panels", panels)
  ))
  page <- htmltools::attachDependencies(
    page,
    htmltools::htmlDependency(
      name = "mascot-preview",
      version = getNamespaceVersion("mascot")[[1]],
      src = "preview",
      package = "mascot",
      stylesheet = "preview.css",
      all_files = FALSE
    )
  )
  page <- htmltools::browsable(page)
  attr(page, "contrast") <- contrast
  page
}

#' Backgrounds and text colours for the two comparison panels
#' @noRd
preview_surfaces <- function(theme) {
  # theme is a union already checked by as_theme_arg().
  value <- list(
    background = c(light = "#FFFFFF", dark = "#212529"),
    foreground = c(light = "#212529", dark = "#F8F9FA")
  )
  if (inherits(theme, "bs_theme")) {
    variables <- bslib::bs_get_variables(theme, c("bg", "fg", "body-bg-dark", "body-color-dark"))
    value$background <- c(
      light = theme_colour(variables[["bg"]], "bg"),
      dark = theme_colour(variables[["body-bg-dark"]], "body-bg-dark")
    )
    value$foreground <- c(
      light = theme_colour(variables[["fg"]], "fg"),
      dark = theme_colour(variables[["body-color-dark"]], "body-color-dark")
    )
  }
  value
}

#' Collect supplied-role contrast findings with the existing calculation
#' @noRd
preview_contrast <- function(theme, backgrounds) {
  checkmate::assert_list(theme, null.ok = TRUE)
  checkmate::assert_character(backgrounds, len = 2, names = "unique", any.missing = FALSE)
  checkmate::assert_names(names(backgrounds), identical.to = c("light", "dark"))
  value <- data.frame(
    role = character(),
    colour = character(),
    background = character(),
    ratio = numeric(),
    mode = character()
  )
  for (mode in c("light", "dark")) {
    map <- if (length(theme$brand)) theme$brand else theme[[mode]]
    for (role in setdiff(names(map), names(theme$css))) {
      ratio <- theme_contrast(map[[role]], backgrounds[[mode]])
      if (ratio < 3) {
        value[nrow(value) + 1L, ] <- list(colour_role_names(role), map[[role]], backgrounds[[mode]], ratio, mode)
      }
    }
  }
  value
}

#' Plain labels shared by the page and combined R warning
#' @noRd
preview_contrast_labels <- function(contrast) {
  checkmate::assert_data_frame(contrast)
  vapply(
    seq_len(nrow(contrast)),
    function(row) {
      checkmate::assert_count(row, positive = TRUE)
      paste0(
        contrast$role[[row]],
        ": ",
        contrast$colour[[row]],
        " against ",
        contrast$background[[row]],
        ", ",
        formatC(contrast$ratio[[row]], format = "f", digits = 2),
        ":1 (",
        contrast$mode[[row]],
        ")."
      )
    },
    character(1)
  )
}

#' One mode's table using mascot() markup and the resolved theme wire contract
#' @noRd
preview_panel <- function(character, moods, status, bubble, sizes, labels, theme, motion, popup_menu, mode, prefix) {
  checkmate::assert_class(character, "mascot_character")
  checkmate::assert_character(moods, any.missing = FALSE, min.len = 1)
  checkmate::assert_class(status, "mascot_status")
  checkmate::assert_class(bubble, "mascot_bubble")
  checkmate::assert_list(sizes, min.len = 1)
  checkmate::assert_character(labels, len = length(sizes), any.missing = FALSE)
  checkmate::assert_list(theme, null.ok = TRUE)
  # Motion and popup_menu unions have been checked by the public converters.
  checkmate::assert_choice(mode, c("light", "dark"))
  checkmate::assert_string(prefix)
  theme <- if (is.null(theme)) list(light = NULL, dark = NULL, css = NULL, brand = NULL) else theme
  theme$mode <- mode
  rows <- lapply(seq_along(moods), function(row) {
    checkmate::assert_count(row, positive = TRUE)
    cells <- lapply(seq_along(sizes), function(column) {
      checkmate::assert_count(column, positive = TRUE)
      tag <- mascot(
        character = character,
        id = paste(prefix, mode, row, column, sep = "-"),
        mood = moods[[row]],
        status = status,
        bubble = bubble,
        size = sizes[[column]],
        placement = "inline",
        motion = motion,
        popup_menu = popup_menu
      )
      tag <- htmltools::tagAppendChild(tag, theme_tag(theme))
      htmltools::tags$td(
        class = "mascot-preview-cell",
        htmltools::tags$figure(
          htmltools::tags$div(class = "mascot-preview-stage", tag),
          htmltools::tags$figcaption(paste(moods[[row]], labels[[column]], mode, sep = ", "))
        )
      )
    })
    htmltools::tags$tr(htmltools::tags$th(scope = "row", mood_label(moods[[row]])), cells)
  })
  heading <- paste0(prefix, "-", mode)
  htmltools::tags$section(
    class = "mascot-preview-mode",
    `data-bs-theme` = mode,
    `aria-labelledby` = heading,
    htmltools::tags$h2(id = heading, paste0(toupper(substr(mode, 1, 1)), substring(mode, 2))),
    htmltools::tags$div(
      class = "mascot-preview-scroll",
      htmltools::tags$table(
        htmltools::tags$caption(paste("Moods and sizes in", mode, "mode")),
        htmltools::tags$thead(htmltools::tags$tr(
          htmltools::tags$th(scope = "col", "Mood"),
          lapply(labels, function(label) {
            checkmate::assert_string(label)
            htmltools::tags$th(scope = "col", label)
          })
        )),
        htmltools::tags$tbody(rows)
      )
    )
  )
}
