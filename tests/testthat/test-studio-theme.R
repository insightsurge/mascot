# The "Theme a mascot" view of the studio app (mascot_studio(view = "theme"); inst/examples/studio/R/theme-*.R).

# The studio app's environment, where the view's functions live, and the theme view's page.
theme_parts <- function() {
  skip_without_studio_packages("theme")
  app <- mascot_studio("theme", run = FALSE)
  page <- app$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = ""))$content
  app_env <- environment(shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))$serverFuncSource())
  # Shiny loads the files in R/ into an environment of their own, above app.R's.
  list(env = environment(get("theme_view_server", app_env)), page = as.character(page))
}

# The view's own files, as parsed expressions by file name.
theme_files <- function(pattern) {
  dir <- file.path(dirname(mascot_example("studio", run = FALSE)), "R")
  files <- list.files(dir, pattern = pattern, full.names = TRUE)
  stats::setNames(lapply(files, parse), basename(files))
}

defined_functions <- function(exprs) {
  names <- vapply(
    exprs,
    function(expr) {
      if (is.call(expr) && identical(expr[[1]], as.name("<-")) && is.call(expr[[3]])) {
        if (identical(expr[[3]][[1]], as.name("function"))) {
          return(as.character(expr[[2]]))
        }
      }
      NA_character_
    },
    character(1)
  )
  names[!is.na(names)]
}

describe("the theme view's files", {
  it("call only exported functions and define no function the shared files already define", {
    view <- theme_files("^theme-.*[.]R$")
    shared <- theme_files("^shared-.*[.]R$")
    expect_setequal(names(view), c("theme-server.R", "theme-ui.R"))
    for (file in names(view)) {
      text <- paste(deparse(view[[file]]), collapse = "\n")
      expect_false(grepl("mascot:::", text, fixed = TRUE), info = file)
    }
    mine <- unlist(lapply(view, defined_functions))
    expect_gt(length(mine), 5)
    expect_length(intersect(mine, unlist(lapply(shared, defined_functions))), 0)
  })
})

describe("the theme view's page", {
  it("has the header, the preview, the code and four tabs, and loads no studio script", {
    parts <- theme_parts()
    page <- parts$page
    expect_match(page, "<title>Theme a mascot</title>", fixed = TRUE)
    for (id in c("character", "mood", "page_mode", "reset_all", "theme_code", "code_style", "preview_caption")) {
      expect_match(page, paste0('id="', id, '"'), fixed = TRUE, info = id)
    }
    expect_match(page, 'id="theme_mascot"', fixed = TRUE)
    for (tab in c("Palette", "Your colours", "Brand colours", "Check")) {
      expect_match(page, paste0(">", tab, "<"), fixed = TRUE, info = tab)
    }
    expect_match(page, '"theme.css"', fixed = TRUE)
    expect_match(page, '"inputs.js"', fixed = TRUE)
    expect_false(grepl("studio.js", page, fixed = TRUE))
    expect_false(grepl("studio.css", page, fixed = TRUE))
    expect_false(grepl('class="pg-studio"', page, fixed = TRUE))
  })
  it("uses the studio's sentence bar and window frame, with no palette menu", {
    page <- theme_parts()$page
    expect_match(page, 'id="theme_sentence_bar" class="pg-toolbar pg-float"', fixed = TRUE)
    expect_match(page, "Showing\\s*<div class=\"form-group shiny-input-container\">")
    expect_match(page, 'aria-describedby="character_tooltip"', fixed = TRUE)
    expect_match(page, 'aria-describedby="mood_tooltip"', fixed = TRUE)
    expect_match(page, '<span id="mood_article">in an</span>', fixed = TRUE)
    expect_match(page, 'data-sentence="auto"', fixed = TRUE)
    expect_false(grepl('id="palette"', page, fixed = TRUE))
    expect_match(page, '<span class="pg-window-dots" aria-hidden="true">', fixed = TRUE)
    expect_match(page, "<span>Preview</span>", fixed = TRUE)
    expect_match(page, 'id="preview_phone"[^>]*aria-pressed="false"[^>]*data-toggle-class="is-phone"')
    expect_false(grepl("Contained preview", page, fixed = TRUE))
    expect_match(page, '<div class="pg-host-footer">', fixed = TRUE)
    # A slim header: the title, then the sentence bar.
    expect_match(
      page,
      '<header class="theme-header">\\s*<h1 class="theme-title">Theme a mascot</h1>\\s*<div id="theme_sentence_bar"'
    )
  })
  it("captions the preview with the character and the palette", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      session$setInputs(character = "sela", mood = "idle")
      expect_identical(output$preview_caption, "Sela \u00b7 original")
      session$setInputs(palette_grid = "coral_navy")
      expect_identical(output$preview_caption, "Sela \u00b7 coral_navy")
      session$setInputs(brand_source = "bslib")
      expect_identical(output$preview_caption, "Sela \u00b7 bs_theme()")
    })
  })
  it("marks the experimental characters in the character menu", {
    page <- theme_parts()$page
    expect_match(page, "Knurl (experimental)", fixed = TRUE)
    expect_match(page, "Neer (experimental)", fixed = TRUE)
  })
  it("draws one palette card per palette, the character's own colours first as original", {
    env <- theme_parts()$env
    for (character in c("tessa", "knurl")) {
      html <- as.character(env$palette_grid(character, "original"))
      values <- regmatches(html, gregexpr('name="palette_grid" value="[^"]+"', html))[[1]]
      expected <- c("original", mascot_palettes(character)$name[-1])
      expect_identical(sub('.*value="', "", sub('"$', "", values)), expected, info = character)
      # Each card draws the mascot, still, in its palette.
      expect_identical(lengths(gregexpr('class="mascot"', html, fixed = TRUE)), length(expected))
    }
    html <- as.character(env$palette_grid("tessa", "coral_navy"))
    expect_match(html, 'value="coral_navy" checked', fixed = TRUE)
    expect_match(html, "Pale peach face, coral ring, navy hair and a teal bow.", fixed = TRUE)
    expect_error(env$palette_grid(1), "character")
    expect_error(env$palette_grid("tessa", 1), "selected")
  })
})

