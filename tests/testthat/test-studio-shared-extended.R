# The parts that every view of the studio app shares (inst/examples/studio/R/shared-*.R), tested without a browser.

# Skips the whole file on CRAN and in R CMD check, unless the extended tests are on (helper-extended.R);
# the smoke tests are in test-studio.R.
skip_unless_extended()

# The shared files on their own, as a new view would load them.
studio_shared <- function(...) {
  env <- new.env()
  for (file in c(...)) {
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", file), envir = env)
  }
  env
}

describe("run_real_call()", {
  it("reports a call that runs cleanly as a changed mascot with nothing to say", {
    run <- studio_shared("shared-run.R")$run_real_call
    result <- run(quote(mascot_theme(palette = "coral_navy")), environment())
    expect_named(result, c("ok", "class", "message", "silencer", "condition_classes"))
    expect_true(result$ok)
    expect_identical(result$class, "ok")
    expect_null(result$message)
    expect_null(result$silencer)
    expect_identical(result$condition_classes, NULL)
  })
  it("evaluates the call where the caller says, so it sees the caller's objects", {
    run <- studio_shared("shared-run.R")$run_real_call
    caller <- new.env()
    caller$chosen <- "happy"
    expect_identical(run(quote(mascot_mood(chosen)), caller)$class, "ok")
    expect_identical(run(quote(mascot_mood(chosen)), new.env(parent = baseenv()))$class, "error")
  })
  it("reports an unknown palette as an error and offers nothing to silence", {
    run <- studio_shared("shared-run.R")$run_real_call
    result <- run(quote(mascot("helper", theme = "not_a_palette")), environment())
    expect_false(result$ok)
    expect_identical(result$class, "error")
    expect_match(result$message, 'Unknown palette "not_a_palette"', fixed = TRUE)
    expect_null(result$silencer)
    expect_true("mascot_error" %in% result$condition_classes)
  })
  it("counts a dropped palette as a changed mascot, with its warning and its silencing line", {
    run <- studio_shared("shared-run.R")$run_real_call
    shiny::testServer(function(input, output, session) NULL, {
      here <- environment()
      expect_true(run(quote(update_mascot("demo", character = "tessa", theme = "coral_navy")), here)$ok)
      # Knurl has no palette called coral_navy: the package keeps the swap and uses Knurl's own colours.
      result <- run(quote(update_mascot("demo", character = "knurl")), here)
      expect_true(result$ok)
      expect_identical(result$class, "warning")
      expect_match(result$message, 'Palette "coral_navy" dropped for character "knurl"', fixed = TRUE)
      expect_true("mascot_palette_dropped" %in% result$condition_classes)
      expect_match(result$silencer, 'mascot_palette_dropped = function(w) invokeRestart("muffleWarning")', fixed = TRUE)
      expect_false("mascot_update_ignored" %in% result$condition_classes)
    })
  })
  it("counts an ignored update as an unchanged mascot and never offers to silence it", {
    run <- studio_shared("shared-run.R")$run_real_call
    shiny::testServer(function(input, output, session) NULL, {
      here <- environment()
      # A mood is checked against the mascot's character, so the mascot gets one first.
      expect_true(run(quote(update_mascot("demo", character = "tessa")), here)$ok)
      result <- run(quote(update_mascot("demo", mood = "sleepy")), here)
      expect_false(result$ok)
      expect_identical(result$class, "warning")
      expect_match(result$message, "left mascot", fixed = TRUE)
      expect_true("mascot_update_ignored" %in% result$condition_classes)
      expect_null(result$silencer)
    })
  })
  it("reports a message, and silences low contrast the way ?mascot_theme shows", {
    run <- studio_shared("shared-run.R")$run_real_call
    shiny::testServer(function(input, output, session) NULL, {
      here <- environment()
      result <- run(quote(update_mascot("demo", placement = mascot_placement("inline", minimise = TRUE))), here)
      expect_true(result$ok)
      expect_identical(result$class, "message")
      expect_match(result$message, "no effect on an inline mascot", fixed = TRUE)
      expect_match(
        result$silencer,
        'mascot_placement_ignored = function(m) invokeRestart("muffleMessage")',
        fixed = TRUE
      )
      result <- run(quote(update_mascot("demo", theme = list(body = "#f8f9fa"))), here)
      expect_true(result$ok)
      expect_identical(result$class, "warning")
      expect_true("mascot_contrast" %in% result$condition_classes)
      # The silencing line runs the same call without the warning.
      withr::local_options(mascot.contrast_warnings = TRUE)
      expect_no_warning(eval(parse(text = result$silencer), here))
    })
  })
  it("turns contrast warnings on only while the call runs, and keeps the caller's choice", {
    run <- studio_shared("shared-run.R")$run_real_call
    call <- quote(mascot("helper", theme = list(body = "#f8f9fa")))
    withr::local_options(mascot.contrast_warnings = NULL)
    expect_true("mascot_contrast" %in% run(call, environment())$condition_classes)
    expect_null(getOption("mascot.contrast_warnings"))
    withr::local_options(mascot.contrast_warnings = FALSE)
    expect_identical(run(call, environment())$class, "ok")
    expect_false(getOption("mascot.contrast_warnings"))
    expect_identical(run(call, environment(), options = list())$class, "ok")
  })
  it("checks its arguments", {
    run <- studio_shared("shared-run.R")$run_real_call
    expect_error(run("mascot()", environment()), "call")
    expect_error(run(quote(mascot()), list()), "envir")
    expect_error(run(quote(mascot()), environment(), options = list(TRUE)), "options")
    expect_error(studio_shared("shared-run.R")$call_silencer(quote(mascot()), "x"), "conditions")
  })
})

