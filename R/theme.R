#' Set a mascot's colours and light or dark mode
#'
#' Customise the character's colours and light or dark mode. Roles you do not set
#' follow the first supplied or filled leader that the character declares (for
#' example `body`), in the character's priority order. With no supplied leader,
#' they keep their original colours. Call [mascot_colour_roles()] to find the
#' roles for a character. A plain named list passed to [mascot()] or
#' [update_mascot()] uses one set of colours in every mode. A [bslib::bs_theme()]
#' fills the character's declared brand leaders with its primary and secondary
#' colours; `_brand.yml` can be supplied through `bs_theme(brand = )`. A
#' `bs_theme()` always uses `mode = "auto"`. Which parts of a character a
#' `bs_theme()` colours is experimental and may change in a later release.
#'
#' After a character swap, follow rules are applied again and roles absent from
#' the incoming character are ignored. A palette is kept if the new character
#' has the same id; otherwise R warns and restores its own colours, keeping
#' explicit role colours where they exist. An empty `mascot_theme()`
#' restores the character's own colours. A chosen colour below 3:1 contrast
#' gives a warning and is kept (see "Contrast warnings" below). Supplied colours
#' are kept exactly.
#' Derived shades keep the hue, with calibrated lightness and saturation shifts.
#' Brand colours are the same in both modes.
#'
#' @section Contrast warnings:
#' A warning appears when a colour chosen by the developer (light, dark, or a
#' [bslib::bs_theme()] brand colour) has contrast below 3:1 against the page
#' background (white in light mode, `#212529` in dark mode, or the `bslib`
#' theme's backgrounds). Contrast is checked when [mascot()] builds the UI,
#' when [update_mascot()] applies colours with `theme = `, and collected into the
#' contrast table by [mascot_preview()]; native and built-in palette colours never warn;
#' the colour is always kept.
#'
#' R warnings appear only when [shiny::in_devmode()] is `TRUE`, and always in
#' [mascot_preview()] and the studio. Set `options(mascot.contrast_warnings = TRUE)`
#' or `FALSE` to force them on or off everywhere. A non-flag value warns once
#' per R session and uses the default. Visitors never see R warnings.
#' CSS-variable colours (`css =`) are checked and warn in the browser console.
#'
#' These warnings have the class `mascot_contrast`. To silence only these
#' warnings:
#' ```r
#' withCallingHandlers(
#'   mascot("helper", theme = list(rim = "#f5e6c8")),
#'   mascot_contrast = function(w) invokeRestart("muffleWarning")
#' )
#' ```
#' Note that `suppressWarnings()` also works but hides every warning.
#'
#' @section A `bs_theme()` or explicit colours:
#' A [bslib::bs_theme()] cannot be combined with `palette`, `light`, `dark` or
#' `css`: `theme` takes either the theme or a `mascot_theme()`, and a
#' `bs_theme()` passed to `mascot_theme()` is an error. It fills only the
#' character's brand roles (the `brand` column of [mascot_colour_roles()]: `body`
#' for `primary` and `rim` for `secondary` on `"tessa"`), and the roles that
#' follow them change with them. A character with no brand roles, such as
#' `"neer"`, keeps its own colours. The colour is the same in light and dark
#' mode. A brand colour that is dark enough on a white page can fail 3:1 on the
#' dark background. In development mode (or with
#' `options(mascot.contrast_warnings = TRUE)`; see "Contrast warnings") a
#' warning of class `mascot_contrast` then names the slot and the mode, and the
#' colour is kept. To change it, give those roles for each mode yourself:
#'
#' ```r
#' mascot("helper", theme = mascot_theme(
#'   light = list(body = "#1b3a6b", rim = "#5c6770"),
#'   dark = list(body = "#9ec5fe", rim = "#adb5bd")
#' ))
#' ```
#'
#' The example uses the brand roles of `"tessa"`; other characters name theirs in
#' [mascot_colour_roles()]. Roles you leave out follow the ones you set, as
#' described above.
#' @param palette A palette id from [mascot_palettes()], or `NULL` (the default)
#'   for the character's own colours. Checked against the chosen character when
#'   used. An unknown palette id is an error in [mascot()] (the UI is being
#'   built) but only a warning in [update_mascot()] (a live session, so the
#'   mascot keeps running unchanged). `"original"` also
#'   chooses its own colours. A palette is applied first, then `light` and `dark`
#'   roles, then `css`. Without a dark map, a palette uses its light colours in
#'   both modes. A `bs_theme()` is a separate alternative.
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @param light,dark Named lists of colour roles, or `NULL` (the default) to keep
#'   the palette's colours (or the character's own colours) in that mode.
#'   Values can be colour names, hex
#'   strings, [grDevices::rgb()] output, CSS `rgb()` or `rgba()` strings, or
#'   three RGB numbers (red, green and blue) in 0--255. Single numeric palette
#'   indices are not accepted. Roles use snake case; `light`, `dark` and
#'   `default` are reserved. Names follow the character format: a lowercase letter,
#'   then lowercase letters or digits separated by single underscores, with an
#'   optional final underscore. Construction checks this form; [mascot()],
#'   [update_mascot()] and [mascot_preview()] check roles against the chosen
#'   character. Built-in characters keep one outline colour in
#'   both modes; their light outer band keeps them readable on any dark page.
#'   To use your own dark-mode outline, set `dark = list(outline = "#FFC93C")`.
#' @param mode Mode selection: `"auto"` (the default), `"light"` or `"dark"`.
#'   `"auto"` follows the nearest valid `data-bs-theme` in the original source
#'   context, then Quarto's body classes. With no page signal it uses light mode.
#'   An explicit light or dark mode always wins. `NULL` is not accepted.
#' @param css A named list mapping colour roles to CSS variable names such as
#'   `list(body = "--team-blue")`, or `NULL` (the default) for no CSS source.
#'   This source is experimental. CSS entries override light and dark entries
#'   for the same role. Missing or invalid variables use the character's own
#'   colour and warn in the browser console; low contrast also warns there and
#'   keeps the colour. Variables are read from the original source context,
#'   including when the mascot floats.
#' @returns A `mascot_theme` object describing colours, CSS sources and mode.
#' The returned object's fields are internal; pass the object on rather than reading its fields.
#' @family mascot helpers
#' @seealso [mascot_colour_roles()], [mascot()], [update_mascot()],
#'   [mascot_styling] for panel and button CSS hooks,
#'   [mascot_motion_settings()] for a complete Shiny settings example
#' @evalRd paste0(
#'   "\\section{Experimental CSS source}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nCSS variables are worked out by the browser, so R cannot check their values.\n}"
#' )
#' @evalRd paste0(
#'   "\\section{Experimental colour mapping for \\code{bs_theme()}}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\n\\code{theme = bslib::bs_theme()} is accepted, but which parts of a character ",
#'   "it colours may change in a later release.\n}"
#' )
#' @export
#' @examples
#' mascot_theme()
#' mascot_theme(palette = "coral_navy", light = list(rim = "#b93664"))
#' mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"), mode = "auto")
#' mascot_theme(css = list(body = "--team-blue"))
#' ui <- mascot("helper", theme = list(body = "#1f6feb"))
#' @examplesIf requireNamespace("bslib", quietly = TRUE)
#' ui <- mascot("brand", theme = bslib::bs_theme(primary = "#1f6feb"))
mascot_theme <- function(..., palette = NULL, light = NULL, dark = NULL, mode = "auto", css = NULL) {
  with_mascot_asserts({
    checkmate::assert_string(palette, min.chars = 1, null.ok = TRUE)
    checkmate::assert_list(light, names = "unique", null.ok = TRUE)
    checkmate::assert_list(dark, names = "unique", null.ok = TRUE)
    checkmate::assert_string(mode)
    checkmate::assert_list(css, names = "unique", null.ok = TRUE)
  })
  if (...length() > 0L) {
    abort_dots(
      names(substitute(list(...)))[-1L],
      ...length(),
      c("palette", "light", "dark", "mode", "css"),
      environment()
    )
  }
  if (!mode %in% c("light", "dark", "auto")) {
    abort_choice(mode, c("light", "dark", "auto"), "mode", "mode", environment())
  }
  value <- structure(
    list(palette = palette, light = light, dark = dark, mode = mode, css = css),
    class = "mascot_theme"
  )
  check_arg(value, "theme", environment())
  value
}

