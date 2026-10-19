# Building blocks for the studio's UI: argument fields with their explanations, function
# cards for the guide, and the small diagrams that explain each category.

# What the studio keeps about a function itself (R/guide.R). Its words come from the help page: see
# help_page() in R/help.R.
the_guide <- function(fn) {
  checkmate::assert_string(fn)
  checkmate::assert_choice(fn, names(playground_guide))
  playground_guide[[fn]]
}

# Read the expression, without evaluating defaults such as Shiny's reactive domain.
argument_default <- function(fn, arg) {
  checkmate::assert_string(fn)
  checkmate::assert_string(arg)
  arguments <- formals(getExportedValue("mascot", fn))
  checkmate::assert_choice(arg, names(arguments))
  value <- deparse1(arguments[[arg]])
  if (nzchar(value)) {
    value
  } else if (arg == "...") {
    "empty"
  } else {
    "none: required"
  }
}

category_functions <- function(category) {
  names(Filter(function(entry) identical(entry$category, category), playground_guide))
}

try_button <- function(event, value, label, class = "btn-outline-primary") {
  tags$button(type = "button", class = paste("btn btn-sm", class), `data-event` = event, `data-value` = value, label)
}

# The popover behind an argument chip: the argument's help text (what it accepts, what NULL means and
# the details), its default read from the function's formals and, when the help page has one, an
# example that supplies the argument.
arg_popover_body <- function(fn, arg) {
  checkmate::assert_string(fn)
  checkmate::assert_string(arg)
  help <- help_arg(fn, arg)
  example <- help_arg_example(fn, arg)
  tagList(
    div(class = "pg-help", if (is.null(help)) tags$p(help_page(fn)$title) else help),
    tags$p(tags$strong("Default: "), tags$code(argument_default(fn, arg))),
    if (!is.null(example)) {
      tagList(tags$p(tags$strong("Example from the help page:")), code_block(example, "pg-code-small"))
    }
  )
}

# One line for the control: the first sentence of the argument's help text.
arg_hint <- function(fn, arg) {
  checkmate::assert_string(fn)
  checkmate::assert_string(arg)
  help <- help_arg(fn, arg)
  if (is.null(help)) help_page(fn)$title else first_sentence(html_text(help))
}

arg_chip <- function(fn, arg) {
  trigger <- tags$button(
    type = "button",
    class = "pg-arg-chip",
    `aria-label` = paste("About the", arg, "argument of", fn),
    tags$code(arg),
    tags$span(class = "pg-info", "?")
  )
  popover(
    trigger,
    tagList(
      arg_popover_body(fn, arg),
      tags$button(
        type = "button",
        class = "btn btn-link btn-sm",
        `data-argument-help` = arg,
        `data-help-function` = fn,
        "Open this argument in inspector Help"
      )
    ),
    title = tags$code(paste0(fn, "(", arg, " =)")),
    options = list(customClass = "pg-help-popover")
  )
}

# One argument: its chip (click for the help text), the control, and a one-line hint.
arg_field <- function(fn, arg, input, note = NULL) {
  checkmate::assert_string(fn)
  checkmate::assert_string(arg)
  controls <- playground_controls[[fn]][[arg]]
  ids <- if (is.character(controls)) sub('^id="([^"]+)"$', "\\1", controls[startsWith(controls, 'id="')])
  div(
    class = "pg-field",
    `data-argument` = arg,
    `data-owner` = fn,
    `data-package-default` = argument_default(fn, arg),
    `data-default-input` = if (length(ids)) ids[[1]],
    div(
      class = "pg-field-head",
      arg_chip(fn, arg),
      tags$span(class = "pg-default", "default ", argument_default(fn, arg))
    ),
    div(class = "pg-hint", arg_hint(fn, arg)),
    shared_input_button(fn, arg),
    input,
    note
  )
}

# Markers let the category builders share their existing argument fields without remounting inputs.
fn_heading <- function(fn) {
  div(`data-function-heading` = fn)
}

inspector_function <- function(fn, ...) {
  div(
    class = "pg-inspector-function",
    `data-function` = fn,
    hidden = if (fn != "mascot_mood") NA,
    tags$h2(class = "pg-function-name", tags$code(paste0(fn, "()"))),
    div(class = "pg-fn-what", help_page(fn)$title),

    div(class = "pg-function-controls", ...)
  )
}

inspector_category <- function(title, value, ...) {
  # title and value retain the category builders' call shape; the index owns their headings.
  pieces <- list(...)
  groups <- list()
  fn <- NULL
  fields <- list()
  for (piece in pieces) {
    marker <- if (inherits(piece, "shiny.tag")) piece$attribs[["data-function-heading"]]
    if (!is.null(marker)) {
      if (!is.null(fn)) {
        groups[[fn]] <- do.call(inspector_function, c(list(fn), fields))
      }
      fn <- marker
      fields <- list()
    } else {
      fields <- c(fields, list(piece))
    }
  }
  if (!is.null(fn)) {
    groups[[fn]] <- do.call(inspector_function, c(list(fn), fields))
  }
  tagList(groups)
}

