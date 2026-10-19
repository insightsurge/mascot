# The "Warnings, errors and common mistakes" of each guide page: the calls to try, the text that says why,
# and the real messages R gives. Shared by the studio (which draws the section in R/ui.R) and the website
# (which draws it from the page with guide_mistakes_html()), so the calls and their evaluation exist once.
# Standalone: base R, mascot::, cli, shiny::MockShinySession and htmltools only.

guide_mistake_base <- list(
  `Borrow another character's palette` = list(
    code = NULL,
    why = "mascot() errors and lists this character's palettes. The hint names another character that has this id; palettes cannot be borrowed between characters yet."
  ),
  `A made-up palette id` = list(
    code = NULL,
    why = "mascot() errors and lists this character's palettes. No character has this id, so there is no borrowed-palette hint."
  ),
  `An unknown palette in an update` = list(
    code = NULL,
    why = "update_mascot() warns (class mascot_update_ignored) and ignores the whole update. The mascot and its current palette stay unchanged; nothing is dropped."
  ),
  `Leave out an argument name` = list(
    code = "update_mascot(\"helper\", \"happy\")",
    why = "Arguments after id must be named. An unnamed argument reports \"an unnamed argument\" and lists the valid names."
  ),
  `A mood that does not exist` = list(
    code = "update_mascot(\"helper\", mood = \"sleepy\")",
    why = "Displays a warning listing valid moods. The mascot keeps its current mood."
  ),
  `Misspell an argument` = list(
    code = "update_mascot(\"helper\", moood = \"happy\")",
    why = "... must be empty, so typos produce an error listing the valid argument names."
  ),
  `Invalid helper value` = list(
    code = "update_mascot(\"helper\", size = mascot_size(10))",
    why = "A helper that errors gives a warning (class mascot_update_ignored); the whole update is ignored and the mascot stays unchanged."
  ),
  `Too small` = list(code = "update_mascot(\"helper\", size = 10)", why = "Sizes must be at least 24 pixels."),
  `Minimise an inline mascot` = list(
    code = "update_mascot(\"helper\", placement = mascot_placement(\"inline\", minimise = TRUE))",
    why = "An inline mascot ignores minimise. An informational message explains this, and the mascot sits inline."
  ),
  `A bubble that never shows` = list(
    code = "update_mascot(\"helper\", bubble = mascot_bubble(\"Hi\", duration = 0))",
    why = "duration must be greater than zero. Use Inf to keep the bubble open."
  ),
  `Not a colour` = list(
    code = "update_mascot(\"helper\", theme = list(body = \"not-a-colour\"))",
    why = "Colours are validated in R before sending to the browser."
  ),
  `Low contrast` = list(
    code = "update_mascot(\"helper\", theme = list(body = \"#f8f9fa\"))",
    why = "The colour is applied, with a warning if contrast against the page is low."
  ),
  `The wrong id` = list(
    code = "update_mascot(\"helpr\", mood = \"happy\")",
    why = paste(
      "No error and no change: the server cannot see browser elements. With shiny::devmode(TRUE), the browser",
      "console reports the missing element."
    )
  )
)

# Use a real palette owned by another shipped character, and an id that no character owns.
guide_mistake_palettes <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  own <- mascot::mascot_palettes(character)$name
  others <- setdiff(mascot::mascot_characters()$id, character)
  available <- unique(unlist(lapply(others, function(id) mascot::mascot_palettes(id)$name)))
  borrowed <- setdiff(available, c("original", own))
  invented <- "zzzzzz"
  while (invented %in% c(own, available)) {
    invented <- paste0(invented, "z")
  }
  list(borrowed = if (length(borrowed)) borrowed[[1L]], invented = invented)
}

guide_character_mistakes <- function(character) {
  checkmate::assert_string(character)
  role <- mascot::mascot_colour_roles(character)$role[1]
  result <- guide_mistake_base
  palettes <- guide_mistake_palettes(character)
  for (name in c("Borrow another character's palette", "A made-up palette id", "An unknown palette in an update")) {
    updating <- identical(name, "An unknown palette in an update")
    palette <- if (name == "A made-up palette id") palettes$invented else palettes$borrowed
    if (is.null(palette)) {
      # No borrowed example is possible if all shipped characters ever share exactly the same ids.
      result[[name]] <- NULL
      next
    }
    result[[name]]$code <- sprintf(
      '%s("helper", character = %s, theme = %s)',
      if (updating) "update_mascot" else "mascot",
      encodeString(character, quote = '"'),
      encodeString(palette, quote = '"')
    )
  }
  for (name in c("Not a colour", "Low contrast")) {
    result[[name]]$code <- sub(
      "body =",
      paste0(deparse1(as.name(role), backtick = TRUE), " ="),
      result[[name]]$code,
      fixed = TRUE
    )
  }
  result
}

