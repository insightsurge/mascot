# The server of the "Theme a mascot" view (theme-ui.R builds its page). Plain helpers first, then the server.

# ---- Plain helpers ----------------------------------------------------------------------------------------------

# The theme argument as a code pair (shortcut and helper), or NULL when there is nothing to set: the character's own
# colours in auto mode need no theme argument. source is "mascot" (palette, own colours, CSS) or "bslib".
theme_view_theme <- function(
  source = "mascot",
  palette = "original",
  light = character(),
  dark = character(),
  mode = "auto",
  css = character(),
  primary = NULL,
  secondary = NULL
) {
  checkmate::assert_choice(source, c("mascot", "bslib"))
  checkmate::assert_string(palette, min.chars = 1)
  checkmate::assert_character(light, any.missing = FALSE)
  checkmate::assert_character(dark, any.missing = FALSE)
  checkmate::assert_choice(mode, c("auto", "light", "dark"))
  checkmate::assert_character(css, any.missing = FALSE)
  pair <- code_theme(source, light, dark, mode, css, primary, secondary, palette)
  if (identical(pair$helper, quote(mascot_theme()))) NULL else pair
}

# The mascot() call the preview shows, with only the arguments that differ from mascot()'s defaults. css_values
# names the CSS variables the theme reads with their values (c(`--app-accent` = "#7b4fd6")): a comment then says
# how a page sets them.
theme_view_call <- function(character, mood, theme = NULL, style = "short", css_values = character()) {
  checkmate::assert_string(character, min.chars = 1)
  checkmate::assert_string(mood, min.chars = 1)
  checkmate::assert_list(theme, null.ok = TRUE)
  checkmate::assert_choice(style, c("short", "helper"))
  checkmate::assert_character(css_values, min.chars = 1, any.missing = FALSE)
  if (length(css_values)) {
    checkmate::assert_names(names(css_values), type = "unique", .var.name = "names(css_values)")
  }
  pairs <- list(
    character = if (character != formals(mascot::mascot)$character) code_character(character),
    mood = if (mood != formals(mascot::mascot)$mood) code_mood(mood),
    theme = theme
  )
  pairs <- Filter(Negate(is.null), pairs)
  code <- format_call("mascot", c(list("helper"), pick_style(pairs, style)))
  if (!length(css_values)) {
    return(code)
  }
  style_tag <- sprintf('tags$style(":root { %s }")', paste0(names(css_values), ": ", css_values, ";", collapse = " "))
  paste0("# Your page sets the CSS variable, for example in its UI:\n# ", style_tag, "\n", code)
}

# The parts each brand colour colours, by slot (list(primary = "body", secondary = "rim")), from the character's
# colour roles; a role listed for both slots is in both. A character with no brand parts gets empty slots.
theme_brand_roles <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  roles <- mascot::mascot_colour_roles(character)
  slots <- strsplit(ifelse(is.na(roles$brand), "", roles$brand), ",\\s*")
  lapply(c(primary = "primary", secondary = "secondary"), function(slot) {
    roles$role[vapply(slots, function(each) slot %in% each, logical(1))]
  })
}

