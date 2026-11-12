# Skips the whole file on CRAN or without Chrome, before any of its code runs.
skip_without_chrome()

describe("watch_mascot_shiny() in a browser", {
  it("handles busy -> idle, output error -> recovery, and disconnect -> reconnect without overwriting server state", {
    skip_if_not_installed("shinytest2")
    local_shiny_browser()

    app <- app_driver(function() {
      library(mascot)
      ui <- shiny::fluidPage(
        mascot("helper"),
        mascot("unwatched"),
        shiny::actionButton("save", "Save"),
        shiny::actionButton("toggle_error", "Toggle error"),
        shiny::textOutput("status_out")
      )
      server <- function(input, output, session) {
        watch_mascot_shiny(
          "helper",
          map = list(
            busy = list(status = "Calculating..."),
            error = list(status = "Fix output error"),
            disconnected = list(status = "Custom offline message")
          ),
          delay = 0.05
        )
        shiny::observeEvent(input$save, {
          update_mascot("helper", mood = "happy", status = "Saved")
          update_mascot("unwatched", mood = "happy", status = "Still steady")
        })
        err_on <- shiny::reactiveVal(FALSE)
        shiny::observeEvent(input$toggle_error, err_on(!err_on()))
        output$status_out <- shiny::renderText({
          if (isTRUE(err_on())) {
            stop("Simulated failure", call. = FALSE)
          }
          "Output OK"
        })
      }
      shiny::shinyApp(ui, server)
    })

    # Establish server baseline on both mascots before exercising overlays.
    expect_identical(mascot_test_state(app, "helper")$mood, "idle")
    app$click("save")
    app$wait_for_js("document.getElementById('helper')?.dataset.shownMood === 'happy'")
    expect_identical(mascot_test_state(app, "helper")$status, "Saved")
    expect_identical(mascot_test_state(app, "unwatched")$status, "Still steady")

    # Busy -> idle: overlay switches to thinking/Calculating... after delay and restores happy/Saved on idle.
    app$run_js("$(document).trigger('shiny:busy')")
    app$wait_for_js("document.getElementById('helper')?.dataset.shownMood === 'thinking'")
    busy_state <- mascot_test_state(app, "helper")
    expect_identical(busy_state$mood, "thinking")
    expect_identical(busy_state$status, "Calculating...")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).mood"), "happy")
    expect_identical(mascot_test_state(app, "unwatched")$mood, "happy")

    app$run_js("$(document).trigger('shiny:idle')")
    app$wait_for_js("document.getElementById('helper')?.dataset.shownMood === 'happy'")
    expect_identical(mascot_test_state(app, "helper")$status, "Saved")

    # Output error -> recovery (do X, then Y at once): real Shiny output error persists across idle until recovery.
    app$click("toggle_error")
    app$wait_for_js("document.getElementById('helper')?.dataset.shownMood === 'worried'")
    err_state <- mascot_test_state(app, "helper")
    expect_identical(err_state$mood, "worried")
    expect_identical(err_state$status, "Fix output error")
    expect_identical(mascot_test_state(app, "unwatched")$mood, "happy")

    app$click("toggle_error")
    app$wait_for_js("document.getElementById('helper')?.dataset.shownMood === 'happy'")
    recovered_state <- mascot_test_state(app, "helper")
    expect_identical(recovered_state$mood, "happy")
    expect_identical(recovered_state$status, "Saved")

    # Disconnect -> reconnect: watched uses custom map text; unwatched keeps exact default disconnect behaviour.
    app$run_js("document.dispatchEvent(new Event('shiny:disconnected'))")
    app$wait_for_js("document.getElementById('helper')?.dataset.shownMood === 'worried'")
    expect_identical(mascot_test_state(app, "helper")$status, "Custom offline message")
    expect_identical(mascot_test_state(app, "unwatched")$mood, "worried")
    expect_identical(
      mascot_test_state(app, "unwatched")$status,
      "Connection lost. Reload the page to continue."
    )

    app$run_js("document.dispatchEvent(new Event('shiny:connected'))")
    app$wait_for_js("document.getElementById('helper')?.dataset.shownMood === 'happy'")
    expect_identical(mascot_test_state(app, "helper")$status, "Saved")
    expect_identical(mascot_test_state(app, "unwatched")$status, "Still steady")
  })
})