function_index <- function() {
  tags$nav(
    class = "pg-index",
    `aria-label` = "Functions by category",
    lapply(names(playground_categories), function(category) {
      tagList(
        tags$h2(`data-category` = category, playground_categories[[category]]$title),
        lapply(category_functions(category), function(fn) {
          bslib::tooltip(
            tags$button(
              type = "button",
              class = "pg-index-link",
              `data-event` = "select_function",
              `data-value` = fn,
              `aria-current` = if (fn == "mascot_mood") "true" else "false",
              tags$code(paste0(fn, "()")),
              tags$span(help_page(fn)$title)
            ),
            help_page(fn)$title,
            options = list(trigger = "hover")
          )
        })
      )
    })
  )
}

wiring_links <- function(fn) {
  shared <- setdiff(names(formals(getExportedValue("mascot", fn))), c("id", "...", "session"))
  lapply(shared, function(arg) {
    helper <- switch(arg, motion = "mascot_motion_settings", click = "mascot_action", paste0("mascot_", arg))
    arg_field(
      fn,
      arg,
      tags$p(
        class = "pg-hint",
        "Choose ",
        tags$a(
          href = "#",
          `data-event` = "select_function",
          `data-value` = helper,
          tags$code(paste0(helper, "()"))
        ),
        " in the function index to set this argument."
      )
    )
  })
}

colour_input <- function(id, value, label, ...) {
  tags$input(
    id = id,
    type = "color",
    class = "pg-colour form-control form-control-color",
    value = value,
    title = label,
    `aria-label` = label,
    ...
  )
}

# A pre block without the line breaks htmltools would add inside it.
code_block <- function(text, class = NULL, id = NULL) {
  tags$pre(id = id, class = class, tags$code(text), .noWS = "inside")
}

code_output <- function(id) {
  tagAppendAttributes(verbatimTextOutput(id), class = "pg-code")
}

copy_button <- function(target, label = "Copy") {
  tags$button(type = "button", class = "btn btn-sm btn-outline-primary pg-copy", `data-copy` = target, label)
}

# ---- The guide card -------------------------------------------------------------------------

# The function's signature, read from the installed package so it is never out of date.
signature <- function(fn) {
  arguments <- formals(get(fn, envir = asNamespace("mascot")))
  parts <- vapply(
    names(arguments),
    function(name) {
      # A required argument deparses to "".
      value <- deparse1(arguments[[name]])
      if (nzchar(value)) paste(name, "=", value) else name
    },
    character(1)
  )
  one_line <- paste0(fn, "(", paste(parts, collapse = ", "), ")")
  if (nchar(one_line) <= 70) one_line else paste0(fn, "(\n  ", paste(parts, collapse = ",\n  "), "\n)")
}

arg_block <- function(fn, arg) {
  checkmate::assert_string(fn)
  checkmate::assert_string(arg)
  div(
    class = "pg-arg",
    `data-argument` = arg,
    tags$code(class = "pg-arg-name", arg),
    tags$span(class = "pg-default", "default ", tags$code(argument_default(fn, arg))),
    div(class = "pg-help", help_arg(fn, arg))
  )
}

studio_expand_icon <- function(id) {
  checkmate::assert_string(id)
  tags$button(
    id = id,
    type = "button",
    class = "pg-card-expand",
    `data-expand-inspector` = "true",
    `aria-label` = "Expand panel",
    `aria-expanded` = "false",
    `aria-controls` = "inspector_sidebar",
    title = "Expand panel",
    tags$svg(
      xmlns = "http://www.w3.org/2000/svg",
      viewBox = "0 0 24 24",
      width = "16",
      height = "16",
      fill = "none",
      stroke = "currentColor",
      `stroke-width` = "1.5",
      `aria-hidden` = "true",
      focusable = "false",
      tags$path(
        class = "pg-expand-path",
        d = "M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5M3 3l6 6m12-6-6 6M3 21l6-6m12 6-6-6"
      ),
      tags$path(
        class = "pg-collapse-path",
        d = "M3 8h5V3m8 0v5h5M8 21v-5H3m13 5v-5h5M8 8 3 3m13 5 5-5M8 16l-5 5m13-5 5 5"
      )
    )
  )
}

