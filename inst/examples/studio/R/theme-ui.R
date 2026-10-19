# The "Theme a mascot" view (mascot_studio(view = "theme"), ?view=theme): one character, themed with live feedback,
# and the plain R code to copy. This file builds its page; theme-server.R holds its server. The view uses the
# studio app's shared parts (R/shared-*.R, R/code.R, www/tokens.css, www/inputs.js), never studio.js.

# The id of the live mascot. The code shown uses "helper", the id the package's examples use.
theme_preview_id <- "theme_mascot"

# The variable the CSS part of Your colours offers, with its starting value.
theme_css_variable <- c(`--app-accent` = "#7b4fd6")

# Brand colour pairs to try (primary, secondary); the pickers start with the first.
theme_brand_samples <- list(
  c("#1f6feb", "#966600"),
  c("#0f766e", "#c2410c"),
  c("#7c3aed", "#db2777"),
  c("#b91c1c", "#1e3a8a")
)

# The page: a header, the preview with its code on the left, the tabs on the right (stacked on a phone).
theme_view_ui <- function(query) {
  checkmate::assert_list(query)
  character <- view_character(query)
  shiny::tagList(
    shiny::tags$head(
      shiny::tags$link(rel = "stylesheet", href = "tokens.css"),
      shiny::tags$link(rel = "stylesheet", href = "shared.css"),
      shiny::tags$link(rel = "stylesheet", href = "theme.css"),
      shiny::tags$script(src = "inputs.js")
    ),
    shiny::div(
      class = "theme-page",
      theme_header(character),
      shiny::div(
        class = "theme-main",
        shiny::div(class = "theme-left", theme_preview_card(character), theme_code_card()),
        shiny::div(class = "theme-right", theme_tabs(character))
      )
    )
  )
}

# The header: character, palette and mood, the page's light/dark switch and Start again.
theme_header <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  moods <- mascot::mascot_moods(character)$name
  shiny::tags$header(
    class = "theme-header",
    shiny::tags$h1(class = "theme-title", studio_view_titles[["theme"]]),
    shiny::div(
      class = "theme-header-controls",
      role = "group",
      `aria-label` = "Character, palette and mood",
      shiny::selectInput("character", "Character", studio_characters(), selected = character, selectize = FALSE),
      shiny::selectInput(
        "palette",
        "Palette",
        studio_palette_labels(character),
        selected = "original",
        selectize = FALSE
      ),
      shiny::selectInput(
        "mood",
        "Mood",
        stats::setNames(moods, tools::toTitleCase(moods)),
        selected = "idle",
        selectize = FALSE
      ),
      shiny::div(
        class = "theme-page-mode",
        shiny::tags$span(class = "theme-label", "Page"),
        bslib::input_dark_mode(id = "page_mode", mode = "light")
      ),
      shiny::actionButton("start_again", "Start again", class = "btn-outline-primary btn-sm")
    )
  )
}

# The live mascot on a plain page surface, as an app would show it.
theme_preview_card <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  shiny::tags$section(
    class = "theme-preview",
    `aria-label` = "Preview",
    shiny::div(
      class = "theme-preview-stage",
      mascot::mascot(
        theme_preview_id,
        character = character,
        # The size follows the stage, which is smaller on a phone so the mascot stays in view while editing.
        size = mascot::mascot_size("100%", small_screen = NULL),
        placement = "inline"
      )
    ),
    shiny::uiOutput("preview_note")
  )
}

# The live R code, its Copy button, the Shortcut/Helper switch and the theme stack line.
theme_code_card <- function() {
  shiny::tags$section(
    class = "theme-code",
    `aria-label` = "R code",
    shiny::div(
      class = "theme-code-head",
      shiny::tags$h2(class = "theme-section-title", "R code"),
      shiny::div(
        title = paste(
          "Shortcuts are plain values, for example theme = \"coral_navy\".",
          "Helpers are mascot_*() calls, for example theme = mascot_theme(palette = \"coral_navy\").",
          "Both give the same mascot."
        ),
        shiny::radioButtons("code_style", NULL, c(Shortcut = "short", Helper = "helper"), inline = TRUE)
      ),
      copy_button("theme_code")
    ),
    shiny::tagAppendAttributes(shiny::verbatimTextOutput("theme_code"), class = "theme-code-text"),
    shiny::uiOutput("theme_stack", class = "theme-stack")
  )
}

