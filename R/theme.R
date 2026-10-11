#' Set a mascot's colours and light or dark mode
#'
#' Unset roles follow the first supplied or filled leader declared by the character.
#' With no supplied leader they keep their original colours. Use
#' [mascot_colour_roles()] to find the roles for a character. A plain named list
#' supplied to [mascot()] or [updateMascot()] uses one set in every mode. A
#' [bslib::bs_theme()] fills the character's declared brand leaders with its primary
#' and secondary colours; `_brand.yml` can be supplied through `bs_theme(brand =)`.
#'
#' A theme survives a character swap: follow rules are resolved again and roles
#' absent from the incoming character are ignored. An empty helper restores the
#' character's own colours. A chosen colour below 3:1 contrast warns and is kept
#' (see "Contrast warnings" below). Supplied colours are kept exactly. Derived
#' shades keep the hue, with calibrated lightness and saturation shifts. Tessa's
#' original leaders reproduce derived colours within
#' 3 units per RGB channel (0--255). Brand colours are the same in both modes.
#'
#' @section Contrast warnings:
#' A warning appears when a colour chosen by the developer (light, dark, or a
#' [bslib::bs_theme()] brand colour) has contrast below 3:1 against the page
#' background (white in light mode, `#212529` in dark mode, or the `bslib`
#' theme's backgrounds). Contrast is checked when [mascot()] builds the UI,
#' when [updateMascot()] applies colours with `theme = `, and collected into the
#' contrast table by [mascot_preview()]; the character's own colours never warn;
#' the colour is always kept.
#'
#' The warning appears in the R console or server log, in every mode (not only
#' Shiny developer mode); app visitors never see it. CSS-variable colours
#' (`css =`) are checked in the browser and warn in the browser console.
#'
#' These warnings have the class `mascot_contrast`. To silence only these
#' warnings:
#' ```r
#' withCallingHandlers(
#'   mascot(id = "helper", theme = list(rim = "#f5e6c8")),
#'   mascot_contrast = function(w) invokeRestart("muffleWarning")
#' )
#' ```
#' Note that `suppressWarnings()` also works but hides every warning.
#' @param light,dark Named lists of colour roles, or `NULL` (the default) for the
#'   character's colours in that mode. Values are colour names, hex strings,
#'   [grDevices::rgb()] output, CSS `rgb()` or `rgba()` strings, or three red,
#'   green and blue numbers in 0--255. Single numeric palette indices are not
#'   accepted. Roles use snake case; `light`, `dark` and `default` are reserved.
#' @param mode One of `"auto"` (the default), `"light"` or `"dark"`.
#'   Auto follows the nearest valid `data-bs-theme` in the original source
#'   context, then Quarto's body classes. With no page signal it uses light.
#'   Explicit light or dark always wins. `NULL` is not accepted.
#' @param css A named list mapping colour roles to CSS variable names such as
#'   `list(body = "--team-blue")`, or `NULL` (the default) for no CSS source.
#'   This source is experimental. CSS entries override light and dark entries
#'   for the same role. Missing or invalid variables use the character's own
#'   colour and warn in the browser console; low contrast also warns there and
#'   keeps the colour. Variables are read from the original source context,
#'   including when the mascot floats.
#' @returns A `mascot_theme` object describing colours, CSS sources and mode.
#' @family mascot helpers
#' @seealso [mascot_colour_roles()], [mascot()], [updateMascot()],
#'   [mascot_motion()] for a complete Shiny settings example
#' @evalRd paste0(
#'   "\\section{Experimental CSS source}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nCSS variables are resolved by the browser, so R cannot check their values.\n}"
#' )
#' @export
#' @examples
#' mascot_theme()
#' mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"), mode = "auto")
#' mascot_theme(css = list(body = "--team-blue"))
#' mascot(id = "helper", theme = list(body = "#1f6feb"))
#' @examplesIf requireNamespace("bslib", quietly = TRUE)
#' mascot(id = "brand", theme = bslib::bs_theme(primary = "#1f6feb"))
mascot_theme <- function(light = NULL, dark = NULL, mode = "auto", css = NULL) {
  checkmate::assert_list(light, names = "unique", null.ok = TRUE)
  checkmate::assert_list(dark, names = "unique", null.ok = TRUE)
  checkmate::assert_choice(mode, c("light", "dark", "auto"))
  checkmate::assert_list(css, names = "unique", null.ok = TRUE)
  value <- structure(
    list(light = light, dark = dark, mode = mode, css = css),
    class = "mascot_theme"
  )
  check_arg(value, "theme", environment())
  value
}