function_card <- function(fn, example = FALSE, expand = FALSE) {
  checkmate::assert_string(fn)
  checkmate::assert_flag(example)
  checkmate::assert_flag(expand)
  help <- help_page(fn)
  arguments <- names(formals(get(fn, envir = asNamespace("mascot"))))
  bslib::card(
    full_screen = FALSE,
    `data-guide-function` = fn,
    bslib::card_header(tags$code(paste0(fn, "()")), if (expand) studio_expand_icon("expand_inspector")),
    tags$h3(class = "pg-section-title", "Description"),
    div(class = "pg-help", help$description),
    div(
      class = "pg-help-usage",
      tags$h3(class = "pg-section-title", "Usage"),
      code_block(signature(fn), "pg-signature")
    ),
    tags$h3(class = "pg-section-title", "Arguments"),
    if (length(arguments)) {
      div(class = "pg-args", lapply(arguments, function(arg) arg_block(fn, arg)))
    } else {
      tags$p(class = "pg-muted", "No arguments.")
    },
    tags$h3(class = "pg-section-title", "Returns"),
    div(class = "pg-help", help$value),
    if (example) {
      tagList(
        tags$h3(class = "pg-section-title", "Example"),
        div(class = "pg-code-wrap", code_output("code_function"), copy_button("code_function"))
      )
    }
  )
}

selected_guide <- function(fn, character = formals(mascot::mascot)$character) {
  checkmate::assert_string(fn)
  checkmate::assert_string(character)
  # Keep headings with their diagrams or tables; callouts can flow into their own column. A piece built
  # by hand is a tag; one from a guide page (R/guide-md.R) says what it is in its "guide_kind" attribute.
  piece_kind <- function(piece) {
    kind <- attr(piece, "guide_kind")
    if (!is.null(kind)) {
      return(kind)
    }
    if (!inherits(piece, "shiny.tag")) {
      return("other")
    }
    if (identical(piece$name, "h3")) {
      "heading"
    } else if (!is.null(piece$attribs$class) && grepl("pg-callout", piece$attribs$class, fixed = TRUE)) {
      "callout"
    } else {
      "other"
    }
  }
  sections <- list()
  content <- list()
  for (piece in function_visual(fn, character)) {
    kind <- piece_kind(piece)
    if (kind != "other" && length(content)) {
      sections <- c(sections, list(div(class = "pg-guide-piece", content)))
      content <- list()
    }
    content <- c(content, list(piece))
    if (kind == "callout") {
      sections <- c(sections, list(div(class = "pg-guide-piece", content)))
      content <- list()
    }
  }
  if (length(content)) {
    sections <- c(sections, list(div(class = "pg-guide-piece", content)))
  }
  bslib::card(
    full_screen = FALSE,
    `data-guide-function` = fn,
    bslib::card_header(tags$code(paste0(fn, "()")), studio_expand_icon("expand_inspector_guide")),
    tagAppendAttributes(
      div(
        div(class = "pg-guide-visual", sections),
        guide_help(fn),
        guide_mistakes(fn, character)
      ),
      class = "pg-guide-columns"
    )
  )
}

guide_content <- function(category) {
  info <- playground_categories[[category]]
  tagList(
    tags$p(class = "pg-lead", info$summary),
    tags$h3(class = "pg-section-title", "Functions"),
    lapply(category_functions(category), function_card)
  )
}

# ---- Visual explanations, per function ------------------------------------------------------

function_visual <- function(fn, character = formals(mascot::mascot)$character) {
  checkmate::assert_string(fn)
  checkmate::assert_string(character)
  studio_guide_page(fn, character)
}

data_table <- function(df, cells = NULL) {
  tags$table(
    class = "table table-sm pg-table",
    tags$thead(tags$tr(lapply(names(df), tags$th))),
    tags$tbody(lapply(seq_len(nrow(df)), function(i) {
      tags$tr(lapply(names(df), function(column) {
        value <- df[[column]][i]
        tags$td(if (!is.null(cells[[column]])) cells[[column]](value) else value)
      }))
    }))
  )
}

size_ruler <- function(pixels, label) {
  marks <- c(24, 72, 160, 320)
  position <- function(value) sprintf("left: %.1f%%", 100 * min(value, 320) / 320)
  div(
    class = "pg-ruler",
    lapply(marks, function(mark) {
      div(class = "pg-ruler-mark", style = position(mark), tags$span(mark))
    }),
    if (!is.null(pixels)) {
      div(class = "pg-ruler-now", style = position(pixels), tags$span(label))
    }
  )
}

