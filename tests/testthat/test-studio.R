describe("mascot_studio()", {
  it("validates each argument and requires later arguments to be named", {
    for (bad in list(NULL, NA_character_, 42, "unknown", "preview", c("studio", "examples"))) {
      expect_error(mascot_studio(view = bad, run = FALSE), "view")
    }
    expect_error(mascot_studio("studio", "mascot_theme", run = FALSE), "Unexpected arguments", class = "mascot_error")
    for (bad in list(NA_character_, "", 42, c("mascot", "update_mascot"), "unknown")) {
      expect_error(mascot_studio(fn = bad, run = FALSE), "fn")
    }
    for (bad in list(NULL, NA_character_, "", 42, "unknown", c("a", "b"))) {
      expect_error(mascot_studio(character = bad, run = FALSE), "character")
    }
    for (bad in list(NULL, NA, 42, "FALSE", c(TRUE, FALSE))) {
      expect_error(mascot_studio(run = bad), "Assertion on 'run' failed")
    }
    expect_error(mascot_studio(), "needs an interactive R session")
  })
  it("returns independent apps with the requested first view and function", {
    skip_without_studio_packages("studio")
    before <- options()
    studio <- mascot_studio(fn = "mascot_theme", run = FALSE)
    expect_s3_class(studio, "shiny.appobj")
    # Each page is drawn once: drawing one takes about a second.
    page <- app_page(studio)
    expect_match(page, 'data-initial-function="mascot_theme"', fixed = TRUE)
    # mascot_preview() is an entry of the studio, not a view of its own.
    expect_match(page, 'data-value="mascot_preview"', fixed = TRUE)
    expect_match(page, 'id="preview_build"', fixed = TRUE)
    expect_match(page, 'id="preview_card"', fixed = TRUE)
    expect_match(page, 'data-full-screen="false"', fixed = TRUE)
    expect_match(page, 'data-bslib-card-init', fixed = TRUE)
    expect_match(page, 'id="studio_example_call"', fixed = TRUE)
    expect_match(page, 'data-copy="studio_example_call"', fixed = TRUE)
    examples <- mascot_studio("examples", run = FALSE)
    page <- app_page(examples)
    expect_match(page, 'id="example_name"', fixed = TRUE)
    expect_match(page, 'href="?view=studio"', fixed = TRUE)
    # Views select the initial host mode; the mounted live engine arrives via renderUI in its iframe.
    expect_match(page, 'data-initial-mode="examples"', fixed = TRUE)
    page <- app_page(examples, "view=studio")
    expect_match(page, 'data-initial-mode="mascot"', fixed = TRUE)
    expect_match(page, 'id="example_name"', fixed = TRUE)
    expect_match(page, 'id="live_host"', fixed = TRUE)
    expect_identical(options(), before)
  })
  it("passes its app to Shiny when launched interactively", {
    local_mocked_bindings(example_interactive = function() TRUE)
    local_mocked_bindings(runApp = function(appDir) inherits(appDir, "shiny.appobj"), .package = "shiny")
    expect_true(mascot_studio())
  })
})

describe("the studio on older R", {
  it("defines its own %||%, which base R has only from R 4.4", {
    path <- dirname(mascot_example("studio", run = FALSE))
    data <- new.env(parent = baseenv())
    # As mascot_studio() does: the data file finds the guide's shared code next to the app.
    data$studio_guide_root <- path
    sys.source(file.path(path, "R", "data.R"), envir = data)
    expect_true(exists("%||%", envir = data, inherits = FALSE))
    expect_identical(data$`%||%`(NULL, "b"), "b")
    expect_identical(data$`%||%`("a", "b"), "a")
  })
})

describe("mascot_studio() opening on a function", {
  it("asks the page to open the Guide only when a function is named", {
    skip_without_studio_packages("studio")
    expect_match(app_page(mascot_studio(fn = "mascot_theme", run = FALSE)), 'data-initial-open="guide"', fixed = TRUE)
    expect_false(grepl("data-initial-open", app_page(mascot_studio(run = FALSE)), fixed = TRUE))
    expect_false(grepl(
      "data-initial-open",
      app_page(mascot_studio("examples", fn = "mascot_theme", run = FALSE)),
      fixed = TRUE
    ))
  })
})

describe("the studio and its guide files on older R", {
  it("use no %||%, which base R has only from R 4.4, in the files the website also reads", {
    guide <- file.path(dirname(mascot_example("studio", run = FALSE)), "guide")
    for (file in c("guide-mistakes.R", "guide-shared.R", "guide-helpers.R")) {
      expect_false(any(grepl("%||%", readLines(file.path(guide, file), warn = FALSE), fixed = TRUE)), info = file)
    }
  })
})

describe("mascot_studio() named arguments", {
  it("keeps the agreed signature and rejects both forms of extra argument", {
    expect_identical(names(formals(mascot_studio)), c("view", "...", "fn", "character", "run"))
    expect_error(mascot_studio("studio", run = FALSE, typo = 1), "Unexpected arguments", class = "mascot_error")
    expect_error(mascot_studio("studio", run = FALSE, 1), "Name the optional arguments", class = "mascot_error")
  })
})

describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_studio(view = 1, run = FALSE), "view", class = "mascot_error")
    expect_error(mascot_studio(fn = 1, run = FALSE), "fn", class = "mascot_error")
    expect_error(mascot_studio(character = 1, run = FALSE), "character", class = "mascot_error")
    expect_error(mascot_studio(run = 1), "run", class = "mascot_error")
    expect_error(mascot_studio(fn = "not_a_function", run = FALSE), "fn", class = "mascot_error")
    expect_error(mascot_studio(character = "not_a_character", run = FALSE), "character", class = "mascot_error")
  })
})

