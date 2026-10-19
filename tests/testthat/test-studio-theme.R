# The "Theme a mascot" view of the studio app (mascot_studio(view = "theme"); inst/examples/studio/R/theme-*.R).

# The studio app's environment, where the view's functions live, and the theme view's page.
theme_parts <- function() {
  testthat::skip_if_not_installed("bslib")
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
    for (id in c("character", "palette", "mood", "page_mode", "start_again", "theme_code", "code_style")) {
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
  it("keeps the code in step with the palette from the cards, the menu and the stack line", {
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
      session$setInputs(code_style = "short", palette = "forest")
      expect_identical(output$theme_code, 'mascot("helper", theme = "forest")')
      # A palette the character lacks is ignored.
      session$setInputs(palette = "orbit")
      expect_identical(output$theme_code, 'mascot("helper", theme = "forest")')
      # The stack line's clear button goes back to the character's own colours.
      session$setInputs(stack_clear = "palette")
      expect_identical(output$theme_code, 'mascot("helper")')
    })
  })
  it("drops a palette the next character does not have and keeps one it has", {
    env <- theme_parts()$env
    shiny::testServer(env$theme_view_server, {
      session$setInputs(character = "tessa", mood = "idle", palette = "coral_navy")
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
      session$setInputs(stack_clear = "css")
      expect_length(updates$`colours-css_roles`$value, 0L)
      # Clearing your colours resets every picker: the code keeps only the palette and the CSS part
      session$setInputs(stack_clear = "colours")
      expect_false(grepl("light =|dark =", output$theme_code))
      expect_match(output$theme_code, 'palette = "coral_navy"', fixed = TRUE)
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
      expect_identical(updates$palette$value, "forest")
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
    expect_match(as.character(env$theme_mode_input("dark", TRUE)), "<fieldset disabled>", fixed = TRUE)
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
      session$setInputs(palette = "coral_navy", mode = "dark", brand_source = "bslib")
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