placement_map <- function(position, minimise, name = mascot::mascot_character()$name) {
  corner <- function(corner_id) {
    active <- identical(position, corner_id)
    tags$span(
      class = paste("pg-map-corner", paste0("pg-", corner_id), if (active) "is-active"),
      `data-value` = corner_id,
      if (active) name
    )
  }
  inline_active <- identical(position, "inline")
  div(
    class = "pg-map",
    div(class = "pg-map-bar"),
    div(
      class = "pg-map-page",
      div(class = "pg-map-line"),
      tags$span(
        class = paste("pg-map-inline", if (inline_active) "is-active"),
        `data-value` = "inline",
        if (inline_active) paste0(name, ", inline") else "inline"
      ),
      div(class = "pg-map-line short"),
      div(class = "pg-map-line")
    ),
    lapply(c("top-left", "top-right", "bottom-left", "bottom-right"), corner),
    div(
      class = "pg-muted pg-map-caption",
      if (inline_active) {
        "Inline: the mascot sits where mascot() is placed in your UI and scrolls with the page."
      } else {
        paste0(
          "Floating in the ",
          sub("-", " ", position, fixed = TRUE),
          " corner of the window",
          if (minimise) ", with a minimise button" else "",
          ". Choose a corner in Controls to move it."
        )
      }
    )
  )
}

# The table from mascot_colour_roles(character), with swatches and follow arrows.
roles_table <- function(character, palette = NULL) {
  checkmate::assert_string(character)
  checkmate::assert_string(palette, min.chars = 1, null.ok = TRUE)
  swatch <- function(colour) {
    tagList(tags$span(class = "pg-swatch", style = paste0("background:", colour)), tags$code(colour))
  }
  follows <- function(value) if (is.na(value)) tags$span(class = "pg-muted", "leader") else paste("\u2190", value)
  shade <- function(value) if (is.na(value)) "" else value
  roles <- mascot_colour_roles(character, palette = palette)
  # The outline row points to the dark-mode outline tip under mascot_theme()'s dark argument.
  outline_text <- roles$description[roles$role == "outline"]
  description <- function(value) {
    if (length(outline_text) == 1L && identical(value, outline_text)) {
      tagList(
        value,
        " ",
        tags$a(
          href = "#",
          class = "pg-role-tip",
          `data-event` = "select_function",
          `data-value` = "mascot_theme",
          "Dark-mode outline tip"
        )
      )
    } else {
      value
    }
  }
  tagList(
    code_block(format_call("mascot_colour_roles", list(character = character, palette = palette)), "pg-code-small"),
    data_table(roles, cells = list(colour = swatch, follows = follows, shade = shade, description = description))
  )
}

# Each Guide section has one builder so further material can grow independently. This one is the
# function's help page (description, details and value), with a link to the matching section of the
# Get started article. Each argument's help text is in the popover of its control instead.
guide_help <- function(fn) {
  checkmate::assert_string(fn)
  help <- help_page(fn)
  heading <- the_guide(fn)$vignette
  div(
    class = "pg-guide-piece pg-guide-help",
    tags$h3(class = "pg-section-title", paste0("Help page: ", fn, "()")),
    div(class = "pg-help", help$description),
    if (!is.null(help$details)) {
      tagList(tags$h4(class = "pg-help-heading", "Details"), div(class = "pg-help", help$details))
    },
    tags$h4(class = "pg-help-heading", "Returns"),
    div(class = "pg-help", help$value),
    tags$p(
      class = "pg-hint",
      "Each argument's help text is available via the ? icon beside its control. Read more in the Get started article: ",
      tags$a(href = vignette_url(heading), target = "_blank", rel = "noopener", heading),
      ". Offline: ",
      tags$code('vignette("mascot", package = "mascot")'),
      "."
    )
  )
}

# Evaluate only against a disposable mock session. No message reaches the live mascot.
guide_mistakes <- function(fn, character) {
  checkmate::assert_string(fn)
  checkmate::assert_string(character)
  # The calls and what R says come from guide/guide-mistakes.R, shared with the website.
  cases <- guide_mistake_cases(fn, character)
  div(
    class = "pg-guide-piece pg-guide-mistakes",
    tags$h3(class = "pg-section-title", "Warnings, errors and common mistakes"),
    if (!length(cases)) tags$p("This listing takes no arguments. Use its returned names rather than typing guesses."),
    lapply(cases, function(case) {
      tagList(
        code_block(case$code, "pg-code-small"),
        if (!is.null(case$why)) tags$p(case$why),
        code_block(
          if (length(case$messages)) paste(case$messages, collapse = "\n") else guide_no_message,
          "pg-log-message"
        )
      )
    })
  )
}

# Studio navigation comes from the same function/control map as completeness checks.
studio_button <- function(id, label, aria_label = label, pressed = NULL) {
  checkmate::assert_string(id)
  checkmate::assert_string(label)
  checkmate::assert_string(aria_label)
  checkmate::assert_flag(pressed, null.ok = TRUE)
  tags$button(
    id = id,
    type = "button",
    class = "btn btn-sm btn-outline-primary",
    `aria-label` = aria_label,
    `aria-pressed` = if (!is.null(pressed)) tolower(as.character(pressed)),
    label
  )
}

