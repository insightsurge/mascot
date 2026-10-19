# The same-origin host runs the real engine in its own viewport and shares one R session.
studio_redesign_driver <- function(width = 1280, height = 720) {
  checkmate::assert_number(width, lower = 1)
  checkmate::assert_number(height, lower = 1)
  app_path <- normalizePath(system.file("examples", "studio", package = "mascot", mustWork = TRUE))
  app <- function() NULL
  body(app) <- substitute(
    {
      library(mascot)
      shiny::shinyAppDir(PATH)
    },
    list(PATH = app_path)
  )
  app_driver(app, width = width, height = height)
}

studio_frame <- "document.getElementById('live_frame').contentWindow"
studio_live <- paste0(studio_frame, ".document.getElementById('helper')")

# Read the engine's own state, including its mounted lifecycle, rather than a studio imitation.
wait_studio_mood <- function(app, mood) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(mood)
  app$wait_for_js(sprintf("%s?.document.getElementById('helper')?.dataset.shownMood === '%s'", studio_frame, mood))
}

describe("the redesigned studio", {
  it("starts an isolated live host and updates mood through the existing control", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    expect_true(nzchar(app$get_js(paste0(studio_live, ".querySelector('.mascot-status').textContent.trim()"))))
    app$set_inputs(mood = "happy")
    wait_studio_mood(app, "happy")
    expect_match(app$get_value(output = "code_ui"), 'mood = "happy"', fixed = TRUE)
    expect_true(app$get_js("document.getElementById('inspector_sidebar').hidden"))
    expect_true(app$get_js("document.getElementById('studio_canvas').clientHeight > 200"))
  })
})

studio_redesign_parts <- function() {
  testthat::skip_if_not_installed("bslib")
  app <- shiny::shinyAppDir(system.file("examples", "studio", package = "mascot"))
  list(
    env = environment(app$serverFuncSource()),
    page = as.character(
      app$httpHandler(
        list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = "")
      )$content
    )
  )
}

describe("studio signature routes", {
  it("makes every mascot formal a call chip with an existing function route", {
    parts <- studio_redesign_parts()
    chip_builder <- get("call_chips", parts$env)
    route <- get("studio_route", parts$env)
    initial <- get("start", parts$env)
    expected <- setdiff(names(formals(mascot)), "...")
    html <- as.character(chip_builder(initial, "short"))
    chips <- regmatches(html, gregexpr('data-call-arg="[^"]+"', html))[[1]]
    expect_length(chips, length(expected) + 1L)
    for (arg in expected) {
      expect_match(html, paste0('data-call-arg="', arg, '"'), fixed = TRUE)
      expect_true(route(arg)$fn %in% getNamespaceExports("mascot"), info = arg)
    }
    expect_match(html, 'data-call-arg="click"', fixed = TRUE)
    expect_false(grepl('data-call-arg="action"', html, fixed = TRUE))
    expect_false(grepl('"Tessa"', html, fixed = TRUE))
    expect_error(route("unknown"), "Assertion on 'arg' failed")
    expect_error(route(1), "Assertion on 'arg' failed")
    expect_error(chip_builder(NULL, "short"), "Assertion on 'state' failed")
    expect_error(chip_builder(initial, "short", 1), "Assertion on 'gesture' failed")
    expect_error(chip_builder(initial, "unknown"), "Assertion on 'style' failed")
  })
  it("searches every export and formal and keeps each input id unique", {
    page <- studio_redesign_parts()$page
    for (fn in getNamespaceExports("mascot")) {
      expect_match(page, paste0('data-search-function="', fn, '"'), fixed = TRUE)
      for (arg in names(formals(getExportedValue("mascot", fn)))) {
        expect_match(page, paste0('id="search_', fn, '_', gsub("[.]", "dot", arg), '"'), fixed = TRUE)
      }
    }
    ids <- regmatches(page, gregexpr(' id="[^"]+"', page))[[1]]
    expect_identical(anyDuplicated(ids), 0L)
    for (text in c('role="combobox"', 'role="listbox"', 'aria-modal="true"', 'id="studio_keys"')) {
      expect_match(page, text, fixed = TRUE)
    }
    expect_length(regmatches(page, gregexpr(' data-group="', page))[[1]], 7L)
  })
})

describe("studio overlays and live controls", {
  it("keeps search modal, routes argument results, and moves one mounted chip editor", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    app$click(selector = "#all_functions")
    expect_true(app$get_js("!document.getElementById('function_flyout').hidden"))
    app$click(selector = "#open_search")
    app$run_js(
      "const q = document.getElementById('function_search'); q.value = 'duration'; q.dispatchEvent(new Event('input', {bubbles:true}));"
    )
    app$wait_for_js(
      "document.getElementById('function_search').getAttribute('aria-activedescendant') === 'search_mascot_bubble_duration'"
    )
    expect_true(app$get_js("document.getElementById('studio_centre').inert"))
    app$run_js(
      "document.getElementById('function_search').focus(); document.dispatchEvent(new KeyboardEvent('keydown', {key:'Tab', bubbles:true}));"
    )
    expect_identical(app$get_js("document.activeElement.id"), "close_search")
    app$run_js(
      "document.getElementById('function_search').dispatchEvent(new KeyboardEvent('keydown', {key:'Enter', bubbles:true}));"
    )
    app$wait_for_js(
      "!document.getElementById('inspector_sidebar').hidden && !document.querySelector('[data-function=mascot_bubble]').hidden"
    )
    expect_true(app$get_js(
      "document.activeElement.id === 'inspector_sidebar' && document.querySelector('[data-function=mascot_bubble] [data-argument=duration]').getClientRects().length > 0"
    ))
    app$click(selector = "#inspector_tab_help")
    app$wait_for_js("document.getElementById('function_help').textContent.includes('duration')")
    expect_match(app$get_js("document.getElementById('function_help').textContent"), "Examples", fixed = TRUE)
    app$click(selector = "#inspector_tab_guide")
    app$wait_for_js("document.querySelector('#guide [data-guide-function=mascot_bubble]') !== null")
    expect_match(app$get_js("document.getElementById('guide').textContent"), "Inf", fixed = TRUE)
    app$run_js("document.dispatchEvent(new KeyboardEvent('keydown', {key:'Escape', bubbles:true}));")
    expect_true(app$get_js("document.getElementById('inspector_sidebar').hidden"))
    # The pinned function list did not swallow Escape from the inspector.
    app$run_js("window.studioStatus = document.getElementById('status_text')")
    app$click(selector = '[data-call-arg=status]')
    expect_true(app$get_js("document.getElementById('chip_editor_body').contains(window.studioStatus)"))
    app$set_inputs(status_text = "Checking a draft")
    app$wait_for_js(sprintf("%s.querySelector('.mascot-status').textContent === 'Checking a draft'", studio_live))
    app$click(selector = "#chip_inspector")
    expect_true(app$get_js(
      "document.getElementById('studio_inspector').contains(window.studioStatus) && document.querySelectorAll('#status_text').length === 1"
    ))
    app$click(selector = "#close_inspector")
    # A real copy is allowed to succeed or report browser denial; a denial must never say Copied.
    app$run_js(
      "window.studioCopy = document.querySelector('#studio_dock [data-copy=code_ui]'); window.studioCopy.click();"
    )
    app$wait_for_js("['Copied', 'Copy failed', 'Copy unavailable'].includes(window.studioCopy.textContent)")
    if (identical(app$get_js("window.studioCopy.textContent"), "Copied")) {
      expect_match(app$get_value(output = "code_ui"), 'status = "Checking a draft"', fixed = TRUE)
    }
  })
  it("preserves bubbles, motion, placement, actions, menus, gestures, code and host modes", {
    local_shiny_browser()
    app <- studio_redesign_driver(width = 1366, height = 768)
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    state <- paste0(studio_frame, ".mascot.host.state(", studio_live, ")")
    select <- function(fn) {
      checkmate::assert_string(fn)
      if (isTRUE(app$get_js("document.getElementById('function_flyout').hidden"))) {
        app$click(selector = "#all_functions")
      }
      app$click(selector = sprintf('.pg-index-link[data-value="%s"]', fn))
    }
    select("mascot_bubble")
    app$set_inputs(
      bubble_text = "<strong>Saved</strong>",
      bubble_html = TRUE,
      bubble_forever = TRUE,
      bubble_closable = FALSE
    )
    app$click(selector = "#bubble_show")
    app$wait_for_js(sprintf("%s.querySelector('.mascot-bubble strong')?.textContent === 'Saved'", studio_live))
    expect_match(app$get_value(output = "code_ui"), "duration = Inf", fixed = TRUE)
    expect_match(app$get_value(output = "code_ui"), "closable = FALSE", fixed = TRUE)
    app$click(selector = "#bubble_clear")
    app$wait_for_js(sprintf("!%s.bubble", state))
    app$set_inputs(idle = "false", mood_change = "false", gestures = "false", messages = "bubble")
    app$wait_for_js(sprintf("%s.motion.idle === false && %s.motion.gestures === false", state, state))
    app$set_inputs(position = "bottom-right", drag = "snap", small_mode = "number", small_px = 72)
    app$wait_for_js(sprintf("%s.dataset.floating === 'true'", studio_live))
    app$click(selector = "#phone_width")
    app$wait_for_js(sprintf(
      "%s.innerWidth <= 390 && %s.querySelector('.mascot-canvas').getBoundingClientRect().width === 72",
      studio_frame,
      studio_live
    ))
    # This is the engine's viewport, rather than a CSS scale of its parent canvas.
    expect_true(app$get_js(sprintf("%s.matchMedia('(max-width: 576px)').matches", studio_frame)))
    app$run_js(sprintf("%s.querySelector('.mascot-minimise').click()", studio_live))
    app$wait_for_js(sprintf("%s.minimised === true", state))
    app$run_js(sprintf("%s.document.querySelector('.mascot-restore').click()", studio_frame))
    app$wait_for_js(sprintf("%s.minimised === false", state))
    app$set_inputs(
      position = "inline",
      action_on = TRUE,
      menu_on = FALSE,
      action_label = "Open help",
      gestures = "true"
    )
    app$wait_for_js(sprintf("%s.click.type === 'action'", state))
    app$run_js(sprintf("%s.querySelector('.mascot-button').click()", studio_live))
    app$wait_for_js("document.getElementById('code_last').textContent.includes('wave')")
    expect_false(grepl("mascot_gesture(", app$get_value(output = "code_ui"), fixed = TRUE))
    expect_false(grepl("gesture = ", app$get_value(output = "code_ui"), fixed = TRUE))
    app$set_inputs(action_on = FALSE, menu_on = TRUE, menu_items = "finish = Finish review")
    app$wait_for_js(sprintf("%s.click.type === 'menu'", state))
    app$run_js(sprintf("%s.querySelector('.mascot-button').click()", studio_live))
    app$wait_for_js(sprintf("%s.document.querySelector('[role=menuitem]') !== null", studio_frame))
    app$run_js(sprintf("%s.document.querySelector('[role=menuitem]').click()", studio_frame))
    app$wait_for_js(
      "document.getElementById('host_event').textContent.includes('finish') || document.getElementById('code_last').textContent.includes('You chose')"
    )
    app$click(selector = "#close_inspector")
    app$set_inputs(host_mode = "preview")
    app$wait_for_js(
      "document.querySelector('[data-canvas=preview]').hidden === false && document.querySelector('#preview_frame iframe') !== null"
    )
    expect_match(app$get_value(output = "code_preview"), "mascot_preview(", fixed = TRUE)
    app$set_inputs(host_mode = "examples")
    app$wait_for_js(
      "document.querySelector('[data-canvas=examples]').hidden === false && document.getElementById('example_code') !== null"
    )
    app$set_inputs(example_name = "form-check")
    app$wait_for_js("document.getElementById('example_code').textContent.includes('mascot(')")
    app$set_inputs(host_mode = "mascot")
    expect_true(app$get_js("document.querySelector('[data-canvas=preview]').hidden"))
    select("mascot_theme")
    app$set_inputs(theme_source = "mascot", theme_mode = "dark")
    app$wait_for_js(sprintf("%s.mode === 'dark'", state))
  })
  it("keeps laptop overlays floating and the phone inspector modal with viewport-clamped chips", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    browser <- app$get_chromote_session()
    for (size in list(
      c(1280L, 720L),
      c(1366L, 768L),
      c(375L, 667L),
      c(390L, 844L),
      c(430L, 932L),
      c(768L, 1024L),
      c(1024L, 768L)
    )) {
      browser$Emulation$setDeviceMetricsOverride(
        width = size[1],
        height = size[2],
        deviceScaleFactor = 1,
        mobile = FALSE
      )
      app$wait_for_js(sprintf("window.innerWidth === %d", size[1]))
      before <- app$get_js("document.getElementById('studio_centre').getBoundingClientRect().width")
      app$click(selector = "#open_inspector")
      expect_equal(app$get_js("document.getElementById('studio_centre').getBoundingClientRect().width"), before)
      expect_true(app$get_js("document.documentElement.scrollWidth <= window.innerWidth"))
      expect_identical(
        app$get_js("document.getElementById('inspector_sidebar').getAttribute('aria-modal')"),
        if (size[1] <= 860) "true" else NULL
      )
      app$click(selector = "#close_inspector")
      app$click(selector = '[data-call-arg=size]')
      expect_true(app$get_js(
        "(() => {const r=document.getElementById('chip_editor').getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth && r.top >= 0 && r.bottom <= innerHeight;})()"
      ))
      app$click(selector = "#close_chip")
    }
    browser$Emulation$setEmulatedMedia(features = list(list(name = "prefers-reduced-motion", value = "reduce")))
    app$wait_for_js("document.getElementById('reduced_motion').textContent.includes('OS')")
    app$run_js(
      "document.getElementById('studio_keys').checked = false; document.getElementById('live_frame').focus(); document.dispatchEvent(new KeyboardEvent('keydown',{key:'/',bubbles:true}));"
    )
    expect_true(app$get_js("document.getElementById('studio_search').hidden"))
    app$run_js(
      "document.getElementById('studio_keys').checked = true; document.dispatchEvent(new KeyboardEvent('keydown',{key:'/',bubbles:true}));"
    )
    expect_false(app$get_js("document.getElementById('studio_search').hidden"))
  })
})