describe("changed_colours()", {
  it("keeps only the values that differ from each role's listed colour, by role and in lower case", {
    changed <- studio_shared("shared-colours.R")$changed_colours
    roles <- data.frame(role = c("body", "rim", "shine"), colour = c("#AABBCC", "#112233", "rgba(0, 0, 0, 0.5)"))
    values <- list(shine = "rgba(0, 0, 0, 0.5)", body = "#aabbcc", rim = "#FF0000", beak = "#123456")
    expect_identical(changed(values, roles), c(rim = "#ff0000"))
    # A role with no picker yet has not changed.
    expect_identical(changed(list(body = NULL, rim = "#112233"), roles), stats::setNames(character(), character()))
    expect_identical(changed(list(), roles), stats::setNames(character(), character()))
  })
  it("checks its arguments", {
    changed <- studio_shared("shared-colours.R")$changed_colours
    roles <- data.frame(role = "body", colour = "#ffffff")
    expect_error(changed(list(body = 1), roles), "values")
    expect_error(changed(list("#ffffff", "#000000"), roles), "names")
    expect_error(changed(list(), data.frame(role = "body")), "colour")
  })
})

describe("colour_groups()", {
  it("puts the brand roles and the leaders a palette changes first, then the rest grouped by name", {
    shared <- studio_shared("shared-colours.R")
    for (id in mascot_characters()$id) {
      roles <- mascot_colour_roles(id)
      groups <- shared$colour_groups(roles, id)
      expect_named(groups, c("Main colours", "More parts"))
      main <- groups$`Main colours`
      brand <- roles$role[!is.na(roles$brand)]
      # Brand roles lead, in the listing's order.
      expect_identical(main[seq_along(brand)], brand, info = id)
      # Every other main role is a leader that at least one of the character's palettes colours differently.
      listed <- mascot_palettes(id)
      listings <- lapply(listed$name[listed$source != "native"], function(p) mascot_colour_roles(id, palette = p))
      for (role in setdiff(main, brand)) {
        expect_true(is.na(roles$follows[roles$role == role]), info = paste(id, role))
        colours <- vapply(listings, function(palette) tolower(palette$colour[palette$role == role]), character(1))
        expect_true(any(colours != tolower(roles$colour[roles$role == role])), info = paste(id, role))
      }
      # Every role appears once; the rest are grouped by the name before the first underscore.
      more <- groups$`More parts`
      expect_setequal(c(main, unlist(more, use.names = FALSE)), roles$role)
      expect_false(anyDuplicated(c(main, unlist(more, use.names = FALSE))) > 0)
      for (group in names(more)) {
        expect_identical(sub("_.*$", "", more[[group]]), rep(group, length(more[[group]])), info = paste(id, group))
      }
    }
  })
  it("groups parts a character adds by their own name, and checks its arguments", {
    shared <- studio_shared("shared-colours.R")
    roles <- rbind(
      mascot_colour_roles("neer")[, c("role", "colour")],
      data.frame(role = c("beak", "beak_tip"), colour = "#000000")
    )
    expect_identical(shared$colour_groups(roles, "neer")$`More parts`$beak, c("beak", "beak_tip"))
    expect_error(shared$colour_groups(list(), "neer"), "roles")
    expect_error(shared$colour_groups(roles, 1), "character")
  })
})