# The four tabs, with one sentence that routes the common questions.
theme_tabs <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  shiny::tagList(
    shiny::tags$p(
      class = "theme-route",
      "Start with a palette. Have brand colours? Use Brand colours. Seen a warning? Use Check."
    ),
    shiny::uiOutput("source_note"),
    bslib::navset_underline(
      id = "theme_tabs",
      bslib::nav_panel("Palette", value = "palette", theme_palette_tab()),
      bslib::nav_panel("Your colours", value = "colours", theme_colours_tab(character)),
      bslib::nav_panel("Brand colours", value = "brand", theme_brand_tab()),
      bslib::nav_panel("Check", value = "check", theme_check_tab())
    )
  )
}

theme_palette_tab <- function() {
  shiny::div(
    class = "theme-tab",
    shiny::tags$p(
      class = "theme-lead",
      "Colour sets made for this character. Each one sets the main colours; the other parts follow them."
    ),
    shiny::uiOutput("palette_grid_ui")
  )
}

# Your colours: a starting palette, a picker for every role in light and dark mode, the parts that read a CSS
# variable, and the mode the mascot is forced into. The pickers are the colour_roles_server("colours") module's.
theme_colours_tab <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  pickers <- colour_roles_ui("colours")
  shiny::div(
    class = "theme-tab",
    shiny::tags$p(
      class = "theme-lead",
      "Change any part's colour. A part marked \"follows body\" takes a lighter or darker shade of that colour until",
      "you set it."
    ),
    shiny::div(
      class = "theme-colours-head",
      shiny::selectInput(
        "start_from",
        "Start from",
        studio_palette_labels(character),
        selected = "original",
        selectize = FALSE
      ),
      shiny::uiOutput("mode_ui")
    ),
    shiny::tags$p(
      class = "theme-muted",
      "Start from sets the palette, as the Palette tab does. Force the mascot sets mode =; the page switch above is",
      "your app's own light/dark switch.",
      shiny::tags$a(
        href = "?view=studio&fn=mascot_theme",
        target = "_blank",
        rel = "noopener",
        "Full reference in the studio"
      )
    ),
    bslib::navset_underline(
      id = "colour_modes",
      bslib::nav_panel("Light", value = "light", pickers$light),
      bslib::nav_panel("Dark", value = "dark", pickers$dark),
      bslib::nav_panel(
        "CSS variables",
        value = "css",
        theme_css_experimental(),
        shiny::tags$p(
          class = "theme-muted",
          "Parts you tick read the variable ",
          shiny::tags$code(names(theme_css_variable)),
          " from your page, after the palette and your light and dark colours. The picker sets it on this page."
        ),
        pickers$css
      )
    )
  )
}

# The experimental status of the CSS source, in the words of ?mascot_theme (its css argument), so the two cannot
# drift apart, with the badge the studio uses for experimental parts.
theme_css_experimental <- function() {
  # The help text wraps lines anywhere, so spaces are made single before the sentence is found.
  text <- gsub("\\s+", " ", paste(as.character(help_arg("mascot_theme", "css")), collapse = " "))
  tail <- studio_help_tail(text, "This source is experimental")
  shiny::div(
    class = "pg-note",
    shiny::tags$span(class = "badge text-bg-warning", "Experimental"),
    if (!is.null(tail)) paste0(" ", sub("[.].*$", ".", html_text(tail)))
  )
}

