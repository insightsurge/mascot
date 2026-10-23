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

describe("CI probe, round 3", {
  probe_studio <- function() {
    fn <- function() {
      library(mascot)
      shiny::shinyAppDir(system.file("examples", "studio", package = "mascot"))
    }
    app <- app_driver(fn, width = 1280, height = 720, env = parent.frame())
    wait_studio_js(app, "live.dataset.shownMood === 'idle'", timeout = 90000)
    app
  }
  frame <- "document.getElementById('live_frame').contentWindow"
  live <- paste0(frame, ".document.getElementById('helper')")
  geometry <- sprintf(
    "(() => { const w = %s, el = %s, c = el.querySelector('canvas'); const box = (n) => { const r = n.getBoundingClientRect(); return [Math.round(r.left), Math.round(r.top), Math.round(r.width), Math.round(r.height)]; }; return {client: [w.document.documentElement.clientWidth, w.document.documentElement.clientHeight], el: box(el), canvas: box(c), kids: [...el.children].map((k) => [k.className, box(k), getComputedStyle(k).position]), placement: w.mascot.host.state(el).placement, last: document.getElementById('position_last').textContent, dropped: w.mascot.host.state(el).dropped ?? null, motion: w.matchMedia('(prefers-reduced-motion: reduce)').matches, hover: w.matchMedia('(hover: hover)').matches}; })()",
    frame, live
  )

  it("repeats the snap drop of test-studio-app.R:572 and prints the geometry", {
    local_shiny_browser()
    skip_without_studio_packages("studio")
    app <- probe_studio()
    state <- paste0(frame, ".mascot.host.state(", live, ")")
    if (isTRUE(app$get_js("document.getElementById('function_flyout').hidden"))) app$click(selector = "#all_functions")
    app$click(selector = '.pg-index-link[data-value="mascot_size"]')
    app$wait_for_js("!document.getElementById('inspector_sidebar').hidden")
    app$set_inputs(size_unit = "pct", size_pct = 30)
    app$wait_for_js(sprintf("%s.size.size === '30%%'", state))
    app$set_inputs(size_unit = "px", size_px = 120)
    app$wait_for_js(sprintf("%s.size.size === 120", state))
    if (isTRUE(app$get_js("document.getElementById('function_flyout').hidden"))) app$click(selector = "#all_functions")
    app$click(selector = '.pg-index-link[data-value="mascot_placement"]')
    app$wait_for_js("document.getElementById('drag').disabled && document.getElementById('minimise').disabled")
    app$set_inputs(position = "bottom-right")
    app$wait_for_js(sprintf("%s.placement.floating && %s.placement.minimise", state, state))
    app$set_inputs(minimise = FALSE)
    app$wait_for_js(sprintf("!%s.placement.minimise", state))
    app$set_inputs(minimise = TRUE, drag = "snap")
    app$wait_for_js(sprintf("%s.placement.drag === 'snap'", state))
    probe_print("drag before", app$get_js(geometry))
    app$run_js(sprintf(
      "(() => { const w = %s, el = %s, c = el.querySelector('canvas'), r = c.getBoundingClientRect(); window.probeMid = null;
        const press = (type, x, y) => c.dispatchEvent(new w.PointerEvent(type, {bubbles:true, cancelable:true, pointerId:1, button:0, isPrimary:true, clientX:x, clientY:y}));
        press('pointerdown', r.left+r.width/2, r.top+r.height/2); press('pointermove', 1, 1);
        const b = el.getBoundingClientRect(); window.probeMid = [Math.round(b.left), Math.round(b.top), Math.round(b.width), Math.round(b.height), el.dataset.dragging || ''];
        press('pointerup', 1, 1); })()",
      frame, live
    ))
    Sys.sleep(2)
    probe_print("drag mid", app$get_js("probeMid"))
    probe_print("drag after", app$get_js(geometry))
    succeed()
  })

  it("repeats the selectize portal of test-studio-app.R:1369 and prints each condition", {
    local_shiny_browser()
    skip_without_studio_packages("studio")
    app <- probe_studio()
    click_now(app, "[data-call-arg=click]")
    app$run_js(
      "{const body=document.getElementById('chip_editor_body');body.style.maxHeight='60px';body.style.overflow='auto';}"
    )
    app$wait_for_js("document.getElementById('chip_editor_body').clientHeight <= 60")
    app$run_js(
      "{const pop=document.getElementById('chip_editor');pop.style.top=(innerHeight-130)+'px';const s=document.getElementById('click_type').selectize;s.focus();s.open();s.positionDropdown();}"
    )
    conditions <- "(() => {const s=document.getElementById('click_type').selectize; const d=s.$dropdown[0];const r=d.getBoundingClientRect(); const e=document.getElementById('chip_editor'); return {open: s.isOpen, body: d.parentElement===document.body, parent: d.parentElement?.id || d.parentElement?.className, direction: d.dataset.direction ?? null, top: r.top, bottom: r.bottom, inner: innerHeight, z: getComputedStyle(d).zIndex, editorZ: getComputedStyle(e).zIndex, editor: [e.hidden, Math.round(e.getBoundingClientRect().top), e.style.top], active: document.activeElement?.id || document.activeElement?.className};})()"
    for (i in 1:6) {
      probe_print(paste("selectize", i), app$get_js(conditions))
      Sys.sleep(0.5)
    }
    succeed()
  })
})