describe("palette_cards()", {
  it("gives one card per palette with its value, description and swatches from the listings", {
    cards <- studio_shared("shared-colours.R")$palette_cards
    for (id in mascot_characters()$id) {
      listed <- mascot_palettes(id)
      result <- cards(id)
      expect_identical(vapply(result, `[[`, "", "name"), listed$name, info = id)
      expect_identical(vapply(result, `[[`, "", "description"), listed$description, info = id)
      expect_identical(result[[1]]$value, "original")
      own <- mascot_colour_roles(id)
      brand <- own$role[!is.na(own$brand)]
      for (card in result[-1]) {
        roles <- mascot_colour_roles(id, palette = card$value)
        expect_identical(card$value, card$name)
        # Brand roles first, then leaders whose colour the palette changes, each with the palette's colour.
        expect_identical(names(card$swatches)[seq_along(brand)], brand, info = card$name)
        expect_identical(unname(card$swatches), roles$colour[match(names(card$swatches), roles$role)])
        for (role in setdiff(names(card$swatches), brand)) {
          expect_true(is.na(own$follows[own$role == role]))
          expect_false(identical(tolower(card$swatches[[role]]), tolower(own$colour[own$role == role])))
        }
      }
      expect_gt(length(result[[1]]$swatches), 0)
    }
    expect_error(cards(1), "character")
  })
})

describe("role_picker() and role_pickers()", {
  it("name the picker and its reset event for a module, and show the swatch in use only when asked", {
    skip_if_not_installed("bslib")
    shared <- studio_shared("shared-colours.R")
    roles <- mascot_colour_roles("sela")
    ns <- shiny::NS("colours")
    html <- as.character(shared$role_picker("dark", "body", roles, resolved = FALSE, ns = ns))
    expect_match(html, 'id="colours-dark_body"', fixed = TRUE)
    expect_match(html, 'data-event="colours-reset_colour"', fixed = TRUE)
    expect_match(html, 'data-value="dark:body"', fixed = TRUE)
    expect_false(grepl("pg-resolved", html, fixed = TRUE))
    expect_match(as.character(shared$role_picker("dark", "body", roles)), 'class="pg-resolved"', fixed = TRUE)
    all <- as.character(shared$role_pickers("light", roles, character = "sela", resolved = FALSE, ns = ns))
    expect_match(all, 'data-event="colours-reset_mode"', fixed = TRUE)
    expect_false(grepl("round swatch", all, fixed = TRUE))
    expect_match(as.character(shared$role_pickers("light", roles, character = "sela")), "round swatch", fixed = TRUE)
    expect_error(shared$role_picker("dark", "beak", roles), "role")
    expect_error(shared$role_picker("dark", "body", roles, resolved = NA), "resolved")
    expect_error(shared$role_pickers("light", roles, ns = "colours"), "ns")
  })
})

describe("colour_roles_ui()", {
  it("gives one piece per mode and one for the CSS variable, named for the module", {
    ui <- studio_shared("shared-colours.R")$colour_roles_ui
    pieces <- ui("colours")
    expect_named(pieces, c("light", "dark", "css"))
    expect_match(as.character(pieces$dark), 'id="colours-dark"', fixed = TRUE)
    expect_named(ui("colours", modes = "light", css = FALSE), "light")
    expect_error(ui("colours", modes = "sepia"), "modes")
    expect_error(ui("colours", css = "yes"), "css")
    expect_error(ui(""), "id")
  })
})