studio_rail <- function() {
  groups <- setdiff(names(playground_categories), "preview")
  icons <- c(
    look = "M6 9a6 6 0 0 1 12 0v6H6Z M9 18h6",
    messages = "M4 4h16v12H9l-5 4Z",
    motion = "m13 2-8 12h6l-1 8 9-13h-7Z",
    layout = "M3 3h18v18H3Z M3 9h18 M9 9v12",
    colours = "M12 3a9 9 0 1 0 0 18h2a3 3 0 0 0 0-6h-1a2 2 0 0 1 0-4h4a4 4 0 0 0-5-8Z",
    wiring = "m8 6-6 6 6 6 m8-12 6 6-6 6 m-3-15-2 18",
    examples = "M4 3h12l4 4v14H4Z M8 11h8 M8 15h8"
  )
  tags$nav(
    class = "pg-rail pg-float",
    `aria-label` = "Function groups",
    tags$button(
      id = "all_functions",
      type = "button",
      class = "pg-logo",
      `aria-label` = "Function index (all 24 functions)",
      title = "Function index (all 24 functions)",
      `aria-describedby` = "function_index_tooltip",
      `aria-expanded` = "false",
      `aria-controls` = "function_flyout",
      "m",
      tags$span(class = "pg-phone-label", "Functions"),
      tags$span(
        id = "function_index_tooltip",
        class = "pg-word-tooltip",
        role = "tooltip",
        "Function index (all 24 functions)"
      )
    ),
    lapply(groups, function(group) {
      tags$button(
        type = "button",
        `data-group` = group,
        title = playground_categories[[group]]$title,
        `aria-label` = playground_categories[[group]]$title,
        `aria-expanded` = "false",
        `aria-controls` = "function_flyout",
        tags$svg(viewBox = "0 0 24 24", `aria-hidden` = "true", tags$path(d = icons[[group]]))
      )
    }),
  )
}

# The mobile utility slot receives the same mounted right rail at the phone breakpoint.
studio_topright <- function() {
  div(id = "studio_phone_tools", class = "pg-topright")
}

studio_inspector_icon <- function(name) {
  checkmate::assert_choice(name, c("controls", "help", "guide", "more"))
  paths <- c(
    controls = paste(
      "m9 3-.5 3-2 1-2.8-1-2 4 2.3 2v2L2.7 16l2 4 2.8-1 2 1 .5 3h6l.5-3 2-1 2.8 1 2-4-2.3-2v-2l2.3-2-2-4-2.8 1-2-1L15 3Z",
      "M15 13a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"
    ),
    help = "M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z M9 9a3 3 0 0 1 6 0c0 2-3 2-3 5 M12 17h.01",
    guide = "M12 5C9 3 5 3 2 4v15c3-1 7-1 10 1 3-2 7-2 10-1V4c-3-1-7-1-10 1Z M12 5v15"
  )
  tags$svg(
    viewBox = "0 0 24 24",
    `aria-hidden` = "true",
    if (name == "more") {
      lapply(c(4, 12, 20), function(y) tags$circle(cx = 12, cy = y, r = 1, fill = "currentColor"))
    } else {
      tags$path(d = paths[[name]])
    }
  )
}

studio_right_rail <- function() {
  div(
    id = "studio_right_rail",
    class = "pg-right-rail pg-float",
    tags$button(
      id = "open_inspector",
      type = "button",
      class = "btn pg-phone-inspector",
      title = "Inspector",
      `aria-label` = "Inspector",
      `aria-controls` = "inspector_sidebar",
      `aria-expanded` = "false",
      studio_inspector_icon("controls"),
      "Inspector"
    ),
    tags$details(
      id = "studio_menu",
      class = "pg-menu",
      tags$summary(
        class = "pg-rail-button",
        role = "button",
        title = "More",
        `aria-label` = "More",
        `aria-haspopup` = "menu",
        `aria-expanded` = "false",
        studio_inspector_icon("more")
      ),
      div(
        class = "pg-menu-body pg-float",
        tags$a(href = "?view=studio", "Studio"),
        tags$a(id = "more_examples", href = "?view=examples", "More examples"),
        tags$a(href = "https://github.com/insightsurge/mascot", target = "_blank", rel = "noopener", "GitHub"),
        tags$a(href = "https://mascot-pkg.web.app/", target = "_blank", rel = "noopener", "Package website"),
        tags$label(
          class = "pg-key-switch",
          tags$input(id = "studio_keys", type = "checkbox", checked = NA),
          "Keyboard shortcuts (/, 1-5, w, n)"
        )
      )
    ),
    div(class = "pg-rail-divider", `aria-hidden` = "true"),
    div(
      class = "pg-inspector-views",
      role = "toolbar",
      `aria-label` = "Inspector views",
      `aria-orientation` = "vertical",
      lapply(c("Controls", "Help", "Guide"), function(label) {
        name <- tolower(label)
        tags$button(
          id = paste0("inspector_view_", name),
          type = "button",
          class = "pg-rail-button",
          title = label,
          `aria-label` = label,
          `aria-pressed` = "false",
          `aria-controls` = "inspector_sidebar",
          `data-inspector-view` = name,
          studio_inspector_icon(name)
        )
      })
    )
  )
}