# Cache only the format's role-name grammar; checked character data stays separate.
theme_role_pattern_cache <- new.env(parent = emptyenv())

#' Read the role-name pattern once per package session
#' @noRd
theme_role_pattern <- function() {
  if (is.null(theme_role_pattern_cache$pattern)) {
    theme_role_pattern_cache$pattern <- character_format_schema()$definitions$colour_map$key_pattern
  }
  theme_role_pattern_cache$pattern
}

#' Validate a colour or CSS map without throwing at runtime
#' @noRd
theme_map_problem <- function(x, arg, roles, css = FALSE) {
  checkmate::assert_string(arg)
  checkmate::assert_character(roles, any.missing = FALSE, null.ok = TRUE)
  checkmate::assert_flag(css)
  # Union input uses check_* so runtime errors can become warnings.
  if (is.null(x)) {
    return(NULL)
  }
  if (!isTRUE(checkmate::check_list(x, names = "unique")) || (length(x) && is.null(names(x)))) {
    return(paste0("`", arg, "` must be a named list with unique colour roles, or NULL."))
  }
  # Before a character is chosen, admit the same role-name grammar as the format.
  valid <- if (is.null(roles)) {
    grepl(theme_role_pattern(), names(x))
  } else {
    names(x) %in% roles
  }
  wrong <- names(x)[!valid | names(x) %in% c("light", "dark", "default")]
  if (is.null(roles) && length(wrong)) {
    return(paste0(
      "`",
      arg,
      "` has unknown or reserved colour roles: ",
      paste(encodeString(wrong, quote = '"'), collapse = ", "),
      ". Use lowercase snake case: a lowercase letter, then lowercase letters or digits ",
      "separated by single underscores, with an optional final underscore. ",
      "`light`, `dark` and `default` are reserved. ",
      "See `mascot_colour_roles()` for a character's roles."
    ))
  }
  if (length(wrong)) {
    return(paste0(
      "`",
      arg,
      "` has unknown or reserved colour roles: ",
      paste(encodeString(wrong, quote = '"'), collapse = ", "),
      ".",
      theme_role_hint(wrong, roles),
      " Valid roles: ",
      paste(encodeString(roles, quote = '"'), collapse = ", "),
      ". See `mascot_colour_roles()` for each character's roles."
    ))
  }
  for (role in names(x)) {
    if (css) {
      if (!isTRUE(checkmate::check_string(x[[role]], pattern = "^--[A-Za-z_][A-Za-z0-9_-]*$"))) {
        return(paste0("`", arg, "$", role, "` must name a CSS variable such as \"--team-blue\"."))
      }
    } else {
      problem <- tryCatch(
        {
          theme_colour(x[[role]], role)
          NULL
        },
        error = function(error) conditionMessage(error)
      )
      if (!is.null(problem)) return(problem)
    }
  }
  NULL
}