# Force the mascot: mode =. A bs_theme() always follows the page, so the control is disabled for it.
theme_mode_input <- function(selected = "auto", disabled = FALSE) {
  checkmate::assert_choice(selected, c("auto", "light", "dark"))
  checkmate::assert_flag(disabled)
  shiny::tags$fieldset(
    disabled = if (disabled) NA,
    shiny::radioButtons(
      "mode",
      "Force the mascot",
      c("auto (follow the page)" = "auto", light = "light", dark = "dark"),
      selected = if (disabled) "auto" else selected,
      inline = TRUE
    )
  )
}

# Brand colours: primary and secondary pickers with sample pairs, the parts they colour (output$brand_parts) and
# how the code writes them (output$brand_source).
theme_brand_tab <- function() {
  slots <- c("primary", "secondary")
  shiny::div(
    class = "theme-tab",
    shiny::tags$p(
      class = "theme-lead",
      "Colour the mascot with your app's brand colours: a primary and a secondary colour for the character's brand",
      "parts."
    ),
    shiny::uiOutput("brand_parts"),
    shiny::div(
      class = "theme-brand-pickers",
      lapply(seq_along(slots), function(i) {
        label <- paste(tools::toTitleCase(slots[[i]]), "colour")
        shiny::tags$label(
          class = "pg-css",
          colour_input(paste0("brand_", slots[[i]]), theme_brand_samples[[1]][[i]], label),
          shiny::tags$span(label)
        )
      })
    ),
    shiny::div(
      class = "theme-brand-samples",
      role = "group",
      `aria-label` = "Sample brand colours",
      shiny::tags$span(class = "theme-muted", "Try a pair:"),
      lapply(theme_brand_samples, function(pair) {
        shiny::tags$button(
          type = "button",
          class = "btn btn-outline-secondary btn-sm theme-brand-sample",
          `data-event` = "brand_sample",
          `data-value` = paste(pair, collapse = ","),
          `aria-label` = paste("Primary", pair[[1]], "and secondary", pair[[2]]),
          lapply(pair, function(colour) shiny::tags$span(class = "theme-swatch", style = paste0("background:", colour)))
        )
      })
    ),
    shiny::uiOutput("brand_source")
  )
}

# How the Brand colours tab writes the colours: as your own colours (a plain list, stable) or, after the button, as a
# bslib::bs_theme() (experimental), which replaces the palette and your own colours.
theme_brand_source_ui <- function(source, roles) {
  checkmate::assert_choice(source, c("mascot", "bslib"))
  checkmate::assert_list(roles, types = "character", names = "unique")
  if (source == "bslib") {
    return(shiny::tagList(
      shiny::tags$h3(class = "theme-section-title", "Written as bslib::bs_theme()"),
      studio_bslib_experimental(),
      shiny::tags$p(
        class = "theme-muted",
        "The palette, your own colours and the forced mode are kept here but not used: a bs_theme() replaces them and",
        "always follows the page (mode = \"auto\")."
      ),
      shiny::tags$button(
        type = "button",
        class = "btn btn-outline-primary btn-sm",
        `data-event` = "brand_source",
        `data-value` = "mascot",
        "Use mascot_theme() again"
      )
    ))
  }
  shiny::tagList(
    shiny::tags$h3(class = "theme-section-title", "Written as your own colours"),
    shiny::tags$p(
      class = "theme-muted",
      if (length(unlist(roles))) {
        "A colour you choose here goes into Your colours, the same in light and dark mode; the code is a plain list."
      } else {
        "This character has no brand parts, so the colours here change nothing."
      }
    ),
    shiny::tags$p(
      class = "theme-muted",
      "Your app uses bslib? Its bs_theme() can colour the same parts. It replaces the palette and your own colours."
    ),
    shiny::tags$button(
      type = "button",
      class = "btn btn-outline-primary btn-sm",
      `data-event` = "brand_source",
      `data-value` = "bslib",
      "Use bs_theme() instead"
    )
  )
}