describe("colour_roles_server()", {
  it("carries changed colours over a character swap only for roles the new character has", {
    skip_if_not_installed("bslib")
    character <- shiny::reactiveVal("tessa")
    shiny::testServer(
      studio_shared("shared-colours.R")$colour_roles_server,
      args = list(character = character, palette = shiny::reactiveVal("original")),
      {
        colours <- session$returned
        tessa <- mascot_colour_roles("tessa")
        neer <- mascot_colour_roles("neer")
        shared_role <- intersect(tessa$role, neer$role)[[1L]]
        tessa_only <- setdiff(tessa$role, neer$role)[[1L]]
        # Given untouched pickers, as the browser reports them, and two changed ones
        do.call(session$setInputs, stats::setNames(as.list(tessa$colour), paste0("light_", tessa$role)))
        expect_length(colours$light(), 0L)
        do.call(
          session$setInputs,
          stats::setNames(list("#123456", "#654321"), paste0("light_", c(shared_role, tessa_only)))
        )
        expect_identical(colours$light()[[shared_role]], "#123456")
        expect_identical(colours$light()[[tessa_only]], "#654321")
        # When the character changes, before the browser has drawn the new pickers
        character("neer")
        session$flushReact()
        # Then only the role Neer has too is kept, and the old pickers' values are not read again
        expect_identical(colours$light(), stats::setNames("#123456", shared_role))
        expect_length(colours$dark(), 0L)
      }
    )
  })
  it("keeps a changed colour when the palette changes and lets untouched pickers follow the palette", {
    skip_if_not_installed("bslib")
    palette <- shiny::reactiveVal("original")
    shiny::testServer(
      studio_shared("shared-colours.R")$colour_roles_server,
      args = list(character = shiny::reactiveVal("tessa"), palette = palette),
      {
        colours <- session$returned
        tessa <- mascot_colour_roles("tessa")
        do.call(session$setInputs, stats::setNames(as.list(tessa$colour), paste0("dark_", tessa$role)))
        session$setInputs(dark_body = "#123456")
        palette("coral_navy")
        session$flushReact()
        expect_identical(colours$dark(), c(body = "#123456"))
        # The browser then reports the pickers drawn again: the palette's colours, and the kept change.
        coral <- mascot_colour_roles("tessa", palette = "coral_navy")
        drawn <- stats::setNames(as.list(coral$colour), paste0("dark_", coral$role))
        drawn$dark_body <- "#123456"
        do.call(session$setInputs, drawn)
        expect_identical(colours$dark(), c(body = "#123456"))
        # Choosing the palette's own colour for a part is no change.
        session$setInputs(dark_rim = tolower(coral$colour[coral$role == "rim"]))
        expect_identical(colours$dark(), c(body = "#123456"))
      }
    )
  })
  it("resets one picker, a mode or everything, and sets a picker", {
    skip_if_not_installed("bslib")
    shiny::testServer(
      studio_shared("shared-colours.R")$colour_roles_server,
      args = list(
        character = shiny::reactiveVal("tessa"),
        palette = shiny::reactiveVal("original"),
        css = c(`--brand` = "#7b4fd6")
      ),
      {
        colours <- session$returned
        sent <- list()
        root <- session$rootScope()
        root$sendInputMessage <- function(inputId, message) {
          sent[[length(sent) + 1L]] <<- list(id = inputId, value = message$value)
        }
        tessa <- mascot_colour_roles("tessa")
        do.call(session$setInputs, stats::setNames(as.list(tessa$colour), paste0("light_", tessa$role)))
        session$setInputs(
          light_body = "#123456",
          light_rim = "#654321",
          css_roles = c("body", "beak"),
          css_value = "#000000"
        )
        expect_identical(colours$css(), c(body = "--brand"))
        expect_identical(colours$css_values(), c(`--brand` = "#000000"))
        # The reset button of one role
        session$setInputs(reset_colour = "light:body")
        expect_identical(colours$light(), c(rim = "#654321"))
        # The message goes to the picker; a running app adds the module's prefix to its name.
        expect_true(endsWith(sent[[1L]]$id, "light_body"))
        expect_identical(sent[[1L]]$value, tessa$colour[tessa$role == "body"])
        session$setInputs(reset_colour = "light:not_a_role")
        expect_length(sent, 1L)
        colours$set("dark", "hair", "#ABCDEF")
        expect_identical(colours$dark(), c(hair = "#abcdef"))
        session$setInputs(reset_mode = "dark")
        expect_length(colours$dark(), 0L)
        expect_identical(colours$light(), c(rim = "#654321"))
        colours$reset()
        expect_length(colours$light(), 0L)
        expect_error(colours$reset("sepia"), "mode")
        expect_error(colours$set("light", "body", 1), "value")
      }
    )
  })
  it("keeps a colour set before the pickers are first drawn", {
    skip_if_not_installed("bslib")
    # testServer() runs this before the module's first flush, as a caller's set() right after start-up does.
    shiny::testServer(
      studio_shared("shared-colours.R")$colour_roles_server,
      args = list(character = shiny::reactiveVal("tessa"), palette = shiny::reactiveVal("original")),
      {
        colours <- session$returned
        colours$set("light", "body", "#ABCDEF")
        session$flushReact()
        expect_identical(colours$light(), c(body = "#abcdef"))
      }
    )
  })
  it("clears the parts that read the CSS variable at once, and tells the browser", {
    skip_if_not_installed("bslib")
    shiny::testServer(
      studio_shared("shared-colours.R")$colour_roles_server,
      args = list(
        character = shiny::reactiveVal("tessa"),
        palette = shiny::reactiveVal("original"),
        css = c(`--brand` = "#7b4fd6")
      ),
      {
        colours <- session$returned
        sent <- list()
        root <- session$rootScope()
        root$sendInputMessage <- function(inputId, message) sent[[inputId]] <<- message
        session$setInputs(css_roles = c("body", "rim"))
        expect_identical(colours$css(), c(body = "--brand", rim = "--brand"))
        # When the caller clears them, before the browser answers
        colours$clear_css()
        session$flushReact()
        # Then no part reads the variable, and the checkboxes are told to clear
        expect_length(colours$css(), 0L)
        # (a running app adds the module's prefix to the name)
        id <- grep("css_roles$", names(sent), value = TRUE)
        expect_length(id, 1L)
        expect_length(sent[[id]]$value, 0L)
      }
    )
  })
  it("starts outside a reactive context, as a running app starts it", {
    # testServer() runs the module inside isolate(), which would hide a reactive read at start-up.
    session <- shiny::MockShinySession$new()
    withr::defer(session$close())
    server <- studio_shared("shared-colours.R")$colour_roles_server
    colours <- shiny::withReactiveDomain(
      session,
      server("colours", shiny::reactiveVal("tessa"), shiny::reactiveVal("original"))
    )
    expect_named(colours, c("light", "dark", "css", "css_values", "reset", "set", "clear_css"))
  })
  it("checks its arguments", {
    server <- studio_shared("shared-colours.R")$colour_roles_server
    expect_error(server("colours", "tessa", shiny::reactiveVal("original")), "character")
    expect_error(server("colours", shiny::reactiveVal("tessa"), "original"), "palette")
    expect_error(server("colours", shiny::reactiveVal("tessa"), shiny::reactiveVal("original"), css = "#fff"), "css")
    expect_error(server(1, shiny::reactiveVal("tessa"), shiny::reactiveVal("original")), "id")
    expect_error(
      server("colours", shiny::reactiveVal("tessa"), shiny::reactiveVal("original"), leader = ""),
      "leader"
    )
  })
})

