#' Preview a mascot in light and dark mode
#'
#' Compare moods and sizes on a single offline page. Creating the page starts no
#' Shiny app, opens no viewer and writes no files. Printing the returned page
#' opens the available Viewer or browser. It can also be embedded in an R Markdown
#' or Quarto document.
#' @evalRd paste0(
#'   "\\section{Experimental}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nIts purpose, arguments and page layout may change in a later release.\n}"
#' )
#' @inheritParams mascot
#' @param mood A mood name or [mascot_mood()] object, or `NULL` (the default)
#'   to show every mood from [mascot_moods()].
#' @param size A finite number of CSS pixels (at least `24`), a positive
#'   percentage string such as `"20%"`, or a [mascot_size()] object. Defaults to
#'   `160`. Percentages follow the comparison cell width. `NULL` is not accepted.
#' @param motion A logical flag or [mascot_motion_settings()] object. Defaults to `FALSE`
#'   for steady faces; `TRUE` allows movement subject to the visitor's preference.
#'   `NULL` is not accepted.
#' @returns A browsable `htmltools` tag list. Its `contrast` attribute is a data
#'   frame with `role`, `colour`, `background`, `ratio` and `mode` columns, one row
#'   per supplied colour below 3:1. With no findings it is a zero-row data frame
#'   with the same columns. Colours are kept unchanged; one combined warning is
#'   issued in R unless `mascot.contrast_warnings` is `FALSE`.
#' @details
#' **Comparison grid.** Rows are moods; columns are the requested `size`, then
#' 160, 96 and 24 CSS pixels. The first column preserves percentage and
#' `small_screen` settings; fixed comparison columns do not change on narrow
#' screens. Every size draws the full character. Each cell keeps its status text,
#' since small faces lose fine detail.
#'
#' **Theme and contrast.** A palette id string works as in [mascot()].
#' Built-in palette colours do not add contrast warnings. Both supplied theme
#' maps are shown, even if the theme
#' selected one mode. Backgrounds are white and `#212529`, or the `bslib` theme's
#' `bg` and `body-bg-dark`; text uses `fg` and `body-color-dark`. Only supplied
#' colour roles are checked, using the same contrast calculation as [mascot()].
#' Experimental CSS variables are worked out in the browser: their warnings appear
#' in its console, outside the R `contrast` attribute.
#'
#' **Bubbles.** Empty bubble space is omitted here; a supplied bubble keeps its
#' normal space and timing. Each cell is wide enough to hold it, so bubbles
#' never cover neighbouring cells.
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
  ...,
  mood = NULL,
  status = NULL,
  bubble = NULL,
  size = 160,
  theme = NULL,
  motion = FALSE
) {
  # These union arguments share mascot()'s converters and checkmate boundaries.
  character <- as_character_arg(character, environment())
  known_moods <- mascot_moods(if (is.null(character$data)) character$id else character$data)$name
  moods <- if (is.null(mood)) known_moods else as_mood_arg(mood, environment(), character)$name
  if (!is.null(mood) && !moods %in% known_moods) {
    abort_choice(moods, known_moods, "mood", "mood", environment())
  }
  status <- as_status_arg(status, environment())
  bubble <- as_bubble_arg(bubble, environment())
  size <- as_size_arg(size, environment())
  invisible(as_motion_arg(motion, environment()))
  # Resolve once, muffling the per-role contrast warnings: one combined warning follows.
  resolved <- withCallingHandlers(
    as_theme_arg(theme, environment(), if (is.null(character$data)) character$id else character$data),
    warning = function(warning) {
      checkmate::assert_class(warning, "warning")
      if (inherits(warning, "mascot_contrast")) {
        invokeRestart("muffleWarning")
      }
    }
  )
  if (...length() > 0L) {
    abort_dots(
      names(substitute(list(...)))[-1L],
      ...length(),
      c("mood", "status", "bubble", "size", "theme", "motion"),
      environment()
    )
  }
  surfaces <- preview_surfaces(theme)
  contrast <- preview_contrast(resolved, surfaces$background)
  lines <- preview_contrast_labels(contrast)
  if (nrow(contrast) && contrast_warnings(always = TRUE)) {
    cli::cli_warn(
      c(
        "Preview colours have contrast below 3:1; the colours are kept.",
        "i" = "{paste(lines, collapse = '\n')}"
      ),
      class = c("mascot_contrast", "mascot_warning")
    )
  }
  sizes <- c(
    list(size),
    lapply(c(160, 96, 24), function(pixels) {
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
    preview_panel(character, moods, status, bubble, sizes, labels, resolved, motion, mode, prefix)
  })
  page <- htmltools::tagList(htmltools::tags$main(
    id = prefix,
    class = paste("mascot-preview", if (is.null(bubble$text)) "mascot-preview-no-bubble"),
    `aria-labelledby` = paste0(prefix, "-heading"),
    # Only safe converted colours go in custom properties; layout lives in CSS.
    style = paste0(
      "--_mascot-preview-light-bg:",
      surfaces$background[["light"]],
      ";",
      "--_mascot-preview-dark-bg:",
      surfaces$background[["dark"]],
      ";",
      "--_mascot-preview-light-fg:",
      surfaces$foreground[["light"]],
      ";",
      "--_mascot-preview-dark-fg:",
      surfaces$foreground[["dark"]],
      ";"
    ),
    htmltools::tags$h1(id = paste0(prefix, "-heading"), paste(character$name, "preview")),
    htmltools::tags$p("Compare each mood and size in both modes. Status text keeps the meaning readable."),
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

#' Collect supplied-role contrast findings with theme_contrast()
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
        value[nrow(value) + 1L, ] <- list(role, map[[role]], backgrounds[[mode]], ratio, mode)
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

#' One mode's table using mascot() markup and the theme as sent to the browser
#' @noRd
preview_panel <- function(character, moods, status, bubble, sizes, labels, theme, motion, mode, prefix) {
  checkmate::assert_class(character, "mascot_character")
  checkmate::assert_character(moods, any.missing = FALSE, min.len = 1)
  checkmate::assert_class(status, "mascot_status")
  checkmate::assert_class(bubble, "mascot_bubble")
  checkmate::assert_list(sizes, min.len = 1)
  checkmate::assert_character(labels, len = length(sizes), any.missing = FALSE)
  checkmate::assert_list(theme, null.ok = TRUE)
  # The motion union has been checked by the public converter. Cells get no click: a static page cannot send one.
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
        motion = motion
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
    htmltools::tags$tr(
      htmltools::tags$th(scope = "row", tools::toTitleCase(gsub("_", " ", moods[[row]], fixed = TRUE))),
      cells
    )
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
