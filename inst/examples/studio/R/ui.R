# Building blocks for the studio's UI: argument fields with their explanations, function
# cards for the guide, and the small diagrams that explain each category.

the_guide <- function(fn) {
  checkmate::assert_string(fn)
  entry <- playground_guide[[fn]]
  session <- shiny::getDefaultReactiveDomain()
  character <- if (!is.null(session$userData$studio_character)) {
    session$userData$studio_character()
  } else {
    formals(mascot::mascot)$character
  }
  if (fn == "mascot_theme") {
    roles <- mascot::mascot_colour_roles(character)$role
    brand <- studio_brand(character)
    replacements <- c(body = brand$primary %||% roles[1], rim = brand$secondary %||% roles[min(2, length(roles))])
    for (arg in names(entry$args)) {
      for (field in c("hint", "example")) {
        text <- entry$args[[arg]][[field]]
        if (is.null(text)) {
          next
        }
        for (part in names(replacements)) {
          text <- gsub(paste0("\\b", part, "\\b"), replacements[[part]], text)
        }
        entry$args[[arg]][[field]] <- text
      }
    }
  }
  entry
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

chips <- function(values, class = "pg-chip") {
  lapply(values, function(value) tags$span(class = class, value))
}

# The popover behind an argument chip: everything the guide knows about the argument.
arg_popover_body <- function(fn, arg) {
  checkmate::assert_string(fn)
  checkmate::assert_string(arg)
  entry <- the_guide(fn)$args[[arg]]
  tagList(
    tags$p(entry$hint),
    tags$p(tags$strong("Accepts: "), chips(entry$accepts)),
    tags$p(tags$strong("Default: "), tags$code(argument_default(fn, arg))),
    if (!is.null(entry$null)) tags$p(tags$strong("NULL means: "), entry$null),
    if (!is.null(entry$detail)) tags$p(entry$detail),
    if (!is.null(entry$example)) code_block(entry$example, "pg-code-small")
  )
}

arg_chip <- function(fn, arg) {
  trigger <- tags$button(
    type = "button",
    class = "pg-arg-chip",
    `aria-label` = paste("About the", arg, "argument of", fn),
    tags$code(arg),
    tags$span(class = "pg-info", "i")
  )
  popover(trigger, arg_popover_body(fn, arg), title = tags$code(paste0(fn, "(", arg, " =)")))
}

# One argument: its chip (click for details), the control, and a one-line hint.
arg_field <- function(fn, arg, input, note = NULL) {
  entry <- the_guide(fn)$args[[arg]]
  div(
    class = "pg-field",
    `data-argument` = arg,
    div(
      class = "pg-field-head",
      arg_chip(fn, arg),
      tags$span(class = "pg-default", "default ", argument_default(fn, arg))
    ),
    div(class = "pg-hint", entry$hint),
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
    div(class = "pg-fn-what", the_guide(fn)$what),
    bslib::popover(
      tags$button(type = "button", class = "btn btn-outline-primary btn-sm", "Usage"),
      code_block(signature(fn), "pg-signature"),
      title = paste0(fn, "()")
    ),
    try_button("open_guide", fn, paste0("Guide: ", fn, "()")),
    div(class = "pg-returns", tags$strong("Returns: "), the_guide(fn)$returns),
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
              tags$span(the_guide(fn)$what)
            ),
            the_guide(fn)$what,
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
    helper <- paste0("mascot_", arg)
    arg_field(
      fn,
      arg,
      tags$p(
        class = "pg-hint",
        "Choose ",
        tags$code(paste0(helper, "()")),
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
  entry <- the_guide(fn)$args[[arg]]
  div(
    class = "pg-arg",
    tags$code(class = "pg-arg-name", arg),
    tags$span(class = "pg-default", "default ", tags$code(argument_default(fn, arg))),
    tags$span(entry$hint)
  )
}

function_card <- function(fn, example = FALSE) {
  entry <- the_guide(fn)
  arguments <- names(formals(get(fn, envir = asNamespace("mascot"))))
  bslib::card(
    full_screen = TRUE,
    `data-guide-function` = fn,
    bslib::card_header(tags$code(paste0(fn, "()"))),
    tags$h3(class = "pg-section-title", "Description"),
    tags$p(entry$what),
    tags$h3(class = "pg-section-title", "Usage"),
    code_block(signature(fn), "pg-signature"),
    tags$h3(class = "pg-section-title", "Arguments"),
    if (length(arguments)) {
      div(class = "pg-args", lapply(arguments, function(arg) arg_block(fn, arg)))
    } else {
      tags$p(class = "pg-muted", "No arguments.")
    },
    div(class = "pg-returns", tags$span(class = "pg-muted", "Returns"), entry$returns),
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
  for (piece in category_visual(the_guide(fn)$category, character)) {
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
        guide_arguments(fn),
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
    category_visual(category),
    tags$h3(class = "pg-section-title", "Functions"),
    lapply(category_functions(category), function_card)
  )
}

# ---- Visual explanations, one per category --------------------------------------------------

category_visual <- function(category, character = formals(mascot::mascot)$character) {
  switch(
    category,
    look = visual_look(),
    messages = visual_messages(),
    motion = visual_motion(),
    layout = visual_layout(),
    colours = visual_colours(character),
    menu = visual_menu(),
    wiring = visual_wiring(),
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

visual_look <- function() {
  tagList(
    tags$h3(class = "pg-section-title", paste("The", nrow(mascot_moods()), "moods")),
    data_table(mascot_moods()),
    div(
      class = "pg-callout",
      tags$strong("The mood never speaks alone. "),
      "The status line under the mascot names the mood (or shows your text), so the meaning is there for
      screen readers and for anyone who cannot tell the faces apart. Choose mascot_mood() in the index to try it."
    )
  )
}

visual_messages <- function() {
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
    data_table(rows),
    tags$h3(class = "pg-section-title", "How long a bubble stays"),
    div(
      class = "pg-timeline",
      div(class = "pg-timeline-bar", div(class = "pg-timeline-fill")),
      div(class = "pg-timeline-labels", tags$span("shown"), tags$span("duration = 5: hides"), tags$span("Inf: stays"))
    ),
    div(
      class = "pg-callout pg-callout-warn",
      tags$strong("HTML is trusted as it is. "),
      "Plain text is escaped, so it is always safe. Wrap only your own content in HTML(), never text a
      visitor typed: it could run code in other visitors' browsers. Bootstrap classes such as badge, table
      and progress work inside the bubble because your bslib page already has Bootstrap."
    )
  )
}

visual_motion <- function() {
  gestures <- mascot_gestures()
  cell <- function(title, body) div(class = "pg-grid-cell", tags$strong(title), div(class = "pg-muted", body))
  tagList(
    tags$h3(class = "pg-section-title", "What animate and swap do together"),
    div(
      class = "pg-grid2",
      div(class = "pg-grid-head"),
      div(class = "pg-grid-head", tags$code("swap = TRUE")),
      div(class = "pg-grid-head", tags$code("swap = FALSE")),
      div(class = "pg-grid-head", tags$code("animate = TRUE")),
      cell("Everything animates", "Moods wiggle, gestures play, character swaps animate."),
      cell("Swaps are instant", "Moods and gestures still animate."),
      div(class = "pg-grid-head", tags$code("animate = FALSE")),
      cell("Everything is instant", "swap has no effect."),
      cell("Everything is instant", "swap has no effect.")
    ),
    div(
      class = "pg-callout",
      tags$strong("The visitor decides first. "),
      "When a visitor turns on reduced motion in their system settings, every change is instant, whatever
      you set here. To try it without changing your settings, use your browser's developer tools: in
      Chrome, Rendering, then \"Emulate CSS media feature prefers-reduced-motion\"."
    ),
    tags$h3(class = "pg-section-title", "Gestures"),
    div(
      class = "pg-cards",
      lapply(seq_len(nrow(gestures)), function(i) {
        bslib::card(
          class = "pg-card-mini",
          div(class = "pg-card-title", tools::toTitleCase(gestures$name[i])),
          div(class = "pg-muted", gestures$description[i]),
          div(class = "pg-card-foot", tags$code(sprintf("gesture = \"%s\"", gestures$name[i]))),
          try_button("gesture", gestures$name[i], "Play it")
        )
      })
    )
  )
}

visual_layout <- function() {
  tagList(
    tags$h3(class = "pg-section-title", "Size"),
    uiOutput("size_ruler"),
    tags$h3(class = "pg-section-title", "Placement"),
    tags$p(
      class = "pg-muted",
      "A plain mascot() floats in the bottom-right corner. This studio starts the selected character inline with placement = \"inline\" so it stays on the canvas."
    ),
    uiOutput("placement_map"),
    div(
      class = "pg-callout",
      tags$strong("Small screens. "),
      "small_screen applies at 576 pixels wide or less. Narrow your browser window to see the mascot switch
      size."
    )
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
    tags$button(
      type = "button",
      class = paste("pg-map-corner", paste0("pg-", corner_id), if (active) "is-active"),
      `data-event` = "set_position",
      `data-value` = corner_id,
      `aria-label` = paste("Float in the", sub("-", " ", corner_id, fixed = TRUE), "corner"),
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
      tags$button(
        type = "button",
        class = paste("pg-map-inline", if (inline_active) "is-active"),
        `data-event` = "set_position",
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
        "Inline: the mascot sits where mascot() is in your UI and scrolls with the page."
      } else {
        paste0(
          "Floating in the ",
          sub("-", " ", position, fixed = TRUE),
          " corner of the window",
          if (minimise) ", with a minimise button" else "",
          ". Click a corner to move it."
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

visual_colours <- function(character) {
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
    ),
    tags$h3(class = "pg-section-title", paste0(mascot_character(character)$name, "'s parts")),
    tags$p(
      class = "pg-muted",
      "Leaders take the colours you give. Followers copy the first leader you set, made the same, lighter or
      darker, unless you set them yourself. Contrast below 3:1 against the page is kept but warned about."
    ),
    uiOutput("roles_table")
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
      step(tags$code("updateMascot()"), div("answers"))
    ),
    div(class = "pg-live", tags$span(class = "pg-muted", "Last choice here: "), textOutput("menu_last", inline = TRUE)),
    tags$h3(class = "pg-section-title", "Your server code for these items"),
    div(class = "pg-code-wrap", code_output("menu_code"), copy_button("menu_code")),
    div(
      class = "pg-callout",
      tags$strong("Keyboard. "),
      "Tab to the mascot's menu button, then Enter or Space opens it; arrow keys move between items; Escape
      closes it."
    )
  )
}

visual_wiring <- function() {
  tagList(
    tags$h3(class = "pg-section-title", "Two calls, one id"),
    div(
      class = "pg-wire",
      div(
        class = "pg-wire-box",
        div(class = "pg-muted", "UI"),
        code_block("mascot(id = \"helper\")")
      ),
      div(class = "pg-flow-arrow", "\u2194"),
      div(
        class = "pg-wire-box",
        div(class = "pg-muted", "server"),
        code_block("updateMascot(\"helper\", mood = \"happy\")")
      )
    ),
    div(
      class = "pg-wire",
      div(
        class = "pg-wire-box",
        div(class = "pg-muted", "module UI"),
        code_block("mascot(id = ns(\"helper\"))")
      ),
      div(class = "pg-flow-arrow", "\u2194"),
      div(
        class = "pg-wire-box",
        div(class = "pg-muted", "module server"),
        code_block("updateMascot(\"helper\", mood = \"happy\")")
      )
    ),
    tags$h3(class = "pg-section-title", "What each kind of value does in updateMascot()"),
    data_table(data.frame(
      `You pass` = c("nothing (NULL)", "an empty helper", "a value"),
      Example = c("mood = NULL", "bubble = mascot_bubble()", "mood = \"happy\""),
      `The mascot` = c("keeps it as it is", "clears it or goes back to the default", "changes it"),
      check.names = FALSE
    )),
    div(
      class = "pg-callout",
      tags$strong("All or nothing. "),
      "updateMascot() checks every value first. If one is wrong, it warns, names the problem and sends
      nothing, so the mascot never ends up half updated. A misspelt argument name or a call outside a
      server is an error, because that is a mistake in the code rather than in the data."
    )
  )
}

# Each Guide section has one builder so further material can grow independently.
guide_arguments <- function(fn) {
  checkmate::assert_string(fn)
  div(
    class = "pg-guide-piece",
    tags$h3(class = "pg-section-title", "Argument details"),
    lapply(names(the_guide(fn)$args), function(arg) {
      tagList(
        tags$h4(tags$code(arg)),
        arg_popover_body(fn, arg)
      )
    }),
    if (!length(the_guide(fn)$args)) tags$p("No arguments.")
  )
}

# Evaluate only against a disposable mock session. No message reaches the live mascot.
guide_mistakes <- function(fn, character) {
  checkmate::assert_string(fn)
  checkmate::assert_string(character)
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
    updateMascot = vapply(
      character_mistakes(character),
      function(x) sub(")$", ", session = session)", x$code),
      character(1)
    ),
    mascot = 'mascot(id = "has spaces")',
    mascot_character = 'mascot_character("unknown-character")',
    mascot_mood = 'mascot_mood("sleepy")',
    mascot_status = 'mascot_status(1)',
    mascot_bubble = 'mascot_bubble("Hi", duration = 0)',
    mascot_motion = 'mascot_motion(animate = "yes")',
    mascot_gesture = 'mascot_gesture("unknown-gesture")',
    mascot_size = 'mascot_size(10)',
    mascot_placement = c('mascot_placement("unknown-position")', 'mascot_placement("inline", minimise = TRUE)'),
    mascot_colour_roles = sprintf('mascot_colour_roles(mascot_character(%s))', format_string(character)),
    mascot_theme = format_call("mascot_theme", list(light = named_call("list", stats::setNames("not-a-colour", role)))),
    mascot_popup_menu = 'mascot_popup_menu(c("has spaces" = "Action"))',
    mascot_preview = 'mascot_preview(size = 10)',
    mascot_example = 'mascot_example("unknown-example", run = FALSE)',
    mascot_studio = 'mascot_studio(view = "unknown-view", run = FALSE)',
    character()
  )
}