describe("preview_folder()", {
  it("makes a served folder for the session and removes both when the session ends", {
    folder_for <- studio_shared("shared-check.R")$preview_folder
    session <- shiny::MockShinySession$new()
    folder <- folder_for(session, "theme-preview")
    expect_identical(folder$prefix, paste0("theme-preview-", session$token))
    expect_identical(folder$dir, file.path(tempdir(), folder$prefix))
    expect_true(dir.exists(folder$dir))
    expect_true(folder$prefix %in% names(shiny::resourcePaths()))
    session$close()
    expect_false(dir.exists(folder$dir))
    expect_false(folder$prefix %in% names(shiny::resourcePaths()))
    expect_error(folder_for(session, "Theme preview"), "prefix")
    expect_error(folder_for(list(token = "x"), "theme-preview"), "session")
  })
})

describe("contrast_check() and contrast_result_ui()", {
  it("finds no hard-to-see colour in a palette, and lists a chosen one with its ratio", {
    env <- studio_shared("shared-check.R")
    expect_identical(nrow(env$contrast_check("tessa", "coral_navy")$findings), 0L)
    result <- env$contrast_check("tessa", list(rim = "#f5e6c8"))
    expect_null(result$error)
    expect_identical(result$findings$role, "rim")
    expect_identical(result$findings$mode, "light")
    html <- as.character(env$contrast_result_ui(result))
    expect_match(html, "These colours are hard to see on the page background. They are kept.", fixed = TRUE)
    expect_match(html, "<code>#F5E6C8</code>", fixed = TRUE)
    expect_match(html, format(round(result$findings$ratio, 2), nsmall = 2), fixed = TRUE)
  })
  it("says when every colour passes, names the parts tied to a CSS variable, and reports a theme that fails", {
    env <- studio_shared("shared-check.R")
    pass <- env$contrast_check("tessa", NULL)
    expect_match(
      as.character(env$contrast_result_ui(pass, NULL)),
      "Every colour you chose in R has at least 3:1 contrast against the page, in light and dark mode.",
      fixed = TRUE
    )
    # With only CSS colours (or none of your own), nothing was checked in R, and the note says so.
    only_css <- as.character(env$contrast_result_ui(pass, "body", chosen = FALSE))
    expect_match(only_css, "No colour of your own was chosen in R, so nothing was checked here.", fixed = TRUE)
    expect_false(grepl("at least 3:1", only_css, fixed = TRUE))
    expect_match(only_css, "are not checked here", fixed = TRUE)
    expect_error(env$contrast_result_ui(pass, chosen = NA), "chosen")
    expect_match(as.character(env$contrast_result_ui(pass, "body")), "\\(\\s*body\\s*\\) are not checked here")
    failed <- env$contrast_check("knurl", "coral_navy")
    expect_match(failed$error, 'Unknown palette "coral_navy"', fixed = TRUE)
    expect_match(as.character(env$contrast_result_ui(failed)), "The check failed:", fixed = TRUE)
    expect_match(as.character(env$contrast_stale_ui()), "The settings changed since the last check.", fixed = TRUE)
    expect_error(env$contrast_check(""), "character")
    expect_error(env$contrast_result_ui(list()), "names")
    expect_error(env$contrast_result_ui(pass, 1), "css")
  })
})