describe("theme_view_theme()", {
  it("leaves the theme out for the character's own colours in auto mode", {
    env <- theme_parts()$env
    expect_null(env$theme_view_theme())
    expect_null(env$theme_view_theme("mascot", "original"))
  })
  it("writes a palette as its name, or as mascot_theme() in the helper form", {
    env <- theme_parts()$env
    pair <- env$theme_view_theme("mascot", "coral_navy")
    expect_identical(pair$short, "coral_navy")
    expect_identical(pair$helper, quote(mascot_theme(palette = "coral_navy")))
    expect_identical(eval(pair$helper), mascot_theme(palette = "coral_navy"))
    forced <- env$theme_view_theme("mascot", "original", mode = "dark")
    expect_identical(forced$short, quote(mascot_theme(mode = "dark")))
  })
  it("checks its arguments", {
    env <- theme_parts()$env
    expect_error(env$theme_view_theme("css"), "source")
    expect_error(env$theme_view_theme("mascot", ""), "palette")
    expect_error(env$theme_view_theme(light = NA_character_), "light")
    expect_error(env$theme_view_theme(dark = 1), "dark")
    expect_error(env$theme_view_theme(mode = "dim"), "mode")
    expect_error(env$theme_view_theme(css = 1), "css")
    expect_error(env$theme_view_theme("bslib", primary = "blue"), "primary")
    expect_error(env$theme_view_theme("bslib", secondary = 1), "secondary")
  })
})

describe("theme_view_call()", {
  it("shows only the arguments that differ from mascot()'s defaults", {
    env <- theme_parts()$env
    expect_identical(env$theme_view_call("tessa", "idle"), 'mascot("helper")')
    palette <- env$theme_view_theme("mascot", "coral_navy")
    expect_identical(env$theme_view_call("tessa", "idle", palette), 'mascot("helper", theme = "coral_navy")')
    expect_identical(
      env$theme_view_call("sela", "happy", palette, "helper"),
      paste0(
        "mascot(\n  \"helper\",\n  character = mascot_character(\"sela\"),\n  mood = mascot_mood(\"happy\"),\n",
        "  theme = mascot_theme(palette = \"coral_navy\")\n)"
      )
    )
    # The code runs as shown.
    expect_s3_class(eval(parse(text = env$theme_view_call("sela", "happy", palette))), "shiny.tag")
  })
  it("checks its arguments", {
    env <- theme_parts()$env
    expect_error(env$theme_view_call(1, "idle"), "character")
    expect_error(env$theme_view_call("tessa", ""), "mood")
    expect_error(env$theme_view_call("tessa", "idle", "coral_navy"), "theme")
    expect_error(env$theme_view_call("tessa", "idle", style = "plain"), "style")
  })
})

describe("theme_stack_parts()", {
  it("lists the layers in the order they apply, each clearable only when in use", {
    env <- theme_parts()$env
    parts <- env$theme_stack_parts()
    expect_identical(parts$label, c("Palette", "Your colours", "CSS", "mode"))
    expect_identical(parts$value, c("original", "none", "none", "auto"))
    expect_false(any(parts$clear))
    used <- env$theme_stack_parts(
      "mascot",
      "coral_navy",
      c(body = "#123456", rim = "#654321", hair = "#111111"),
      c(body = "#abcdef"),
      c(body = "--app-accent"),
      "dark"
    )
    expect_identical(used$value, c("coral_navy", "3 light, 1 dark", "1 part", "dark"))
    expect_true(all(used$clear))
    html <- as.character(env$theme_stack_ui(used))
    expect_match(html, "Palette:\\s*<code>coral_navy</code>")
    expect_identical(lengths(gregexpr('data-event="stack_clear"', html, fixed = TRUE)), 4L)
    bslib <- env$theme_stack_parts("bslib")
    expect_identical(bslib$key, c("bslib", "mode"))
    expect_error(env$theme_stack_parts("css"), "source")
    expect_error(env$theme_stack_parts(mode = "dim"), "mode")
    expect_error(env$theme_stack_ui(list()), "parts")
  })
})

describe("theme_view_server()", {
  it("keeps the code in step with the palette from the cards, the Start from menu and the stack line", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      session$setInputs(character = "tessa", mood = "idle", code_style = "short")
      expect_identical(output$theme_code, 'mascot("helper")')
      # Given a palette card
      session$setInputs(palette_grid = "coral_navy")
      # Then the code and the stack line follow it
      expect_identical(output$theme_code, 'mascot("helper", theme = "coral_navy")')
      expect_match(output$theme_stack$html, "Palette:\\s*<code>coral_navy</code>")
      session$setInputs(code_style = "helper")
      expect_identical(output$theme_code, 'mascot("helper", theme = mascot_theme(palette = "coral_navy"))')
      session$setInputs(code_style = "short", palette_grid = "forest")
      expect_identical(output$theme_code, 'mascot("helper", theme = "forest")')
      # A palette the character lacks is ignored.
      session$setInputs(palette_grid = "orbit")
      expect_identical(output$theme_code, 'mascot("helper", theme = "forest")')
      # The stack line's clear button goes back to the character's own colours.
      session$setInputs(stack_clear = "palette")
      expect_identical(output$theme_code, 'mascot("helper")')
    })
  })
  it("drops a palette the next character does not have and keeps one it has", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      session$setInputs(character = "tessa", mood = "idle", palette_grid = "coral_navy")
      session$setInputs(character = "sela")
      expect_identical(output$theme_code, 'mascot("helper", character = "sela", theme = "coral_navy")')
      session$setInputs(character = "knurl")
      expect_identical(output$theme_code, 'mascot("helper", character = "knurl")')
    })
  })
  it("sends each change to the live mascot with update_mascot(), only the parts that changed", {
    env <- theme_parts()$env
    # A recorder in place of update_mascot(), in the app's own environment (a fresh one for this test).
    calls <- list()
    assign(
      "update_mascot",
      function(id, ...) calls[[length(calls) + 1L]] <<- list(id = id, args = list(...)),
      envir = env
    )
    shiny::testServer(env$theme_view_server, {
      session$setInputs(character = "tessa", mood = "idle")
      session$elapse(300)
      # The page drew this mascot already: nothing to send.
      expect_length(calls, 0)
      session$setInputs(palette_grid = "coral_navy", mood = "happy")
      session$elapse(300)
      expect_length(calls, 1)
      expect_identical(calls[[1]]$id, "theme_mascot")
      expect_identical(calls[[1]]$args, list(mood = "happy", theme = mascot_theme(palette = "coral_navy")))
      # A new character also gets the mood and theme it should show.
      session$setInputs(character = "knurl")
      session$elapse(300)
      # Knurl has no coral_navy, so the palette goes back to her own colours.
      expect_identical(calls[[2]]$args, list(character = "knurl", mood = "happy", theme = mascot_theme()))
    })
  })
})