# The theme stack line: what each layer adds, in the order the package applies them (palette, own colours, CSS),
# and the mode. Returns one row per layer: its key, label, value and whether it can be cleared.
theme_stack_parts <- function(
  source = "mascot",
  palette = "original",
  light = character(),
  dark = character(),
  css = character(),
  mode = "auto"
) {
  checkmate::assert_choice(source, c("mascot", "bslib"))
  checkmate::assert_string(palette, min.chars = 1)
  checkmate::assert_character(light, any.missing = FALSE)
  checkmate::assert_character(dark, any.missing = FALSE)
  checkmate::assert_character(css, any.missing = FALSE)
  checkmate::assert_choice(mode, c("auto", "light", "dark"))
  counts <- c(light = length(light), dark = length(dark))
  used <- counts[counts > 0L]
  colours <- if (length(used)) paste(used, names(used), collapse = ", ") else "none"
  if (source == "bslib") {
    return(data.frame(
      key = c("bslib", "mode"),
      label = c("Brand", "mode"),
      value = c("bslib::bs_theme()", "auto"),
      clear = c(TRUE, FALSE),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    key = c("palette", "colours", "css", "mode"),
    label = c("Palette", "Your colours", "CSS", "mode"),
    value = c(
      palette,
      colours,
      if (length(css)) paste(length(css), if (length(css) == 1L) "part" else "parts") else "none",
      mode
    ),
    clear = c(palette != "original", any(counts > 0L), length(css) > 0L, mode != "auto"),
    stringsAsFactors = FALSE
  )
}

# The stack line as HTML: "Palette: coral_navy · Your colours: none · ...", with a clear button per layer in use.
theme_stack_ui <- function(parts) {
  checkmate::assert_data_frame(parts)
  checkmate::assert_names(names(parts), must.include = c("key", "label", "value", "clear"))
  items <- lapply(seq_len(nrow(parts)), function(i) {
    shiny::tags$span(
      class = "theme-stack-part",
      paste0(parts$label[[i]], ": "),
      shiny::tags$code(parts$value[[i]]),
      if (parts$clear[[i]]) {
        shiny::tags$button(
          type = "button",
          class = "btn btn-link btn-sm theme-stack-clear",
          `data-event` = "stack_clear",
          `data-value` = parts$key[[i]],
          `aria-label` = paste("Clear", parts$label[[i]]),
          "×"
        )
      }
    )
  })
  separated <- unlist(
    lapply(seq_along(items), function(i) {
      if (i == 1L) list(items[[i]]) else list(shiny::tags$span(class = "theme-stack-dot", "·"), items[[i]])
    }),
    recursive = FALSE
  )
  shiny::div(class = "theme-stack-line", `aria-label` = "Theme layers, in the order they apply", separated)
}

# ---- Server -----------------------------------------------------------------------------------------------------

theme_view_server <- function(input, output, session) {
  checkmate::assert_class(input, "reactivevalues")
  checkmate::assert_class(output, "shinyoutput")
  default_character <- formals(mascot::mascot)$character
  character <- shiny::reactive({
    value <- input$character
    if (isTRUE(value %in% unname(studio_characters()))) value else default_character
  })
  moods <- shiny::reactive(mascot::mascot_moods(character())$name)
  mood <- shiny::reactive(if (isTRUE(input$mood %in% moods())) input$mood else "idle")

  # The palette: one value, which the header menu and the Palette tab's cards both show and set.
  palette_now <- shiny::reactiveVal("original")
  palette <- shiny::reactive({
    value <- palette_now()
    if (value %in% studio_palette_choices(character())) value else "original"
  })
  pick_palette <- function(value) {
    if (isTRUE(value %in% studio_palette_choices(shiny::isolate(character())))) palette_now(value)
  }
  shiny::observeEvent(input$palette, pick_palette(input$palette))
  shiny::observeEvent(input$palette_grid, pick_palette(input$palette_grid))
  shiny::observeEvent(input$start_from, pick_palette(input$start_from))
  shiny::observeEvent(character(), {
    for (id in c("palette", "start_from")) {
      shiny::updateSelectInput(session, id, choices = studio_palette_labels(character()), selected = palette())
    }
    shiny::updateSelectInput(
      session,
      "mood",
      choices = stats::setNames(moods(), tools::toTitleCase(moods())),
      selected = mood()
    )
    palette_now(palette())
  })
  shiny::observeEvent(palette(), {
    shiny::updateSelectInput(session, "palette", selected = palette())
    shiny::updateSelectInput(session, "start_from", selected = palette())
    shiny::updateRadioButtons(session, "palette_grid", selected = palette())
  })
  output$palette_grid_ui <- shiny::bindEvent(
    shiny::renderUI(palette_grid(character(), shiny::isolate(palette()))),
    character()
  )

  # Your colours: a picker for every role, light and dark, and the parts that read the CSS variable.
  colours <- colour_roles_server(
    "colours",
    character,
    palette,
    css = theme_css_variable,
    resolved = FALSE,
    leader = "own colour"
  )
  # Brand colours. source is the one record of how the theme is written: "mascot" (palette, your colours, CSS) or
  # "bslib" (a bs_theme(), which replaces them). Only the Brand colours buttons and the stack line change it; opening
  # a tab never does.
  source <- shiny::reactiveVal("mascot")
  shiny::observeEvent(input$brand_source, {
    if (isTRUE(input$brand_source %in% c("mascot", "bslib"))) source(input$brand_source)
  })
  brand_roles <- shiny::reactive(theme_brand_roles(character()))
  brand <- shiny::reactive(list(
    primary = input$brand_primary %||% theme_brand_samples[[1]][[1]],
    secondary = input$brand_secondary %||% theme_brand_samples[[1]][[2]]
  ))
  # Written as your own colours, a brand colour sets its parts in both modes, as a plain list does. The pickers'
  # starting values set nothing: only a colour the user chooses does.
  for (slot in c("primary", "secondary")) {
    local({
      slot <- slot
      shiny::observeEvent(
        input[[paste0("brand_", slot)]],
        {
          for (role in brand_roles()[[slot]]) {
            for (each in c("light", "dark")) {
              colours$set(each, role, input[[paste0("brand_", slot)]])
            }
          }
        },
        ignoreInit = TRUE
      )
    })
  }
  shiny::observeEvent(input$brand_sample, {
    pair <- strsplit(input$brand_sample, ",", fixed = TRUE)[[1]]
    shiny::req(length(pair) == 2L, all(grepl("^#[0-9a-fA-F]{6}$", pair)))
    session$sendInputMessage("brand_primary", list(value = pair[[1]]))
    session$sendInputMessage("brand_secondary", list(value = pair[[2]]))
  })
  output$brand_parts <- shiny::renderUI(theme_brand_parts_ui(brand_roles(), mascot::mascot_character(character())$name))
  output$brand_source <- shiny::renderUI(theme_brand_source_ui(source(), brand_roles()))
  output$source_note <- shiny::renderUI({
    shiny::req(source() == "bslib")
    shiny::div(
      class = "pg-note pg-warn",
      "The mascot uses your bs_theme() from Brand colours: the palette, your own colours and the forced mode are kept",
      "but not used. ",
      shiny::tags$button(
        type = "button",
        class = "btn btn-link btn-sm p-0 align-baseline",
        `data-event` = "brand_source",
        `data-value` = "mascot",
        "Use mascot_theme() again"
      )
    )
  })

  mode <- shiny::reactive({
    if (source() == "bslib" || !isTRUE(input$mode %in% c("auto", "light", "dark"))) "auto" else input$mode
  })
  output$mode_ui <- shiny::renderUI(theme_mode_input(shiny::isolate(mode()), source() == "bslib"))
  for (name in c("mode_ui", "brand_parts", "brand_source")) {
    shiny::outputOptions(output, name, suspendWhenHidden = FALSE)
  }

  theme <- shiny::reactive({
    if (source() == "bslib") {
      return(theme_view_theme("bslib", primary = brand()$primary, secondary = brand()$secondary))
    }
    theme_view_theme("mascot", palette(), colours$light(), colours$dark(), mode(), colours$css())
  })
  # The values of the CSS variables the theme reads; none when no part reads one.
  css_values <- shiny::reactive({
    if (source() == "mascot" && length(colours$css())) colours$css_values() else base::character()
  })
  stack <- shiny::reactive({
    theme_stack_parts(source(), palette(), colours$light(), colours$dark(), colours$css(), mode())
  })
  output$theme_stack <- shiny::renderUI(theme_stack_ui(stack()))
  shiny::observeEvent(input$stack_clear, {
    switch(
      input$stack_clear,
      bslib = source("mascot"),
      palette = palette_now("original"),
      colours = {
        colours$reset("light")
        colours$reset("dark")
      },
      css = shiny::updateCheckboxGroupInput(session, "colours-css_roles", selected = base::character()),
      mode = shiny::updateRadioButtons(session, "mode", selected = "auto"),
      NULL
    )
  })

  output$theme_code <- shiny::renderText({
    style <- if (identical(input$code_style, "helper")) "helper" else "short"
    theme_view_call(character(), mood(), theme(), style, css_values())
  })

  # The live mascot: each change is sent with update_mascot(), as an app would, and only the parts that changed.
  # The page drew the mascot with the address's character, its idle mood and its own colours.
  sent <- new.env(parent = emptyenv())
  sent$character <- shiny::isolate(character())
  sent$mood <- "idle"
  sent$theme <- NULL
  last_update <- shiny::reactiveVal(NULL)
  sent$css <- base::character()
  drawn <- shiny::debounce(
    shiny::reactive(list(character = character(), mood = mood(), theme = theme(), css = css_values())),
    250
  )
  shiny::observeEvent(drawn(), {
    now <- drawn()
    changes <- list()
    if (!identical(now$character, sent$character)) {
      changes$character <- now$character
    }
    if (!identical(now$mood, sent$mood) || length(changes)) {
      changes$mood <- now$mood
    }
    # The browser reads a CSS variable again only when the theme is sent, so a new value sends it again.
    if (!identical(now$theme$helper, sent$theme$helper) || !identical(now$css, sent$css) || length(changes)) {
      changes$theme <- if (is.null(now$theme)) quote(mascot_theme()) else now$theme$helper
    }
    shiny::req(length(changes) > 0L)
    call <- as.call(c(list(quote(update_mascot), theme_preview_id), changes))
    result <- run_real_call(call, environment())
    if (result$ok) {
      sent$character <- now$character
      sent$mood <- now$mood
      sent$theme <- now$theme
      sent$css <- now$css
    }
    last_update(result)
  })
  output$preview_note <- shiny::renderUI({
    result <- last_update()
    shiny::req(result, result$class != "ok")
    shiny::div(
      class = paste("theme-note", if (result$class %in% c("error", "warning")) "is-warn"),
      role = "status",
      shiny::tags$span(class = "theme-muted", "The package says (", shiny::tags$code(result$class), "):"),
      shiny::tags$pre(class = "theme-message", result$message)
    )
  })

  shiny::observeEvent(input$start_again, session$reload())
  invisible(NULL)
}