# A "did you mean" for misspelt theme roles: the closest known role for each wrong name, when one is close.
# Per-node helper: theme_map_problem() checked both inputs (house exception, r-code.md).
theme_role_hint <- function(wrong, roles) {
  reserved <- c("light", "dark", "default")
  roles <- setdiff(roles, reserved)
  wrong <- setdiff(wrong, reserved)
  if (!length(wrong) || !length(roles)) {
    return("")
  }
  close <- vapply(
    wrong,
    function(name) {
      distance <- utils::adist(name, roles)[1L, ]
      if (min(distance) <= 2L) roles[[which.min(distance)]] else NA_character_
    },
    character(1)
  )
  close <- unique(close[!is.na(close)])
  if (!length(close)) {
    return("")
  }
  paste0(" Did you mean ", paste(encodeString(close, quote = '"'), collapse = ", "), "?")
}

#' Validate shortcuts and complete helper objects without changing anything
#' @noRd
theme_problem <- function(x, roles = NULL) {
  checkmate::assert_character(roles, any.missing = FALSE, null.ok = TRUE)
  # Union input uses the same non-throwing boundary as size and placement.
  if (is.null(x)) {
    return(NULL)
  }
  if (is.character(x)) {
    return(if (isTRUE(checkmate::check_string(x, min.chars = 1))) NULL else "`theme` must name one palette id.")
  }
  if (inherits(x, "bs_theme")) {
    if (!theme_has_bslib()) {
      return("`theme` needs bslib 0.7.0 or later for a bs_theme() object.")
    }
    return(NULL)
  }
  if (!inherits(x, "mascot_theme")) {
    return(theme_map_problem(x, "theme", roles))
  }
  fields <- c("palette", "light", "dark", "mode", "css")
  if (!isTRUE(checkmate::check_list(x, names = "unique")) || !setequal(names(x), fields) || length(x) != 5L) {
    return("`theme` must be a mascot_theme() object with palette, light, dark, mode and css fields.")
  }
  if (!isTRUE(checkmate::check_string(x$palette, min.chars = 1, null.ok = TRUE))) {
    return("`theme$palette` must be one palette id or NULL.")
  }
  if (!isTRUE(checkmate::check_choice(x$mode, c("light", "dark", "auto")))) {
    return("`theme$mode` must be one of \"light\", \"dark\" or \"auto\".")
  }
  for (field in c("light", "dark", "css")) {
    problem <- theme_map_problem(x[[field]], paste0("theme$", field), roles, field == "css")
    if (!is.null(problem)) return(problem)
  }
  NULL
}