describe("the Your colours tab", {
  it("has a starting palette, the forced mode, Light, Dark and CSS tabs, and a link to the studio", {
    page <- theme_parts()$page
    for (id in c("start_from", "mode_ui", "colour_modes", "colours-light", "colours-dark", "colours-css")) {
      expect_match(page, paste0('id="', id, '"'), fixed = TRUE, info = id)
    }
    expect_match(page, "Force the mascot", fixed = TRUE)
    # One line points a user with two brand colours to the Brand colours tab.
    expect_match(
      page,
      'Just have two brand colours[?]\\s*<button[^>]*data-event="go_tab" data-value="brand"[^>]*>Use the Brand colours tab.</button>'
    )
    expect_match(page, 'href="?view=studio&amp;fn=mascot_theme"', fixed = TRUE)
    # The CSS source is marked experimental in the help page's own words.
    expect_match(page, "Experimental</span>\\s*This source is experimental\\.")
  })
  it("draws a picker for every role, saying own colour rather than leader", {
    env <- theme_parts()$env
    roles <- mascot_colour_roles("knurl")
    html <- as.character(env$role_pickers("light", roles, character = "knurl", resolved = FALSE, leader = "own colour"))
    for (role in roles$role) {
      expect_match(html, paste0('id="light_', role, '"'), fixed = TRUE, info = role)
    }
    expect_match(html, "own colour", fixed = TRUE)
    expect_false(grepl(">leader<", html, fixed = TRUE))
    expect_match(html, "Use × to go back to the character's colour.", fixed = TRUE)
    expect_false(grepl("round swatch", html, fixed = TRUE))
    # A translucent role keeps a text box.
    expect_match(html, 'id="light_shine_translucent" type="text"', fixed = TRUE)
    expect_error(env$role_pickers("light", roles, character = "knurl", leader = ""), "leader")
  })
  it("writes the shortest mascot_theme() call for the colours, the CSS parts and the mode", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      session$setInputs(character = "tessa", mood = "idle", code_style = "short", mode = "auto")
      roles <- mascot_colour_roles("tessa")
      # Given the pickers as the browser reports them
      do.call(session$setInputs, stats::setNames(as.list(roles$colour), paste0("colours-light_", roles$role)))
      do.call(session$setInputs, stats::setNames(as.list(roles$colour), paste0("colours-dark_", roles$role)))
      expect_identical(output$theme_code, 'mascot("helper")')
      # The same colour in both modes is a plain list
      session$setInputs(`colours-light_body` = "#C2185B", `colours-dark_body` = "#c2185b")
      expect_identical(output$theme_code, 'mascot("helper", theme = list(body = "#c2185b"))')
      # A palette to start from, a dark-only colour and a forced mode need mascot_theme()
      session$setInputs(start_from = "coral_navy", `colours-dark_rim` = "#ffcc00", mode = "dark")
      expected <- mascot_theme(
        palette = "coral_navy",
        light = list(body = "#c2185b"),
        dark = list(body = "#c2185b", rim = "#ffcc00"),
        mode = "dark"
      )
      expect_identical(eval(parse(text = output$theme_code))$attribs$id, "helper")
      expect_match(output$theme_code, 'palette = "coral_navy"', fixed = TRUE)
      expect_match(output$theme_code, 'mode = "dark"', fixed = TRUE)
      code_theme <- eval(str2lang(output$theme_code)[["theme"]])
      expect_identical(code_theme, expected)
      expect_match(output$theme_stack$html, "Your colours:\\s*<code>1 light, 2 dark</code>")
      # A part that reads the CSS variable comes with the line that sets it on the page
      session$setInputs(`colours-css_roles` = "body", `colours-css_value` = "#7b4fd6")
      expect_match(output$theme_code, 'css = list(body = "--app-accent")', fixed = TRUE)
      expect_match(output$theme_code, '# tags$style(":root { --app-accent: #7b4fd6; }")', fixed = TRUE)
      expect_match(output$theme_stack$html, "CSS:\\s*<code>1 part</code>")
      # Clearing the mode from the stack line puts the control back to auto
      updates <- list()
      session$sendInputMessage <- function(id, message) updates[[id]] <<- message
      session$setInputs(stack_clear = "mode")
      expect_identical(updates$mode$value, "auto")
      # Clearing CSS goes through the colour module: no part reads the variable at once, and the checkboxes clear
      session$setInputs(stack_clear = "css")
      expect_length(updates$`colours-css_roles`$value, 0L)
      expect_false(grepl("css =|--app-accent", output$theme_code))
      # Clearing your colours resets every picker: only the palette is left
      session$setInputs(stack_clear = "colours")
      expect_identical(output$theme_code, 'mascot("helper", theme = "coral_navy")')
    })
  })
  it("keeps the starting palette, the header menu and the cards on one value", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      updates <- list()
      session$sendInputMessage <- function(id, message) updates[[id]] <<- message
      session$setInputs(character = "tessa", mood = "idle")
      session$setInputs(start_from = "forest")
      expect_identical(output$theme_code, 'mascot("helper", theme = "forest")')
      expect_false("palette" %in% names(updates))
      expect_identical(updates$palette_grid$value, "forest")
    })
  })
})

