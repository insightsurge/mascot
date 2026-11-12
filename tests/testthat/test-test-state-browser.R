# Skips the whole file on CRAN or without Chrome, before any of its code runs.
skip_without_chrome()

describe("mascot_test_state() in a browser", {
  it("reads initial and updated mood, status, bubble and module DOM ids after settling", {
    skip_if_not_installed("shinytest2")
    local_shiny_browser()

    app <- app_driver(function() {
      library(mascot)
      mod_ui <- function(id) {
        ns <- shiny::NS(id)
        mascot(ns("helper"), character = "sela")
      }
      mod_server <- function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          shiny::observeEvent(input$ping, ignoreNULL = TRUE, {
            update_mascot("helper", mood = "celebrating", status = "Module done")
          })
        })
      }
      ui <- shiny::fluidPage(
        mascot("helper", character = "tessa", placement = mascot_placement("bottom-right", minimise = TRUE)),
        mod_ui("form"),
        shiny::actionButton("save", "Save"),
        shiny::actionButton("mod_go", "Module go")
      )
      server <- function(input, output, session) {
        shiny::observeEvent(input$save, {
          update_mascot(
            "helper",
            mood = "happy",
            status = "Saved",
            bubble = mascot_bubble("All rows saved", duration = Inf)
          )
        })
        shiny::observeEvent(input$mod_go, {
          update_mascot("form-helper", mood = "happy", status = "Form ready")
        })
        mod_server("form")
      }
      shiny::shinyApp(ui, server)
    })

    initial <- mascot_test_state(app, "helper")
    expect_identical(initial$id, "helper")
    expect_identical(initial$character, "tessa")
    expect_identical(initial$mood, "idle")
    expect_true(nzchar(initial$status))
    expect_null(initial$bubble)
    expect_false(initial$minimised)

    # Do X, then Y at once: click save and immediately read the settled browser state.
    app$click("save")
    app$wait_for_js("document.getElementById('helper')?.dataset.shownMood === 'happy'")
    saved <- mascot_test_state(app, "helper")
    expect_identical(saved$mood, "happy")
    expect_identical(saved$status, "Saved")
    expect_identical(
      saved$bubble,
      list(text = "All rows saved", html = FALSE, closable = TRUE, duration = Inf)
    )

    # Module mascot uses full namespaced DOM id.
    app$click("mod_go")
    app$wait_for_js("document.getElementById('form-helper')?.dataset.shownMood === 'happy'")
    mod_state <- mascot_test_state(app, "form-helper")
    expect_identical(mod_state$id, "form-helper")
    expect_identical(mod_state$character, "sela")
    expect_identical(mod_state$mood, "happy")
    expect_identical(mod_state$status, "Form ready")

    # Missing DOM id times out with a descriptive mascot_error.
    expect_error(
      mascot_test_state(app, "does-not-exist", timeout = 50),
      class = "mascot_error"
    )
  })
})
