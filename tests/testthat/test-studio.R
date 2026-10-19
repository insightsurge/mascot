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
    skip_if_not_installed("bslib")
    before <- options()
    studio <- mascot_studio(fn = "mascot_theme", run = FALSE)
    expect_s3_class(studio, "shiny.appobj")
    page <- function(app, query = "") {
      as.character(app$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = query))$content)
    }
    expect_match(page(studio), 'data-initial-function="mascot_theme"', fixed = TRUE)
    # mascot_preview() is an entry of the studio, not a view of its own.
    expect_match(page(studio), 'data-value="mascot_preview"', fixed = TRUE)
    expect_match(page(studio), 'id="preview_build"', fixed = TRUE)
    expect_match(page(studio), 'id="preview_card"', fixed = TRUE)
    expect_match(page(studio), 'data-full-screen="false"', fixed = TRUE)
    expect_match(page(studio), 'data-bslib-card-init', fixed = TRUE)
    expect_match(page(studio), 'id="studio_example_call"', fixed = TRUE)
    expect_match(page(studio), 'data-copy="studio_example_call"', fixed = TRUE)
    expect_false(grepl('id="studio_view"', page(studio), fixed = TRUE))
    expect_false(grepl('id="studio_fn"', page(studio), fixed = TRUE))
    expect_false(grepl('id="studio_run"', page(studio), fixed = TRUE))
    expect_false(grepl("view=preview", page(studio), fixed = TRUE))
    examples <- mascot_studio("examples", run = FALSE)
    expect_match(page(examples), 'id="example_name"', fixed = TRUE)
    expect_match(page(examples), 'href="?view=studio"', fixed = TRUE)
    # Views select the initial host mode; the mounted live engine arrives via renderUI in its iframe.
    expect_match(page(examples), 'data-initial-mode="examples"', fixed = TRUE)
    expect_match(page(examples, "view=studio"), 'data-initial-mode="mascot"', fixed = TRUE)
    expect_match(page(examples, "view=studio"), 'id="example_name"', fixed = TRUE)
    expect_match(page(examples, "view=studio"), 'id="live_host"', fixed = TRUE)
    expect_identical(options(), before)
  })
  it("passes its app to Shiny when launched interactively", {
    local_mocked_bindings(example_interactive = function() TRUE)
    local_mocked_bindings(runApp = function(appDir) inherits(appDir, "shiny.appobj"), .package = "shiny")
    expect_true(mascot_studio())
  })
  it("opens the chosen view and function in Chrome", {
    skip_on_cran()
    skip_if_not_installed("shinytest2")
    skip_if_not_installed("chromote")
    skip_if_not_installed("bslib")
    skip_if(is.null(chromote::find_chrome()), "Chrome is unavailable")
    withr::local_envvar(TMPDIR = withr::local_tempdir())
    app <- app_driver(
      function() {
        library(mascot)
        mascot_studio(fn = "mascot_theme", run = FALSE)
      },
      width = 1440,
      height = 900
    )
    withr::defer(app$stop())
    app$wait_for_js(
      "document.querySelector('.pg-index-link[data-value=mascot_theme]').getAttribute('aria-current') === 'true'"
    )
    expect_false(app$get_js("document.querySelector('[data-function=mascot_theme]').hidden"))
    # A named function opens on its Guide, as ?mascot_studio promises.
    app$wait_for_js(
      "!document.getElementById('inspector_sidebar').hidden && document.getElementById('inspector_tab_guide').getAttribute('aria-selected') === 'true'"
    )
    expect_identical(app$get_value(input = "character"), formals(mascot)$character)
    # Starting on mascot_preview() shows its page on the canvas in place of the live mascot.
    preview <- app_driver(
      function() {
        library(mascot)
        mascot_studio(fn = "mascot_preview", run = FALSE)
      },
      width = 1440,
      height = 900
    )
    withr::defer(preview$stop())
    preview$wait_for_js("!!document.querySelector('iframe.pg-preview')")
    expect_true(preview$get_js("document.querySelector('[data-canvas=mascot]').hidden"))
    expect_false(preview$get_js("document.querySelector('[data-canvas=preview]').hidden"))
    expect_true(preview$get_js("document.querySelector('#preview_card .bslib-full-screen-enter') !== null"))
    examples <- app_driver(function() {
      library(mascot)
      mascot_studio("examples", run = FALSE)
    })
    withr::defer(examples$stop())
    examples$wait_for_js("!!document.getElementById('example_name')")
    expect_identical(examples$get_js("document.getElementById('studio_canvas').dataset.mode"), "examples")
    examples$click(selector = "#studio_menu > summary")
    examples$click(selector = 'a[href="?view=studio"]')
    examples$wait_for_js(
      "!!document.getElementById('live_frame')?.contentDocument?.getElementById('helper') && !!document.getElementById('studio_inspector')"
    )
    expect_identical(examples$get_js("new URLSearchParams(location.search).get('view')"), "studio")
    expect_identical(examples$get_js("document.querySelectorAll('#example_name').length"), 1L)
    expect_identical(examples$get_js("document.getElementById('studio_canvas').dataset.mode"), "mascot")
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
    skip_if_not_installed("bslib")
    page <- function(app, query = "") {
      as.character(app$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = query))$content)
    }
    expect_match(page(mascot_studio(fn = "mascot_theme", run = FALSE)), 'data-initial-open="guide"', fixed = TRUE)
    expect_false(grepl("data-initial-open", page(mascot_studio(run = FALSE)), fixed = TRUE))
    expect_false(grepl(
      "data-initial-open",
      page(mascot_studio("examples", fn = "mascot_theme", run = FALSE)),
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

describe("B2 studio choices", {
  it("classifies unknown view, function and character choices", {
    expect_error(mascot_studio(view = "wrong", run = FALSE), class = "mascot_error_choice")
    expect_error(mascot_studio(fn = "wrong", run = FALSE), class = "mascot_error_choice")
    expect_error(mascot_studio(character = "wrong", run = FALSE), class = "mascot_error_choice")
  })
})