#' Validate a colour or CSS map without throwing at runtime
#' @noRd
theme_map_problem <- function(x, arg, roles, css = FALSE) {
  checkmate::assert_string(arg)
  checkmate::assert_character(roles, any.missing = FALSE)
  checkmate::assert_flag(css)
  # Union input uses check_* so runtime errors can become warnings.
  if (is.null(x)) {
    return(NULL)
  }
  if (!isTRUE(checkmate::check_list(x, names = "unique")) || (length(x) && is.null(names(x)))) {
    return(paste0("`", arg, "` must be a named list with unique colour roles, or NULL."))
  }
  wrong <- names(x)[!names(x) %in% roles | names(x) %in% c("light", "dark", "default")]
  if (length(wrong)) {
    return(paste0(
      "`",
      arg,
      "` has unknown or reserved colour roles: ",
      paste(encodeString(wrong, quote = '"'), collapse = ", "),
      ". Valid roles: ",
      paste(roles, collapse = ", "),
      "."
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

#' Validate shortcuts and complete helper objects without changing anything
#' @noRd
theme_problem <- function(x) {
  # Union input uses the same non-throwing boundary as size and placement.
  if (is.null(x)) {
    return(NULL)
  }
  if (inherits(x, "bs_theme")) {
    if (!theme_has_bslib()) {
      return("`theme` needs the bslib package for a bs_theme() object.")
    }
    return(NULL)
  }
  roles <- colour_role_registry()
  if (!inherits(x, "mascot_theme")) {
    return(theme_map_problem(x, "theme", roles))
  }
  fields <- c("light", "dark", "mode", "css")
  if (!isTRUE(checkmate::check_list(x, names = "unique")) || !setequal(names(x), fields) || length(x) != 4L) {
    return("`theme` must be a mascot_theme() object with light, dark, mode and css fields.")
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
  channels <- tryCatch(grDevices::col2rgb(x, alpha = TRUE), error = function(error) NULL)
  if (is.null(channels)) {
    return(NULL)
  }
  c(channels[1:3, 1], channels[4, 1] / 255)
}

#' Convert a user colour to the engine's supported forms
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
      )
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

#' Resolve one theme for the wire while retaining its brand source for swaps
#' @noRd
as_theme_arg <- function(x, call, character = NULL) {
  checkmate::assert_environment(call)
  checkmate::assert_choice(character, builtin_characters()$id, null.ok = TRUE)
  check_arg(x, "theme", call)
  if (is.null(x)) {
    return(NULL)
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
        if (theme_contrast(brand[[slot]], backgrounds[[mode]]) < 3) {
          cli::cli_warn(
            paste0(
              "Brand colour {.val {slot}} in {mode} mode has contrast below 3:1 against ",
              "{.val {backgrounds[[mode]]}}; the colour is kept."
            ),
            class = "mascot_contrast",
            call = call
          )
        }
      }
    }
    x <- mascot_theme()
  } else if (!inherits(x, "mascot_theme")) {
    x <- mascot_theme(light = x, dark = x)
  }
  roles <- colour_role_registry(character)
  engine <- unique(unlist(lapply(
    if (is.null(character)) builtin_characters()$id else character,
    function(id) names(character_colour_data(id)$colours)
  )))
  convert <- function(map, field) {
    checkmate::assert_list(map, null.ok = TRUE)
    checkmate::assert_string(field)
    problem <- theme_map_problem(map, paste0("theme$", field), roles, field == "css")
    if (!is.null(problem)) {
      cli::cli_abort("{problem}", call = call)
    }
    if (!length(map)) {
      return(NULL)
    }
    value <- map
    for (role in names(map)) {
      if (field != "css") {
        value[[role]] <- theme_colour(map[[role]], role)
        if (theme_contrast(value[[role]], backgrounds[[field]]) < 3) {
          cli::cli_warn(
            paste0(
              "Colour for role {.val {role}} in {field} mode has contrast below 3:1 against ",
              "{.val {backgrounds[[field]]}}; the colour is kept."
            ),
            class = "mascot_contrast",
            call = call
          )
        }
      }
    }
    names(value) <- engine[match(names(map), colour_role_names(engine))]
    value
  }
  list(
    light = convert(x$light, "light"),
    dark = convert(x$dark, "dark"),
    mode = x$mode,
    css = convert(x$css, "css"),
    brand = brand
  )
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

#' Optional bslib availability, separate from reading a theme
#' @noRd
theme_has_bslib <- function() {
  requireNamespace("bslib", quietly = TRUE)
}

#' @export
#' @noRd
format.mascot_theme <- function(x, ...) {
  checkmate::assert_class(x, "mascot_theme")
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_theme <- function(x, ...) {
  checkmate::assert_class(x, "mascot_theme")
  cli::cat_line(format(x))
  invisible(x)
}