# The old E1 scenario now reaches functions through the overlay and reads the real iframe host.
studio_select_function <- function(app, fn) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(fn)
  if (isTRUE(app$get_js("document.getElementById('function_flyout').hidden"))) {
    app$click(selector = "#all_functions")
  }
  app$click(selector = sprintf('.pg-index-link[data-value="%s"]', fn))
  app$wait_for_js(sprintf(
    "!document.getElementById('inspector_sidebar').hidden && !document.querySelector('#studio_inspector [data-function=%s]').hidden && document.querySelectorAll('#studio_inspector [data-function]:not([hidden])').length === 1",
    fn
  ))
}

studio_colour <- function(app, id, value) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(id)
  checkmate::assert_string(value)
  app$wait_for_js(sprintf("Shiny.shinyapp.$inputValues['%s'] !== undefined", id))
  app$run_js(sprintf(
    "{ const p = document.getElementById('%s'); p.value = '%s'; p.dispatchEvent(new Event('input', {bubbles:true})); }",
    id,
    value
  ))
}

describe("E1 studio behaviour in the redesigned UI", {
  it("selects every function and preserves mounted controls, help, guides and code views", {
    local_shiny_browser()
    app <- studio_redesign_driver(width = 1440, height = 900)
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    expect_identical(app$get_js(paste0(studio_frame, ".document.querySelectorAll('.mascot').length")), 1L)
    for (output in c("code_ui", "code_server", "code_app")) {
      expect_match(app$get_value(output = output), 'placement = "inline"', fixed = TRUE)
    }
    app$run_js("window.originalStatus = document.getElementById('status_text')")
    for (fn in getNamespaceExports("mascot")) {
      studio_select_function(app, fn)
      app$click(selector = "#inspector_tab_help")
      app$wait_for_js(sprintf("document.getElementById('function_help').textContent.includes('%s(')", fn))
      app$click(selector = "#inspector_tab_guide")
      app$wait_for_js(sprintf("document.querySelector('#guide [data-guide-function=%s]') !== null", fn))
      expect_identical(
        app$get_js(
          "document.querySelectorAll('#guide input, #guide select, #guide textarea, #guide [data-event]').length"
        ),
        0L
      )
      if (fn == "mascot_size") {
        app$wait_for_js("!!document.querySelector('#guide #size_ruler .pg-ruler')")
        expect_true(app$get_js("!document.querySelector('#guide #placement_map')"))
      }
      if (fn == "mascot_placement") {
        app$wait_for_js("!!document.querySelector('#guide #placement_map .pg-map')")
        expect_true(app$get_js("!document.querySelector('#guide #size_ruler')"))
      }
      if (fn == "mascot_colour_roles") {
        app$wait_for_js("!!document.querySelector('#guide #roles_table .pg-table')")
      }
      if (fn == "mascot_theme") app$wait_for_js("!!document.querySelector('#guide .pg-flow')")
    }
    studio_select_function(app, "mascot")
    app$click(selector = '[data-function=mascot] a[data-value=mascot_status]')
    app$wait_for_js("!document.querySelector('[data-function=mascot_status]').hidden")
    expect_true(app$get_js("document.getElementById('status_text') === window.originalStatus"))
    app$set_inputs(status_text = "Checking 120 rows")
    app$wait_for_js(sprintf("%s.querySelector('.mascot-status').textContent === 'Checking 120 rows'", studio_live))
    app$wait_for_js("document.getElementById('log').textContent.includes('Checking 120 rows')")
    app$set_inputs(mood = "happy")
    wait_studio_mood(app, "happy")
    app$wait_for_js("document.getElementById('code_last').textContent.includes('happy')")
    app$click(selector = "#open_code")
    app$wait_for_js("!document.getElementById('code_drawer').hidden")
    expect_true(app$get_js("document.getElementById('studio_dock').contains(document.getElementById('code_style'))"))
    expect_identical(
      app$get_js(
        "[...document.querySelectorAll('#code_tabs .nav-link')].filter(el => el.getClientRects().length).map(el => el.textContent.trim()).join('|')"
      ),
      "UI|Server|App|Last|Log"
    )
    expect_match(app$get_value(output = "code_app"), "shinyApp(ui, server)", fixed = TRUE)
    app$set_inputs(code_style = "helper")
    app$wait_for_js("document.getElementById('code_ui').textContent.includes('mascot_mood(\"happy\")')")
    app$click(selector = "#close_code")
    app$click(selector = "#close_inspector")
    app$click(selector = "#reset_all")
    # Reset reloads the page, which drops the browser's script context for a moment.
    for (attempt in 1:20) {
      Sys.sleep(1)
      ok <- tryCatch(
        isTRUE(app$get_js(
          "document.readyState === 'complete' && !!document.getElementById('live_frame') && document.getElementById('status_text')?.value === ''"
        )),
        error = function(e) FALSE
      )
      if (ok) break
    }
    expect_true(ok)
    wait_studio_mood(app, "idle")
  })

  it("shows HTML examples and raw-string code, clears bubbles and honours duration and close controls", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    studio_select_function(app, "mascot_bubble")
    app$set_inputs(bubble_forever = TRUE)
    app$wait_for_js(
      "document.getElementById('bubble_seconds').getAttribute('aria-disabled') === 'true' && $('#bubble_duration').data('ionRangeSlider').options.disable === true"
    )
    app$set_inputs(bubble_forever = FALSE)
    app$wait_for_js("$('#bubble_duration').data('ionRangeSlider').options.disable === false")
    app$set_inputs(bubble_example = "Small table")
    app$click(selector = "#bubble_show")
    app$wait_for_js(sprintf("!!%s.querySelector('.mascot-bubble table')", studio_live))
    app$set_inputs(
      bubble_text = '<p class="notice">Saved</p>',
      bubble_html = TRUE,
      bubble_forever = TRUE,
      bubble_closable = FALSE
    )
    app$click(selector = "#bubble_show")
    app$wait_for_js(sprintf("%s.querySelector('.mascot-bubble .notice')?.textContent === 'Saved'", studio_live))
    code <- app$get_value(output = "code_ui")
    expect_type(parse(text = code), "expression")
    expect_match(code, 'r"(', fixed = TRUE)
    expect_false(grepl('\\"', code, fixed = TRUE))
    expect_match(code, "duration = Inf", fixed = TRUE)
    expect_match(code, "closable = FALSE", fixed = TRUE)
    app$click(selector = "#bubble_clear")
    app$wait_for_js(sprintf("!%s.mascot.host.state(%s).bubble", studio_frame, studio_live))
  })

  it("reports snap and free drops, minimise and restore, and keeps percentage and phone sizes", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    state <- paste0(studio_frame, ".mascot.host.state(", studio_live, ")")
    studio_select_function(app, "mascot_size")
    app$set_inputs(size_unit = "pct", size_pct = 30)
    app$wait_for_js(sprintf("%s.size.size === '30%%'", state))
    expect_match(app$get_value(output = "code_ui"), '"30%"', fixed = TRUE)
    app$set_inputs(size_unit = "px", size_px = 120)
    app$wait_for_js(sprintf("%s.size.size === 120", state))
    studio_select_function(app, "mascot_placement")
    app$wait_for_js("document.getElementById('drag').disabled && document.getElementById('minimise').disabled")
    app$set_inputs(position = "bottom-right")
    app$wait_for_js(sprintf("%s.placement.floating && %s.placement.minimise", state, state))
    app$set_inputs(minimise = FALSE)
    app$wait_for_js(sprintf("!%s.placement.minimise", state))
    expect_match(app$get_value(output = "code_ui"), "minimise = FALSE", fixed = TRUE)
    app$set_inputs(minimise = TRUE, drag = "snap")
    app$wait_for_js(sprintf("%s.placement.drag === 'snap'", state))
    # Dispatch to the iframe canvas in its own viewport coordinates, as the engine receives them.
    drop <- function() {
      app$run_js(sprintf(
        "(() => { const w = %s, c = %s.querySelector('canvas'), r = c.getBoundingClientRect();
          const press = (type, x, y) => c.dispatchEvent(new w.PointerEvent(type, {bubbles:true, cancelable:true, pointerId:1, button:0, isPrimary:true, clientX:x, clientY:y}));
          press('pointerdown', r.left+r.width/2, r.top+r.height/2); press('pointermove', 80, 80); press('pointerup', 80, 80); })()",
        studio_frame,
        studio_live
      ))
    }
    drop()
    app$wait_for_js("document.getElementById('position_last').textContent.includes('top-left')")
    expect_identical(app$get_value(input = "helper_position"), "top-left")
    app$wait_for_js("document.querySelector('#position input:checked').value === 'top-left'")
    expect_match(app$get_value(output = "code_ui"), "top-left", fixed = TRUE)
    app$wait_for_js("document.getElementById('log').textContent.includes('input$helper_position')")
    app$set_inputs(position = "bottom-right", drag = "free")
    app$wait_for_js(sprintf("%s.placement.drag === 'free'", state))
    drop()
    app$wait_for_js(
      "typeof Shiny.shinyapp.$inputValues.helper_position === 'object' && document.getElementById('position_last').textContent.includes('x =')"
    )
    expect_named(app$get_value(input = "helper_position"), c("x", "y"))
    app$run_js(sprintf("%s.querySelector('.mascot-minimise').click()", studio_live))
    app$wait_for_js("document.getElementById('minimised_last').textContent.includes('TRUE')")
    app$wait_for_js(sprintf("%s.minimised === true", state))
    app$run_js(sprintf("%s.document.querySelector('.mascot-restore').click()", studio_frame))
    app$wait_for_js("document.getElementById('minimised_last').textContent.includes('FALSE')")
    app$wait_for_js(sprintf("%s.minimised === false", state))
    app$set_inputs(small_mode = "number", small_px = 72)
    app$click(selector = "#phone_width")
    app$wait_for_js(sprintf(
      "%s.innerWidth <= 390 && %s.querySelector('.mascot-canvas').getBoundingClientRect().width === 72",
      studio_frame,
      studio_live
    ))
  })

  it("changes light and dark roles, CSS variables, contrast results, resets and the family listing", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    state <- paste0(studio_frame, ".mascot.host.state(", studio_live, ")")
    studio_select_function(app, "mascot_theme")
    app$set_inputs(theme_source = "mascot", theme_mode = "light")
    studio_colour(app, "light_body", "#1f6feb")
    app$wait_for_js(sprintf("%s.colours.body?.toLowerCase() === '#1f6feb'", state))
    studio_colour(app, "light_body_highlight", "#abcdef")
    app$wait_for_js(sprintf("%s.colours.body_highlight?.toLowerCase() === '#abcdef'", state))
    app$wait_for_js(
      "document.querySelector('.pg-resolved[data-mode=light][data-role=body_highlight]').style.background === 'rgb(171, 205, 239)'"
    )
    app$run_js("document.querySelector('[data-event=reset_colour][data-value=\"light:body_highlight\"]').click()")
    app$wait_for_js("!document.getElementById('code_ui').textContent.includes('#abcdef')")
    studio_colour(app, "dark_body", "#224466")
    app$set_inputs(theme_mode = "dark")
    app$wait_for_js(sprintf("%s.mode === 'dark' && %s.colours.body?.toLowerCase() === '#224466'", state, state))
    app$set_inputs(css_roles = "body")
    studio_colour(app, "css_accent", "#663399")
    app$wait_for_js(sprintf("%s.colours.body?.toLowerCase() === '#663399'", state))
    expect_match(app$get_value(output = "code_ui"), "--studio-accent", fixed = TRUE)
    app$set_inputs(css_roles = character(), theme_mode = "light")
    studio_colour(app, "light_body", "#f8f9fa")
    app$wait_for_js(sprintf("%s.colours.body?.toLowerCase() === '#f8f9fa'", state))
    app$click(selector = "#contrast_check")
    app$wait_for_js("document.getElementById('contrast').textContent.includes('hard to see')")
    studio_colour(app, "light_body", "#1f6feb")
    app$wait_for_js("document.getElementById('contrast').textContent.includes('Stale contrast result')")
    app$run_js("document.querySelector('[data-event=reset_mode][data-value=light]').click()")
    app$wait_for_js("!document.getElementById('code_ui').textContent.includes('#1f6feb')")
    studio_select_function(app, "mascot_characters")
    family <- mascot_families()$id[1]
    app$set_inputs(list_family = family)
    expected <- mascot_characters(family = family)
    app$wait_for_js(sprintf("document.querySelectorAll('#family_listing tbody tr').length === %d", nrow(expected)))
    expect_match(app$get_value(output = "code_function"), paste0('family = "', family, '"'), fixed = TRUE)
    cells <- app$get_js(
      "[...document.querySelectorAll('#family_listing tbody tr')].map(row => row.cells[0].textContent)"
    )
    expect_setequal(unlist(cells), expected$id)
    app$click(selector = "#inspector_tab_guide")
    app$wait_for_js(sprintf("document.querySelectorAll('#characters_table tbody tr').length === %d", nrow(expected)))
    studio_select_function(app, "mascot_moods")
    app$set_inputs(character = "tessa")
    app$click(selector = "#inspector_tab_guide")
    app$wait_for_js("document.getElementById('guide').textContent.includes(\"Tessa's\")")
  })

  it("runs combined updates, invalid calls and delayed success and failure beside an activity log", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    studio_select_function(app, "update_mascot")
    expect_true(app$get_js(
      "document.querySelector('[data-function=update_mascot]').contains(document.getElementById('wiring_log'))"
    ))
    app$click(selector = "#send_many")
    wait_studio_mood(app, "celebrating")
    app$wait_for_js("document.getElementById('wiring_log').textContent.includes('Review complete')")
    for (part in c('mood = "celebrating"', 'status = "Review complete"', 'duration = Inf', 'gesture = "wave"')) {
      expect_match(app$get_value(output = "code_last"), part, fixed = TRUE)
    }
    expect_false(grepl("mascot_gesture(", app$get_value(output = "code_ui"), fixed = TRUE))
    app$set_inputs(mistake = "Misspell an argument")
    app$click(selector = "#mistake_run")
    app$wait_for_js("document.querySelector('#wiring_log .is-error')?.textContent.includes('Unexpected arguments')")
    wait_studio_mood(app, "celebrating")
    expect_match(app$get_value(output = "code_last"), "moood", fixed = TRUE)
    app$set_inputs(task_fail = FALSE)
    app$click(selector = "#task_run")
    app$wait_for_js("document.getElementById('task_run').disabled")
    wait_studio_mood(app, "thinking")
    wait_studio_mood(app, "happy")
    app$wait_for_js(
      "!document.getElementById('task_run').disabled && document.getElementById('status_text').value === 'All 120 rows checked'"
    )
    expect_match(app$get_value(output = "code_last"), "session = session", fixed = TRUE)
    expect_match(app$get_value(output = "code_ui"), 'status = "All 120 rows checked"', fixed = TRUE)
    app$set_inputs(task_fail = TRUE)
    app$click(selector = "#task_run")
    wait_studio_mood(app, "thinking")
    wait_studio_mood(app, "worried")
    app$wait_for_js(sprintf(
      "%s.querySelector('.mascot-bubble')?.textContent.includes('Three rows have no batch date.')",
      studio_live
    ))
    app$wait_for_js(
      "document.getElementById('status_text').value === 'Check failed' && !document.getElementById('task_run').disabled"
    )
    expect_match(app$get_value(output = "code_last"), "session = session", fixed = TRUE)
    studio_select_function(app, "mascot_popup_menu")
    app$set_inputs(menu_items = "no equals sign")
    app$set_inputs(menu_on = FALSE)
    app$wait_for_js(sprintf("%s.mascot.host.state(%s).click.type === 'none'", studio_frame, studio_live))
    expect_false(grepl("observeEvent(input$helper_menu", app$get_value(output = "code_app"), fixed = TRUE))
    app$click(selector = "#open_code")
    app$click(selector = "#log_clear")
    app$wait_for_js(
      "document.getElementById('log').textContent.includes('Nothing yet.') && document.getElementById('wiring_log').textContent.includes('Nothing yet.')"
    )
  })
})