describe("busy_done_mark()", {
  it("marks a result with the number of the click it answers, and nothing else", {
    env <- studio_shared("shared-check.R")
    expect_identical(as.character(env$busy_done_mark(3)), '<span hidden data-busy-done="3"></span>')
    expect_identical(as.character(env$busy_done_mark("12")), '<span hidden data-busy-done="12"></span>')
    # A value the browser sent that isn't a click number gives no mark
    for (click in list(NULL, "click", -5, 1e12, 1.5, NA, c(1, 2), "1\" onclick=\"x")) {
      expect_null(env$busy_done_mark(click), info = deparse(click))
    }
    expect_error(env$busy_done_mark(list(1)), "click")
  })
})

describe("palette_swap_run()", {
  it("keeps a palette the next character has and drops one it lacks, with the package's warning", {
    env <- studio_shared("shared-run.R", "shared-check.R")
    shiny::testServer(function(input, output, session) NULL, {
      here <- environment()
      kept <- env$palette_swap_run("demo", "tessa", "sela", "coral_navy", here)
      expect_true(kept$ok)
      expect_identical(kept$class, "ok")
      expect_identical(
        kept$code,
        paste(
          'update_mascot("demo", character = "tessa", theme = "coral_navy", motion = FALSE)',
          'update_mascot("demo", character = "sela")',
          sep = "\n"
        )
      )
      dropped <- env$palette_swap_run("demo", "tessa", "knurl", "coral_navy", here)
      expect_true(dropped$ok)
      expect_true("mascot_palette_dropped" %in% dropped$condition_classes)
      expect_match(dropped$message, 'Palette "coral_navy" dropped for character "knurl"', fixed = TRUE)
      expect_identical(kept$step, "swap")
      # A setup the package rejects stops before the swap and says which step it was.
      failed <- env$palette_swap_run("demo", "knurl", "sela", "coral_navy", here)
      expect_false(failed$ok)
      expect_identical(failed$step, "setup")
      expect_identical(failed$code, 'update_mascot("demo", character = "knurl", theme = "coral_navy", motion = FALSE)')
      expect_match(failed$message, 'Unknown palette "coral_navy" for character "knurl"', fixed = TRUE)
      expect_true("mascot_update_ignored" %in% failed$condition_classes)
      expect_error(env$palette_swap_run("", "tessa", "sela", "coral_navy", here), "id")
      expect_error(env$palette_swap_run("demo", "tessa", "sela", "coral_navy", list()), "envir")
    })
  })
})