describe("the Brand colours tab", {
  it("lists the parts each brand colour colours, from the character's colour roles", {
    env <- theme_parts()$env
    for (character in c("tessa", "sela", "knurl", "neer")) {
      roles <- mascot_colour_roles(character)
      slots <- env$theme_brand_roles(character)
      expect_named(slots, c("primary", "secondary"))
      expect_setequal(unlist(slots, use.names = FALSE), roles$role[!is.na(roles$brand)])
    }
    expect_identical(env$theme_brand_roles("neer"), list(primary = character(), secondary = character()))
    html <- as.character(env$theme_brand_parts_ui(env$theme_brand_roles("tessa"), "Tessa"))
    expect_match(html, "Primary colours\\s*<code>body</code>")
    neer <- as.character(env$theme_brand_parts_ui(env$theme_brand_roles("neer"), "Neer"))
    expect_match(neer, "Neer\\s*has no parts that take brand colours. Use Your colours to colour any part.")
    expect_error(env$theme_brand_roles(""), "character")
    expect_error(env$theme_brand_parts_ui(list(1), "Tessa"), "roles")
    expect_error(env$theme_brand_parts_ui(list(), ""), "name")
  })
  it("offers bs_theme() as a button that warns it replaces the palette and your colours", {
    env <- theme_parts()$env
    roles <- env$theme_brand_roles("tessa")
    mascot_form <- as.character(env$theme_brand_source_ui("mascot", roles))
    expect_match(mascot_form, 'data-event="brand_source" data-value="bslib"', fixed = TRUE)
    expect_match(mascot_form, "It replaces the palette and your own colours.", fixed = TRUE)
    bslib_form <- as.character(env$theme_brand_source_ui("bslib", roles))
    expect_match(bslib_form, "Experimental", fixed = TRUE)
    expect_match(bslib_form, 'data-value="mascot"', fixed = TRUE)
    expect_error(env$theme_brand_source_ui("css", roles), "source")
    expect_error(env$theme_mode_input("dim"), "selected")
    kept <- as.character(env$theme_mode_input("dark", TRUE))
    expect_match(kept, "<fieldset disabled>", fixed = TRUE)
    expect_match(kept, 'value="dark" checked', fixed = TRUE)
    expect_match(kept, "This choice comes back with mascot_theme().", fixed = TRUE)
  })
  it("writes chosen brand colours as a plain list, and as bs_theme() only after the button", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      session$setInputs(character = "tessa", mood = "idle", mode = "dark")
      # Given the brand pickers: opening the tab changes nothing
      session$setInputs(theme_tabs = "brand")
      expect_identical(output$theme_code, 'mascot("helper", theme = mascot_theme(mode = "dark"))')
      session$setInputs(mode = "auto", brand_primary = "#0f766e", brand_secondary = "#c2410c")
      # Then the brand parts take the colours in both modes, which is a plain list
      expect_identical(output$theme_code, 'mascot("helper", theme = list(body = "#0f766e", rim = "#c2410c"))')
      # When the user switches to bs_theme()
      session$setInputs(palette_grid = "coral_navy", mode = "dark", brand_source = "bslib")
      expect_identical(
        output$theme_code,
        'mascot(\n  "helper",\n  theme = bslib::bs_theme(primary = "#0f766e", secondary = "#c2410c")\n)'
      )
      expect_match(output$theme_stack$html, "Brand:\\s*<code>bslib::bs_theme\\(\\)</code>")
      expect_match(output$theme_stack$html, "mode:\\s*<code>auto</code>")
      expect_match(output$source_note$html, "kept\\s+but not used")
      # And back: the palette and colours were kept
      session$setInputs(stack_clear = "bslib")
      expect_match(output$theme_code, 'palette = "coral_navy"', fixed = TRUE)
      expect_match(output$theme_code, 'light = list(body = "#0f766e", rim = "#c2410c")', fixed = TRUE)
      expect_match(output$theme_code, 'mode = "dark"', fixed = TRUE)
    })
  })
  it("sends a sample pair to both pickers", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      updates <- list()
      session$sendInputMessage <- function(id, message) updates[[id]] <<- message
      session$setInputs(brand_sample = "#7c3aed,#db2777")
      expect_identical(updates$brand_primary$value, "#7c3aed")
      expect_identical(updates$brand_secondary$value, "#db2777")
      updates <- list()
      session$setInputs(brand_sample = "red,blue")
      expect_length(updates, 0)
    })
  })
})