describe("studio demonstration server routes", {
  it("starts the live studio and example source handlers together for either URL view", {
    parts <- studio_redesign_parts()
    initial <- list(
      character = "tessa",
      mood = "idle",
      gesture = "",
      status_text = "",
      code_style = "short",
      bubble_text = "Hello",
      bubble_html = FALSE,
      bubble_forever = FALSE,
      bubble_duration = 5,
      bubble_closable = TRUE,
      theme_source = "own",
      theme_mode = "auto",
      css_roles = character(),
      css_accent = "#123456",
      position = "inline",
      minimise = TRUE,
      drag = "none",
      size_unit = "px",
      size_px = 160,
      small_mode = "auto",
      small_px = 72,
      idle = "follow",
      mood_change = "follow",
      gestures = "follow",
      swap = "follow",
      minimising = "follow",
      restoring = "follow",
      messages = "follow",
      others = TRUE,
      action_on = FALSE,
      menu_on = FALSE,
      menu_items = "",
      menu_direction = "auto",
      mistake = "Misspell an argument"
    )
    for (view in c("studio", "examples")) {
      shiny::testServer(get("server", parts$env), {
        do.call(
          session$setInputs,
          c(
            initial,
            list(
              tabs = view,
              host_mode = if (view == "examples") "examples" else "mascot",
              example_name = "form-check",
              example_run = FALSE
            )
          )
        )
        expect_match(output$live_host$html, 'id="live_frame"', fixed = TRUE)
        expect_match(output$example_result$html, 'id="example_code"', fixed = TRUE)
        saved <- output$code_ui
        session$setInputs(gesture = "wave")
        expect_match(output$code_last, 'gesture = "wave"', fixed = TRUE)
        expect_identical(output$code_ui, saved)
        session$setInputs(gesture_replay = "wave")
        expect_match(output$code_last, 'gesture = "wave"', fixed = TRUE)
        expect_identical(output$code_ui, saved)
        session$setInputs(gesture = "")
        expect_identical(output$code_ui, saved)
      })
    }
  })
  it("filters both character tables and shows update activity inside its inspector", {
    parts <- studio_redesign_parts()
    expect_match(parts$page, 'id="wiring_log"', fixed = TRUE)
    expect_match(parts$page, 'id="send_many"', fixed = TRUE)
    expect_match(parts$page, 'id="mistake_run"', fixed = TRUE)
    expect_match(parts$page, 'id="task_run"', fixed = TRUE)
    initial <- list(
      character = "tessa",
      mood = "idle",
      status_text = "",
      code_style = "short",
      bubble_text = "Hello",
      bubble_html = FALSE,
      bubble_forever = FALSE,
      bubble_duration = 5,
      bubble_closable = TRUE,
      theme_source = "own",
      theme_mode = "auto",
      css_roles = character(),
      css_accent = "#123456",
      position = "inline",
      minimise = TRUE,
      drag = "none",
      size_unit = "px",
      size_px = 160,
      small_mode = "auto",
      small_px = 72,
      idle = "follow",
      mood_change = "follow",
      gestures = "follow",
      swap = "follow",
      minimising = "follow",
      restoring = "follow",
      messages = "follow",
      others = TRUE,
      action_on = FALSE,
      menu_on = FALSE,
      menu_items = "",
      menu_direction = "auto",
      mistake = "Misspell an argument"
    )
    shiny::testServer(get("studio_server", parts$env), {
      do.call(session$setInputs, initial)
      expect_match(output$live_call$html, 'data-call-function="mascot_popup_menu"', fixed = TRUE)
      expect_false(grepl("click =", output$code_ui, fixed = TRUE))
      session$setInputs(size_px = 208, status_text = "Draft checked")
      session$elapse(700)
      session$setInputs(chip_style = list(arg = "size", style = "helper"))
      expect_match(output$code_ui, "size = mascot_size(208)", fixed = TRUE)
      expect_match(output$code_ui, 'status = "Draft checked"', fixed = TRUE)
      expect_identical(input$code_style, "short")
      session$setInputs(code_style = "helper")
      session$setInputs(chip_style = list(arg = "status", style = "short"))
      expect_match(output$code_ui, "size = mascot_size(208)", fixed = TRUE)
      expect_match(output$code_ui, 'status = "Draft checked"', fixed = TRUE)
      session$setInputs(chip_reset = "size")
      expect_identical(state$size$short, formals(mascot)$size)
      expect_false(grepl("size =", output$code_ui, fixed = TRUE))
      session$setInputs(chip_reset = "status")
      expect_identical(state$status$short, quote(mascot_status()))
      expect_false(grepl("status =", output$code_ui, fixed = TRUE))
      session$setInputs(code_style = "short")
      session$setInputs(
        click_type = "action",
        action_label = "Open report",
        action_tooltip = TRUE,
        action_disabled = FALSE
      )
      session$elapse(700)
      expect_match(output$live_call$html, 'data-call-function="mascot_action"', fixed = TRUE)
      session$setInputs(chip_reset = "click")
      expect_identical(live_demo$click$short, quote(mascot_action()))
      for (family in mascot_families()$id) {
        session$setInputs(list_family = family, select_function = "mascot_characters")
        expected <- mascot_characters(family = family)
        expect_identical(family_listing(), expected)
        expect_match(output$family_listing$html, expected$id[1], fixed = TRUE)
        expect_identical(output$family_listing$html, output$characters_table$html)
        expect_match(output$code_function, paste0('family = "', family, '"'), fixed = TRUE)
      }
      session$setInputs(list_family = "")
      expect_identical(family_listing(), mascot_characters())
      session$setInputs(send_many = 1)
      expect_match(output$wiring_log$html, "Review complete", fixed = TRUE)
      expect_identical(output$wiring_log$html, output$log$html)
      session$setInputs(helper_minimised = TRUE)
      expect_identical(output$minimised_last, "TRUE: minimised")
      expect_match(output$wiring_log$html, "input$helper_minimised", fixed = TRUE)
      session$setInputs(helper_minimised = FALSE)
      expect_identical(output$minimised_last, "FALSE: restored")
      session$setInputs(log_clear = 1)
      expect_match(output$wiring_log$html, "Nothing yet.", fixed = TRUE)
    })
  })
})