describe("sentence_bar() and sentence_words()", {
  it("build a toolbar whose sentence selects are words with a tooltip that describes them", {
    env <- studio_shared("shared-layout.R")
    bar <- env$sentence_bar(
      "bar",
      "Quick controls",
      "Character and mood",
      list("Showing", shiny::selectInput("character", NULL, c(Tessa = "tessa")), "."),
      shiny::actionButton("reset_all", "Start again")
    )
    bar <- env$sentence_words(bar, list(character = shiny::tags$code("mascot_character()")))
    html <- as.character(bar)
    expect_match(
      html,
      '<div id="bar" class="pg-toolbar pg-float" role="toolbar" aria-label="Quick controls">',
      fixed = TRUE
    )
    expect_match(html, '<div class="pg-sentence" role="group" aria-label="Character and mood">', fixed = TRUE)
    expect_match(html, '<div class="pg-sentence-word">', fixed = TRUE)
    expect_match(html, 'aria-label="Character"', fixed = TRUE)
    expect_match(html, 'aria-describedby="character_tooltip"', fixed = TRUE)
    expect_match(html, '<span id="character_tooltip" class="pg-word-tooltip" role="tooltip">', fixed = TRUE)
    # The other controls follow the sentence.
    expect_lt(regexpr("pg-sentence", html), regexpr('id="reset_all"', html))
    expect_error(env$sentence_bar("", "a", "b", list()), "id")
    expect_error(env$sentence_bar("bar", "a", "b", "Showing"), "sentence")
    expect_error(env$sentence_words(bar, list()), "tooltips")
    expect_error(env$sentence_words("bar", list(character = "x")), "bar")
  })
})

describe("window_bar() and window_footer()", {
  it("draw the three window dots, a title and a caption line", {
    env <- studio_shared("shared-layout.R")
    html <- as.character(env$window_bar("Preview", shiny::tags$span("extra")))
    expect_match(html, '<div class="pg-host-bar">', fixed = TRUE)
    expect_identical(lengths(gregexpr('<i class="pg-light-', html, fixed = TRUE)), 3L)
    expect_match(html, "<span>Preview</span>\\s*<span>extra</span>")
    expect_match(as.character(env$window_footer("caption")), '<div class="pg-host-footer">caption</div>', fixed = TRUE)
    expect_error(env$window_bar(""), "title")
  })
})

describe("role_picker() marks", {
  it("carry the listed colour, mark a changed picker, and mark the hint of a role that follows no other", {
    env <- studio_shared("shared-colours.R")
    roles <- mascot_colour_roles("tessa")
    plain <- as.character(env$role_picker("light", "body", roles))
    expect_match(
      plain,
      sprintf('<div class="pg-role" data-default="%s">', roles$colour[roles$role == "body"]),
      fixed = TRUE
    )
    expect_match(plain, '<div class="pg-muted pg-role-leader">leader</div>', fixed = TRUE)
    changed <- as.character(env$role_picker("light", "body", roles, value = "#123456"))
    expect_match(changed, '<div class="pg-role is-changed"', fixed = TRUE)
    same <- as.character(env$role_picker("light", "body", roles, value = tolower(roles$colour[roles$role == "body"])))
    expect_false(grepl("is-changed", same, fixed = TRUE))
    follower <- roles$role[!is.na(roles$follows)][[1]]
    expect_false(grepl("pg-role-leader", as.character(env$role_picker("light", follower, roles)), fixed = TRUE))
  })
})