describe("the Check tab", {
  it("offers the four scenarios as buttons beside their own mascot", {
    parts <- theme_parts()
    scenarios <- parts$env$theme_check_scenarios()
    expect_named(scenarios, c("kept", "dropped", "contrast", "missing"))
    for (key in names(scenarios)) {
      expect_match(parts$page, sprintf('data-event="check_scenario" data-value="%s"', key), fixed = TRUE, info = key)
    }
    expect_match(parts$page, 'id="check_demo"', fixed = TRUE)
    for (id in c("check_preview", "check_contrast")) {
      expect_match(parts$page, paste0('id="', id, '"'), fixed = TRUE)
    }
    expect_match(parts$page, "at least 3:1 contrast", fixed = TRUE)
  })
  it("shows each scenario's call, outcome, class, message and silencing line, as the package gives them", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      session$setInputs(character = "tessa", mood = "idle")
      session$setInputs(check_scenario = "kept")
      html <- output$check_scenario_ui$html
      expect_match(html, 'update_mascot("check_demo", character = "sela")', fixed = TRUE)
      expect_match(html, "Outcome:\\s*<code>ok</code>")
      expect_match(html, "Palette coral_navy kept for Sela.", fixed = TRUE)
      session$setInputs(check_scenario = "dropped")
      html <- output$check_scenario_ui$html
      expect_match(html, "Class:\\s*<code>mascot_palette_dropped</code>")
      expect_match(html, 'Palette "coral_navy" dropped for character "knurl"', fixed = TRUE)
      expect_match(html, 'mascot_palette_dropped = function(w) invokeRestart("muffleWarning")', fixed = TRUE)
      session$setInputs(check_scenario = "contrast")
      html <- output$check_scenario_ui$html
      expect_match(html, "Class:\\s*<code>mascot_contrast</code>")
      expect_match(html, "contrast below 3:1", fixed = TRUE)
      expect_match(html, "mascot_contrast = function(w)", fixed = TRUE)
      session$setInputs(check_scenario = "missing")
      html <- output$check_scenario_ui$html
      expect_match(html, "Outcome:\\s*<code>error</code>")
      expect_match(html, 'Characters "tessa", "sela" have', fixed = TRUE)
      expect_false(grepl("To silence", html, fixed = TRUE))
    })
  })
  it("checks contrast for the settings at the click, and says when they changed", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      session$setInputs(character = "tessa", mood = "idle")
      roles <- mascot_colour_roles("tessa")
      # The pickers as the browser reports them, then one changed
      do.call(session$setInputs, stats::setNames(as.list(roles$colour), paste0("colours-light_", roles$role)))
      session$setInputs(`colours-light_rim` = "#f5e6c8")
      session$setInputs(check_contrast = 1)
      expect_match(output$check_contrast_ui$html, "hard to see", fixed = TRUE)
      expect_match(output$check_contrast_ui$html, "<code>#F5E6C8</code>", fixed = TRUE)
      session$setInputs(`colours-light_rim` = "#123456")
      expect_match(output$check_contrast_ui$html, "The settings changed since the last check.", fixed = TRUE)
      session$setInputs(check_contrast = 2)
      expect_match(output$check_contrast_ui$html, "Every colour you chose in R", fixed = TRUE)
    })
  })
  it("builds the every-mood page into the session's own folder when asked", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      folder <- file.path(tempdir(), paste0("theme-preview-", session$token))
      session$setInputs(character = "sela", mood = "idle", palette_grid = "coral_navy")
      expect_false(dir.exists(folder))
      session$setInputs(check_preview = 1)
      html <- output$check_preview_ui$html
      expect_match(html, 'mascot_preview(character = "sela", theme = "coral_navy")', fixed = TRUE)
      expect_match(html, sprintf('src="theme-preview-%s/preview-1.html"', session$token), fixed = TRUE)
      expect_true(file.exists(file.path(folder, "preview-1.html")))
      session$setInputs(palette_grid = "forest")
      expect_match(output$check_preview_ui$html, "The settings changed since this page was built.", fixed = TRUE)
    })
  })
  it("sets the CSS variable values on the every-mood page and marks it out of date when one changes", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      folder <- file.path(tempdir(), paste0("theme-preview-", session$token))
      session$setInputs(character = "tessa", mood = "idle")
      roles <- mascot_colour_roles("tessa")
      do.call(session$setInputs, stats::setNames(as.list(roles$colour), paste0("colours-light_", roles$role)))
      # Given the body reading the CSS variable, set to red
      session$setInputs(`colours-css_roles` = "body", `colours-css_value` = "#ff0000")
      session$setInputs(check_preview = 1)
      # Then the saved page sets the variable, and the code says so
      saved <- paste(readLines(file.path(folder, "preview-1.html"), warn = FALSE), collapse = "\n")
      expect_match(saved, "<style>:root { --app-accent: #ff0000; }</style>", fixed = TRUE)
      expect_match(output$check_preview_ui$html, '# The page sets the CSS variable: tags$style(":root', fixed = TRUE)
      expect_false(grepl("The settings changed", output$check_preview_ui$html, fixed = TRUE))
      # When the value changes, the page is out of date
      session$setInputs(`colours-css_value` = "#00aa00")
      expect_match(output$check_preview_ui$html, "The settings changed since this page was built.", fixed = TRUE)
    })
  })
  it("numbers its pages itself and keeps only the last two, whatever the button sends", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      folder <- file.path(tempdir(), paste0("theme-preview-", session$token))
      session$setInputs(character = "tessa", mood = "idle")
      # A huge or non-numeric value from the browser is only a trigger
      session$setInputs(check_preview = 1e12)
      expect_true(file.exists(file.path(folder, "preview-1.html")))
      session$setInputs(check_preview = "not a number")
      session$setInputs(check_preview = -5)
      expect_setequal(list.files(folder, pattern = "^preview-"), c("preview-2.html", "preview-3.html"))
      expect_match(output$check_preview_ui$html, "preview-3.html", fixed = TRUE)
    })
  })
  it("checks the arguments of its result card", {
    env <- theme_parts()$env
    result <- list(ok = TRUE, class = "ok", message = NULL, silencer = NULL, condition_classes = NULL)
    expect_match(
      as.character(env$theme_check_result_ui("Title", "x()", result)),
      "The package says nothing",
      fixed = TRUE
    )
    expect_error(env$theme_check_result_ui("", "x()", result), "title")
    expect_error(env$theme_check_result_ui("Title", "", result), "code")
    expect_error(env$theme_check_result_ui("Title", "x()", list()), "names")
    expect_error(env$theme_check_result_ui("Title", "x()", result, ""), "outcome")
  })
})

describe("opening the theme view", {
  it("is in the studio's More menu, in a new tab, and in the Examples view's list", {
    skip_without_studio_packages("studio")
    app <- mascot_studio(run = FALSE)
    page <- function(query) {
      as.character(app$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = query))$content)
    }
    expect_match(
      page(""),
      '<a id="more_theme" href="?view=theme" target="_blank" rel="noopener">Theme a mascot</a>',
      fixed = TRUE
    )
    expect_match(page("view=examples"), '<option value="theme">Theme a mascot (theme)</option>', fixed = TRUE)
  })
})

describe("the theme view's drawing and code", {
  it("draws what the code shows, tab by tab", {
    env <- theme_parts()$env
    # A recorder in place of update_mascot(), in the app's own environment (a fresh one for this test).
    calls <- list()
    assign("update_mascot", function(id, ...) calls[[length(calls) + 1L]] <<- list(...), envir = env)
    shiny::testServer(env$theme_view_server, {
      # The theme the code shows, evaluated, and the theme last sent to the mascot.
      shown <- function() {
        call <- str2lang(sub("^(#[^\n]*\n)+", "", output$theme_code))
        if (is.null(call$theme)) mascot_theme() else eval(call$theme)
      }
      drawn <- function() {
        session$elapse(300)
        calls[[length(calls)]]$theme
      }
      session$setInputs(character = "tessa", mood = "idle", code_style = "helper", mode = "auto")
      roles <- mascot_colour_roles("tessa")
      do.call(session$setInputs, stats::setNames(as.list(roles$colour), paste0("colours-light_", roles$role)))
      do.call(session$setInputs, stats::setNames(as.list(roles$colour), paste0("colours-dark_", roles$role)))
      # Palette
      session$setInputs(palette_grid = "coral_navy")
      expect_identical(drawn(), shown())
      expect_identical(drawn(), mascot_theme(palette = "coral_navy"))
      # Your colours
      session$setInputs(`colours-light_body` = "#c2185b", mode = "dark")
      expect_identical(drawn(), shown())
      # Brand colours, as your own colours and then as bs_theme()
      session$setInputs(brand_primary = "#0f766e")
      expect_identical(drawn(), shown())
      session$setInputs(brand_source = "bslib")
      expect_s3_class(drawn(), "bs_theme")
      expect_identical(
        bslib::bs_get_variables(drawn(), c("primary", "secondary")),
        bslib::bs_get_variables(shown(), c("primary", "secondary"))
      )
      # Clearing back to the character's own colours sends the empty theme the code leaves out.
      session$setInputs(stack_clear = "bslib")
      for (layer in c("palette", "colours", "mode")) {
        session$setInputs(stack_clear = layer)
      }
      expect_identical(drawn(), shown())
    })
  })
})