describe("E1 actions, menus and generated preview in the redesigned UI", {
  it("honours labels, tooltips, disabled actions, menu direction and real click and choice events", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    state <- paste0(studio_frame, ".mascot.host.state(", studio_live, ")")
    studio_select_function(app, "mascot_action")
    app$set_inputs(action_on = TRUE, action_label = "Open help", action_tooltip = FALSE, action_disabled = TRUE)
    app$wait_for_js(sprintf("%s.click.type === 'action' && %s.click.disabled === true", state, state))
    expect_identical(
      app$get_js(sprintf("%s.querySelector('.mascot-button').getAttribute('aria-label')", studio_live)),
      "Open help"
    )
    expect_match(app$get_value(output = "code_ui"), "tooltip = FALSE", fixed = TRUE)
    expect_match(app$get_value(output = "code_ui"), "disabled = TRUE", fixed = TRUE)
    before <- app$get_js("Shiny.shinyapp.$inputValues.helper_click ?? null")
    app$run_js(sprintf("%s.querySelector('.mascot-button').click()", studio_live))
    # Round trip another input before reading the click counter; no sleep or guessed animation time.
    app$set_inputs(status_text = "Disabled action checked")
    app$wait_for_js(sprintf("%s.status.text === 'Disabled action checked'", state))
    expect_identical(app$get_js("Shiny.shinyapp.$inputValues.helper_click ?? null"), before)
    app$set_inputs(action_disabled = FALSE, action_tooltip = TRUE)
    app$wait_for_js(sprintf("%s.click.disabled === false && %s.click.tooltip === true", state, state))
    app$run_js(sprintf("%s.querySelector('.mascot-button').click()", studio_live))
    app$wait_for_js(
      "document.getElementById('click_last').textContent.includes('click') && document.getElementById('code_last').textContent.includes('wave')"
    )
    expect_false(grepl("mascot_gesture(", app$get_value(output = "code_ui"), fixed = TRUE))
    studio_select_function(app, "mascot_popup_menu")
    app$set_inputs(
      action_on = FALSE,
      menu_on = TRUE,
      menu_items = "finish = Finish review\nabout = About this studio",
      menu_direction = "right",
      menu_label = "Review actions",
      menu_tooltip = FALSE
    )
    app$wait_for_js(sprintf("%s.click.type === 'menu' && %s.click.direction === 'right'", state, state))
    expect_identical(app$get_js(paste0("Object.keys(", state, ".click.items).join()")), "finish,about")
    expect_match(app$get_value(output = "code_ui"), 'direction = "right"', fixed = TRUE)
    app$run_js(sprintf("%s.querySelector('.mascot-button').click()", studio_live))
    app$wait_for_js(sprintf(
      "!!%s.document.querySelector('.mascot-menu:not([hidden]):not(.mascot-motion-copy) [data-item-id=finish]')",
      studio_frame
    ))
    app$run_js(sprintf(
      "%s.document.querySelector('.mascot-menu:not([hidden]):not(.mascot-motion-copy) [data-item-id=finish]').click()",
      studio_frame
    ))
    app$wait_for_js(sprintf("%s.querySelector('.mascot-bubble')?.textContent.includes('Finish review')", studio_live))
    expect_false(grepl("You chose", app$get_value(output = "code_ui"), fixed = TRUE))
    app$run_js(sprintf("%s.querySelector('.mascot-button').click()", studio_live))
    app$wait_for_js(sprintf(
      "!!%s.document.querySelector('.mascot-menu:not([hidden]):not(.mascot-motion-copy) [data-item-id=about]')",
      studio_frame
    ))
    app$run_js(sprintf(
      "%s.document.querySelector('.mascot-menu:not([hidden]):not(.mascot-motion-copy) [data-item-id=about]').click()",
      studio_frame
    ))
    app$wait_for_js("document.querySelector('.modal.show .modal-title')?.textContent === 'About this studio'")
    # Bootstrap ignores a dismissal while the modal is still fading in, so retry until it has closed.
    for (attempt in 1:20) {
      app$run_js("document.querySelector('.modal.show [data-bs-dismiss=modal]')?.click()")
      Sys.sleep(0.5)
      if (isTRUE(app$get_js("!document.querySelector('.modal.show')"))) break
    }
    expect_true(app$get_js("!document.querySelector('.modal.show')"))
  })

  it("rebuilds preview code from controls, returns to the mounted host and opens standalone examples", {
    local_shiny_browser()
    app <- studio_redesign_driver(width = 1440, height = 900)
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    app$run_js(sprintf("window.originalHost = %s", studio_live))
    studio_select_function(app, "mascot_preview")
    app$wait_for_js("!!document.querySelector('iframe.pg-preview')")
    expect_true(app$get_js("document.querySelector('[data-canvas=mascot]').hidden"))
    studio_colour(app, "preview_body", "#1f6feb")
    studio_colour(app, "preview_rim", "#966600")
    app$set_inputs(
      preview_theme_source = "custom",
      preview_menu_items = "about = About the preview",
      preview_width = "phone"
    )
    app$wait_for_js(
      "document.getElementById('code_preview').textContent.includes('body = \"#1f6feb\"') && document.getElementById('code_preview').textContent.includes('About the preview')"
    )
    app$wait_for_js("document.querySelector('iframe.pg-preview').classList.contains('is-phone')")
    expect_match(
      app$get_value(output = "code_preview"),
      'click = mascot_popup_menu(c(about = "About the preview"))',
      fixed = TRUE
    )
    app$run_js(
      "window.sawBuilding = false; window.buildObserver = new MutationObserver(() => {if (document.querySelector('.pg-building')) window.sawBuilding = true;}); window.buildObserver.observe(document.body, {childList:true, subtree:true});"
    )
    app$set_inputs(preview_status = "Auto build status")
    app$wait_for_js(
      "document.getElementById('code_preview').textContent.includes('status = \"Auto build status\"') && !document.querySelector('.pg-building')"
    )
    expect_true(app$get_js("window.sawBuilding"))
    app$run_js("window.buildObserver.disconnect()")
    studio_select_function(app, "mascot_mood")
    app$wait_for_js("document.querySelector('[data-canvas=preview]').hidden")
    expect_true(app$get_js(sprintf("window.originalHost === %s", studio_live)))
    expect_false(app$get_js("document.querySelector('[data-canvas=mascot]').hidden"))
    app$run_js("window.location.search = '?view=examples'")
    app$wait_for_js(
      "!!document.getElementById('example_code') && !!document.getElementById('live_frame') && Shiny.shinyapp.isConnected()"
    )
    expect_true(app$get_js(
      "!!document.getElementById('live_frame') && document.getElementById('studio_canvas').dataset.mode === 'examples'"
    ))
    # The page was reloaded by the browser, so drive the controls the way a visitor does.
    app$run_js("document.getElementById('example_name').selectize.setValue('form-check')")
    app$run_js("document.getElementById('example_run').click()")
    app$wait_for_js(
      "document.getElementById('example_call').textContent.includes('mascot::mascot_example(\"form-check\")')"
    )
    expect_match(app$get_js("document.getElementById('example_code').textContent"), "mascot(", fixed = TRUE)
  })
})