#' Read colour channels without treating numeric values as R palette indices
#' @noRd
theme_channels <- function(x) {
  # This union is validated here once and reused for conversion and contrast.
  if (is.numeric(x) && isTRUE(checkmate::check_numeric(x, len = 3, lower = 0, upper = 255, any.missing = FALSE))) {
    return(c(x, 1))
  }
  if (!isTRUE(checkmate::check_string(x, min.chars = 1))) {
    return(NULL)
  }
  if (grepl("^rgba?\\(", x, ignore.case = TRUE)) {
    match <- regmatches(x, regexec("^(rgb|rgba)\\((.*)\\)$", x, ignore.case = TRUE))[[1]]
    if (!length(match)) {
      return(NULL)
    }
    parts <- trimws(strsplit(match[[3]], ",", fixed = TRUE)[[1]])
    count <- if (tolower(match[[2]]) == "rgb") 3L else 4L
    if (
      length(parts) != count ||
        grepl(",\\s*\\)$", x, perl = TRUE) ||
        any(
          !grepl("^[+-]?(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)(?:e[+-]?[0-9]+)?$", parts, perl = TRUE, ignore.case = TRUE)
        )
    ) {
      return(NULL)
    }
    channels <- as.numeric(parts)
    if (
      any(!is.finite(channels)) || any(channels < 0) || any(channels[1:3] > 255) || (count == 4L && channels[[4]] > 1)
    ) {
      return(NULL)
    }
    return(if (count == 3L) c(channels, 1) else channels)
  }
  # bslib can return short hex ("#000"), which col2rgb() rejects on older R; expand it for every supported R.
  if (grepl("^#[0-9a-fA-F]{3,4}$", x)) {
    x <- paste0("#", paste(rep(strsplit(substring(x, 2), "")[[1]], each = 2), collapse = ""))
  }
  channels <- tryCatch(grDevices::col2rgb(x, alpha = TRUE), error = function(error) NULL)
  if (is.null(channels)) {
    return(NULL)
  }
  c(channels[1:3, 1], channels[4, 1] / 255)
}

#' Convert a user colour to the forms the mascot supports
#' @noRd
theme_colour <- function(x, role) {
  checkmate::assert_string(role)
  # x is a colour union; theme_channels() is the shared validation and conversion seam.
  channels <- theme_channels(x)
  if (is.null(channels)) {
    cli::cli_abort(
      paste0(
        "Colour for role {.val {role}} is invalid: {.val {paste(deparse(x), collapse = ' ')}}; ",
        "use a colour name, hex, rgb()/rgba() string or three RGB numbers in 0-255."
      ),
      class = "mascot_error"
    )
  }
  if (channels[[4]] == 1 && all(channels[1:3] == floor(channels[1:3]))) {
    return(grDevices::rgb(channels[[1]], channels[[2]], channels[[3]], maxColorValue = 255))
  }
  paste0("rgba(", paste(format(channels, scientific = FALSE, trim = TRUE, digits = 15), collapse = ","), ")")
}