# How far the mascot's canvas centre is from the preview card's centre, in CSS pixels.
mascot_offset_js <- paste0(
  "(() => { const c = document.querySelector('#theme_mascot canvas').getBoundingClientRect(); ",
  "const p = document.getElementById('theme_preview').getBoundingClientRect(); ",
  "return Math.abs((c.left + c.right) / 2 - (p.left + p.right) / 2); })()"
)

# The theme view in Chrome, started the way mascot_studio(view = "theme") starts it.
theme_driver <- function(width = 1280, height = 800) {
  checkmate::assert_number(width, lower = 1)
  checkmate::assert_number(height, lower = 1)
  app <- function() NULL
  body(app) <- quote({
    library(mascot)
    mascot::mascot_studio("theme", run = FALSE)
  })
  app_driver(app, width = width, height = height)
}

describe("the theme view in a browser", {
  it("switches tabs, draws the chosen palette, copies its code and links back from the studio", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    withr::defer(app$stop())
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    # The header is one line: title, sentence, page switch, Start again; the sentence has the studio's text size.
    middles <- app$get_js(paste0(
      "['.theme-title', '.pg-sentence', '#page_mode', '#reset_all'].map((s) => { ",
      "const r = document.querySelector(s).getBoundingClientRect(); return (r.top + r.bottom) / 2; })"
    ))
    expect_lt(diff(range(unlist(middles))), 12)
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.pg-sentence')).fontSize"), "14px")
    # The mascot is centred in its card, also at phone width.
    expect_lt(app$get_js(mascot_offset_js), 3)
    # Phone width narrows the preview area to 375px and back.
    area <- "document.querySelector('.theme-preview-area').getBoundingClientRect().width"
    wide <- app$get_js(area)
    expect_gt(wide, 400)
    app$click(selector = "#preview_phone")
    app$wait_for_js("document.getElementById('theme_preview').classList.contains('is-phone')")
    expect_lte(app$get_js(area), 375)
    expect_identical(app$get_js("document.getElementById('preview_phone').getAttribute('aria-pressed')"), "true")
    expect_lt(app$get_js(mascot_offset_js), 3)
    app$click(selector = "#preview_phone")
    app$wait_for_js("!document.getElementById('theme_preview').classList.contains('is-phone')")
    expect_equal(app$get_js(area), wide)
    # The live code runs across the bottom, under the preview and the tabs.
    expect_true(app$get_js(paste0(
      "(() => { const box = (s) => document.querySelector(s).getBoundingClientRect(); ",
      "const code = box('.theme-code'), main = box('.theme-main'); ",
      "return code.top >= box('.theme-right').bottom && code.top >= box('.theme-preview').bottom && ",
      "Math.abs(code.width - main.width) < 2; })()"
    )))
    # Each tab shows its own panel.
    for (tab in c("colours", "brand", "check", "palette")) {
      app$run_js(sprintf("document.querySelector('#theme_tabs a[data-value=\"%s\"]').click()", tab))
      app$wait_for_js(sprintf(
        "document.querySelector('#theme_tabs + .tab-content > .tab-pane[data-value=\"%s\"]')?.classList.contains('active')",
        tab
      ))
    }
    # A palette card recolours the live mascot and the code.
    coral <- mascot_colour_roles("tessa", palette = "coral_navy")
    app$click(selector = "label.theme-palette-card:has(input[value=coral_navy])")
    app$wait_for_js("mascot.host.state(document.getElementById('theme_mascot')).theme.palette === 'coral_navy'")
    expect_identical(
      tolower(app$get_js("mascot.host.state(document.getElementById('theme_mascot')).colours.body")),
      tolower(coral$colour[coral$role == "body"])
    )
    app$wait_for_value(output = "theme_code", ignore = list(NULL, 'mascot("helper")'))
    expect_identical(app$get_value(output = "theme_code"), 'mascot("helper", theme = "coral_navy")')
    expect_identical(app$get_js("document.getElementById('start_from').value"), "coral_navy")
    # Copy puts the code shown on the clipboard.
    app$run_js(
      "window.copied = null; navigator.clipboard.writeText = (text) => { window.copied = text; return Promise.resolve(); };"
    )
    app$click(selector = "[data-copy=theme_code]")
    app$wait_for_js("window.copied !== null")
    expect_identical(app$get_js("window.copied"), app$get_value(output = "theme_code"))
    # The studio's More menu opens this view in a new tab.
    link <- app$get_js(paste0(
      "fetch('?view=studio').then((r) => r.text()).then((html) => {",
      "const a = new DOMParser().parseFromString(html, 'text/html').getElementById('more_theme');",
      "return a ? [a.getAttribute('href'), a.target, a.textContent] : null; })"
    ))
    expect_identical(unlist(link), c("?view=theme", "_blank", "Theme a mascot"))
  })
  it("stacks the preview, the tabs and the code on a phone, and keeps the preview in view", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver(width = 375, height = 812)
    withr::defer(app$stop())
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    top <- function(selector) app$get_js(sprintf("document.querySelector('%s').getBoundingClientRect().top", selector))
    expect_lt(top(".theme-preview"), top(".theme-stack"))
    expect_lt(top(".theme-stack"), top(".theme-right"))
    expect_lt(top(".theme-right"), top(".theme-code"))
    # The small preview shows the mascot centred in its card.
    expect_lt(app$get_js(mascot_offset_js), 3)
    # The page switch and Start again sit side by side at their own size, under the sentence.
    buttons <- app$get_js(paste0(
      "['#page_mode', '#reset_all'].map((s) => { const r = document.querySelector(s).getBoundingClientRect(); ",
      "return [r.top, r.width]; })"
    ))
    expect_lt(abs(buttons[[1]][[1]] - buttons[[2]][[1]]), 4)
    expect_lt(buttons[[1]][[2]] + buttons[[2]][[2]], 250)
    expect_true(app$get_js(
      "document.querySelector('.theme-page').scrollWidth <= document.querySelector('.theme-page').clientWidth"
    ))
    # The four tabs fit on one line.
    expect_true(app$get_js(
      "(() => { const n = document.querySelector('#theme_tabs'); return n.scrollWidth <= n.clientWidth; })()"
    ))
    # Scrolled down to the tabs, the preview stays at the top.
    app$run_js("document.querySelector('.theme-page').scrollTop = 900")
    app$wait_for_js("document.querySelector('.theme-page').scrollTop > 0")
    expect_lt(abs(top(".theme-preview")), 2)
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.theme-preview')).position"), "sticky")
  })
})

