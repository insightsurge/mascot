# Each setting is kept as R code, not as a value: the studio evaluates the code to update
# the mascot and prints the same code for you to copy. Every builder returns two forms: the
# plain shortcut ("happy") and the helper (mascot_mood("happy")). Both give the same mascot.

code_pair <- function(short, helper = short) {
  list(short = short, helper = helper)
}

# c(finish = "Finish review") or list(body = "#1f6feb") as a call, from a named vector.
named_call <- function(fn, values) {
  as.call(c(as.name(fn), as.list(values)))
}

helper_call <- function(fn, ...) {
  args <- Filter(Negate(is.null), list(...))
  as.call(c(list(str2lang(fn)), args))
}

code_character <- function(name) {
  code_pair(name, helper_call("mascot_character", name))
}

code_mood <- function(name) {
  code_pair(name, helper_call("mascot_mood", name))
}

code_status <- function(text) {
  if (!nzchar(trimws(text))) {
    return(code_pair(quote(mascot_status())))
  }
  code_pair(text, helper_call("mascot_status", text))
}

code_bubble <- function(text, html, duration, closable) {
  if (!nzchar(trimws(text))) {
    return(code_pair(quote(mascot_bubble())))
  }
  value <- if (html) call("HTML", text) else text
  helper <- helper_call(
    "mascot_bubble",
    value,
    duration = if (!identical(duration, 5)) duration,
    closable = if (!closable) FALSE
  )
  code_pair(if (length(helper) == 2) value else helper, helper)
}

code_gesture <- function(name) {
  code_pair(name, helper_call("mascot_gesture", name))
}

code_motion <- function(
  idle = "follow",
  mood_change = "follow",
  gestures = "follow",
  swap = "follow",
  minimising = "follow",
  restoring = "follow",
  messages = "follow",
  others = TRUE
) {
  flags <- list(
    idle = idle,
    mood_change = mood_change,
    gestures = gestures,
    swap = swap,
    minimising = minimising,
    restoring = restoring
  )
  args <- lapply(flags, function(value) {
    checkmate::assert_choice(value, c("follow", "true", "false"))
    if (value != "follow") identical(value, "true")
  })
  checkmate::assert_character(messages, any.missing = FALSE, null.ok = TRUE)
  checkmate::assert_flag(others)
  if (length(messages) > 1L && any(messages %in% c("follow", "all"))) {
    cli::cli_abort("Choose Follow others, All, or only panel names.")
  }
  args$messages <- if (!identical(messages, "follow")) {
    if (!length(messages)) {
      FALSE
    } else if (identical(messages, "all")) {
      TRUE
    } else {
      as.call(c(list(quote(c)), as.list(messages)))
    }
  }
  if (!others) {
    args$others <- FALSE
  }
  helper <- do.call(helper_call, c(list("mascot_motion_settings"), args))
  code_pair(if (length(helper) == 1L) TRUE else helper, helper)
}

code_size <- function(size, small_screen = "auto") {
  if (identical(small_screen, "auto")) {
    helper <- helper_call("mascot_size", size)
    code_pair(if (length(helper) == 2) size else helper, helper)
  } else if (is.null(small_screen)) {
    helper <- as.call(list(quote(mascot_size), size, small_screen = NULL))
    code_pair(helper, helper)
  } else {
    helper <- helper_call("mascot_size", size, small_screen = small_screen)
    code_pair(helper, helper)
  }
}

code_placement <- function(position = "bottom-right", ..., minimise = TRUE, drag = "none") {
  checkmate::assert_choice(position, c("inline", "top-left", "top-right", "bottom-left", "bottom-right"))
  checkmate::assert_flag(minimise)
  checkmate::assert_choice(drag, c("none", "snap", "free"))
  if (...length() > 0L) {
    cli::cli_abort("Name {.arg minimise} and {.arg drag}.", class = "mascot_error")
  }
  # An inline mascot ignores minimise and drag (and says so), so the code leaves them out.
  if (position == "inline") {
    minimise <- TRUE
    drag <- "none"
  }
  extras <- list(minimise = if (!minimise) FALSE, drag = if (!identical(drag, "none")) drag)
  helper <- helper_call(
    "mascot_placement",
    if (!identical(position, "bottom-right")) position,
    minimise = extras$minimise,
    drag = extras$drag
  )
  fields <- c(list(position = position), extras)
  short <- if (!minimise || !identical(drag, "none")) named_call("list", Filter(Negate(is.null), fields)) else position
  code_pair(short, helper)
}