# The parts each brand colour colours, from mascot_colour_roles()$brand; a character with none says so.
theme_brand_parts_ui <- function(roles, name) {
  checkmate::assert_list(roles, types = "character", names = "unique")
  checkmate::assert_string(name, min.chars = 1)
  if (!length(unlist(roles))) {
    return(shiny::div(
      class = "pg-note",
      name,
      " has no parts that take brand colours. Use Your colours to colour any part."
    ))
  }
  shiny::tags$ul(
    class = "theme-brand-parts",
    lapply(names(roles), function(slot) {
      shiny::tags$li(
        paste(tools::toTitleCase(slot), "colours "),
        if (length(roles[[slot]])) {
          lapply(seq_along(roles[[slot]]), function(i) {
            shiny::tagList(if (i > 1L) ", ", shiny::tags$code(roles[[slot]][[i]]))
          })
        } else {
          "no part"
        },
        paste0(" (", name, ").")
      )
    })
  )
}

# The four scenarios of the Check tab, by the value their button sends: a title and the call that runs.
# kept and dropped are character swaps (palette_swap_run()); the others are one call each.
theme_check_scenarios <- function() {
  swap <- studio_palette_swap
  name <- function(id) mascot::mascot_character(id)$name
  list(
    kept = list(title = paste(name(swap[["from"]]), "in", swap[["palette"]], "becomes", name(swap[["kept"]]))),
    dropped = list(title = paste(name(swap[["from"]]), "in", swap[["palette"]], "becomes", name(swap[["dropped"]]))),
    contrast = list(
      title = "A colour that is hard to see",
      call = call("update_mascot", "check_demo", character = swap[["from"]], theme = list(rim = "#f5e6c8"))
    ),
    missing = list(
      title = paste("A palette", name(swap[["dropped"]]), "does not have"),
      call = call("mascot", "helper", character = swap[["dropped"]], theme = swap[["palette"]])
    )
  )
}

# Check: every mood in light and dark (mascot_preview()), the contrast check, and what the package says in four
# common cases, run as real calls.
theme_check_tab <- function() {
  scenarios <- theme_check_scenarios()
  shiny::div(
    class = "theme-tab",
    shiny::tags$p(
      class = "theme-lead",
      "See what the package does when you swap characters or choose a colour that is hard to see."
    ),
    shiny::tags$h3(class = "theme-section-title", "Every mood, light and dark"),
    shiny::tags$p(
      class = "theme-muted",
      shiny::tags$span(class = "badge text-bg-warning", "Experimental"),
      " The page mascot_preview() builds for this theme: every mood in light and dark, at your size and smaller.",
      " It checks only colours you supplied; palette colours never warn."
    ),
    shiny::actionButton("check_preview", "Show every mood", class = "btn-outline-primary btn-sm"),
    shiny::uiOutput("check_preview_ui"),
    shiny::tags$h3(class = "theme-section-title", "Contrast"),
    shiny::tags$p(
      class = "theme-muted",
      "Each colour you chose is compared with the page background: white in light mode and #212529 in dark mode, or",
      "your bs_theme()'s backgrounds. A colour needs at least 3:1 contrast to be easy to see."
    ),
    shiny::actionButton("check_contrast", "Check contrast", class = "btn-outline-primary btn-sm"),
    shiny::uiOutput("check_contrast_ui"),
    shiny::tags$h3(class = "theme-section-title", "When you swap characters or pick a hard-to-see colour"),
    shiny::tags$p(
      class = "theme-muted",
      "Each button runs real package calls on the mascot below and shows what the package says, in its own words."
    ),
    shiny::div(
      class = "theme-check-demo",
      shiny::div(
        class = "theme-check-mascot",
        mascot::mascot(
          "check_demo",
          character = studio_palette_swap[["from"]],
          theme = studio_palette_swap[["palette"]],
          size = 96,
          placement = "inline",
          motion = FALSE
        )
      ),
      shiny::div(
        class = "theme-check-buttons",
        lapply(names(scenarios), function(key) {
          shiny::tags$button(
            type = "button",
            class = "btn btn-outline-primary btn-sm",
            `data-event` = "check_scenario",
            `data-value` = key,
            scenarios[[key]]$title
          )
        })
      )
    ),
    shiny::div(role = "status", shiny::uiOutput("check_scenario_ui"))
  )
}