describe("E1 function descriptions in the new flyout", {
  it("only shows truncated descriptions on hover and closes the previous tooltip", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    app$click(selector = "#all_functions")
    app$run_js(
      "{ const b = document.querySelector('.pg-index-link'); b.querySelector('span').style.width = '1000px'; (bootstrap.Tooltip.getInstance(b) || bootstrap.Tooltip.getInstance(b.closest('bslib-tooltip'))).show(); }"
    )
    expect_identical(app$get_js("document.querySelectorAll('.tooltip.show').length"), 0L)
    app$run_js(
      "for (const b of [...document.querySelectorAll('.pg-index-link')].slice(0,2)) {const s=b.querySelector('span'); s.style.width='3rem'; s.style.whiteSpace='nowrap'; s.style.overflow='hidden';}"
    )
    for (i in 0:1) {
      app$run_js(sprintf(
        "document.querySelectorAll('.pg-index-link')[%d].dispatchEvent(new MouseEvent('mouseover', {bubbles:true}))",
        i
      ))
      app$wait_for_js(sprintf(
        "(() => { const b=document.querySelectorAll('.pg-index-link')[%d]; const t=b.hasAttribute('aria-describedby') ? b : b.closest('bslib-tooltip'); return document.getElementById(t?.getAttribute('aria-describedby'))?.classList.contains('show') === true; })()",
        i
      ))
    }
    app$wait_for_js("document.querySelectorAll('.tooltip.show').length === 1")
    app$run_js(
      "for (const b of document.querySelectorAll('.pg-index-link')) b.dispatchEvent(new MouseEvent('mouseout', {bubbles:true}))"
    )
    app$wait_for_js("!document.querySelector('.tooltip.show')")
  })
})

describe("small current-configuration editors", {
  it("edits one value with an argument-local code style and restores the same mounted inputs", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    app$run_js(
      "window.originalSize = document.getElementById('size_px'); window.originalStatus = document.getElementById('status_text')"
    )
    app$click(selector = '[data-call-arg=size]')
    app$wait_for_js(
      "!document.getElementById('chip_editor').hidden && $('#size_px').data('ionRangeSlider').result.from === 160"
    )
    expect_false(app$get_js("document.getElementById('chip_changed').hidden === false"))
    expect_identical(app$get_js("document.querySelectorAll('#chip_editor_body .pg-field').length"), 0L)
    expect_false(app$get_js(
      "document.getElementById('chip_editor_body').contains(document.getElementById('small_mode'))"
    ))
    expect_false(app$get_js("document.getElementById('chip_style').hidden"))
    expect_identical(app$get_js("document.activeElement.id"), "chip_editor")
    app$set_inputs(size_px = 208)
    app$wait_for_js("document.querySelector('[data-call-arg=size]').title === 'size = 208'")
    app$click(selector = '[data-chip-style=helper]')
    app$wait_for_js("document.querySelector('[data-call-arg=size]').textContent.includes('mascot_size(208)')")
    expect_identical(app$get_value(input = "code_style"), "short")
    app$click(selector = "#chip_reset")
    app$wait_for_js(
      "document.getElementById('chip_reset').hidden && $('#size_px').data('ionRangeSlider').result.from === 160"
    )
    expect_true(app$get_js("window.originalSize === document.getElementById('size_px')"))
    app$run_js("document.dispatchEvent(new KeyboardEvent('keydown', {key:'Escape', bubbles:true}))")
    expect_true(app$get_js(
      "document.getElementById('chip_editor').hidden && document.activeElement.dataset.callArg === 'size'"
    ))
    for (arg in c("id", "character", "mood", "status", "bubble", "motion", "placement", "theme", "click")) {
      app$click(selector = sprintf('[data-call-arg=%s]', arg))
      expect_identical(
        app$get_js("document.getElementById('chip_style').hidden"),
        arg %in% c("id", "character", "mood")
      )
      expect_identical(app$get_js("document.querySelectorAll('.selectize-dropdown:has(.active)').length"), 0L)
      expect_true(app$get_js(
        "(() => {const r=document.getElementById('chip_editor').getBoundingClientRect(); return r.left>=0 && r.right<=innerWidth && r.top>=0 && r.bottom<=innerHeight;})()"
      ))
      app$click(selector = "#close_chip")
    }
    app$click(selector = '[data-call-arg=status]')
    expect_identical(
      app$get_js(
        "document.querySelectorAll('#chip_editor_body input:not([type=hidden]), #chip_editor_body textarea, #chip_editor_body select').length"
      ),
      1L
    )
    app$set_inputs(status_text = "Draft checked")
    app$wait_for_js("!document.getElementById('chip_changed').hidden")
    app$click(selector = "#chip_inspector")
    expect_true(app$get_js(
      "document.getElementById('studio_inspector').contains(window.originalStatus) && document.querySelectorAll('#status_text').length === 1 && document.activeElement.id === 'inspector_sidebar'"
    ))
  })

  it("routes menu and action chips, reveals conditional controls, and links Rd argument help", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    app$click(selector = '[data-call-arg=click]')
    expect_identical(app$get_js("document.getElementById('chip_inspector').textContent"), "Advanced controls")
    expect_identical(app$get_value(input = "click_type"), "menu")
    app$click(selector = "#chip_inspector")
    app$wait_for_js(
      "document.activeElement.id === 'inspector_sidebar' && !document.querySelector('[data-function=mascot_popup_menu]').hidden && document.getElementById('menu_items').getClientRects().length > 0"
    )
    app$click(selector = '[data-call-arg=click]')
    app$set_inputs(click_type = "action")
    app$wait_for_js("document.querySelector('[data-call-arg=click]').dataset.callFunction === 'mascot_action'")
    app$click(selector = "#chip_inspector")
    app$wait_for_js("!document.querySelector('[data-function=mascot_action]').hidden")
    app$click(selector = '[data-call-arg=theme]')
    app$click(selector = "#chip_inspector")
    app$wait_for_js(
      "document.querySelector('#theme_mode input:checked') && document.getElementById('theme_mode').getClientRects().length > 0"
    )
    app$click(selector = '[data-call-arg=status]')
    app$click(selector = "#chip_help")
    app$wait_for_js(
      "document.getElementById('inspector_tab_help').getAttribute('aria-selected') === 'true' && document.getElementById('function_help').dataset.activeArgument === 'status' && document.activeElement.id === 'inspector_sidebar'"
    )
    expect_true(app$get_js(
      "document.querySelector('#function_help [data-argument=status] .pg-help').textContent.trim().length > 0"
    ))
    app$click(selector = '[data-call-arg=bubble]')
    app$click(selector = "#chip_help")
    app$wait_for_js(
      "document.activeElement.id === 'inspector_sidebar' && document.getElementById('function_help').dataset.activeArgument === 'bubble' && !document.getElementById('inspector_help').hidden"
    )
    app$click(selector = "#close_inspector")
    app$click(selector = '[data-call-arg=size]')
    app$click(selector = "#chip_inspector")
    app$click(selector = '[data-function=mascot_size] [data-argument=small_screen] .pg-arg-chip')
    app$wait_for_js("!!document.querySelector('.popover.show [data-argument-help=small_screen]')")
    app$click(selector = '.popover.show [data-argument-help=small_screen]')
    app$wait_for_js(
      "document.activeElement.id === 'inspector_sidebar' && document.getElementById('function_help').dataset.activeArgument === 'small_screen' && !document.getElementById('inspector_help').hidden"
    )
  })
})