# A menu has no shortcut: a named vector is not a click, so both forms use the helper.
code_menu <- function(items, direction = "auto", label = "", tooltip = TRUE) {
  vector <- if (length(items)) named_call("c", items)
  has_label <- nzchar(trimws(label))
  helper <- helper_call(
    "mascot_popup_menu",
    vector,
    direction = if (!identical(direction, "auto")) direction,
    label = if (has_label) label,
    tooltip = if (!tooltip && has_label) FALSE
  )
  code_pair(helper)
}

# An action's shortcut is its label; the helper also carries a hidden tooltip or a disabled state.
code_action <- function(label, tooltip = TRUE, disabled = FALSE) {
  if (!nzchar(trimws(label))) {
    return(code_pair(quote(mascot_action())))
  }
  helper <- helper_call("mascot_action", label, tooltip = if (!tooltip) FALSE, disabled = if (disabled) TRUE)
  code_pair(if (tooltip && !disabled) label else helper, helper)
}

code_theme <- function(source, light, dark, mode, css_roles, primary, secondary, palette = "original") {
  checkmate::assert_choice(source, c("own", "mascot", "bslib"))
  checkmate::assert_character(light, any.missing = FALSE, null.ok = TRUE)
  checkmate::assert_character(dark, any.missing = FALSE, null.ok = TRUE)
  checkmate::assert_choice(mode, c("auto", "light", "dark"))
  checkmate::assert_character(css_roles, any.missing = FALSE, null.ok = TRUE)
  checkmate::assert_string(primary, null.ok = TRUE)
  checkmate::assert_string(secondary, null.ok = TRUE)
  checkmate::assert_string(palette, min.chars = 1)
  if (source == "own") {
    helper <- helper_call("mascot_theme", palette = if (palette != "original") palette, mode = if (mode != "auto") mode)
    return(code_pair(if (palette != "original" && mode == "auto") palette else helper, helper))
  }
  if (source == "bslib") {
    return(code_pair(helper_call("bslib::bs_theme", primary = primary, secondary = secondary)))
  }
  css <- if (length(css_roles)) stats::setNames(rep("--studio-accent", length(css_roles)), css_roles)
  helper <- helper_call(
    "mascot_theme",
    palette = if (palette != "original") palette,
    light = if (length(light)) named_call("list", light),
    dark = if (length(dark)) named_call("list", dark),
    mode = if (mode != "auto") mode,
    css = if (length(css)) named_call("list", css)
  )
  # A plain named list uses one set of colours in both modes.
  same <- length(light) && identical(light, dark) && mode == "auto" && !length(css)
  plain_palette <- palette != "original" && !length(light) && !length(dark) && mode == "auto" && !length(css)
  code_pair(
    if (plain_palette) {
      palette
    } else if (same && palette == "original") {
      named_call("list", light)
    } else {
      helper
    },
    helper
  )
}

# Raw strings avoid escaped quotes in copied HTML and other user text. R permits
# paired (), [] or {} delimiters with any number of dashes outside the brackets.
format_string <- function(text) {
  checkmate::assert_string(text, na.ok = FALSE)
  if (!grepl('"', text, fixed = TRUE)) {
    return(deparse1(text, width.cutoff = 500))
  }
  dash <- ""
  while (grepl(paste0(")", dash, '"'), text, fixed = TRUE)) {
    dash <- paste0(dash, "-")
  }
  paste0('r"', dash, "(", text, ")", dash, '"')
}