guide_mistake_calls <- function(fn, character) {
  checkmate::assert_string(fn)
  checkmate::assert_string(character)
  role <- mascot::mascot_colour_roles(character)$role[1]
  mistakes <- guide_character_mistakes(character)
  update_cases <- Filter(function(x) startsWith(x$code, "update_mascot("), mistakes)
  palette_cases <- Filter(function(x) startsWith(x$code, "mascot("), mistakes)
  switch(
    fn,
    update_mascot = vapply(
      update_cases,
      function(x) sub(")$", ", session = session)", x$code),
      character(1)
    ),
    mascot = c(
      'mascot("has spaces")',
      'mascot("helper", click = c(help = "Help"))',
      vapply(palette_cases, function(x) x$code, character(1))
    ),
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
    mascot_colour_roles = sprintf('mascot_colour_roles(mascot_character(%s))', encodeString(character, quote = '"')),
    mascot_moods = 'mascot_moods("unknown-character")',
    mascot_gestures = 'mascot_gestures("unknown-character")',
    mascot_anchors = 'mascot_anchors("unknown-character")',
    mascot_palettes = 'mascot_palettes("unknown-character")',
    mascot_characters = 'mascot_characters(family = "unknown-family")',
    # The palette mistakes belong here too: the palette argument of mascot_theme() is where they start.
    mascot_theme = c(
      sprintf('mascot_theme(light = list(%s = "not-a-colour"))', deparse1(as.name(role), backtick = TRUE)),
      vapply(palette_cases, function(x) x$code, character(1)),
      vapply(
        update_cases[names(update_cases) == "An unknown palette in an update"],
        function(x) sub(")$", ", session = session)", x$code),
        character(1)
      )
    ),
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

# Run the calls of `fn` against a disposable mock session (no message reaches a live mascot) and collect what
# R says. Returns a list with one element per call: code, why (a sentence or NULL) and messages.
guide_mistake_cases <- function(fn, character) {
  checkmate::assert_string(fn, min.chars = 1)
  checkmate::assert_string(character, min.chars = 1)
  old_contrast <- getOption("mascot.contrast_warnings")
  on.exit(options(mascot.contrast_warnings = old_contrast), add = TRUE)
  if (is.null(old_contrast)) {
    options(mascot.contrast_warnings = TRUE)
  }
  cases <- guide_mistake_calls(fn, character)
  described <- guide_character_mistakes(character)
  lapply(seq_along(cases), function(i) {
    code <- cases[[i]]
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
    label <- if (is.null(names(cases))) "" else names(cases)[[i]]
    list(code = code, why = described[[label]]$why, messages = messages)
  })
}

# What a call without a message tells the reader.
guide_no_message <- "No R warning or error. Check the id against your UI; the browser receives updates for that id only."

# The section as tags, for the website (the studio draws its own with its code blocks and copy buttons).
guide_mistakes_html <- function(fn, character = formals(mascot::mascot)$character) {
  checkmate::assert_string(fn, min.chars = 1)
  checkmate::assert_string(character, min.chars = 1)
  tags <- htmltools::tags
  cases <- guide_mistake_cases(fn, character)
  htmltools::tagList(
    tags$h3(class = "pg-section-title", "Warnings, errors and common mistakes"),
    if (!length(cases)) tags$p("This listing takes no arguments. Use its returned names rather than typing guesses."),
    lapply(cases, function(case) {
      htmltools::tagList(
        tags$pre(class = "pg-code-small", tags$code(case$code)),
        if (!is.null(case$why)) tags$p(case$why),
        tags$pre(
          class = "pg-log-message",
          tags$code(if (length(case$messages)) paste(case$messages, collapse = "\n") else guide_no_message)
        )
      )
    })
  )
}