#' Measure contrast only; never change a supplied colour
#' @noRd
theme_contrast <- function(colour, background) {
  checkmate::assert_string(colour)
  checkmate::assert_string(background)
  foreground <- theme_channels(colour)
  back <- theme_channels(background)[1:3] / 255
  rgb <- foreground[1:3] / 255 * foreground[[4]] + back * (1 - foreground[[4]])
  luminance <- function(channels) {
    checkmate::assert_numeric(channels, len = 3, lower = 0, upper = 1)
    sum(ifelse(channels <= 0.04045, channels / 12.92, ((channels + 0.055) / 1.055)^2.4) * c(0.2126, 0.7152, 0.0722))
  }
  values <- c(luminance(rgb), luminance(back))
  (max(values) + 0.05) / (min(values) + 0.05)
}

#' Prepare one theme for the browser while keeping its brand source for swaps
#' @noRd
as_theme_arg <- function(x, call, character = NULL) {
  checkmate::assert_environment(call)
  character_catalogue_assert(character, nullable = TRUE)
  problem <- theme_problem(x, if (is.null(character)) NULL else colour_role_registry(character))
  if (is.null(problem) && is.null(character)) {
    palette <- if (is.character(x)) {
      x
    } else if (inherits(x, "mascot_theme")) {
      x$palette
    }
    if (!is.null(palette) && !grepl("^[a-z][a-z0-9_]*$", palette)) {
      problem <- paste0(
        "`theme` must name a lowercase palette id; ",
        encodeString(palette, quote = '\"'),
        " is not a palette id."
      )
    }
  }
  if (!is.null(problem)) {
    cli::cli_abort("{problem}", call = call, class = "mascot_error")
  }
  if (is.null(x)) {
    return(NULL)
  }
  if (is.character(x)) {
    x <- mascot_theme(palette = x)
  }
  brand <- NULL
  backgrounds <- c(light = "#ffffff", dark = "#212529")
  if (inherits(x, "bs_theme")) {
    variables <- bslib::bs_get_variables(x, c("primary", "secondary"))
    brand <- lapply(c("primary", "secondary"), function(slot) theme_colour(variables[[slot]], slot))
    names(brand) <- c("primary", "secondary")
    backgrounds <- preview_surfaces(x)$background
    for (mode in names(backgrounds)) {
      for (slot in names(brand)) {
        if (contrast_warnings() && theme_contrast(brand[[slot]], backgrounds[[mode]]) < 3) {
          cli::cli_warn(
            paste0(
              "Brand colour {.val {slot}} in {mode} mode has contrast below 3:1 against ",
              "{.val {backgrounds[[mode]]}}; the colour is kept."
            ),
            class = c("mascot_contrast", "mascot_warning"),
            call = call
          )
        }
      }
    }
    x <- mascot_theme()
  } else if (!inherits(x, "mascot_theme")) {
    x <- structure(list(palette = NULL, light = x, dark = x, mode = "auto", css = NULL), class = "mascot_theme")
  }
  roles <- if (is.null(character)) NULL else colour_role_registry(character)
  convert <- function(map, field) {
    checkmate::assert_list(map, null.ok = TRUE)
    checkmate::assert_string(field)
    problem <- theme_map_problem(map, paste0("theme$", field), roles, field == "css")
    if (!is.null(problem)) {
      cli::cli_abort("{problem}", call = call, class = "mascot_error")
    }
    if (!length(map)) {
      return(NULL)
    }
    value <- map
    for (role in names(map)) {
      if (field != "css") {
        value[[role]] <- theme_colour(map[[role]], role)
        if (contrast_warnings() && theme_contrast(value[[role]], backgrounds[[field]]) < 3) {
          cli::cli_warn(
            paste0(
              "Colour for role {.val {role}} in {field} mode has contrast below 3:1 against ",
              "{.val {backgrounds[[field]]}}; the colour is kept."
            ),
            class = c("mascot_contrast", "mascot_warning"),
            call = call
          )
        }
      }
    }
    value
  }
  value <- list(
    light = convert(x$light, "light"),
    dark = convert(x$dark, "dark"),
    mode = x$mode,
    css = convert(x$css, "css"),
    brand = brand
  )
  if (!is.null(x$palette)) {
    value$palette <- x$palette
    value$palette_colours <- list(light = NULL, dark = NULL)
    if (!is.null(character)) {
      data <- character_colour_data(character)
      problem <- theme_palette_problem(x$palette, data)
      if (!is.null(problem)) {
        cli::cli_abort("{problem}", call = call, class = "mascot_error")
      }
      value$palette_colours <- theme_palette_colours(x$palette, data)
    }
  }
  value
}

