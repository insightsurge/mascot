# The "Theme a mascot" view (mascot_studio(view = "theme"), ?view=theme): one character, themed with live feedback,
# and the plain R code to copy. This file builds its page; theme-server.R holds its server. The view uses the
# studio app's shared parts (R/shared-*.R, R/code.R, www/tokens.css, www/inputs.js), never studio.js.

# The id of the live mascot. The code shown uses "helper", the id the package's examples use.
theme_preview_id <- "theme_mascot"

# The variable the CSS part of Your colours offers, with its starting value.
theme_css_variable <- c(`--app-accent` = "#7b4fd6")

# The page: a header, the preview with its code on the left, the tabs on the right (stacked on a phone).
theme_view_ui <- function(query) {
  checkmate::assert_list(query)
  character <- view_character(query)
  shiny::tagList(
    shiny::tags$head(
      shiny::tags$link(rel = "stylesheet", href = "tokens.css"),
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
    bslib::navset_underline(
      id = "theme_tabs",
      bslib::nav_panel("Palette", value = "palette", theme_palette_tab()),
      bslib::nav_panel("Your colours", value = "colours", theme_colours_tab()),
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

theme_colours_tab <- function() {
  shiny::div(class = "theme-tab", shiny::tags$p(class = "theme-lead", "Change any part's colour."))
}

theme_brand_tab <- function() {
  shiny::div(
    class = "theme-tab",
    shiny::tags$p(class = "theme-lead", "Colour the mascot with your app's brand colours.")
  )
}

theme_check_tab <- function() {
  shiny::div(
    class = "theme-tab",
    shiny::tags$p(
      class = "theme-lead",
      "See what the package does when you swap characters or choose a colour that is hard to see."
    )
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