describe("the studio's code builders on their own", {
  it("need nothing from the studio's other files, nor %||% (base R has it only from 4.4)", {
    # Given code.R in a minimal environment where %||% stops, as on R before 4.4 without the studio's data.R
    guard <- new.env(parent = baseenv())
    guard[["%||%"]] <- function(x, y) stop("code.R used %||%")
    code <- new.env(parent = guard)
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "code.R"), envir = code)
    # Then the builders that used it work
    menu <- code$code_menu(c(about = "About"), "auto", NULL)
    expect_identical(eval(menu$helper, asNamespace("mascot")), mascot_popup_menu(c(about = "About")))
    pairs <- list(mood = code$code_mood("happy"), size = code$code_size(120))
    expect_identical(code$pick_style(pairs, "helper")$mood, quote(mascot_mood("happy")))
    picked <- code$pick_style(pairs, c(.default = "short", mood = "helper"))
    expect_identical(picked$mood, quote(mascot_mood("happy")))
    expect_identical(picked$size, 120)
  })
})

describe("colour_roles_server() with the browser's timing", {
  module <- function() studio_shared("shared-colours.R")$colour_roles_server
  it("ignores a late value from the old pickers that arrives after a palette change", {
    skip_if_not_installed("bslib")
    palette <- shiny::reactiveVal("original")
    shiny::testServer(module(), args = list(character = shiny::reactiveVal("tessa"), palette = palette), {
      colours <- session$returned
      tessa <- mascot_colour_roles("tessa")
      do.call(session$setInputs, stats::setNames(as.list(tessa$colour), paste0("light_", tessa$role)))
      session$setInputs(light_rim = "#654321")
      # When the palette changes and, before the browser draws the new pickers, a late value of the old rim arrives
      palette("coral_navy")
      session$flushReact()
      session$setInputs(light_rim = "#654322")
      # Then the old pickers' other values are not taken as changes against the new palette
      expect_identical(names(colours$light()), "rim")
    })
  })
  it("carries only the colours every character in a quick run of switches has", {
    skip_if_not_installed("bslib")
    character <- shiny::reactiveVal("tessa")
    shiny::testServer(module(), args = list(character = character, palette = shiny::reactiveVal("original")), {
      colours <- session$returned
      tessa <- mascot_colour_roles("tessa")
      do.call(session$setInputs, stats::setNames(as.list(tessa$colour), paste0("light_", tessa$role)))
      session$setInputs(light_body = "#123456", light_rim = "#654321")
      for (next_character in c("sela", "knurl", "neer")) {
        character(next_character)
        session$flushReact()
      }
      shared <- Reduce(
        intersect,
        lapply(c("tessa", "sela", "knurl", "neer"), function(id) mascot_colour_roles(id)$role)
      )
      expect_true(all(names(colours$light()) %in% intersect(c("body", "rim"), shared)))
      expect_identical(colours$light()[["body"]], "#123456")
    })
  })
  it("resets a role while it is being edited, and takes the browser's echo of the reset as no change", {
    skip_if_not_installed("bslib")
    shiny::testServer(
      module(),
      args = list(character = shiny::reactiveVal("tessa"), palette = shiny::reactiveVal("original")),
      {
        colours <- session$returned
        tessa <- mascot_colour_roles("tessa")
        do.call(session$setInputs, stats::setNames(as.list(tessa$colour), paste0("light_", tessa$role)))
        session$setInputs(light_body = "#123456")
        session$setInputs(reset_colour = "light:body")
        expect_length(colours$light(), 0L)
        # The browser then reports the picker it was told to show
        session$setInputs(light_body = tolower(tessa$colour[tessa$role == "body"]))
        expect_length(colours$light(), 0L)
        # And a further edit counts again
        session$setInputs(light_body = "#abcdef")
        expect_identical(colours$light(), c(body = "#abcdef"))
      }
    )
  })
})
