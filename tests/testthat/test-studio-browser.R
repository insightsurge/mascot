describe("mascot_studio()", {
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
    app$wait_for_js(
      "document.querySelector('.pg-index-link[data-value=mascot_theme]').getAttribute('aria-current') === 'true'"
    )
    expect_false(app$get_js("document.querySelector('[data-function=mascot_theme]').hidden"))
    # A named function opens on its Guide, as ?mascot_studio promises: the Guide shows that function's page.
    wait_studio_panel(app, "guide", "mascot_theme")
    expect_identical(app$get_js("document.getElementById('inspector_tab_guide').getAttribute('aria-selected')"), "true")
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
    wait_studio_preview(preview)
    expect_true(preview$get_js("document.querySelector('[data-canvas=mascot]').hidden"))
    expect_false(preview$get_js("document.querySelector('[data-canvas=preview]').hidden"))
    expect_true(preview$get_js("document.querySelector('#preview_card .bslib-full-screen-enter') !== null"))
    examples <- app_driver(function() {
      library(mascot)
      mascot_studio("examples", run = FALSE)
    })
    examples$wait_for_js("!!document.getElementById('example_name')")
    expect_identical(examples$get_js("document.getElementById('studio_canvas').dataset.mode"), "examples")
    examples$click(selector = "#studio_menu > summary")
    examples$click(selector = 'a[href="?view=studio"]')
    wait_studio_js(examples, "!!document.getElementById('studio_inspector')")
    expect_identical(examples$get_js("new URLSearchParams(location.search).get('view')"), "studio")
    expect_identical(examples$get_js("document.querySelectorAll('#example_name').length"), 1L)
    expect_identical(examples$get_js("document.getElementById('studio_canvas').dataset.mode"), "mascot")
  })
})

describe("mascot_studio() Shift+E in the inspector", {
  it("types a capital E in a field and widens a reading tab outside one", {
    local_shiny_browser()
    skip_without_studio_packages("studio")
    app <- app_driver(
      function() {
        library(mascot)
        mascot_studio(fn = "mascot_status", run = FALSE)
      },
      width = 1440,
      height = 900
    )
    chrome <- app$get_chromote_session()
    # A trusted key press, as a person types it: the browser inserts the text unless the page prevents it.
    shift_e <- function() {
      chrome$Input$dispatchKeyEvent(
        type = "keyDown",
        key = "E",
        code = "KeyE",
        text = "E",
        modifiers = 8L,
        windowsVirtualKeyCode = 69L
      )
      chrome$Input$dispatchKeyEvent(
        type = "keyUp",
        key = "E",
        code = "KeyE",
        modifiers = 8L,
        windowsVirtualKeyCode = 69L
      )
    }
    expanded <- "document.getElementById('inspector_sidebar').classList.contains('is-expanded')"
    app$wait_for_js(
      "!document.getElementById('inspector_sidebar').hidden && document.getElementById('inspector_tab_guide').getAttribute('aria-selected') === 'true'"
    )
    app$click(selector = "#inspector_tab_controls")
    app$wait_for_js("!!document.getElementById('status_text')?.getClientRects().length")
    app$run_js("{ const field = document.getElementById('status_text'); field.value = ''; field.focus(); }")
    shift_e()
    expect_identical(app$get_js("document.getElementById('status_text').value"), "E")
    # In a reading tab, Shift+E on the panel itself still widens and narrows it.
    app$click(selector = "#inspector_tab_guide")
    app$run_js("document.getElementById('inspector_sidebar').focus()")
    expect_false(app$get_js(expanded))
    shift_e()
    expect_true(app$get_js(expanded))
    shift_e()
    expect_false(app$get_js(expanded))
  })
})

describe("mascot_studio() inspector keys and colour swatches in Chrome", {
  studio_on_theme <- function(env = parent.frame()) {
    app_driver(
      function() {
        library(mascot)
        mascot_studio(fn = "mascot_theme", run = FALSE)
      },
      width = 1440,
      height = 900,
      env = env
    )
  }
  it("moves between the inspector tabs with the arrow, Home and End keys, whatever the number of tabs", {
    local_shiny_browser()
    skip_without_studio_packages("studio")
    app <- studio_on_theme()
    selected <- "document.querySelector('[data-inspector-tab][aria-selected=true]')"
    app$wait_for_js(paste0(selected, "?.dataset.inspectorTab === 'guide'"))
    # Each key goes to the selected tab, as a key press on the focused tab does; the last tab wraps to the first.
    steps <- list(
      c("ArrowRight", "controls"),
      c("ArrowLeft", "guide"),
      c("ArrowLeft", "help"),
      c("Home", "controls"),
      c("End", "guide")
    )
    press <- function(steps) {
      for (step in steps) {
        app$run_js(sprintf(
          "{ const tab = %s; tab.focus(); tab.dispatchEvent(new KeyboardEvent('keydown', { key: '%s', bubbles: true })); }",
          selected,
          step[[1]]
        ))
        app$wait_for_js(sprintf(
          "%s?.dataset.inspectorTab === '%s' && document.activeElement === %s",
          selected,
          step[[2]],
          selected
        ))
        expect_identical(app$get_js(paste0(selected, ".dataset.inspectorTab")), step[[2]])
      }
    }
    press(steps)
    # With two tabs left, a fixed count of three would point past the last tab.
    app$run_js("document.querySelector('[data-inspector-tab=help]').remove();")
    press(list(
      c("ArrowRight", "controls"),
      c("ArrowRight", "guide"),
      c("ArrowLeft", "controls"),
      c("ArrowLeft", "guide"),
      c("Home", "controls"),
      c("End", "guide")
    ))
  })
  it("repaints the colour swatches for the mode in use when the page switches between light and dark", {
    local_shiny_browser()
    skip_without_studio_packages("studio")
    app <- studio_on_theme()
    swatches <- function(active, idle) {
      sprintf(
        paste0(
          "(() => { const s = (mode) => [...document.querySelectorAll(`.pg-resolved[data-mode=${mode}]`)]; ",
          "return s('%s').length > 0 && s('%s').length > 0 && ",
          "s('%s').every((el) => !el.classList.contains('is-idle')) && ",
          "s('%s').every((el) => el.classList.contains('is-idle')); })()"
        ),
        active,
        idle,
        active,
        idle
      )
    }
    wait_studio_js(app, "frame.mascot.host.state(live)?.mode === 'light'")
    app$wait_for_js(swatches("light", "dark"))
    expect_true(app$get_js(swatches("light", "dark")))
    app$run_js("document.documentElement.setAttribute('data-bs-theme', 'dark')")
    wait_studio_js(app, "frame.mascot.host.state(live)?.mode === 'dark'")
    app$wait_for_js(swatches("dark", "light"))
    expect_true(app$get_js(swatches("dark", "light")))
  })
})