describe("studio review follow-ups", {
  it("separates comma-delimited arguments from one-off gesture code", {
    parts <- studio_redesign_parts()
    chips <- get("call_chips", parts$env)(get("start", parts$env), "short")
    html <- as.character(chips)
    args <- setdiff(names(formals(mascot)), "...")
    expect_length(regmatches(html, gregexpr('class="pg-call-comma"', html))[[1]], length(args) + 1L)
    # Each comma is a sibling after the closing button, never part of its hit area.
    expect_length(
      regmatches(html, gregexpr('</button>\\s*<span class="pg-call-comma">,</span>', html))[[1]],
      length(args)
    )
    expect_match(html, 'data-call-arg="gesture"', fixed = TRUE)
    signature <- names(formals(mascot))
    positions <- vapply(
      signature,
      function(arg) {
        pattern <- if (arg == "...") 'class="pg-call-dots"' else paste0('data-call-arg="', arg, '"')
        regexpr(pattern, html, fixed = TRUE)[[1]]
      },
      integer(1)
    )
    expect_true(all(diff(positions) > 0))
    expect_match(html, 'title="status = NULL"', fixed = TRUE)
    # Unset values display the exported defaults, in either style, including NULL.
    initial <- get("start", parts$env)
    defaults <- get("defaults", parts$env)
    for (style in c("short", "helper")) {
      unset <- lapply(defaults, get("code_pair", parts$env))
      defaults_html <- as.character(get("call_chips", parts$env)(unset, style))
      for (arg in names(defaults)) {
        expected <- paste(arg, "=", deparse1(formals(mascot)[[arg]]))
        expect_match(
          defaults_html,
          paste0('title="', htmltools::htmlEscape(expected, attribute = TRUE), '"'),
          fixed = TRUE
        )
      }
      initial$status <- NULL
      expect_match(as.character(get("call_chips", parts$env)(initial, style)), 'title="status = NULL"', fixed = TRUE)
    }
    expect_match(html, 'title="demo only, not an argument of mascot()"', fixed = TRUE)
    expect_match(html, '</button>\\s*<span>\\)</span>\\s*$', perl = TRUE)
    gesture <- get("gesture_chip", parts$env)
    expect_match(as.character(gesture()), "none yet", fixed = TRUE)
    expect_match(as.character(gesture("wave")), 'mascot_gesture(&quot;wave&quot;)', fixed = TRUE)
    expect_error(gesture(1), "Assertion on 'name' failed")
    for (id in c("show_anchors", "chip_title", "chip_inspector", "chip_help", "chip_guide")) {
      expect_match(parts$page, paste0('id="', id, '"'), fixed = TRUE)
    }
    expect_false(grepl('id="chip_question"', parts$page, fixed = TRUE))
    expect_match(parts$page, 'id="show_anchors"', fixed = TRUE)
  })

  it("keeps top-bar controls mounted and gives every chip three inspector routes", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    app$run_js(
      "window.topMood=document.getElementById('mood'); window.topCharacter=document.getElementById('character')"
    )
    expect_match(app$get_js("document.querySelector('[data-call-arg=gesture]').textContent"), "none yet", fixed = TRUE)
    app$set_inputs(gesture = "wave")
    app$wait_for_js(
      "document.querySelector('[data-call-arg=gesture]').textContent.includes('mascot_gesture(\"wave\")')"
    )
    expect_false(grepl("gesture", app$get_value(output = "code_ui"), fixed = TRUE))
    expect_true(app$get_js(
      "document.querySelector('[data-call-arg=gesture]').nextElementSibling.textContent === ')' && document.querySelectorAll('#live_call .pg-call-comma').length === document.querySelectorAll('#live_call [data-call-arg]:not(.pg-gesture-chip)').length + 1"
    ))
    for (arg in c("character", "mood", "gesture")) {
      app$click(selector = sprintf('[data-call-arg=%s]', arg))
      expect_true(app$get_js(
        "window.topMood === document.getElementById('mood') && window.topCharacter === document.getElementById('character') && document.getElementById('studio_character_bar').contains(window.topMood) && document.getElementById('studio_character_bar').contains(window.topCharacter)"
      ))
      expect_identical(
        app$get_js(
          "document.querySelectorAll('#chip_editor input, #chip_editor select, #chip_editor textarea').length"
        ),
        0L
      )
      expect_match(
        app$get_js("document.getElementById('chip_editor_body').textContent"),
        "Change it in the top bar",
        fixed = TRUE
      )
      expect_identical(
        app$get_js("[...document.querySelectorAll('.pg-chip-footer button')].map(b=>b.textContent).join('|')"),
        "Advanced controls|Help|Guide"
      )
      app$click(selector = '#chip_topbar')
      expect_true(app$get_js(
        "!!document.activeElement.closest('#studio_character_bar') && !!document.querySelector('#studio_character_bar .pg-topbar-highlight')"
      ))
      app$click(selector = sprintf('[data-call-arg=%s]', arg))
      app$click(selector = '#chip_inspector')
      expect_identical(app$get_js("document.activeElement.id"), "inspector_sidebar")
      expect_true(app$get_js("[...document.querySelectorAll('select')].every(s=>!s.selectize?.isOpen)"))
      # The Controls route also keeps shared controls in the top bar.
      expect_true(app$get_js(
        "document.getElementById('studio_character_bar').contains(window.topMood) && document.getElementById('studio_character_bar').contains(window.topCharacter)"
      ))
      app$click(selector = '#close_inspector')
    }
    app$click(selector = '[data-call-arg=gesture]')
    app$click(selector = '#chip_help')
    app$wait_for_js(
      "document.getElementById('function_help').dataset.activeArgument === 'name' && !!document.querySelector('#function_help [data-guide-function=mascot_gesture]')"
    )
    app$click(selector = '[data-call-arg=placement]')
    app$click(selector = '#chip_guide')
    app$wait_for_js(
      "!document.getElementById('inspector_guide').hidden && !!document.querySelector('#guide [data-guide-function=mascot_placement]')"
    )
    expect_identical(app$get_js("document.activeElement.id"), "inspector_sidebar")
  })

  it("draws real anchor positions and retains them at phone width and after a character change", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    overlay <- paste0(studio_frame, ".document.querySelector('.pg-anchor-overlay')")
    expect_identical(app$get_js("document.getElementById('show_anchors').getAttribute('aria-pressed')"), "false")
    expect_true(app$get_js(paste0(overlay, ".hidden")))
    app$set_inputs(motion_on = FALSE)
    app$click(selector = '#show_anchors')
    app$wait_for_js(paste0("!", overlay, ".hidden && ", overlay, ".querySelectorAll('g[data-anchor]').length > 0"))
    # Character swaps arrive in host messages; the original UI script is not the
    # live descriptor. Supply the independent package fixture to the frame instead.
    verify <- function(character) {
      checkmate::assert_string(character)
      app$run_js(paste0(studio_frame, ".anchorFixture = ", character_json(character), ";"))
      expected <- mascot_anchors(character)$name
      expect_setequal(
        app$get_js(paste0("[...", overlay, ".querySelectorAll('g[data-anchor]')].map(p=>p.dataset.anchor)")),
        expected
      )
      app$wait_for_js(paste0(
        "(() => {const w=",
        studio_frame,
        ";const el=",
        studio_live,
        ";",
        "const compiled=w.mascot.parts.compile(w.anchorFixture); const channels=w.mascot.parts.resolveChannels(compiled,'idle');const state=w.mascot.parts.frame(compiled, channels, 'full', {x:150,base_y:270});",
        "const layer=",
        overlay,
        ";const rect=el.querySelector('canvas').getBoundingClientRect();",
        "const groups=[...layer.querySelectorAll('g[data-anchor]')];",
        "return groups.every(p=>{const a=state.anchors[p.dataset.anchor]; const d=p.querySelector('circle').getBoundingClientRect(); return Math.abs(d.left+d.width/2-(rect.left+a.matrix[4]/300*rect.width))<1 && Math.abs(d.top+d.height/2-(rect.top+a.matrix[5]/300*rect.height))<1;});})()"
      ))
      # Real rendered boxes: no labels overlap each other, the canvas or viewport.
      app$wait_for_js(paste0(
        "(() => {const w=",
        studio_frame,
        ";const rect=",
        studio_live,
        ".querySelector('canvas').getBoundingClientRect();",
        "const labels=[...",
        overlay,
        ".querySelectorAll('.pg-anchor-label')].filter(p=>p.getClientRects().length).map(p=>p.getBoundingClientRect());",
        "const overlaps=(a,b)=>a.left<b.right && a.right>b.left && a.top<b.bottom && a.bottom>b.top;",
        "return labels.length>0 && labels.every((r,i)=>r.left>=0 && r.right<=w.innerWidth && r.top>=0 && r.bottom<=w.innerHeight && !overlaps(r,rect) && labels.slice(i+1).every(b=>!overlaps(r,b)));})()"
      ))
      expect_true(app$get_js(paste0(
        "[...",
        overlay,
        ".querySelectorAll('g[data-anchor]')].every(g=>g.querySelector('title').textContent.includes(g.dataset.anchor) && g.querySelector('line') && g.querySelector('text').getComputedTextLength() <= +g.querySelector('rect').getAttribute('width')-8)"
      )))
    }
    verify("tessa")
    app$click(selector = '#phone_width')
    verify("tessa")
    app$set_inputs(character = "sela")
    app$wait_for_js(paste0(studio_live, ".dataset.character === 'sela'"))
    app$wait_for_js(paste0(overlay, ".querySelectorAll('g[data-anchor]').length === ", nrow(mascot_anchors("sela"))))
    verify("sela")
    app$set_inputs(character = "neer")
    app$wait_for_js(paste0(studio_live, ".dataset.character === 'neer'"))
    app$wait_for_js(paste0(overlay, ".querySelectorAll('g[data-anchor]').length === ", nrow(mascot_anchors("neer"))))
    verify("neer")
    app$click(selector = '#show_anchors')
    expect_true(app$get_js(paste0(overlay, ".hidden")))
  })

  it("portals selectize menus above clipped editors and restores them when closed", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    app$click(selector = '[data-call-arg=click]')
    expect_true(app$get_js("!document.getElementById('click_type').selectize.isOpen"))
    app$run_js(
      "{const body=document.getElementById('chip_editor_body');body.style.maxHeight='60px';body.style.overflow='auto';}"
    )
    app$wait_for_js("document.getElementById('chip_editor_body').clientHeight <= 60")
    app$run_js(
      "{const pop=document.getElementById('chip_editor');pop.style.top=(innerHeight-130)+'px';const s=document.getElementById('click_type').selectize;s.focus();s.open();s.positionDropdown();}"
    )
    app$wait_for_js(
      "(() => {const s=document.getElementById('click_type').selectize; const d=s.$dropdown[0];const r=d.getBoundingClientRect();return s.isOpen && d.parentElement===document.body && d.dataset.direction==='up' && r.top>=0 && r.bottom<=innerHeight && +getComputedStyle(d).zIndex>+getComputedStyle(document.getElementById('chip_editor')).zIndex;})()"
    )
    app$run_js(
      "{const s=document.getElementById('click_type').selectize;s.$control_input.trigger($.Event('keydown',{keyCode:38}));s.$control_input.trigger($.Event('keydown',{keyCode:13}));}"
    )
    app$wait_for_js(
      "!document.getElementById('click_type').selectize.isOpen && document.getElementById('click_type').value === 'action'"
    )
    app$click(selector = '#close_chip')
    expect_true(app$get_js(
      "!document.querySelector('.pg-chip-dropdown') && !document.getElementById('click_type').selectize.isOpen && document.getElementById('studio_inspector').contains(document.getElementById('click_type').selectize.$dropdown[0])"
    ))
    app$click(selector = '[data-call-arg=click]')
    app$click(selector = '#chip_inspector')
    expect_identical(app$get_js("document.activeElement.id"), "inspector_sidebar")
    expect_true(app$get_js("[...document.querySelectorAll('select')].every(s=>!s.selectize?.isOpen)"))
  })
})