# Resolve a field using the existing map; a renamed helper needs just this route changed.
studio_route <- function(arg) {
  checkmate::assert_string(arg)
  checkmate::assert_choice(arg, setdiff(names(formals(mascot::mascot)), "..."))
  fn <- switch(arg, id = "mascot", motion = "mascot_motion_settings", click = "mascot_action", paste0("mascot_", arg))
  fields <- playground_controls[[fn]]
  targets <- unlist(Filter(is.character, fields), use.names = FALSE)
  ids <- sub('^id="([^"]+)"$', "\\1", targets[startsWith(targets, 'id="')])
  list(fn = fn, input = if (arg != "id" && length(ids)) ids[[1]] else "")
}

studio_search <- function() {
  div(
    id = "studio_search",
    class = "pg-search-backdrop",
    role = "dialog",
    `aria-modal` = "true",
    `aria-label` = "Search functions and arguments",
    hidden = NA,
    div(
      class = "pg-search-box pg-float",
      div(
        class = "pg-surface-head",
        tags$strong("Find a function or argument"),
        studio_button("close_search", "Close")
      ),
      tags$input(
        id = "function_search",
        type = "search",
        role = "combobox",
        autocomplete = "off",
        placeholder = "Function, title or argument",
        `aria-label` = "Search functions and arguments",
        `aria-controls` = "search_results",
        `aria-expanded` = "true",
        `aria-autocomplete` = "list"
      ),
      tags$div(id = "search_count", role = "status"),
      tags$ul(
        id = "search_results",
        role = "listbox",
        `aria-label` = "Search results",
        lapply(names(playground_guide), function(fn) {
          args <- names(formals(getExportedValue("mascot", fn)))
          tags$li(
            id = paste0("search_", fn, "_function"),
            role = "option",
            `aria-selected` = "false",
            `data-search-function` = fn,
            `data-search-title` = help_page(fn)$title,
            `data-search-group` = playground_categories[[playground_guide[[fn]]$category]]$title,
            tags$code(paste0(fn, "()")),
            tags$small(help_page(fn)$title),
            div(
              class = "pg-search-matches",
              hidden = NA,
              tags$span("matches:"),
              lapply(args, function(arg) {
                fragments <- playground_controls[[fn]][[arg]]
                ids <- if (is.character(fragments)) {
                  sub('^id="([^"]+)"$', "\\1", fragments[startsWith(fragments, 'id="')])
                }
                tags$button(
                  id = paste0("search_", fn, "_", gsub("[.]", "dot", arg)),
                  type = "button",
                  class = "pg-search-badge",
                  hidden = NA,
                  `data-search-function` = fn,
                  `data-search-argument` = arg,
                  `data-search-input` = if (length(ids)) ids[1] else "",
                  `aria-label` = paste("Open", fn, "at", arg),
                  arg
                )
              }),
              tags$span(class = "pg-search-more", hidden = NA)
            )
          )
        })
      )
    )
  )
}