# Lays out a call on one line when it fits in 80 characters, else one argument per line,
# nesting the same way for long inner calls such as mascot_theme(light = list(...)).
format_expr <- function(expr, indent = 0) {
  if (is.character(expr)) {
    values <- vapply(expr, format_string, character(1))
    return(if (length(values) == 1) values else paste0("c(", paste(values, collapse = ", "), ")"))
  }
  if (!is.call(expr) || length(expr) < 2) {
    return(deparse1(expr, width.cutoff = 500))
  }
  args <- as.list(expr)[-1]
  names <- if (is.null(names(args))) rep("", length(args)) else names(args)
  parts <- vapply(
    seq_along(args),
    function(i) {
      value <- format_expr(args[[i]], indent + 2)
      if (nzchar(names[i])) paste(arg_name(names[i]), "=", value) else value
    },
    character(1)
  )
  fn <- deparse1(expr[[1]])
  one_line <- paste0(fn, "(", paste(parts, collapse = ", "), ")")
  if (!grepl("\n", one_line, fixed = TRUE) && indent + nchar(one_line) <= 80) {
    return(one_line)
  }
  pad <- strrep(" ", indent + 2)
  paste0(fn, "(\n", pad, paste(parts, collapse = paste0(",\n", pad)), "\n", strrep(" ", indent), ")")
}

# A name as R needs it on the left of "=": finish-review becomes `finish-review`.
arg_name <- function(name) {
  deparse1(as.name(name), backtick = TRUE)
}

format_call <- function(fn, args) {
  format_expr(as.call(c(list(str2lang(fn)), args)))
}

# Picks the shortcut or helper form of every setting.
pick_style <- function(pairs, style) {
  if (length(style) > 1L) {
    style <- as.list(style)
  }
  lapply(names(pairs), function(arg) {
    pairs[[arg]][[if (length(style) == 1L) style else style[[arg]] %||% style[[".default"]]]]
  }) |>
    stats::setNames(names(pairs))
}

# The observeEvent() that answers a click: the action's, or one branch per menu item, for the app to fill in.
click_handler_code <- function(click) {
  value <- eval(click)
  if (inherits(value, "mascot_popup_menu")) {
    return(menu_handler_code(value$items))
  }
  if (is.null(value$label)) {
    return(NULL)
  }
  sprintf("observeEvent(input$helper_click, {\n  # What \"%s\" does in your app.\n})", value$label)
}

# The observeEvent() that answers the menu: one branch per item, for the app to fill in.
menu_handler_code <- function(items) {
  if (!length(items)) {
    return(NULL)
  }
  branches <- vapply(
    names(items),
    function(id) sprintf("    %s = {\n      # What \"%s\" does in your app.\n    }", arg_name(id), items[[id]]),
    character(1)
  )
  paste0(
    "observeEvent(input$helper_menu, {\n  switch(\n    input$helper_menu,\n",
    paste(branches, collapse = ",\n"),
    "\n  )\n})"
  )
}

# Indent source lines while preserving every line inside a multiline string token.
indent_code <- function(text, by) {
  checkmate::assert_string(text)
  checkmate::assert_count(by)
  tokens <- utils::getParseData(parse(text = text, keep.source = TRUE))
  strings <- tokens[tokens$token == "STR_CONST" & tokens$line2 > tokens$line1, ]
  protected <- unlist(Map(function(first, last) seq.int(first + 1L, last), strings$line1, strings$line2))
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  indent <- !seq_along(lines) %in% protected
  lines[indent] <- paste0(strrep(" ", by), lines[indent])
  paste(lines, collapse = "\n")
}

# A whole app to paste into app.R: user settings in the UI, one server update to try.
whole_app_code <- function(ui, click_handler, packages, css_value = NULL) {
  checkmate::assert_string(ui)
  checkmate::assert_string(click_handler, null.ok = TRUE)
  checkmate::assert_character(packages, min.chars = 1, any.missing = FALSE)
  checkmate::assert_string(css_value, null.ok = TRUE)
  paste0(
    paste0("library(", packages, ")", collapse = "\n"),
    "\n\nui <- fluidPage(\n",
    if (!is.null(css_value)) sprintf("  tags$style(\":root { --studio-accent: %s; }\"),\n", css_value),
    indent_code(ui, 2),
    ",\n",
    "  actionButton(\"celebrate\", \"Celebrate\")\n)\n\n",
    "server <- function(input, output, session) {\n",
    "  # One button demonstrates a single server update.\n",
    "  observeEvent(input$celebrate, {\n",
    '    update_mascot("helper", mood = "celebrating", bubble = "Review complete.")',
    "\n  })\n",
    if (!is.null(click_handler)) paste0(indent_code(click_handler, 2), "\n"),
    "}\n\nshinyApp(ui, server)"
  )
}