describe("studio sentence controls and overview", {
  it("renders inline sentence words with help-page tooltips and per-argument Rd overviews", {
    parts <- studio_redesign_parts()
    for (id in c("character", "palette", "mood", "gesture")) {
      expect_match(parts$page, paste0('<select[^>]*aria-label="', tools::toTitleCase(id), '"[^>]*id="', id, '"'))
    }
    expect_match(
      parts$page,
      'class="pg-sentence" role="group" aria-label="Character, palette, mood and one-off gesture"',
      fixed = TRUE
    )
    expect_match(parts$page, 'placeholder="Search functions and arguments"', fixed = TRUE)
    expect_match(parts$page, 'id="gesture_play"', fixed = TRUE)
    expect_match(parts$page, 'id="mood_article">in an', fixed = TRUE)
    expect_match(parts$page, "mood, with", fixed = TRUE)
    expect_match(parts$page, "Play it again", fixed = TRUE)
    for (id in c("character", "palette", "mood", "gesture")) {
      fn <- if (id == "palette") "mascot_palettes" else paste0("mascot_", id)
      expect_match(parts$page, paste0('aria-describedby="', id, '_tooltip"'), fixed = TRUE)
      expect_match(parts$page, paste0(fn, "()"), fixed = TRUE)
      expect_match(
        parts$page,
        htmltools::htmlEscape(get("help_page", parts$env)(fn)$title),
        fixed = TRUE
      )
    }
    expect_equal(nrow(mascot_anchors("neer")), 14L)
    for (id in c("reset_anchors", "no_anchors")) {
      expect_match(parts$page, paste0('id="', id, '"'), fixed = TRUE)
    }
    for (arg in setdiff(names(formals(mascot)), "...")) {
      expect_match(parts$page, paste0('data-chip-overview="', arg, '"'), fixed = TRUE)
      overview <- as.character(get("arg_popover_body", parts$env)("mascot", arg))
      expect_match(overview, "Default:", fixed = TRUE)
      expect_match(overview, "pg-help", fixed = TRUE)
    }
    for (colour in c("red", "yellow", "green")) {
      expect_match(parts$page, paste0('class="pg-light-', colour, '"'), fixed = TRUE)
    }
  })

  it("groups four labelled selects, plays and replays a gesture, and opens search on focus", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    expect_identical(
      app$get_js("[...document.querySelectorAll('.pg-sentence[role=group] select')].map(s=>s.id).join('|')"),
      "character|palette|mood|gesture"
    )
    expect_true(app$get_js(
      "[...document.querySelectorAll('.pg-sentence select')].every(s=>s.getAttribute('aria-label')?.length>0) && !!document.querySelector('.pg-sentence[aria-label]')"
    ))
    expect_identical(app$get_js("document.getElementById('gesture').options[0].value"), "")
    expect_setequal(
      app$get_js("[...document.getElementById('gesture').options].slice(1).map(o=>o.value)"),
      mascot_gestures("tessa")$name
    )
    app$run_js(paste0(
      "window.gestureCalls=[]; {const host=",
      studio_frame,
      ".mascot.host; const receive=host.receive; host.receive=function(m){const el=document.getElementById('live_frame').contentDocument.getElementById('helper'); const before=host.state(el).snapshot.gesture_watermark; const result=receive(m); if(m.gesture && host.state(el).snapshot.gesture_watermark>before) window.gestureCalls.push(m.gesture.name); return result;};}"
    ))
    app$set_inputs(gesture = "wave")
    app$wait_for_js(
      "window.gestureCalls.length === 1 && document.getElementById('code_last').textContent.includes('wave')"
    )
    app$click(selector = "#gesture_play")
    app$wait_for_js("window.gestureCalls.length === 2")
    app$set_inputs(gesture = "")
    app$wait_for_js("document.getElementById('gesture').value === ''")
    app$click(selector = "#gesture_play")
    app$wait_for_js("window.gestureCalls.length === 3 && window.gestureCalls[2] === 'wave'")
    for (character in c("sela", "neer", "tessa")) {
      app$set_inputs(character = character)
      app$wait_for_js(paste0(studio_live, ".dataset.character === '", character, "'"))
      expected <- jsonlite::toJSON(sort(mascot_gestures(character)$name))
      app$wait_for_js(paste0(
        "JSON.stringify([...document.getElementById('gesture').options].slice(1).map(o=>o.value).sort()) === JSON.stringify(",
        expected,
        ")"
      ))
    }
    expect_false(grepl("gesture", app$get_value(output = "code_ui"), fixed = TRUE))
    expect_false(grepl("gesture", app$get_value(output = "code_server"), fixed = TRUE))
    expect_false(grepl("gesture", app$get_value(output = "code_app"), fixed = TRUE))
    expect_identical(app$get_js("document.querySelectorAll('.pg-window-dots[aria-hidden=true] i').length"), 3L)
    expect_identical(
      app$get_js(
        "new Set([...document.querySelectorAll('.pg-window-dots i')].map(e=>getComputedStyle(e).backgroundColor)).size"
      ),
      3L
    )
    expect_true(app$get_js(
      "document.getElementById('open_search').matches('input[type=search]') && document.getElementById('open_search').placeholder === 'Search functions and arguments'"
    ))
    app$run_js("document.getElementById('open_search').focus()")
    app$wait_for_js(
      "!document.getElementById('studio_search').hidden && document.activeElement.id === 'function_search'"
    )
    app$click(selector = "#close_search")
    expect_true(app$get_js("document.getElementById('studio_search').hidden"))
    app$click(selector = "#open_search")
    app$wait_for_js("!document.getElementById('studio_search').hidden")
  })

  it("opens the Rd overview from the single title row and reserves Help for the inspector", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    app$click(selector = '[data-call-arg=placement]')
    expect_identical(app$get_js("document.getElementById('chip_title').textContent"), "placement =")
    app$click(selector = '[data-chip-overview=placement] button')
    app$wait_for_js("!!document.querySelector('.popover.show .pg-help')")
    expect_match(app$get_js("document.querySelector('.popover.show').textContent"), "Default:", fixed = TRUE)
    expect_true(app$get_js(
      "document.querySelector('.popover.show .pg-help').textContent.trim().length > 0 && document.getElementById('inspector_sidebar').hidden"
    ))
    app$run_js("document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}))")
    app$click(selector = '#chip_help')
    app$wait_for_js(
      "document.getElementById('function_help').dataset.activeArgument === 'placement' && document.getElementById('inspector_tab_help').getAttribute('aria-selected') === 'true' && document.activeElement.id === 'inspector_sidebar'"
    )
  })
})