call_chips <- function(state, style, gesture = NULL) {
  checkmate::assert_string(gesture, null.ok = TRUE)
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_character(style, any.missing = FALSE)
  checkmate::assert_subset(unname(style), c("short", "helper"), .var.name = "style")
  if (length(style) > 1L) {
    style <- as.list(style)
  }
  signature <- formals(mascot::mascot)
  args <- names(signature)
  tagList(
    tags$button(
      type = "button",
      class = "pg-call-name",
      `data-call-open` = "mascot",
      title = "Open mascot() in the inspector",
      "mascot("
    ),
    lapply(args, function(arg) {
      if (arg == "...") {
        return(tags$span(
          class = "pg-call-entry",
          tags$code(class = "pg-call-dots", title = "Additional unnamed arguments are not accepted", "..."),
          tags$span(class = "pg-call-comma", ",")
        ))
      }
      route <- studio_route(arg)
      if (arg == "click") {
        route <- if (inherits(eval(state$click$helper), "mascot_popup_menu")) {
          list(fn = "mascot_popup_menu", input = "menu_items")
        } else {
          list(fn = "mascot_action", input = "action_label")
        }
      }
      chosen <- if (length(style) == 1L) style else style[[arg]] %||% style[[".default"]]
      changed <- !is.null(state[[arg]]) && !identical(state[[arg]]$short, defaults[[arg]])
      value <- if (arg == "id") {
        '"helper"'
      } else if (!changed) {
        format_expr(signature[[arg]])
      } else {
        format_expr(state[[arg]][[chosen]])
      }
      tags$span(
        class = "pg-call-entry",
        tags$button(
          type = "button",
          class = "pg-call-chip",
          `data-call-arg` = arg,
          `data-call-changed` = if (arg != "id") tolower(as.character(changed)),
          `data-call-function` = route$fn,
          `data-call-input` = route$input,
          `data-call-style` = chosen,
          `data-call-hint` = arg_hint("mascot", arg),
          `data-call-default` = argument_default("mascot", arg),
          title = paste(arg, "=", value),
          `aria-expanded` = "false",
          `aria-controls` = "chip_editor",
          `aria-label` = paste(arg, "=", value, "options"),
          tags$code(tags$span(class = "pg-chip-name", paste(arg, "=")), tags$span(class = "pg-chip-value", value)),
          chip_pencil()
        ),
        tags$span(class = "pg-call-comma", ",")
      )
    }),
    gesture_chip(gesture),
    tags$span(")")
  )
}

# A small editing cue shared by configuration and gesture chips.
chip_pencil <- function() {
  tags$svg(
    class = "pg-chip-pencil",
    viewBox = "0 0 24 24",
    width = 12,
    height = 12,
    `aria-hidden` = "true",
    fill = "none",
    stroke = "currentColor",
    `stroke-width` = 2,
    tags$path(d = "M4 16L16 4l4 4L8 20H4Z M14 6l4 4")
  )
}

# A one-off event is demonstrated inside mascot(...) and never enters copied configuration code.
gesture_chip <- function(name = NULL) {
  checkmate::assert_string(name, null.ok = TRUE)
  value <- if (is.null(name)) "none yet" else format_expr(code_gesture(name)$helper)
  tags$button(
    type = "button",
    class = "pg-call-chip pg-gesture-chip",
    title = "demo only, not an argument of mascot()",
    `data-call-arg` = "gesture",
    `data-call-function` = "mascot_gesture",
    `data-call-input` = "gesture",
    `data-call-hint` = arg_hint("mascot_gesture", "name"),
    `data-call-default` = "none yet",
    `aria-label` = paste("Last played gesture:", value, "options"),
    `aria-expanded` = "false",
    `aria-controls` = "chip_editor",
    tags$code(tags$span(class = "pg-chip-name", "gesture ="), tags$span(class = "pg-chip-value", value)),
    chip_pencil()
  )
}

function_help <- function(fn) {
  checkmate::assert_choice(fn, names(playground_guide))
  page <- help_page(fn)
  # Keep Usage outside the card so it stays pinned through Details and Examples too.
  card <- htmltools::tagQuery(function_card(fn, expand = TRUE))$find(".pg-help-usage")$remove()$allTags()
  tagList(
    div(
      class = "pg-help-usage",
      tags$h3(class = "pg-section-title", "Usage"),
      code_block(signature(fn), "pg-signature")
    ),
    card,
    if (!is.null(page$details)) tagList(tags$h3("Details"), page$details),
    tags$h3("Examples"),
    lapply(help_examples(fn), code_block)
  )
}

# Shared inputs stay in the top bar; these buttons explicitly focus them.
shared_input_button <- function(fn, arg) {
  checkmate::assert_string(fn)
  checkmate::assert_string(arg)
  controls <- playground_controls[[fn]][[arg]]
  shared <- c("character", "mood", "example_name", "example_run")
  if (!is.character(controls)) {
    return(NULL)
  }
  ids <- sub('^id="([^"]+)"$', "\\1", controls[startsWith(controls, 'id="')])
  ids <- intersect(ids, shared)
  if (!length(ids)) {
    return(NULL)
  }
  tags$button(type = "button", class = "btn btn-sm", `data-focus-input` = ids[[1]], paste("Edit", arg))
}

# The live table of palette roles; the palette is chosen in the sentence of the Controls.
palette_roles_demo <- function() {
  tagList(
    tags$h3(class = "pg-section-title", "Palette roles on the live mascot"),
    tags$p("Choose a palette in the sentence to recolour the live mascot and this table."),
    uiOutput("roles_table")
  )
}