#' A data-only script block; closing tags cannot escape it
#' @noRd
theme_tag <- function(theme) {
  checkmate::assert_list(theme, null.ok = TRUE)
  if (is.null(theme)) {
    return(NULL)
  }
  text <- as.character(jsonlite::toJSON(theme, auto_unbox = TRUE, null = "null"))
  htmltools::tags$script(
    type = "application/json",
    `data-mascot-theme` = "",
    htmltools::HTML(gsub("</", "<\\/", text, fixed = TRUE))
  )
}

#' Optional bslib availability, separate from reading a theme: installed and 0.7.0 or later, the version
#' DESCRIPTION asks for (`body-bg-dark` and `popover()` came in 0.6.0, `input_task_button()` in 0.7.0)
#' @noRd
theme_has_bslib <- function() {
  requireNamespace("bslib", quietly = TRUE) && bslib_version() >= "0.7.0"
}

#' The installed bslib version; called only after requireNamespace() has found bslib
#' @noRd
bslib_version <- function() {
  utils::packageVersion("bslib")
}

#' @export
#' @noRd
format.mascot_theme <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_theme")
  })
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_theme <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_theme")
  })
  cli::cat_line(format(x))
  invisible(x)
}

#' Decide whether to emit R contrast warnings in this context
#' @noRd
contrast_warnings <- function(always = FALSE) {
  checkmate::assert_flag(always)
  override <- getOption("mascot.contrast_warnings")
  if (isTRUE(override) || identical(override, FALSE)) {
    return(override)
  }
  if (!is.null(override) && !isTRUE(contrast_warning_state$warned)) {
    contrast_warning_state$warned <- TRUE
    cli::cli_warn(
      "Option {.code mascot.contrast_warnings} must be TRUE or FALSE; using the default.",
      class = "mascot_warning"
    )
  }
  always || shiny::in_devmode()
}

# Session-local diagnostic state; no warning or option changes on load.
contrast_warning_state <- new.env(parent = emptyenv())

#' Explain an unavailable palette against a known character
#' @noRd
theme_palette_problem <- function(palette, data) {
  checkmate::assert_string(palette, min.chars = 1)
  checkmate::assert_list(data)
  valid <- character_palette_names(data)
  if (palette %in% c("original", valid)) {
    return(NULL)
  }
  paste0(
    "Unknown palette ",
    encodeString(palette, quote = '\"'),
    " for character ",
    encodeString(data$id, quote = '\"'),
    ". Choose ",
    paste(encodeString(valid, quote = '\"'), collapse = ", "),
    ".",
    theme_role_hint(palette, valid),
    theme_palette_owner_hint(palette, data)
  )
}

#' Name the other characters that have a palette of this name
#'
#' Each palette belongs to its own character, so an unknown palette that another
#' character has is worth a pointer.
#' @noRd
theme_palette_owner_hint <- function(palette, data) {
  checkmate::assert_string(palette, min.chars = 1)
  checkmate::assert_list(data)
  owners <- character_palette_owners(palette, data$id)
  if (!length(owners)) {
    return("")
  }
  paste0(
    if (length(owners) > 1L) " Characters " else " Character ",
    paste(encodeString(owners, quote = '\"'), collapse = ", "),
    if (length(owners) > 1L) " have" else " has",
    " a palette called ",
    encodeString(palette, quote = '\"'),
    "; each palette belongs to its own character."
  )
}

#' Resolve palette leaders once, keeping explicit role maps separate for swaps
#' @noRd
theme_palette_colours <- function(palette, data) {
  checkmate::assert_string(palette, min.chars = 1)
  checkmate::assert_list(data)
  problem <- theme_palette_problem(palette, data)
  if (!is.null(problem)) {
    cli::cli_abort("{problem}", class = "mascot_error")
  }
  definition <- character_palettes(data)[[palette]]
  maps <- lapply(c("light", "dark"), function(mode) {
    map <- if (mode == "dark" && !is.null(definition$dark)) definition$dark else definition$light
    if (!length(map)) {
      return(NULL)
    }
    value <- lapply(names(map), function(role) theme_colour(map[[role]], role))
    names(value) <- names(map)
    value
  })
  names(maps) <- c("light", "dark")
  maps
}