describe("the forced mode in a browser", {
  it("comes back after a round trip through bs_theme()", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    withr::defer(app$stop())
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    app$run_js("document.querySelector('#theme_tabs a[data-value=colours]').click()")
    app$wait_for_js("!!document.querySelector('input[name=mode][value=dark]')")
    # Given Force the mascot: dark
    app$click(selector = "input[name=mode][value=dark]")
    app$wait_for_js("document.getElementById('theme_code').textContent.includes('mode = \"dark\"')")
    # When the theme goes to bs_theme() and back
    app$run_js("document.querySelector('#theme_tabs a[data-value=brand]').click()")
    app$click(selector = "[data-event=brand_source][data-value=bslib]")
    app$wait_for_js("document.getElementById('theme_code').textContent.includes('bs_theme')")
    expect_true(app$get_js("document.querySelector('input[name=mode][value=dark]').checked"))
    app$click(selector = "#brand_source [data-event=brand_source][data-value=mascot]")
    # Then the radio and the code say dark again
    app$wait_for_js("document.getElementById('theme_code').textContent.includes('mode = \"dark\"')")
    app$wait_for_js("!document.querySelector('#mode_ui fieldset').disabled")
    expect_true(app$get_js("document.querySelector('input[name=mode][value=dark]').checked"))
    expect_identical(app$get_value(input = "mode"), "dark")
  })
})

describe("the colour tiles in a browser", {
  it("show the reset only on a changed tile, and hide the own-colour hint", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    withr::defer(app$stop())
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    app$run_js("document.querySelector('#theme_tabs a[data-value=colours]').click()")
    app$wait_for_js("!!document.getElementById('colours-light_body')")
    tile <- "document.getElementById('colours-light_body').closest('.pg-role')"
    reset_shown <- sprintf("getComputedStyle(%s.querySelector('.pg-role-reset')).display !== 'none'", tile)
    expect_false(app$get_js(reset_shown))
    expect_identical(app$get_js(sprintf("getComputedStyle(%s.querySelector('.pg-role-leader')).display", tile)), "none")
    # Given a changed colour
    app$run_js("const i = document.getElementById('colours-light_body'); i.value = '#c2185b'; $(i).trigger('change');")
    # Then the tile is marked and offers its reset; the reset puts it back
    app$wait_for_js(sprintf("%s.classList.contains('is-changed')", tile))
    expect_true(app$get_js(reset_shown))
    # A keyboard user presses Enter on the reset button: the tile goes back, and the focus moves to its picker.
    app$run_js(sprintf("%s.querySelector('.pg-role-reset').focus()", tile))
    expect_true(app$get_js(sprintf("document.activeElement === %s.querySelector('.pg-role-reset')", tile)))
    chrome <- app$get_chromote_session()
    chrome$Input$dispatchKeyEvent(
      type = "keyDown",
      key = "Enter",
      code = "Enter",
      windowsVirtualKeyCode = 13,
      text = "\r"
    )
    chrome$Input$dispatchKeyEvent(type = "keyUp", key = "Enter", code = "Enter", windowsVirtualKeyCode = 13)
    app$wait_for_js(sprintf("!%s.classList.contains('is-changed')", tile))
    app$wait_for_js("document.activeElement === document.getElementById('colours-light_body')")
    # More parts is one grid of tiles too, with no heading per group.
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.pg-role-group-title')).display"), "none")
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.pg-role-group')).display"), "contents")
    # The tiles sit in a grid of columns.
    expect_gt(
      app$get_js(sprintf(
        "getComputedStyle(%s.parentElement).gridTemplateColumns.split(' ').length",
        tile
      )),
      1
    )
  })
})

describe("the mascot_studio() guide page", {
  it("documents every view the app serves", {
    dir <- dirname(mascot_example("studio", run = FALSE))
    views <- new.env()
    sys.source(file.path(dir, "R", "views.R"), envir = views)
    guide <- paste(readLines(file.path(dir, "guide", "mascot_studio.Rmd"), warn = FALSE), collapse = "\n")
    for (view in names(views$studio_view_titles)) {
      expect_match(guide, sprintf('`"%s"`', view), fixed = TRUE, info = view)
    }
    expect_false(grepl("Two views", guide, fixed = TRUE))
  })
})