# These calls use a separate mascot so the sentence and the live host keep their current settings.
palette_swap_section <- function(character) {
  checkmate::assert_string(character)
  example <- studio_palette_swap
  from <- mascot_character(example[["from"]])$name
  kept <- mascot_character(example[["kept"]])$name
  dropped <- mascot_character(example[["dropped"]])$name
  initial <- list("palette_swap_demo", character = example[["from"]], theme = example[["palette"]], motion = FALSE)
  tagList(
    tags$h3(class = "pg-section-title", "Character swap"),
    tags$p(paste(
      "Both examples start with",
      from,
      "in",
      paste0(example[["palette"]], "."),
      kept,
      "keeps the palette;",
      dropped,
      "drops it and returns to its own colours."
    )),
    do.call(mascot, c(initial, list(placement = "inline"))),
    code_block(paste(
      format_call("update_mascot", initial),
      format_call("update_mascot", list("palette_swap_demo", character = example[["kept"]])),
      format_call("update_mascot", list("palette_swap_demo", character = example[["dropped"]])),
      sep = "\n"
    )),
    try_button("palette_swap", "kept", paste("Swap and keep", example[["palette"]])),
    try_button("palette_swap", "dropped", paste("Swap and drop", example[["palette"]])),
    tags$div(role = "status", textOutput("palette_swap_result"))
  )
}

# The part of a help text (HTML) that starts at `from`, up to its closing paragraph; NULL when absent.
studio_help_tail <- function(html, from) {
  checkmate::assert_string(from, min.chars = 1)
  text <- paste(as.character(html), collapse = "")
  start <- regexpr(from, text, fixed = TRUE)
  if (start < 0L) {
    return(NULL)
  }
  tail <- substr(text, start, nchar(text))
  gsub("\\s+", " ", sub("</p>\\s*$", "", tail))
}

# The founder's decision (#335): built-in characters keep one outline colour in both modes; an app that
# wants a different dark-mode outline sets it. Both mascots below are forced into dark mode, so the
# comparison reads on any page.
studio_dark_outline_colour <- "#FFC93C"

dark_outline_demo <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  roles <- mascot_colour_roles(character)
  if (!"outline" %in% roles$role) {
    return(NULL)
  }
  custom <- helper_call(
    "mascot_theme",
    dark = named_call("list", c(outline = studio_dark_outline_colour))
  )
  # The words come from ?mascot_theme (its dark argument), so the two cannot drift apart.
  tip <- studio_help_tail(help_arg("mascot_theme", "dark"), "Built-in characters keep one outline colour")
  default_theme <- mascot_theme(mode = "dark")
  custom_theme <- mascot_theme(dark = list(outline = studio_dark_outline_colour), mode = "dark")
  figure <- function(id, theme, caption) {
    tags$figure(
      mascot(id, character = character, theme = theme, size = 100, placement = "inline", motion = FALSE),
      tags$figcaption(caption)
    )
  }
  div(
    id = "dark_outline_tip",
    class = "pg-dark-outline",
    tags$h3(class = "pg-section-title", "Tip: the outline in dark mode"),
    if (!is.null(tip)) tags$p(shiny::HTML(tip)),
    code_block(paste(deparse1(helper_call("mascot_theme")), deparse1(custom), sep = "\n")),
    div(
      class = "pg-dark-panel",
      figure("dark_outline_default", default_theme, "Default outline"),
      figure("dark_outline_custom", custom_theme, "Custom dark outline")
    ),
    tags$p(
      class = "pg-muted",
      "Both examples are forced into dark mode with mode = \"dark\", so they look the same on any page."
    )
  )
}

# Build the example from the selected character's current palette and role listings.
studio_palette_base <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  palettes <- mascot_palettes(character)$name
  palette <- palettes[[if (length(palettes) > 1L) 2L else 1L]]
  roles <- mascot_colour_roles(character, palette = palette)
  # A role whose change is easy to see; the outline would contradict the table of the live mascot.
  role <- intersect(c("body", "accessory"), roles$role)[1L]
  if (is.na(role)) {
    role <- roles$role[[1L]]
  }
  base <- roles$colour[[match(role, roles$role)]]
  colour <- if (tolower(base) == "#b93664") "#2563eb" else "#b93664"
  list(palette = palette, role = role, base = base, colour = colour)
}

palette_base_demo <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  example <- studio_palette_base(character)
  theme <- helper_call(
    "mascot_theme",
    palette = example$palette,
    light = named_call("list", stats::setNames(example$colour, example$role))
  )
  div(
    class = "pg-palette-base",
    tags$h3(class = "pg-section-title", "Use a palette as a base"),
    tags$p("The explicit light role wins over the palette. Other roles keep the palette or follow the changed leader."),
    code_block(deparse1(theme)),
    data_table(data.frame(role = example$role, palette = example$base, light = example$colour)),
    mascot(
      "palette_base_demo",
      character = character,
      theme = eval(theme),
      status = "Example, not the live mascot",
      placement = "inline",
      motion = FALSE
    )
  )
}
