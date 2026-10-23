# Throwaway diagnostics for the CI repro branch: prints facts about the runner's Chrome. Never merged.

probe_print <- function(label, value) {
  message("PROBE ", label, ": ", jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", digits = NA))
}

probe_env_js <- "(() => {
  const mq = (q) => matchMedia(q).matches;
  return {
    hover_hover: mq('(hover: hover)'), pointer_fine: mq('(pointer: fine)'), any_hover: mq('(any-hover: hover)'),
    reduced_motion: mq('(prefers-reduced-motion: reduce)')
  };
})()"

probe_repeats <- as.integer(Sys.getenv("PROBE_REPEATS", "0"))

describe("CI probe", {
  it("prints the device the tests' Chrome reports", {
    local_shiny_browser()
    fn <- function() NULL
    body(fn) <- quote({
      library(mascot)
      shiny::shinyApp(shiny::fluidPage(mascot("helper")), function(input, output, session) NULL)
    })
    app <- app_driver(fn)
    probe_print("app env", app$get_js(probe_env_js))
    browser <- app$get_chromote_session()
    browser$Emulation$setEmulatedMedia(features = list(list(name = "prefers-reduced-motion", value = "reduce")))
    probe_print("app env, reduce emulated", app$get_js(probe_env_js))
    succeed()
  })

  it("starts the popup-menu module app many times", {
    skip_if(probe_repeats == 0L)
    local_shiny_browser()
    fn <- function() {
      library(mascot)
      ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tagList(
          mascot(id = ns("helper"), click = mascot_popup_menu(c(about = "About this app"))),
          shiny::textOutput(ns("count"))
        )
      }
      shiny::shinyApp(shiny::fluidPage(ui("module")), function(input, output, session) {
        shiny::moduleServer("module", function(input, output, session) {
          output$count <- shiny::renderText(0L)
        })
      })
    }
    failures <- 0L
    for (i in seq_len(probe_repeats)) {
      app <- tryCatch(
        shinytest2::AppDriver$new(fn, load_timeout = browser_timeout, timeout = browser_timeout),
        error = function(e) e
      )
      if (inherits(app, "error")) {
        failures <- failures + 1L
        probe_print(paste("start failed", i), conditionMessage(app))
        failed <- app$app
        if (!is.null(failed)) {
          probe_print("page after failure", tryCatch(
            failed$get_js(
              "({href: location.href, tracer: typeof window.shinytest2, ready: window.shinytest2?.ready ?? null, jq: typeof window.jQuery, dollar: typeof window.$, shiny: typeof window.Shiny, nav: performance.getEntriesByType('navigation').map((e) => e.type), connected: !!window.Shiny?.shinyapp?.config?.sessionId})"
            ),
            error = function(e) conditionMessage(e)
          ))
          probe_print("logs after failure", tail(as.character(format(failed$get_logs())), 30))
          try(failed$stop(), silent = TRUE)
        }
      } else {
        app$stop()
      }
    }
    probe_print("popup app starts failed", c(failures, probe_repeats))
    succeed()
  })

  it("chooses Knurl at 375 pixels many times", {
    skip_if(probe_repeats == 0L)
    local_shiny_browser()
    skip_if_not_installed("bslib")
    fn <- function() {
      library(mascot)
      shiny::shinyAppDir(system.file("examples", "studio", package = "mascot"))
    }
    failures <- 0L
    for (i in seq_len(probe_repeats)) {
      app <- app_driver(fn, width = 375, height = 900)
      app$run_js(
        "window.charLog = []; const t0 = performance.now(); const at = () => Math.round(performance.now() - t0);
        $(document).on('change', '#character', (e) => charLog.push([at(), 'change', e.target.value]));
        $(document).on('shiny:inputchanged', (e) => { if (e.name === 'character' || e.name === 'initial_character') charLog.push([at(), 'input ' + e.name, e.value]); });
        $(document).on('shiny:message', (e) => { const m = e.message?.inputMessages; if (m) for (const x of m) if (x.id === 'character') charLog.push([at(), 'server update', JSON.stringify(x.message)]); });"
      )
      app$wait_for_js(
        "document.querySelector('#studio_centre #studio_character_bar #character') && document.querySelector('#studio_centre #studio_character_bar #mood')"
      )
      app$run_js("charLog.push([-1, 'set_inputs', 'knurl'])")
      app$set_inputs(character = "knurl")
      ok <- tryCatch(
        {
          app$wait_for_js("document.getElementById('character').value === 'knurl'", timeout = 10000)
          TRUE
        },
        error = function(e) FALSE
      )
      if (!ok) {
        failures <- failures + 1L
        probe_print(paste("knurl failed", i), app$get_js("[document.getElementById('character').value, charLog]"))
      }
      app$stop()
    }
    probe_print("knurl failed", c(failures, probe_repeats))
    succeed()
  })
})
