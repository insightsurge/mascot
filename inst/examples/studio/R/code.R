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
  as.call(c(as.name(fn), args))
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

code_motion <- function(animate, swap) {
  helper <- helper_call("mascot_motion", animate = if (!animate) FALSE, swap = if (!swap) FALSE)
  code_pair(if (swap) animate else helper, helper)
}

code_size <- function(size, small_screen) {
  helper <- helper_call(
    "mascot_size",
    size,
    small_screen = small_screen
  )
  code_pair(if (length(helper) == 2) size else helper, helper)
}

code_placement <- function(position, minimise, drag = FALSE) {
  checkmate::assert_choice(position, c("inline", "top-left", "top-right", "bottom-left", "bottom-right"))
  checkmate::assert_flag(minimise)
  checkmate::assert(checkmate::check_flag(drag), checkmate::check_choice(drag, c("snap", "free")), .var.name = "drag")
  helper <- helper_call(
    "mascot_placement",
    position,
    minimise = if (minimise) TRUE,
    drag = if (!identical(drag, FALSE)) drag
  )
  fields <- list(position = position, minimise = if (minimise) TRUE, drag = if (!identical(drag, FALSE)) drag)
  short <- if (minimise || !identical(drag, FALSE)) named_call("list", Filter(Negate(is.null), fields)) else position
  code_pair(short, helper)
}

code_menu <- function(items) {
  if (!length(items)) {
    return(code_pair(quote(mascot_popup_menu())))
  }
  vector <- named_call("c", items)
  code_pair(vector, helper_call("mascot_popup_menu", vector))
}

code_theme <- function(source, light, dark, mode, css_roles, primary, secondary) {
  if (source == "own") {
    return(code_pair(quote(mascot_theme())))
  }
  if (source == "bslib") {
    return(code_pair(helper_call("bs_theme", primary = primary, secondary = secondary)))
  }
  css <- if (length(css_roles)) stats::setNames(rep("--studio-accent", length(css_roles)), css_roles)
  helper <- helper_call(
    "mascot_theme",
    light = if (length(light)) named_call("list", light),
    dark = if (length(dark)) named_call("list", dark),
    mode = if (mode != "auto") mode,
    css = if (length(css)) named_call("list", css)
  )
  # A plain named list uses one set of colours in both modes.
  same <- length(light) && identical(light, dark) && mode == "auto" && !length(css)
  code_pair(if (same) named_call("list", light) else helper, helper)
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
  if (identical(make.names(name), name)) name else paste0("`", name, "`")
}

format_call <- function(fn, args) {
  format_expr(as.call(c(as.name(fn), args)))
}

# Picks the shortcut or helper form of every setting.
pick_style <- function(pairs, style) {
  lapply(pairs, function(pair) pair[[style]])
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

# A whole app to paste into a new app.R: Tessa starts plain, and a button applies the settings.
whole_app_code <- function(update, menu_handler, packages, css_value = NULL) {
  indent <- function(text, by) gsub("\n", paste0("\n", strrep(" ", by)), text, fixed = TRUE)
  paste0(
    paste0("library(", packages, ")", collapse = "\n"),
    "\n\nui <- fluidPage(\n",
    if (!is.null(css_value)) sprintf("  tags$style(\":root { --studio-accent: %s; }\"),\n", css_value),
    "  mascot(id = \"helper\"),\n",
    "  actionButton(\"apply\", \"Apply my settings\")\n)\n\n",
    "server <- function(input, output, session) {\n",
    "  observeEvent(input$apply, {\n    ",
    indent(update, 4),
    "\n  })\n",
    if (!is.null(menu_handler)) paste0("  ", indent(menu_handler, 2), "\n"),
    "}\n\nshinyApp(ui, server)"
  )
}