# What a scenario's calls did: the code that ran, the outcome, the package's message and the classes of its
# conditions, and the line that silences it when there is one. outcome adds what happened when the package says
# nothing (a palette kept over a swap).
theme_check_result_ui <- function(title, code, result, outcome = NULL) {
  checkmate::assert_string(title, min.chars = 1)
  checkmate::assert_string(code, min.chars = 1)
  checkmate::assert_list(result)
  checkmate::assert_string(outcome, min.chars = 1, null.ok = TRUE)
  checkmate::assert_names(names(result), must.include = c("ok", "class", "message", "silencer", "condition_classes"))
  specific <- setdiff(
    grep("^mascot_", result$condition_classes, value = TRUE),
    c("mascot_warning", "mascot_message", "mascot_error")
  )
  shiny::div(
    class = paste("theme-check-result", if (result$class %in% c("error", "warning")) "is-warn"),
    shiny::tags$h4(class = "theme-check-title", title),
    shiny::tags$pre(class = "theme-code-text", code),
    shiny::tags$p(class = "theme-check-outcome", "Outcome: ", shiny::tags$code(result$class)),
    if (length(specific)) {
      shiny::tags$p(class = "theme-check-outcome", "Class: ", shiny::tags$code(paste(specific, collapse = ", ")))
    },
    if (!result$ok) {
      shiny::tags$p(
        class = "theme-check-outcome",
        if (result$class == "error") "The call stopped with an error." else "The mascot is unchanged."
      )
    },
    if (!is.null(result$message)) shiny::tags$pre(class = "theme-message", result$message),
    if (is.null(result$message)) shiny::tags$p("The package says nothing: the call ran as written.", outcome),
    if (!is.null(result$silencer)) {
      shiny::tagList(
        shiny::tags$p(class = "theme-muted", "To silence only this warning:"),
        shiny::tags$pre(class = "theme-code-text", result$silencer)
      )
    }
  )
}

# The palette cards as one radio group (input$palette_grid): each card is the drawn mascot in that palette, still,
# with the palette's description and the colours it sets. The character's own colours come first, as "original".
palette_grid <- function(character, selected = "original") {
  checkmate::assert_string(character, min.chars = 1)
  checkmate::assert_string(selected, min.chars = 1)
  cards <- palette_cards(character)
  shiny::div(
    id = "palette_grid",
    class = "theme-palette-grid shiny-input-radiogroup",
    role = "radiogroup",
    `aria-label` = "Palettes",
    lapply(cards, function(card) {
      shiny::tags$label(
        class = "theme-palette-card",
        shiny::tags$input(
          type = "radio",
          name = "palette_grid",
          value = card$value,
          checked = if (identical(card$value, selected)) NA
        ),
        shiny::div(
          class = "theme-card-mascot",
          mascot::mascot(
            paste0("palette_card_", character, "_", card$value),
            character = character,
            # The status names the palette, so the card reads without the drawing.
            status = gsub("_", " ", card$value, fixed = TRUE),
            theme = if (card$value != "original") card$value,
            size = 88,
            placement = "inline",
            motion = FALSE
          )
        ),
        shiny::div(
          class = "theme-card-text",
          shiny::tags$code(class = "theme-card-name", card$value),
          if (card$value == "original" && card$name != "original") {
            shiny::tags$span(class = "theme-muted", paste0("(", card$name, ")"))
          },
          shiny::tags$span(class = "theme-card-description", card$description),
          shiny::tags$span(
            class = "theme-swatches",
            lapply(names(card$swatches), function(role) {
              shiny::tags$span(
                class = "theme-swatch",
                style = paste0("background:", card$swatches[[role]]),
                title = paste(role, card$swatches[[role]])
              )
            })
          )
        )
      )
    })
  )
}
