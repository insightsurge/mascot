# bslib is optional for mascot, but required for this branding example.
# Standalone app: attach the package as a user would.
library(mascot) # nolint: undesirable_function_linter.
if (!requireNamespace("bslib", quietly = TRUE)) {
  cli::cli_abort("The branding example needs {.pkg bslib}. Choose {.val basic} to try an app without it.")
}
# Share presentation while keeping the scenario code here.
# nolint start: undesirable_function_linter.
source(
  system.file("examples", "shared", "shell.R", package = "mascot"),
  local = TRUE
)
# nolint end

# A brand fills Tessa's body, rim and bow through her brand slots.
brand <- bslib::bs_theme(version = 5, primary = "#1f6feb", secondary = "#966600")
# A complete palette covers coloured parts, including sleeves, hands, feet and
# accessory details. Eye whites, teeth and dark face lines keep their neutrals.
brand_palette <- function(mode, palette = "brand") {
  checkmate::assert_choice(mode, c("light", "dark"))
  checkmate::assert_choice(palette, c("brand", "rose"))
  if (palette == "rose") {
    return(mascot_theme(
      light = list(
        eyelid = "#A84679",
        tongue = "#963B63",
        body = "#B53D78",
        body_highlight = "#C95791",
        rim = "#9E477C",
        limb = "#A94A82",
        sleeve = "#B53D78",
        blush = "#D16A9B",
        blush_strong = "#A63D72",
        accessory = "#A94A82",
        accessory_detail = "#74345F",
        sparkle_outline = "#9E477C",
        sweat = "#9B65A5",
        shadow = "#8E718C"
      ),
      dark = list(
        eyelid = "#F2A6CF",
        tongue = "#E987B4",
        body = "#F2A6CF",
        body_highlight = "#F7BFDB",
        rim = "#C5B0EB",
        limb = "#C5B0EB",
        sleeve = "#F2A6CF",
        blush = "#F3A7D0",
        blush_strong = "#D98FC8",
        accessory = "#C5B0EB",
        accessory_detail = "#91649F",
        sparkle_outline = "#C5B0EB",
        sweat = "#AFC8F2",
        shadow = "#B8A6C8"
      ),
      mode = mode
    ))
  }
  mascot_theme(
    light = list(
      eyelid = "#1F6FEB",
      tongue = "#963B63",
      body = "#1F6FEB",
      body_highlight = "#5E83B5",
      rim = "#966600",
      limb = "#966600",
      sleeve = "#1F6FEB",
      blush = "#6774AE",
      blush_strong = "#966600",
      accessory = "#966600",
      accessory_detail = "#644300",
      sparkle_outline = "#966600",
      sweat = "#5E83B5",
      shadow = "#69788B"
    ),
    dark = list(
      eyelid = "#9EC5FE",
      tongue = "#E987B4",
      body = "#9EC5FE",
      body_highlight = "#B6CFEE",
      rim = "#D6B56E",
      limb = "#D6B56E",
      sleeve = "#9EC5FE",
      blush = "#9EB2E6",
      blush_strong = "#D6B56E",
      accessory = "#D6B56E",
      accessory_detail = "#B88F45",
      sparkle_outline = "#D6B56E",
      sweat = "#AFC8F2",
      shadow = "#9BADC4"
    ),
    mode = mode
  )
}

ui <- shiny::tagList(shiny::tags$div(
  class = "example-grid",
  shiny::tags$section(
    class = "example-panel",
    shiny::tags$h2("Your colours and words"),
    shiny::tags$p(
      "The palette colours Tessa's body, hands, feet and bow. Use the header switch for light/dark mode."
    ),
    shiny::radioButtons(
      "palette",
      "Mascot colours",
      choices = c("App brand" = "brand", "Pink and lilac" = "rose"),
      selected = "brand",
      inline = TRUE
    ),
    shiny::textInput("status", "Status text", "Ready for your team's review"),
    shiny::textInput("message", "Bubble text", "I can help you find the next step."),
    shiny::actionButton("personalise", "Use my words"),
    shiny::actionButton("celebrate", "Celebrate a finished review"),
    shiny::actionButton("original", "Use Tessa's own colours"),
    shiny::actionButton("brand", "Use selected colours"),
    shiny::tags$p(
      class = "example-note",
      "Click Tessa to finish a review, reset her feedback or open About. Keyboard users can press Enter or Space."
    )
  ),
  shiny::tags$section(
    class = "example-panel example-stage",
    shiny::tags$h2("Personalise Tessa"),
    mascot(
      id = "helper",
      theme = brand,
      status = "Ready for your team's review",
      popup_menu = mascot_popup_menu(
        c(finish = "Finish review", reset = "Reset helper", about = "About this example"),
        key_bindings = TRUE
      )
    ),
    shiny::tags$details(shiny::tags$summary("Tessa's colour roles"), shiny::tableOutput("roles"))
  )
))

server <- function(input, output, session) {
  use_brand <- shiny::reactiveVal(TRUE)
  output$roles <- shiny::renderTable(mascot_colour_roles("tessa"), na = "")
  shiny::observeEvent(
    input$dark_mode,
    {
      if (use_brand()) {
        # bs_theme supplies one set of brand colours. Explicit role palettes can
        # choose different colours per mode, without R adjusting either colour.
        updateMascot(
          "helper",
          theme = brand_palette(if (identical(input$dark_mode, "dark")) "dark" else "light", input$palette)
        )
      }
    },
    ignoreInit = TRUE
  )
  shiny::observeEvent(
    # bs_theme fills brand slots at creation. On initial connection and palette
    # changes, send the remaining chosen roles too for a complete character.
    input$palette,
    {
      use_brand(TRUE)
      updateMascot(
        "helper",
        theme = brand_palette(if (identical(input$dark_mode, "dark")) "dark" else "light", input$palette)
      )
    },
    ignoreInit = FALSE
  )
  shiny::observeEvent(input$personalise, {
    shiny::req(nzchar(trimws(input$status)), nzchar(trimws(input$message)))
    updateMascot("helper", status = mascot_status(input$status), bubble = mascot_bubble(input$message, duration = Inf))
  })
  shiny::observeEvent(input$celebrate, updateMascot("helper", mood = "celebrating", status = "Review complete"))
  shiny::observeEvent(input$original, {
    use_brand(FALSE)
    updateMascot("helper", theme = mascot_theme())
  })
  shiny::observeEvent(input$brand, {
    use_brand(TRUE)
    updateMascot(
      "helper",
      theme = brand_palette(if (identical(input$dark_mode, "dark")) "dark" else "light", input$palette)
    )
  })
  # Menu item names become input$helper_menu; the app owns each action.
  shiny::observeEvent(input$helper_menu, {
    if (identical(input$helper_menu, "finish")) {
      updateMascot(
        "helper",
        mood = "happy",
        status = "Review complete",
        bubble = mascot_bubble("All checks finished.", duration = Inf),
        gesture = mascot_gesture("nod")
      )
    }
    if (identical(input$helper_menu, "reset")) {
      updateMascot(
        "helper",
        mood = "idle",
        status = "Ready for your team's review",
        bubble = mascot_bubble()
      )
    }
    if (identical(input$helper_menu, "about")) {
      shiny::showModal(shiny::modalDialog(
        title = "About this example",
        "Your app owns the menu action. Tessa supplies the entry point.",
        easyClose = TRUE
      ))
    }
  })
}

example_app(
  "Personalise Tessa",
  "Use an app brand, choose light/dark colours and give Tessa your own words.",
  ui,
  server,
  theme = brand
)