describe("studio inline help and movable anchors", {
  it("shows function titles on keyboard focus and hover without intercepting clicks", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    browser <- app$get_chromote_session()
    for (id in c("character", "mood", "gesture")) {
      app$run_js(sprintf("document.getElementById('%s').focus()", id))
      app$wait_for_js(sprintf("getComputedStyle(document.getElementById('%s_tooltip')).visibility === 'visible'", id))
      expect_match(
        app$get_js(sprintf("document.getElementById('%s_tooltip').textContent", id)),
        paste0("mascot_", id, "()"),
        fixed = TRUE
      )
      expect_identical(
        app$get_js(sprintf("getComputedStyle(document.getElementById('%s_tooltip')).pointerEvents", id)),
        "none"
      )
      app$run_js("document.activeElement.blur()")
      # At rest the word has no box; the focus ring and tint belong to the focused state.
      expect_true(app$get_js(sprintf(
        "getComputedStyle(document.getElementById('%s')).backgroundColor === 'rgba(0, 0, 0, 0)' && getComputedStyle(document.getElementById('%s')).textDecorationStyle === 'dotted'",
        id,
        id
      )))
      rect <- app$get_js(sprintf(
        "(() => {const r=document.getElementById('%s').getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2};})()",
        id
      ))
      browser$Input$dispatchMouseEvent(type = "mouseMoved", x = rect$x, y = rect$y)
      app$wait_for_js(sprintf("getComputedStyle(document.getElementById('%s_tooltip')).visibility === 'visible'", id))
      browser$Input$dispatchMouseEvent(type = "mouseMoved", x = 0, y = 0)
    }
    expect_identical(app$get_js("document.getElementById('mood_article').textContent"), "in an")
    app$set_inputs(mood = "thinking")
    wait_studio_mood(app, "thinking")
    expect_identical(app$get_js("document.getElementById('mood_article').textContent"), "in a")
    expect_match(app$get_js("document.querySelector('.pg-sentence').textContent"), "mood, with", fixed = TRUE)
  })

  it("drags labels with mouse and touch, moves by keyboard, resets and remembers each character", {
    local_shiny_browser()
    app <- studio_redesign_driver()
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    app$set_inputs(motion_on = FALSE)
    app$click(selector = "#show_anchors")
    pin <- paste0(studio_frame, ".document.querySelector('g[data-anchor]')")
    app$wait_for_js(paste0(pin, "?.querySelector('rect').getAttribute('width') > 0"))
    # Save the actual element and its initial label geometry in the host's coordinates.
    app$run_js(paste0(
      "window.testPin=",
      pin,
      ";window.testBox=testPin.querySelector('rect');window.testOrigin={x:+testBox.getAttribute('x'),y:+testBox.getAttribute('y')};"
    ))
    app$run_js("testBox.focus();testPin.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowRight',bubbles:true}))")
    app$wait_for_js("+testBox.getAttribute('x') === testOrigin.x+2 && !document.getElementById('reset_anchors').hidden")
    app$run_js("testPin.dispatchEvent(new KeyboardEvent('keydown',{key:'Home',bubbles:true}))")
    app$wait_for_js(
      "Math.abs(+testBox.getAttribute('x')-testOrigin.x)<0.5 && document.getElementById('reset_anchors').hidden"
    )
    browser <- app$get_chromote_session()
    # DevTools pointer coordinates belong to the outer page; add the iframe origin.
    point <- app$get_js(
      "(() => {const f=document.getElementById('live_frame').getBoundingClientRect();const r=testBox.getBoundingClientRect();return {x:f.left+r.left+r.width/2,y:f.top+r.top+r.height/2};})()"
    )
    browser$Input$dispatchMouseEvent(type = "mouseMoved", x = point$x, y = point$y)
    browser$Input$dispatchMouseEvent(type = "mousePressed", x = point$x, y = point$y, button = "left", clickCount = 1)
    browser$Input$dispatchMouseEvent(
      type = "mouseMoved",
      x = point$x + 18,
      y = point$y + 12,
      button = "left",
      buttons = 1
    )
    browser$Input$dispatchMouseEvent(
      type = "mouseReleased",
      x = point$x + 18,
      y = point$y + 12,
      button = "left",
      clickCount = 1
    )
    expect_true(app$get_js(paste0(
      "(() => {const w=",
      studio_frame,
      ";const layer=w.document.querySelector('.pg-anchor-overlay');",
      "return !layer.hasAttribute('tabindex') && !layer.querySelector('svg').hasAttribute('tabindex') && !testPin.hasAttribute('tabindex') && testBox.tabIndex===0 && w.getComputedStyle(testPin).outlineStyle==='none' && !testBox.matches(':focus-visible');})()"
    )))
    expect_identical(
      app$get_js(
        "getComputedStyle(document.getElementById('live_frame')).outlineStyle"
      ),
      "none"
    )
    app$wait_for_js(
      "Math.abs(+testBox.getAttribute('x')-testOrigin.x-18)<0.5 && Math.abs(+testBox.getAttribute('y')-testOrigin.y-12)<0.5"
    )
    app$run_js(
      "window.testMoved={x:+testBox.getAttribute('x'),y:+testBox.getAttribute('y'),name:testPin.dataset.anchor};"
    )
    expect_true(app$get_js(
      "+testPin.querySelector('line').getAttribute('x2') === +testBox.getAttribute('x') + +testBox.getAttribute('width')/2 && +testPin.querySelector('line').getAttribute('y2') === +testBox.getAttribute('y')+8"
    ))
    app$set_inputs(character = "sela")
    app$wait_for_js(paste0(studio_live, ".dataset.character === 'sela'"))
    app$set_inputs(character = "tessa")
    app$wait_for_js(paste0(studio_live, ".dataset.character === 'tessa'"))
    app$wait_for_js(paste0(
      "(() => {const g=",
      studio_frame,
      ".document.querySelector('[data-anchor=\"'+testMoved.name+'\"]');const r=g?.querySelector('rect');return r && +r.getAttribute('x')===testMoved.x && +r.getAttribute('y')===testMoved.y;})()"
    ))
    app$click(selector = "#reset_anchors")
    app$wait_for_js("document.getElementById('reset_anchors').hidden")
    app$run_js(paste0(
      "window.testPin=",
      pin,
      ";window.testBox=testPin.querySelector('rect');window.testOrigin={x:+testBox.getAttribute('x'),y:+testBox.getAttribute('y')};"
    ))
    point <- app$get_js(
      "(() => {const f=document.getElementById('live_frame').getBoundingClientRect();const r=testBox.getBoundingClientRect();return {x:f.left+r.left+r.width/2,y:f.top+r.top+r.height/2};})()"
    )
    browser$Input$dispatchTouchEvent(type = "touchStart", touchPoints = list(list(x = point$x, y = point$y)))
    browser$Input$dispatchTouchEvent(type = "touchMove", touchPoints = list(list(x = point$x + 14, y = point$y + 10)))
    browser$Input$dispatchTouchEvent(type = "touchEnd", touchPoints = list())
    app$wait_for_js("+testBox.getAttribute('x') > testOrigin.x+5 && !document.getElementById('reset_anchors').hidden")
    app$run_js(
      "for(let i=0;i<200;i++) testPin.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowRight',shiftKey:true,bubbles:true}));"
    )
    expect_true(app$get_js(paste0(
      "(() => {const r=testBox.getBoundingClientRect();return r.left>=0 && r.right<=",
      studio_frame,
      ".innerWidth && r.top>=0 && r.bottom<=",
      studio_frame,
      ".innerHeight;})()"
    )))
    app$run_js("testPin.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}))")
    app$wait_for_js("document.getElementById('reset_anchors').hidden")
    app$set_inputs(character = "neer")
    app$wait_for_js(
      "!document.getElementById('show_anchors').disabled && document.getElementById('no_anchors').hidden"
    )
    app$wait_for_js(paste0(
      studio_frame,
      ".document.querySelectorAll('.pg-anchor-overlay g[data-anchor]').length === ",
      nrow(mascot_anchors("neer"))
    ))
    expect_setequal(
      app$get_js(paste0(
        studio_frame,
        ".document.querySelector('.pg-anchor-overlay') && [...",
        studio_frame,
        ".document.querySelectorAll('.pg-anchor-overlay g[data-anchor]')].map(g => g.dataset.anchor)"
      )),
      mascot_anchors("neer")$name
    )
    app$set_inputs(character = "tessa")
    app$wait_for_js("!document.getElementById('show_anchors').disabled && document.getElementById('no_anchors').hidden")
  })
})


describe("studio phone layout", {
  it("keeps the sentence and tools separate and wraps the call inside the viewport", {
    local_shiny_browser()
    app <- studio_redesign_driver(width = 390, height = 844)
    withr::defer(app$stop())
    wait_studio_mood(app, "idle")
    app$wait_for_js("document.querySelectorAll('#live_call [data-call-arg]').length > 1")
    expect_true(app$get_js("document.documentElement.scrollWidth <= innerWidth"))
    expect_true(app$get_js(paste0(
      "(() => {const boxes=['.pg-sentence','.pg-search-field','#open_inspector'].map(s=>document.querySelector(s).getBoundingClientRect());",
      "const overlap=(a,b)=>a.left<b.right && a.right>b.left && a.top<b.bottom && a.bottom>b.top;",
      "return boxes.every((a,i)=>a.width>0 && a.height>0 && boxes.slice(i+1).every(b=>!overlap(a,b)));})()"
    )))
    expect_true(app$get_js(
      "(() => {const c=document.getElementById('live_call');return c.scrollWidth<=c.clientWidth && getComputedStyle(c).flexWrap==='wrap';})()"
    ))
    expect_identical(
      app$get_js(
        "[...document.querySelectorAll('.pg-sentence select')].map(s=>s.id).join('|')"
      ),
      "character|palette|mood|gesture"
    )
    # The menu must stay on screen even when its tools row is near the right edge.
    app$click(selector = '#studio_menu summary')
    app$wait_for_js(
      "(() => {const r=document.querySelector('.pg-menu-body').getBoundingClientRect();return r.left>=0 && r.top>=0 && r.right<=innerWidth && r.bottom<=innerHeight;})()"
    )
    app$run_js("document.getElementById('studio_menu').open=false")
    app$click(selector = '[data-call-arg=size]')
    app$wait_for_js("!document.getElementById('chip_editor').hidden")
    expect_true(app$get_js(
      "(() => {const r=document.getElementById('chip_editor').getBoundingClientRect();return r.left>=0 && r.top>=0 && r.right<=innerWidth && r.bottom<=innerHeight;})()"
    ))
    expect_true(app$get_js(
      "(() => {const c=document.getElementById('chip_editor_scroll');return getComputedStyle(c).overflowY==='auto' && [...document.querySelectorAll('#chip_editor button')].filter(b=>b.getClientRects().length).every(b=>b.getBoundingClientRect().height>=40);})()"
    ))
  })
})
