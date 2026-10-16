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
    tags$span(class = "pg-info", "i")
  )
  popover(
    trigger,
    arg_popover_body(fn, arg),
    title = tags$code(paste0(fn, "(", arg, " =)")),
    options = list(customClass = "pg-help-popover")
  )
}

# One argument: its chip (click for the help text), the control, and a one-line hint.
arg_field <- function(fn, arg, input, note = NULL) {
  checkmate::assert_string(fn)
  checkmate::assert_string(arg)
  div(
    class = "pg-field",
    `data-argument` = arg,
    div(
      class = "pg-field-head",
      arg_chip(fn, arg),
      tags$span(class = "pg-default", "default ", argument_default(fn, arg))
    ),
    div(class = "pg-hint", arg_hint(fn, arg)),
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
    bslib::popover(
      tags$button(type = "button", class = "btn btn-outline-primary btn-sm", "Usage"),
      code_block(signature(fn), "pg-signature"),
      title = paste0(fn, "()")
    ),
    try_button("open_guide", fn, paste0("Guide: ", fn, "()")),
    div(class = "pg-returns", tags$strong("Returns: "), div(class = "pg-help", help_page(fn)$value)),
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
        tags$h2(playground_categories[[category]]$title),
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
  shared <- setdiff(names(the_guide(fn)$args), c("id", "...", "session"))
  lapply(shared, function(arg) {
    helper <- if (arg == "motion") "mascot_motion_settings" else paste0("mascot_", arg)
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

copy_button <- function(target) {
  tags$button(type = "button", class = "btn btn-sm btn-outline-primary pg-copy", `data-copy` = target, "Copy")
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

function_card <- function(fn, example = FALSE) {
  checkmate::assert_string(fn)
  checkmate::assert_flag(example)
  help <- help_page(fn)
  arguments <- names(formals(get(fn, envir = asNamespace("mascot"))))
  bslib::card(
    full_screen = FALSE,
    `data-guide-function` = fn,
    bslib::card_header(tags$code(paste0(fn, "()"))),
    tags$h3(class = "pg-section-title", "Description"),
    div(class = "pg-help", help$description),
    tags$h3(class = "pg-section-title", "Usage"),
    code_block(signature(fn), "pg-signature"),
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
  # Keep headings with their diagrams or tables; callouts can flow into their own column.
  sections <- list()
  content <- list()
  for (piece in function_visual(fn, character)) {
    heading <- inherits(piece, "shiny.tag") && identical(piece$name, "h3")
    callout <- inherits(piece, "shiny.tag") &&
      !is.null(piece$attribs$class) &&
      grepl("pg-callout", piece$attribs$class, fixed = TRUE)
    if ((heading || callout) && length(content)) {
      sections <- c(sections, list(div(class = "pg-guide-piece", content)))
      content <- list()
    }
    content <- c(content, list(piece))
    if (callout) {
      sections <- c(sections, list(div(class = "pg-guide-piece", content)))
      content <- list()
    }
  }
  if (length(content)) {
    sections <- c(sections, list(div(class = "pg-guide-piece", content)))
  }
  div(
    `data-guide-function` = fn,
    tagAppendAttributes(
      bslib::layout_columns(
        col_widths = bslib::breakpoints(sm = 12, lg = c(6, 6)),
        div(
          class = "pg-guide-example",
          tags$h3(class = "pg-section-title", paste0("Example: how to call ", fn, "()")),
          div(class = "pg-code-wrap", code_output("code_function"), copy_button("code_function"))
        ),
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
  switch(
    fn,
    mascot_mood = visual_mood(),
    mascot_moods = visual_moods(character),
    mascot_characters = visual_characters(),
    mascot_families = visual_families(),
    mascot_anchors = visual_anchors(character),
    mascot_palettes = visual_palettes(character),
    mascot_status = visual_status(),
    mascot_bubble = visual_bubble(),
    mascot_motion_settings = visual_motion(),
    mascot_gesture = visual_gesture(),
    mascot_gestures = visual_gestures(character),
    mascot_size = visual_size(),
    mascot_placement = visual_placement(),
    mascot_colour_roles = visual_colour_roles(character),
    mascot_theme = visual_theme(character),
    mascot_action = visual_action(),
    mascot_popup_menu = visual_menu(),
    mascot = visual_mascot(),
    update_mascot = visual_update_mascot(),
    NULL
  )
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

mood_cards <- function(moods) {
  div(
    id = "mood",
    class = "pg-mood-input pg-cards",
    `data-value` = "idle",
    role = "group",
    `aria-label` = "Mood",
    lapply(seq_len(nrow(moods)), function(i) {
      bslib::card(
        class = "pg-card-mini",
        div(class = "pg-card-title", tools::toTitleCase(moods$name[i])),
        div(class = "pg-muted", moods$description[i]),
        div(class = "pg-card-foot", tags$code(sprintf("mood = \"%s\"", moods$name[i]))),
        tagAppendAttributes(
          try_button("try_mood", moods$name[i], "Try it"),
          `aria-label` = paste("Try", moods$name[i]),
          `aria-pressed` = if (moods$name[i] == "idle") "true" else "false"
        )
      )
    })
  )
}

visual_mood <- function() {
  tagList(
    tags$h3(class = "pg-section-title", paste("The", nrow(mascot_moods()), "moods")),
    data_table(mascot_moods()),
    div(
      class = "pg-callout",
      tags$strong("The mood never speaks alone. "),
      "The status line under the mascot names the mood (or displays your custom text), providing clear meaning for
      screen readers and anyone who cannot distinguish facial expressions. Try moods with the cards in Controls."
    )
  )
}

visual_moods <- function(character = formals(mascot::mascot)$character) {
  moods <- mascot_moods(character)
  tagList(
    tags$h3(class = "pg-section-title", paste0(mascot_character(character)$name, "'s ", nrow(moods), " moods")),
    tags$p(
      class = "pg-muted",
      "The five shared moods come first. A character may add its own; a mood that is not available falls back to the
      one named in fallback."
    ),
    data_table(moods)
  )
}

visual_characters <- function() {
  tagList(
    tags$h3(class = "pg-section-title", "Characters this session knows"),
    data_table(mascot_characters())
  )
}

visual_families <- function() {
  tagList(
    tags$h3(class = "pg-section-title", "Character families"),
    data_table(mascot_families())
  )
}

visual_anchors <- function(character = formals(mascot::mascot)$character) {
  tagList(
    tags$h3(class = "pg-section-title", paste0(mascot_character(character)$name, "'s anchors")),
    data_table(mascot_anchors(character))
  )
}

visual_palettes <- function(character = formals(mascot::mascot)$character) {
  tagList(
    tags$h3(class = "pg-section-title", paste0(mascot_character(character)$name, "'s palettes")),
    tags$p(class = "pg-muted", "original is the character's own colours, with no palette applied."),
    data_table(mascot_palettes(character))
  )
}

visual_status <- function() {
  rows <- data.frame(
    ` ` = c("Visible", "Screen readers", "Use it for", "Set it", "Clear it"),
    `Status line` = c(
      "Always, under the mascot",
      "Announced politely when it changes",
      "The current state: \"Checking 120 rows\"",
      "status = \"text\"",
      "status = mascot_status()"
    ),
    `Speech bubble` = c(
      "Until it times out or is closed",
      "Announced politely when it appears",
      "News: \"Three rows were skipped\"",
      "bubble = \"text\"",
      "bubble = mascot_bubble()"
    ),
    check.names = FALSE
  )
  tagList(
    tags$h3(class = "pg-section-title", "Status line or speech bubble?"),
    data_table(rows)
  )
}

visual_bubble <- function() {
  tagList(
    tags$h3(class = "pg-section-title", "How long a bubble stays"),
    div(
      class = "pg-timeline",
      div(class = "pg-timeline-bar", div(class = "pg-timeline-fill")),
      div(class = "pg-timeline-labels", tags$span("shown"), tags$span("duration = 5: hides"), tags$span("Inf: stays"))
    ),
    div(
      class = "pg-callout pg-callout-warn",
      tags$strong("HTML is trusted as it is. "),
      "Plain text is escaped and always safe. Wrap only your own content in HTML(), never untrusted visitor
      input. Bootstrap classes such as badge, table, and progress work inside the bubble because bslib includes
      Bootstrap."
    )
  )
}

visual_motion <- function() {
  # selected_guide() reads the explanation from the helper's help page.
  NULL
}

visual_gesture <- function() {
  gestures <- mascot_gestures()
  tagList(
    tags$h3(class = "pg-section-title", "Gestures"),
    div(
      class = "pg-cards",
      lapply(seq_len(nrow(gestures)), function(i) {
        bslib::card(
          class = "pg-card-mini",
          div(class = "pg-card-title", tools::toTitleCase(gestures$name[i])),
          div(class = "pg-muted", gestures$description[i]),
          div(class = "pg-card-foot", tags$code(sprintf("gesture = \"%s\"", gestures$name[i])))
        )
      })
    )
  )
}

visual_gestures <- function(character = formals(mascot::mascot)$character) {
  gestures <- mascot_gestures(character)
  tagList(
    tags$h3(class = "pg-section-title", paste0(mascot_character(character)$name, "'s gestures")),
    tags$p(
      class = "pg-muted",
      "frames is the length of the movement that plays, at 30 frames per second. A gesture whose parts are missing
      plays its fallback."
    ),
    data_table(gestures)
  )
}

visual_size <- function() {
  tagList(
    tags$h3(class = "pg-section-title", "Size"),
    uiOutput("size_ruler"),
    div(
      class = "pg-callout",
      tags$strong("Small screens. "),
      "small_screen applies at 576 pixels wide or less. Narrow your browser window to see the mascot switch
      size."
    )
  )
}

visual_placement <- function() {
  tagList(
    tags$h3(class = "pg-section-title", "Placement"),
    tags$p(
      class = "pg-muted",
      "A default mascot() floats in the bottom-right corner. This studio displays the character inline with placement = \"inline\" so it remains on the canvas."
    ),
    uiOutput("placement_map")
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
roles_table <- function(character) {
  swatch <- function(colour) {
    tagList(tags$span(class = "pg-swatch", style = paste0("background:", colour)), tags$code(colour))
  }
  follows <- function(value) if (is.na(value)) tags$span(class = "pg-muted", "leader") else paste("\u2190", value)
  shade <- function(value) if (is.na(value)) "" else value
  tagList(
    code_block(sprintf("mascot_colour_roles(\"%s\")", character), "pg-code-small"),
    data_table(mascot_colour_roles(character), cells = list(colour = swatch, follows = follows, shade = shade))
  )
}

visual_colour_roles <- function(character) {
  tagList(
    tags$h3(class = "pg-section-title", paste0(mascot_character(character)$name, "'s parts")),
    tags$p(
      class = "pg-muted",
      "Leaders adopt the colours you supply. Followers copy the first leader you customise, shaded the same, lighter, or
      darker, unless you customise them directly. Low contrast against the page warns in development mode, previews and this studio; the colour is kept. The mascot.contrast_warnings option forces R warnings on or off."
    ),
    uiOutput("roles_table")
  )
}

visual_theme <- function(character = formals(mascot::mascot)$character) {
  brand <- studio_brand(character)
  tagList(
    tags$h3(class = "pg-section-title", "Which colour applies"),
    div(
      class = "pg-flow",
      div(class = "pg-flow-step", tags$code("mode = \"light\""), " or ", tags$code("\"dark\""), div("always wins")),
      div(class = "pg-flow-arrow", "\u2192"),
      div(class = "pg-flow-step", "page switch", div(tags$code("data-bs-theme"))),
      div(class = "pg-flow-arrow", "\u2192"),
      div(class = "pg-flow-step", "Quarto", div(tags$code("quarto-dark"))),
      div(class = "pg-flow-arrow", "\u2192"),
      div(class = "pg-flow-step", "no signal", div("light"))
    ),
    tags$h3(class = "pg-section-title", "Brand colours from bslib"),
    div(
      class = "pg-flow",
      div(class = "pg-flow-step", tags$code("bs_theme(primary =)")),
      div(class = "pg-flow-arrow", "\u2192"),
      div(class = "pg-flow-step", tags$code(brand$primary), div("and its followers")),
      div(class = "pg-flow-gap"),
      div(class = "pg-flow-step", tags$code("bs_theme(secondary =)")),
      div(class = "pg-flow-arrow", "\u2192"),
      div(class = "pg-flow-step", tags$code(brand$secondary), div("and its followers"))
    )
  )
}

visual_action <- function() {
  step <- function(...) div(class = "pg-flow-step", ...)
  arrow <- div(class = "pg-flow-arrow", "\u2192")
  tagList(
    tags$h3(class = "pg-section-title", "From a click to your server"),
    div(
      class = "pg-flow",
      step("The visitor clicks", div(tags$strong("Open help"))),
      arrow,
      step(tags$code("input$helper_click"), div("counts up")),
      arrow,
      step("Your", tags$code("observeEvent()"), div("opens your help")),
      arrow,
      step(tags$code("update_mascot()"), div("can answer too"))
    ),
    div(
      class = "pg-callout",
      tags$strong("A picture or a button. "),
      "Without click, the mascot is a picture: no keyboard stop, no events. With one, it is a button named by its ",
      "label, so screen readers say what a click does."
    )
  )
}

visual_menu <- function() {
  step <- function(...) div(class = "pg-flow-step", ...)
  arrow <- div(class = "pg-flow-arrow", "\u2192")
  tagList(
    tags$h3(class = "pg-section-title", "From a click to your server"),
    div(
      class = "pg-flow",
      step("The visitor picks", div(tags$strong("Finish review"))),
      arrow,
      step(tags$code("input$helper_menu"), div("becomes \"finish\"")),
      arrow,
      step("Your", tags$code("observeEvent()"), div("decides")),
      arrow,
      step(tags$code("update_mascot()"), div("answers"))
    ),
    div(class = "pg-live", tags$span(class = "pg-muted", "Last choice here: "), textOutput("menu_last", inline = TRUE)),
    tags$h3(class = "pg-section-title", "Your server code for these items"),
    div(class = "pg-code-wrap", code_output("menu_code"), copy_button("menu_code")),
    div(
      class = "pg-callout",
      tags$strong("Keyboard. "),
      "Tab to the mascot's menu button, then Enter or Space opens it; arrow keys move between items; Escape
      closes it. Opening and closing it also set input$helper_click."
    )
  )
}

visual_mascot <- function() {
  tagList(
    tags$h3(class = "pg-section-title", "Two calls, one id"),
    div(
      class = "pg-wire",
      div(
        class = "pg-wire-box",
        div(class = "pg-muted", "UI"),
        code_block("mascot(\"helper\")")
      ),
      div(class = "pg-flow-arrow", "\u2194"),
      div(
        class = "pg-wire-box",
        div(class = "pg-muted", "server"),
        code_block("update_mascot(\"helper\", mood = \"happy\")")
      )
    ),
    div(
      class = "pg-wire",
      div(
        class = "pg-wire-box",
        div(class = "pg-muted", "module UI"),
        code_block("mascot(ns(\"helper\"))")
      ),
      div(class = "pg-flow-arrow", "\u2194"),
      div(
        class = "pg-wire-box",
        div(class = "pg-muted", "module server"),
        code_block("update_mascot(\"helper\", mood = \"happy\")")
      )
    )
  )
}

visual_update_mascot <- function() {
  tagList(
    tags$h3(class = "pg-section-title", "What each kind of value does in update_mascot()"),
    data_table(data.frame(
      `You pass` = c("nothing (NULL)", "an empty helper", "a value"),
      Example = c("mood = NULL", "bubble = mascot_bubble()", "mood = \"happy\""),
      `The mascot` = c("keeps it as it is", "clears it or goes back to the default", "changes it"),
      check.names = FALSE
    )),
    div(
      class = "pg-callout",
      tags$strong("All or nothing. "),
      "update_mascot() validates all values first. If any value is invalid, it warns, reports the issue, and sends
      nothing, preventing partial updates. Calling with an invalid argument name or outside a server session
      produces an error."
    )
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
      "Each argument's help text is available via the i icon beside its control. Read more in the Get started article: ",
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
  old_contrast <- getOption("mascot.contrast_warnings")
  on.exit(options(mascot.contrast_warnings = old_contrast), add = TRUE)
  if (is.null(old_contrast)) {
    options(mascot.contrast_warnings = TRUE)
  }
  cases <- guide_mistake_calls(fn, character)
  div(
    class = "pg-guide-piece pg-guide-mistakes",
    tags$h3(class = "pg-section-title", "Warnings, errors and common mistakes"),
    if (!length(cases)) tags$p("This listing takes no arguments. Use its returned names rather than typing guesses."),
    lapply(cases, function(code) {
      messages <- character()
      mock <- shiny::MockShinySession$new()
      on.exit(mock$close(), add = TRUE)
      env <- new.env(parent = environment())
      env$session <- mock
      tryCatch(
        withCallingHandlers(
          eval(str2lang(code), env),
          warning = function(w) {
            messages <<- c(messages, paste("Warning:", cli::ansi_strip(conditionMessage(w))))
            invokeRestart("muffleWarning")
          },
          message = function(m) {
            messages <<- c(messages, paste("Message:", trimws(cli::ansi_strip(conditionMessage(m)))))
            invokeRestart("muffleMessage")
          }
        ),
        error = function(e) messages <<- c(messages, paste("Error:", cli::ansi_strip(conditionMessage(e))))
      )
      tagList(
        code_block(code, "pg-code-small"),
        code_block(
          if (length(messages)) {
            paste(messages, collapse = "\n")
          } else {
            "No R warning or error. Check the id against your UI; the browser receives updates for that id only."
          },
          "pg-log-message"
        )
      )
    })
  )
}

guide_mistake_calls <- function(fn, character) {
  checkmate::assert_string(fn)
  checkmate::assert_string(character)
  role <- mascot_colour_roles(character)$role[1]
  switch(
    fn,
    update_mascot = vapply(
      character_mistakes(character),
      function(x) sub(")$", ", session = session)", x$code),
      character(1)
    ),
    mascot = c('mascot("has spaces")', 'mascot("helper", click = c(help = "Help"))'),
    mascot_character = 'mascot_character("unknown-character")',
    mascot_mood = paste0(
      'mascot("helper", character = ',
      encodeString(character, quote = '"'),
      ', mood = mascot_mood("sleepy"))'
    ),
    mascot_status = 'mascot_status(1)',
    mascot_bubble = 'mascot_bubble("Hi", duration = 0)',
    mascot_motion_settings = 'mascot_motion_settings(idle = "yes")',
    mascot_gesture = 'mascot_gesture("unknown-gesture")',
    mascot_size = 'mascot_size(10)',
    mascot_placement = c('mascot_placement("unknown-position")', 'mascot_placement("inline", minimise = TRUE)'),
    mascot_colour_roles = sprintf('mascot_colour_roles(mascot_character(%s))', format_string(character)),
    mascot_moods = 'mascot_moods("unknown-character")',
    mascot_gestures = 'mascot_gestures("unknown-character")',
    mascot_anchors = 'mascot_anchors("unknown-character")',
    mascot_palettes = 'mascot_palettes("unknown-character")',
    mascot_characters = 'mascot_characters(family = "unknown-family")',
    mascot_theme = format_call("mascot_theme", list(light = named_call("list", stats::setNames("not-a-colour", role)))),
    mascot_action = 'mascot_action("Open help", FALSE)',
    mascot_popup_menu = c(
      'mascot_popup_menu(c("has spaces" = "Action"))',
      'mascot_popup_menu(c(about = "About"), "top")'
    ),
    mascot_preview = 'mascot_preview(size = 10)',
    mascot_example = 'mascot_example("unknown-example", run = FALSE)',
    mascot_studio = 'mascot_studio(view = "unknown-view", run = FALSE)',
    character()
  )
}