describe("the Brand colours tab for a character with no brand parts", {
  it("hides the pickers and sample pairs and points to Your colours", {
    parts <- theme_parts()
    expect_match(parts$page, "data-display-if=\"output.brand_has_parts == &#39;yes&#39;\"", fixed = TRUE)
    expect_match(
      as.character(parts$env$theme_brand_parts_ui(parts$env$theme_brand_roles("neer"), "Neer")),
      'data-event="go_tab" data-value="colours"',
      fixed = TRUE
    )
    expect_error(parts$env$theme_tab_button("help", "Help"), "tab")
    shiny::testServer(parts$env$theme_view_server, {
      sent <- list()
      session$sendInputMessage <- function(id, message) sent[[id]] <<- message
      session$setInputs(character = "tessa", mood = "idle")
      expect_identical(output$brand_has_parts, "yes")
      expect_match(output$brand_source$html, "Use bs_theme() instead", fixed = TRUE)
      session$setInputs(character = "neer")
      expect_identical(output$brand_has_parts, "no")
      expect_error(output$brand_source)
      # The button opens Your colours.
      session$setInputs(go_tab = "colours")
      expect_identical(sent$theme_tabs$value, "colours")
    })
  })
  it("shows no brand pickers for Neer in a browser", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    withr::defer(app$stop())
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    app$run_js("document.querySelector('#theme_tabs a[data-value=brand]').click()")
    app$wait_for_js("document.getElementById('brand_primary').offsetParent !== null")
    app$set_inputs(character = "neer")
    app$wait_for_js("document.getElementById('brand_primary').offsetParent === null")
    expect_false(app$get_js("[...document.querySelectorAll('.theme-brand-sample')].some((b) => b.offsetParent)"))
    app$click(selector = "[data-event=go_tab][data-value=colours]")
    app$wait_for_js("document.querySelector('#theme_tabs a[data-value=colours]').classList.contains('active')")
  })
})

describe("the Check tab's slow buttons in a browser", {
  it("say they are busy until their result shows", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    withr::defer(app$stop())
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    app$run_js("document.querySelector('#theme_tabs a[data-value=check]').click()")
    for (case in list(
      c("check_contrast", "Checking…", "Check contrast"),
      c("check_preview", "Building…", "Show every mood")
    )) {
      # When the button is clicked, it says so at once
      state <- app$get_js(sprintf(
        "(() => { const b = document.getElementById('%s'); b.click(); return [b.textContent, b.getAttribute('aria-busy'), String(b.disabled)]; })()",
        case[[1]]
      ))
      expect_identical(unlist(state), c(case[[2]], "true", "true"), info = case[[1]])
      # Then it is back once the result shows
      app$wait_for_js(sprintf("!document.getElementById('%s').disabled", case[[1]]))
      expect_identical(app$get_js(sprintf("document.getElementById('%s').textContent", case[[1]])), case[[3]])
      expect_null(app$get_js(sprintf("document.getElementById('%s').getAttribute('aria-busy')", case[[1]])))
      expect_true(app$get_js(sprintf("document.getElementById('%s_ui').textContent.trim().length > 0", case[[1]])))
    }
  })
})

describe("a translucent colour typed half way", {
  it("is named by its picker, and only the colours mascot_theme() rejects are", {
    env <- theme_parts()$env
    expect_length(env$theme_draft_problems(c(body = "#123456"), c(shine_translucent = "rgba(1, 2, 3, 0.5)")), 0L)
    problems <- env$theme_draft_problems(c(shine_translucent = "rgba(1,2", body = "#123456"))
    expect_named(problems, "colours-light_shine_translucent")
    expect_match(problems[[1]], "Not a valid colour yet", fixed = TRUE)
    expect_error(env$theme_draft_problems(light = 1), "light")
  })
  it("leaves the code and the preview at the last accepted theme, with a note under its text box", {
    env <- theme_parts()$env
    calls <- list()
    assign("update_mascot", function(id, ...) calls[[length(calls) + 1L]] <<- list(...), envir = env)
    shiny::testServer(env$theme_view_server, {
      notes <- list()
      session$sendCustomMessage <- function(type, message) {
        if (identical(type, "studio:field-problem")) notes[[message$id]] <<- message$text
      }
      session$setInputs(character = "knurl", mood = "idle", code_style = "short", mode = "auto")
      roles <- mascot_colour_roles("knurl")
      do.call(session$setInputs, stats::setNames(as.list(roles$colour), paste0("colours-light_", roles$role)))
      session$setInputs(`colours-light_shine_translucent` = "rgba(1, 2, 3, 0.5)")
      session$elapse(300)
      accepted <- output$theme_code
      expect_match(accepted, 'shine_translucent = "rgba(1, 2, 3, 0.5)"', fixed = TRUE)
      sent <- length(calls)
      # When the box holds a colour the package rejects
      session$setInputs(`colours-light_shine_translucent` = "rgba(1,2")
      session$elapse(300)
      # Then the code and the preview stay at the accepted theme, and the box gets a note
      expect_identical(output$theme_code, accepted)
      expect_length(calls, sent)
      expect_match(notes$`colours-light_shine_translucent`, "Not a valid colour yet", fixed = TRUE)
      # And once the colour is valid again, both follow and the note goes
      session$setInputs(`colours-light_shine_translucent` = "rgba(9, 9, 9, 0.5)")
      session$elapse(300)
      expect_match(output$theme_code, 'shine_translucent = "rgba(9, 9, 9, 0.5)"', fixed = TRUE)
      expect_identical(notes$`colours-light_shine_translucent`, "")
      expect_gt(length(calls), sent)
    })
  })
})

describe("a translucent colour typed half way, in a browser", {
  it("gets a note under its text box until it is valid", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    withr::defer(app$stop())
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    app$set_inputs(character = "knurl")
    app$run_js("document.querySelector('#theme_tabs a[data-value=colours]').click()")
    app$wait_for_js("!!document.getElementById('colours-light_shine_translucent')")
    box <- "document.getElementById('colours-light_shine_translucent')"
    app$run_js(sprintf("const b = %s; b.value = 'rgba(1,2'; $(b).trigger('change');", box))
    app$wait_for_js("!!document.getElementById('colours-light_shine_translucent_problem')")
    expect_identical(app$get_js(sprintf("%s.getAttribute('aria-invalid')", box)), "true")
    expect_match(
      app$get_js("document.getElementById('colours-light_shine_translucent_problem').textContent"),
      "Not a valid colour yet",
      fixed = TRUE
    )
    app$run_js(sprintf("const b = %s; b.value = 'rgba(1, 2, 3, 0.5)'; $(b).trigger('change');", box))
    app$wait_for_js("!document.getElementById('colours-light_shine_translucent_problem')")
    expect_null(app$get_js(sprintf("%s.getAttribute('aria-invalid')", box)))
  })
})