describe("studio choices", {
  it("classifies unknown view, function and character choices", {
    expect_error(mascot_studio(view = "wrong", run = FALSE), class = "mascot_error_choice")
    expect_error(mascot_studio(fn = "wrong", run = FALSE), class = "mascot_error_choice")
    expect_error(mascot_studio(character = "wrong", run = FALSE), class = "mascot_error_choice")
  })
})

describe("mascot_studio() views", {
  it("opens the theme view on its own page, without the studio's shell", {
    # The test also opens the studio's page.
    skip_without_studio_packages("studio")
    theme <- mascot_studio("theme", character = "sela", run = FALSE)
    html <- app_page(theme)
    expect_match(html, "<title>Theme a mascot</title>", fixed = TRUE)
    expect_match(html, '<div class="mascot" id="theme_mascot"[^>]* data-character="sela"')
    expect_false(grepl('id="studio_shell"', html, fixed = TRUE))
    expect_false(grepl("studio.js", html, fixed = TRUE))
    # A link that names another view still opens it.
    expect_match(app_page(theme, "view=studio"), 'id="studio_shell"', fixed = TRUE)
    expect_match(app_page(mascot_studio(run = FALSE), "view=theme"), 'id="theme_mascot"', fixed = TRUE)
  })
  it("starts only the server of the view a session serves", {
    skip_if_not_installed("bslib")
    app <- shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))
    env <- environment(app$serverFuncSource())
    for (view in c("theme", "studio")) {
      # Given a session whose page was built for this view
      session <- shiny::MockShinySession$new()
      session$setInputs(tabs = view)
      # When the app's server starts it
      shiny::withReactiveDomain(session, env$server(session$input, session$output, session))
      # Then only the studio makes its preview folder (one of the studio server's first steps)
      folder <- file.path(tempdir(), paste0("studio-preview-", session$token))
      expect_identical(dir.exists(folder), view == "studio", info = view)
      session$close()
      expect_false(dir.exists(folder))
    }
  })
  it("reads the view from the address bar first, then from the page", {
    skip_if_not_installed("bslib")
    env <- environment(shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))$serverFuncSource())
    from <- get("view_from_client", env)
    expect_identical(from("?view=theme", "studio"), "theme")
    expect_identical(from("?view=examples&character=sela"), "examples")
    expect_identical(from("?view=unknown", "theme"), "theme")
    expect_identical(from("", "theme"), "theme")
    expect_identical(from(NULL, "unknown"), "studio")
    expect_identical(from(NULL), "studio")
    expect_error(from(1), "search")
    expect_error(from("", 1), "routed")
    expect_identical(names(env$views), names(get("studio_view_titles", env)))
    expect_error(get("studio_views", env)(function(query) NULL, env$server), "studio_ui")
  })
  it("needs knitr only for the studio's own page", {
    skip_if_not_installed("bslib")
    dir <- dirname(mascot_example("studio", run = FALSE))
    top <- vapply(as.list(parse(file.path(dir, "app.R"))), deparse1, character(1))
    expect_false(any(grepl("knitr", top[!startsWith(top, "studio_view_ui <-")], fixed = TRUE)))
    env <- environment(shiny::shinyAppDir(dir)$serverFuncSource())
    expect_match(deparse1(body(env$studio_view_ui)), 'requireNamespace("knitr"', fixed = TRUE)
    theme_ui <- get("theme_view_ui", env)
    expect_false(grepl("knitr", deparse1(body(theme_ui)), fixed = TRUE))
    expect_error(theme_ui("sela"), "query")
  })
})

describe("mascot_studio() checked object guidance", {
  it("verifies objects and points to public previews while the studio uses ids", {
    local_empty_registry()
    bot <- mascot_read_character(system.file("examples", "characters", "study_bot.json", package = "mascot"))
    for (character in list(bot, mascot_character(bot))) {
      expect_error(mascot_studio(character = character, run = FALSE), "built-in character id", class = "mascot_error")
    }
    expect_s3_class(mascot_studio(character = mascot_character("tessa"), run = FALSE), "shiny.appobj")
    expect_length(character_data_ids(), 0)
    bot$name <- "Edited"
    expect_error(mascot_studio(character = bot, run = FALSE), class = "mascot_error_character")
  })
})

# The studio app in brief: the tests CRAN runs. The rest are in the test-studio*-extended.R and -browser.R files.
describe("the studio app, in brief", {
  it("draws its page with the main controls and no duplicate ids", {
    page <- studio_parts()$page
    for (id in c("mood", "status_text", "bubble_text", "palette", "code_ui")) {
      expect_match(page, paste0('id="', id, '"'), fixed = TRUE, info = id)
    }
    expect_unique_ids(page)
  })
  it("sends a mood change to the live mascot and shows it in the generated code", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    shiny::testServer(get("studio_server", parts$env), {
      envelopes <- list()
      session$sendCustomMessage <- function(type, message) {
        if (identical(type, "mascot:update")) envelopes[[length(envelopes) + 1L]] <<- message
      }
      do.call(session$setInputs, start)
      studio_go_live(session)
      session$setInputs(mood = "happy")
      session$flushReact()
      expect_identical(envelopes[[length(envelopes)]]$state$mood, "happy")
      expect_match(output$code_ui, 'mood = "happy"', fixed = TRUE)
    })
  })
})
