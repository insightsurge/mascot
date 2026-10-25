# The same-origin host runs the real engine in its own viewport and shares one R session.
studio_driver <- function(width = 1280, height = 720, env = parent.frame()) {
  checkmate::assert_number(width, lower = 1)
  checkmate::assert_number(height, lower = 1)
  checkmate::assert_environment(env)
  skip_without_studio_packages("studio")
  app_path <- normalizePath(system.file("examples", "studio", package = "mascot", mustWork = TRUE))
  app <- function() NULL
  body(app) <- substitute(
    {
      library(mascot)
      shiny::shinyAppDir(PATH)
    },
    list(PATH = app_path)
  )
  # The app belongs to the calling test, not to this helper: stop it when that test ends (#445).
  app_driver(app, width = width, height = height, env = env)
}

# Strict lookups for clicks and asserted reads; waits use `wait_studio_js()` (helper-chrome.R).
studio_frame <- "document.getElementById('live_frame').contentWindow"
studio_live <- paste0(studio_frame, ".document.getElementById('helper')")

# Read the engine's own state, including its mounted lifecycle, rather than a studio imitation.
wait_studio_mood <- function(app, mood) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(mood)
  # Generous: the live host starts in its own R process, and the local gate's `tests` mode runs this under covr.
  wait_studio_js(app, sprintf("live.dataset.shownMood === '%s'", mood), timeout = 90000)
}

# Opens a function through the functions overlay, as a visitor does, and waits until only its inspector shows.
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

# Waits until "R code for this function" shows the code of `fn`: the studio marks it busy until the server has stamped
# the text it drew with the function it is for.
wait_studio_code <- function(app, fn) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(fn)
  app$wait_for_js(sprintf(
    "!document.getElementById('code_pin').hasAttribute('aria-busy') && document.getElementById('code_function').dataset.stamp === '%s'",
    fn
  ))
}

# Opens the editor of the call argument `argument` and waits until the server has answered the click. The page opens the
# editor at once and tells the server which argument it shows; the server then sets the editor's controls to the
# call's values. Text typed before that answer would be set back to the call's earlier text, so a test that types waits
# for it. Shiny reports the server busy while it works on the click and idle when it has answered.
open_studio_chip <- function(app, argument) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(argument, min.chars = 1)
  app$run_js(paste(
    "window.studioChipAnswered = false;",
    "$(document).one('shiny:busy', () => $(document).one('shiny:idle', () => { window.studioChipAnswered = true; }));"
  ))
  click_now(app, sprintf("[data-call-arg=%s]", argument))
  app$wait_for_js(sprintf(
    "window.studioChipAnswered && !document.getElementById('chip_editor').hidden && Shiny.shinyapp.$inputValues.chip_argument === '%s'",
    argument
  ))
}

# Holds back what the browser sends for the inputs `names`, to stand in for a server that has not answered yet: the
# page changes at once, and the server's reply (a redrawn panel, a new chip) is missing until `release_studio_inputs()`.
# Setting an input with `app$set_inputs()` waits for the server, so change a held input in the page itself.
hold_studio_inputs <- function(app, names) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_character(names, min.len = 1, any.missing = FALSE, min.chars = 1)
  app$run_js(sprintf(
    paste(
      "(() => { const socket = Shiny.shinyapp.$socket, names = %s;",
      "if (!window.studioHold) {",
      "  const send = socket.send.bind(socket);",
      "  window.studioHold = { names: [], held: [], send,",
      "    release() { this.names = []; for (const message of this.held.splice(0)) send(message); } };",
      "  socket.send = (message) => {",
      "    const hold = window.studioHold;",
      "    if (typeof message === 'string' && hold.names.some((name) => message.includes('\"' + name + '\"'))) hold.held.push(message);",
      "    else send(message);",
      "  };",
      "}",
      "window.studioHold.names = names; })()"
    ),
    jsonlite::toJSON(names)
  ))
}

# Sends what `hold_studio_inputs()` kept, and returns how many messages that was.
release_studio_inputs <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$get_js("(() => { const n = window.studioHold.held.length; window.studioHold.release(); return n; })()")
}

# Holds back what the server sends to the page, to stand in for a slow connection: the page goes on working, and the
# server's replies (a redrawn panel, a control set by updateTextInput()) arrive, in order, when `release_studio_replies()`
# is called. Everything the server has sent since is in `window.studioReplies.held`.
hold_studio_replies <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$run_js(paste(
    "(() => { const shinyApp = Shiny.shinyapp, dispatch = shinyApp.dispatchMessage.bind(shinyApp);",
    "const hold = window.studioReplies = { on: true, held: [], dispatch,",
    "  release() { this.on = false; for (const message of this.held.splice(0)) dispatch(message); } };",
    "shinyApp.dispatchMessage = (message) => (hold.on ? hold.held.push(message) : dispatch(message)); })()"
  ))
}

# Waits until the server has sent a message that `condition` (JavaScript on `reply`, the parsed message) accepts, and
# the page is holding it back (`hold_studio_replies()`).
wait_studio_reply <- function(app, condition) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(condition, min.chars = 1)
  app$wait_for_js(sprintf(
    "window.studioReplies.held.some((message) => { const reply = typeof message === 'string' ? JSON.parse(message) : message; return %s; })",
    condition
  ))
}

# Types `value` into the text control `id`, as a visitor does: the control changes at once, Shiny sends it a moment later.
type_studio_text <- function(app, id, value) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(id, min.chars = 1)
  checkmate::assert_string(value)
  app$run_js(sprintf(
    "{ const field = document.getElementById('%s'); field.value = %s; field.dispatchEvent(new Event('input', { bubbles: true })); }",
    id,
    jsonlite::toJSON(value, auto_unbox = TRUE)
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

describe("the studio's live host", {
  it("starts an isolated live host and updates mood through the existing control", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    expect_true(nzchar(app$get_js(paste0(studio_live, ".querySelector('.mascot-status').textContent.trim()"))))
    app$set_inputs(mood = "happy")
    wait_studio_mood(app, "happy")
    expect_match(app$get_value(output = "code_ui"), 'mood = "happy"', fixed = TRUE)
    expect_true(app$get_js("document.getElementById('inspector_sidebar').hidden"))
    expect_true(app$get_js("document.getElementById('studio_canvas').clientHeight > 200"))
  })
})

describe("studio overlays and live controls", {
  it("counts functions, ranks names before titles and arguments, and limits badges", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    app$click(selector = "#open_search")
    expect_identical(
      app$get_js("document.getElementById('search_count').textContent"),
      paste(length(getNamespaceExports("mascot")), "functions")
    )
    app$run_js(
      "window.queryStudio = q => {const input=document.getElementById('function_search'); input.value=q; input.dispatchEvent(new Event('input',{bubbles:true}));}; queryStudio('update_mascot')"
    )
    expect_identical(app$get_js("document.querySelectorAll('#search_results [role=option]:not([hidden])').length"), 1L)
    expect_identical(app$get_js("document.getElementById('search_count').textContent"), "1 function")
    expect_true(app$get_js(
      "[...document.querySelectorAll('#search_results [role=option]')].every(r=>r.hidden ? r.getClientRects().length===0 : r.getClientRects().length>0)"
    ))
    app$run_js(
      "document.getElementById('function_search').dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}))"
    )
    app$wait_for_js(
      "!document.getElementById('inspector_sidebar').hidden && !document.querySelector('[data-function=update_mascot]').hidden"
    )
    expect_identical(app$get_js("document.activeElement.id"), "inspector_sidebar")
    app$click(selector = "#close_inspector")
    app$click(selector = "#open_search")
    app$run_js("queryStudio('character')")
    expect_true(app$get_js(paste0(
      "(() => {const rows=[...document.querySelectorAll('#search_results [role=option]:not([hidden])')];",
      "const ranks=rows.map(r=>r.dataset.searchFunction.includes('character')?0:r.dataset.searchTitle.toLowerCase().includes('character')?1:2);",
      "return ranks.includes(0)&&ranks.includes(1)&&ranks.includes(2)&&ranks.every((r,i)=>!i||r>=ranks[i-1]) && ",
      "rows.every(r=>new Set(rows.map(x=>x.dataset.searchFunction)).size===rows.length) && ",
      "[...document.querySelectorAll('#search_results .pg-search-group')].every(h=>h.textContent.trim().length>0);})()"
    )))
    app$run_js("queryStudio('mood')")
    expect_true(app$get_js(
      "!document.getElementById('search_update_mascot_mood').hidden && !document.getElementById('search_mascot_motion_settings_mood_change').hidden"
    ))
    app$run_js(
      "document.getElementById('function_search').dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowDown',bubbles:true}))"
    )
    expect_identical(
      app$get_js("document.getElementById('function_search').getAttribute('aria-activedescendant')"),
      app$get_js("document.querySelectorAll('#search_results [role=option]:not([hidden])')[1].id")
    )
    app$run_js("queryStudio('s')")
    expect_true(app$get_js(paste0(
      "(() => {const row=document.getElementById('search_mascot_motion_settings_function');",
      "const n=[...row.querySelectorAll('[data-search-argument]')].filter(b=>b.dataset.searchArgument.includes('s')).length;",
      "return n>4 && row.querySelectorAll('button:not([hidden])').length===4 && row.querySelector('.pg-search-more').textContent==='+'+(n-4);})()"
    )))
    app$run_js("queryStudio('no_such_function_or_argument')")
    expect_identical(app$get_js("document.getElementById('search_count').textContent"), "0 functions")
    expect_null(app$get_js("document.getElementById('function_search').getAttribute('aria-activedescendant')"))
    app$run_js("queryStudio('dark')")
    app$click(selector = "#search_mascot_theme_dark")
    app$wait_for_js(
      "!document.querySelector('[data-function=mascot_theme]').hidden && document.querySelector('[data-function=mascot_theme] [data-argument=dark]').contains(document.activeElement)"
    )
    expect_true(app$get_js(
      "document.activeElement.getClientRects().length>0 && !!document.activeElement.closest('.tab-pane.active')"
    ))
    app$click(selector = "#close_inspector")
    app$click(selector = "#open_search")
    app$run_js("queryStudio('tooltip')")
    app$click(selector = "#search_mascot_action_tooltip")
    app$wait_for_js(
      "document.getElementById('action_tooltip').getClientRects().length>0 && document.getElementById('action_tooltip').contains(document.activeElement)"
    )
  })

  it("keeps search modal, routes argument results, and moves one mounted chip editor", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    app$click(selector = "#all_functions")
    expect_true(app$get_js("!document.getElementById('function_flyout').hidden"))
    app$click(selector = "#open_search")
    app$run_js(
      "const q = document.getElementById('function_search'); q.value = 'duration'; q.dispatchEvent(new Event('input', {bubbles:true}));"
    )
    app$wait_for_js(
      "document.getElementById('function_search').getAttribute('aria-activedescendant') === 'search_mascot_bubble_function'"
    )
    expect_true(app$get_js("document.getElementById('studio_centre').inert"))
    app$get_chromote_session()$Input$dispatchKeyEvent(
      type = "keyDown",
      key = "Tab",
      code = "Tab",
      windowsVirtualKeyCode = 9L
    )
    app$get_chromote_session()$Input$dispatchKeyEvent(
      type = "keyUp",
      key = "Tab",
      code = "Tab",
      windowsVirtualKeyCode = 9L
    )
    expect_identical(app$get_js("document.activeElement.id"), "search_mascot_bubble_duration")
    app$get_chromote_session()$Input$dispatchKeyEvent(
      type = "keyDown",
      key = "Enter",
      code = "Enter",
      windowsVirtualKeyCode = 13L
    )
    app$get_chromote_session()$Input$dispatchKeyEvent(
      type = "keyUp",
      key = "Enter",
      code = "Enter",
      windowsVirtualKeyCode = 13L
    )
    app$wait_for_js(
      "!document.getElementById('inspector_sidebar').hidden && !document.querySelector('[data-function=mascot_bubble]').hidden"
    )
    app$wait_for_js(
      "document.querySelector('[data-function=mascot_bubble] [data-argument=duration]').contains(document.activeElement) && document.activeElement.matches('.irs-handle')"
    )
    expect_identical(
      app$get_js("document.getElementById('inspector_view_controls').getAttribute('aria-pressed')"),
      "true"
    )
    app$click(selector = "#inspector_tab_help")
    expect_identical(app$get_js("document.getElementById('inspector_view_help').getAttribute('aria-pressed')"), "true")
    wait_studio_panel(app, "help", "mascot_bubble")
    expect_match(app$get_js("document.getElementById('function_help').textContent"), "Examples", fixed = TRUE)
    app$click(selector = "#inspector_tab_guide")
    wait_studio_panel(app, "guide", "mascot_bubble")
    expect_match(app$get_js("document.getElementById('guide').textContent"), "Inf", fixed = TRUE)
    app$run_js("document.dispatchEvent(new KeyboardEvent('keydown', {key:'Escape', bubbles:true}));")
    expect_true(app$get_js("document.getElementById('inspector_sidebar').hidden"))
    expect_identical(app$get_js("document.activeElement.id"), "inspector_view_guide")
    # The pinned function list did not swallow Escape from the inspector.
    app$run_js("window.studioStatus = document.getElementById('status_text')")
    click_now(app, '[data-call-arg=status]')
    expect_true(app$get_js("document.getElementById('chip_editor_body').contains(window.studioStatus)"))
    app$set_inputs(status_text = "Checking a draft")
    wait_studio_js(
      app,
      sprintf("%s.querySelector('.mascot-status').textContent === 'Checking a draft'", studio_live_wait)
    )
    app$click(selector = "#chip_inspector")
    expect_true(app$get_js(
      "document.getElementById('studio_inspector').contains(window.studioStatus) && document.querySelectorAll('#status_text').length === 1"
    ))
    app$click(selector = "#close_inspector")
    # The dock's Copy copies the settings code, with the status just set
    stub_studio_clipboard(app)
    click_now(app, "#studio_dock [data-copy=code_ui]")
    app$wait_for_js("window.copied !== null")
    expect_match(app$get_js("window.copied"), 'status = "Checking a draft"', fixed = TRUE)
    app$wait_for_js("document.querySelector('#studio_dock [data-copy=code_ui]').textContent === 'Copied'")
  })
  it("preserves bubbles, motion, placement, actions, menus, gestures, code and host modes", {
    local_shiny_browser()
    app <- studio_driver(width = 1366, height = 768)
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
    wait_studio_js(app, sprintf("%s.querySelector('.mascot-bubble strong')?.textContent === 'Saved'", studio_live_wait))
    expect_match(app$get_value(output = "code_ui"), "duration = Inf", fixed = TRUE)
    expect_match(app$get_value(output = "code_ui"), "closable = FALSE", fixed = TRUE)
    app$click(selector = "#bubble_clear")
    app$wait_for_js(sprintf("!%s.bubble", state))
    app$set_inputs(idle = "false", mood_change = "false", gestures = "false", messages = "bubble")
    app$wait_for_js(sprintf("%s.motion.idle === false && %s.motion.gestures === false", state, state))
    app$set_inputs(position = "bottom-right", drag = "snap", small_mode = "number", small_px = 72)
    wait_studio_js(app, sprintf("%s.dataset.floating === 'true'", studio_live_wait))
    app$click(selector = "#phone_width")
    wait_studio_js(
      app,
      sprintf(
        "%s.innerWidth <= 390 && %s.querySelector('.mascot-canvas').getBoundingClientRect().width === 72",
        studio_frame_wait,
        studio_live_wait
      )
    )
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
    wait_studio_js(app, sprintf("%s.document.querySelector('[role=menuitem]') !== null", studio_frame_wait))
    app$run_js(sprintf("%s.document.querySelector('[role=menuitem]').click()", studio_frame))
    app$wait_for_js(
      "document.getElementById('host_event').textContent.includes('finish') || document.getElementById('code_last').textContent.includes('You chose')"
    )
    app$click(selector = "#close_inspector")
    app$set_inputs(host_mode = "preview")
    wait_studio_preview(app)
    expect_false(app$get_js("document.querySelector('[data-canvas=preview]').hidden"))
    expect_match(app$get_value(output = "code_preview"), "mascot_preview(", fixed = TRUE)
    app$run_js("document.getElementById('more_examples').click()")
    app$wait_for_js(
      "document.querySelector('[data-canvas=examples]').hidden === false && document.getElementById('example_code') !== null"
    )
    app$set_inputs(example_name = "form-check")
    # The studio's own example (shown first) also contains mascot(, so wait for the call naming the new one
    app$wait_for_js("document.getElementById('example_call').textContent.includes('\"form-check\"')")
    expect_match(app$get_js("document.getElementById('example_code').textContent"), "mascot(", fixed = TRUE)
    app$click(selector = "#back_to_studio")
    app$set_inputs(host_mode = "mascot")
    expect_true(app$get_js("document.querySelector('[data-canvas=preview]').hidden"))
    select("mascot_theme")
    app$set_inputs(theme_source = "mascot", theme_mode = "dark")
    app$wait_for_js(sprintf("%s.mode === 'dark'", state))
  })
  it("keeps laptop overlays floating and the phone inspector modal with viewport-clamped chips", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    browser <- app$get_chromote_session()
    for (size in list(
      c(1280L, 720L),
      c(1366L, 768L),
      c(1440L, 900L),
      c(360L, 720L),
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
      # Click in the page: the node can be replaced between Chrome resolving it and clicking it.
      app$run_js(sprintf(
        "document.querySelector('%s').click()",
        if (size[1] <= 860) "#open_inspector" else "#inspector_view_controls"
      ))
      expect_equal(app$get_js("document.getElementById('studio_centre').getBoundingClientRect().width"), before)
      expect_true(app$get_js("document.documentElement.scrollWidth <= window.innerWidth"))
      expect_identical(
        app$get_js("document.getElementById('inspector_sidebar').getAttribute('aria-modal')"),
        if (size[1] <= 860) "true" else NULL
      )
      app$click(selector = "#close_inspector")
      click_now(app, '[data-call-arg=size]')
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

describe("studio behaviour for each function", {
  it("selects every function and preserves mounted controls, help, guides and code views", {
    local_shiny_browser()
    app <- studio_driver(width = 1440, height = 900)
    wait_studio_mood(app, "idle")
    expect_identical(app$get_js(paste0(studio_frame, ".document.querySelectorAll('.mascot').length")), 1L)
    for (output in c("code_ui", "code_server", "code_app")) {
      expect_match(app$get_value(output = output), 'placement = "inline"', fixed = TRUE)
    }
    app$run_js("window.originalStatus = document.getElementById('status_text')")
    for (fn in getNamespaceExports("mascot")) {
      studio_select_function(app, fn)
      app$click(selector = "#inspector_tab_help")
      wait_studio_panel(app, "help", fn)
      app$click(selector = "#inspector_tab_guide")
      wait_studio_panel(app, "guide", fn)
      expect_identical(
        app$get_js(
          "document.querySelectorAll('#guide input, #guide select, #guide textarea, #guide [data-event]:not([data-event=palette_swap]):not([data-event=menu_long_status]):not([data-event=select_function])').length"
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
    wait_studio_js(
      app,
      sprintf("%s.querySelector('.mascot-status').textContent === 'Checking 120 rows'", studio_live_wait)
    )
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
    app <- studio_driver()
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
    wait_studio_js(app, sprintf("!!%s.querySelector('.mascot-bubble table')", studio_live_wait))
    app$set_inputs(
      bubble_text = '<p class="notice">Saved</p>',
      bubble_html = TRUE,
      bubble_forever = TRUE,
      bubble_closable = FALSE
    )
    app$click(selector = "#bubble_show")
    wait_studio_js(
      app,
      sprintf("%s.querySelector('.mascot-bubble .notice')?.textContent === 'Saved'", studio_live_wait)
    )
    code <- app$get_value(output = "code_ui")
    expect_type(parse(text = code), "expression")
    expect_match(code, 'r"(', fixed = TRUE)
    expect_false(grepl('\\"', code, fixed = TRUE))
    expect_match(code, "duration = Inf", fixed = TRUE)
    expect_match(code, "closable = FALSE", fixed = TRUE)
    app$click(selector = "#bubble_clear")
    wait_studio_js(app, sprintf("!%s.mascot.host.state(%s).bubble", studio_frame_wait, studio_live_wait))
  })

  it("reports snap and free drops, minimise and restore, and keeps percentage and phone sizes", {
    local_shiny_browser()
    app <- studio_driver()
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
    # Dispatch to the iframe canvas in its own viewport coordinates, as the engine receives them. The pointer goes to
    # the frame's top-left corner, wherever the canvas starts, so the mascot ends up clamped in that corner.
    drop <- function() {
      app$run_js(sprintf(
        "(() => { const w = %s, c = %s.querySelector('canvas'), r = c.getBoundingClientRect();
          const press = (type, x, y) => c.dispatchEvent(new w.PointerEvent(type, {bubbles:true, cancelable:true, pointerId:1, button:0, isPrimary:true, clientX:x, clientY:y}));
          press('pointerdown', r.left+r.width/2, r.top+r.height/2); press('pointermove', 1, 1); press('pointerup', 1, 1); })()",
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
    wait_studio_js(
      app,
      sprintf(
        "%s.innerWidth <= 390 && %s.querySelector('.mascot-canvas').getBoundingClientRect().width === 72",
        studio_frame_wait,
        studio_live_wait
      )
    )
  })

  it("changes light and dark roles, CSS variables, contrast results, resets and the family listing", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    state <- paste0(studio_frame, ".mascot.host.state(", studio_live, ")")
    studio_select_function(app, "mascot_theme")
    app$set_inputs(theme_source = "mascot", theme_mode = "light")
    studio_colour(app, "colours-light_body", "#1f6feb")
    app$wait_for_js(sprintf("%s.colours.body?.toLowerCase() === '#1f6feb'", state))
    studio_colour(app, "colours-light_body_highlight", "#abcdef")
    app$wait_for_js(sprintf("%s.colours.body_highlight?.toLowerCase() === '#abcdef'", state))
    app$wait_for_js(
      "document.querySelector('.pg-resolved[data-mode=light][data-role=body_highlight]').style.background === 'rgb(171, 205, 239)'"
    )
    app$run_js(
      "document.querySelector('[data-event=\"colours-reset_colour\"][data-value=\"light:body_highlight\"]').click()"
    )
    # The reset reaches the picker itself (Shiny adds the module's prefix to the input message), and the code in the
    # same answer. The picker is the positive sign of the answer; code that lacks the colour is true before it.
    highlight <- tolower(mascot_colour_roles("tessa")$colour[mascot_colour_roles("tessa")$role == "body_highlight"])
    app$wait_for_js(sprintf(
      "document.getElementById('colours-light_body_highlight').value === '%s' && !document.getElementById('code_ui').textContent.includes('#abcdef')",
      highlight
    ))
    studio_colour(app, "colours-dark_body", "#224466")
    app$set_inputs(theme_mode = "dark")
    app$wait_for_js(sprintf("%s.mode === 'dark' && %s.colours.body?.toLowerCase() === '#224466'", state, state))
    app$set_inputs(`colours-css_roles` = "body")
    studio_colour(app, "colours-css_value", "#663399")
    app$wait_for_js(sprintf("%s.colours.body?.toLowerCase() === '#663399'", state))
    expect_match(app$get_value(output = "code_ui"), "--studio-accent", fixed = TRUE)
    app$set_inputs(`colours-css_roles` = character(), theme_mode = "light")
    studio_colour(app, "colours-light_body", "#f8f9fa")
    app$wait_for_js(sprintf("%s.colours.body?.toLowerCase() === '#f8f9fa'", state))
    click_studio_busy(app, "contrast_check")
    expect_match(app$get_js("document.getElementById('contrast').textContent"), "hard to see", fixed = TRUE)
    studio_colour(app, "colours-light_body", "#1f6feb")
    app$wait_for_js("document.getElementById('contrast').textContent.includes('settings changed since the last check')")
    # The reset reaches the picker and the code in one answer; the picker is the positive sign of it
    body <- tolower(mascot_colour_roles("tessa")$colour[mascot_colour_roles("tessa")$role == "body"])
    app$run_js("document.querySelector('[data-event=\"colours-reset_mode\"][data-value=light]').click()")
    app$wait_for_js(sprintf("document.getElementById('colours-light_body').value === '%s'", body))
    expect_false(grepl("#1f6feb", app$get_value(output = "code_ui"), fixed = TRUE))
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
    expect_identical(app$get_value(input = "character"), "tessa")
    app$click(selector = "#inspector_tab_guide")
    wait_studio_panel(app, "guide", "mascot_moods")
    expect_match(app$get_js("document.getElementById('guide').textContent"), "Tessa's", fixed = TRUE)
  })

  it("marks Help and Guide busy while they show an earlier function's page", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    studio_select_function(app, "mascot_size")
    app$click(selector = "#inspector_tab_guide")
    wait_studio_panel(app, "guide", "mascot_size")
    if (isTRUE(app$get_js("document.getElementById('function_flyout').hidden"))) {
      app$click(selector = "#all_functions")
    }
    # When another function is picked, both panels still hold the pages of mascot_size, and say so at once
    state <- app$get_js(paste(
      "(() => { document.querySelector('.pg-index-link[data-value=\"mascot_placement\"]').click();",
      "return ['inspector_help', 'inspector_guide'].map((id) => document.getElementById(id).getAttribute('aria-busy'))",
      ".concat(getComputedStyle(document.querySelector('#guide > .card')).opacity); })()"
    ))
    expect_identical(unlist(state), c("true", "true", "0.5"))
    # Then each comes back once the server has drawn the page of the new function
    app$click(selector = "#inspector_tab_help")
    wait_studio_panel(app, "help", "mascot_placement")
    app$click(selector = "#inspector_tab_guide")
    wait_studio_panel(app, "guide", "mascot_placement")
    expect_identical(app$get_js("getComputedStyle(document.querySelector('#guide > .card')).opacity"), "1")
  })
  it("tells Shiny the Guide is shown even when Shiny's own visibility check misses the switch", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    studio_select_function(app, "mascot_size")
    app$click(selector = "#inspector_tab_guide")
    wait_studio_panel(app, "guide", "mascot_size")
    # Given the server knows the Guide is hidden, and Shiny's observers for it no longer report changes
    app$click(selector = "#inspector_tab_controls")
    app$wait_for_js("Shiny.shinyapp.$inputValues['.clientdata_output_guide_hidden'] === true")
    app$run_js(paste(
      "for (const key of ['shiny-resize-observer', 'shiny-intersection-observer'])",
      "$('#guide').data(key)?.disconnect();"
    ))
    # When another function is picked, its Help is read until the server has nothing left to draw, and its Guide opened
    studio_select_function(app, "mascot_placement")
    app$click(selector = "#inspector_tab_help")
    wait_studio_panel(app, "help", "mascot_placement")
    app$wait_for_idle()
    app$click(selector = "#inspector_tab_guide")
    # Then the Guide is drawn for it
    wait_studio_panel(app, "guide", "mascot_placement")
    expect_false(app$get_js("Shiny.shinyapp.$inputValues['.clientdata_output_guide_hidden']"))
  })
  it("marks the Guide busy while it shows another character's page", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    studio_select_function(app, "mascot_moods")
    app$click(selector = "#inspector_tab_guide")
    wait_studio_panel(app, "guide", "mascot_moods")
    # Given the server has not answered the change of character yet
    hold_studio_inputs(app, "character")
    # When another character is chosen, the page still holds the Guide of the first, and says so at once
    state <- app$get_js(paste(
      "(() => { const select = document.getElementById('character'); select.value = 'sela'; $(select).trigger('change');",
      "return [document.getElementById('inspector_guide').getAttribute('aria-busy'),",
      "getComputedStyle(document.querySelector('#guide > .card')).opacity]; })()"
    ))
    expect_identical(unlist(state), c("true", "0.5"))
    # Then it comes back once the server has drawn the Guide for the new character
    expect_gte(release_studio_inputs(app), 1L)
    wait_studio_panel(app, "guide", "mascot_moods", character = "sela")
    expect_match(app$get_js("document.getElementById('guide').textContent"), "Sela's", fixed = TRUE)
    expect_identical(app$get_js("getComputedStyle(document.querySelector('#guide > .card')).opacity"), "1")
  })
  it("marks the code of the function busy while it shows the code of another function", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    studio_select_function(app, "mascot_moods")
    wait_studio_code(app, "mascot_moods")
    expect_match(app$get_js("document.getElementById('code_function').textContent"), "mascot_moods(", fixed = TRUE)
    # Given the server has not answered the change of function yet
    hold_studio_inputs(app, "select_function")
    # When another function is picked, the code of the first is still there, and says it is busy at once
    studio_select_function(app, "mascot_gestures")
    expect_identical(app$get_js("document.getElementById('code_pin').getAttribute('aria-busy')"), "true")
    expect_identical(app$get_js("getComputedStyle(document.querySelector('#code_pin .pg-code')).opacity"), "0.5")
    expect_match(app$get_js("document.getElementById('code_function').textContent"), "mascot_moods(", fixed = TRUE)
    # Then it comes back once the code of the new function is drawn
    expect_gte(release_studio_inputs(app), 1L)
    wait_studio_code(app, "mascot_gestures")
    expect_match(app$get_js("document.getElementById('code_function').textContent"), "mascot_gestures(", fixed = TRUE)
    expect_identical(app$get_js("getComputedStyle(document.querySelector('#code_pin .pg-code')).opacity"), "1")
  })
  it("clears the argument marker of the Help panel when another function or whole-function help opens", {
    local_shiny_browser()
    app <- studio_driver(width = 1440, height = 900)
    wait_studio_mood(app, "idle")
    marker <- "document.getElementById('function_help').dataset.activeArgument || ''"
    open_argument_help <- function() {
      click_now(app, "[data-call-arg=size]")
      app$click(selector = "#chip_inspector")
      app$click(selector = "[data-function=mascot_size] [data-argument=small_screen] .pg-arg-chip")
      app$wait_for_js("!!document.querySelector('.popover.show [data-argument-help=small_screen]')")
      app$click(selector = ".popover.show [data-argument-help=small_screen]")
      app$wait_for_js(paste0(
        marker,
        " === 'small_screen' && !!document.querySelector('#function_help [data-guide-function=mascot_size]')"
      ))
    }
    # Given the Help panel was opened at an argument of mascot_size()
    open_argument_help()
    # When another function is picked, the marker goes with it
    studio_select_function(app, "mascot_placement")
    expect_identical(app$get_js(marker), "")
    app$click(selector = "#inspector_tab_help")
    wait_studio_panel(app, "help", "mascot_placement")
    # And when the help of the whole function opens
    studio_select_function(app, "mascot_size")
    open_argument_help()
    click_now(app, "[data-call-arg=size]")
    app$click(selector = "#chip_help")
    wait_studio_panel(app, "help", "mascot_size")
    expect_identical(app$get_js(marker), "")
  })
  it("opens argument help once the Help page of its function is drawn", {
    local_shiny_browser()
    app <- studio_driver(width = 1440, height = 900)
    wait_studio_mood(app, "idle")
    studio_select_function(app, "mascot_placement")
    app$click(selector = "#inspector_tab_help")
    wait_studio_panel(app, "help", "mascot_placement")
    # Given the server has not answered the change of function yet
    hold_studio_inputs(app, "select_function")
    # When the help of an argument of mascot_size() is asked for, as a link in an argument's popover does
    app$run_js(paste(
      "(() => { const link = document.createElement('button'); link.dataset.helpFunction = 'mascot_size';",
      "link.dataset.argumentHelp = 'small_screen'; document.body.append(link); link.click(); link.remove(); })()"
    ))
    # Then no argument is marked while the page of mascot_placement() is still the one shown
    expect_identical(app$get_js("document.getElementById('inspector_help').getAttribute('aria-busy')"), "true")
    expect_identical(app$get_js("document.getElementById('function_help').dataset.activeArgument || ''"), "")
    # And the argument is marked once the page of mascot_size() is drawn
    expect_gte(release_studio_inputs(app), 1L)
    wait_studio_panel(app, "help", "mascot_size")
    app$wait_for_js("document.getElementById('function_help').dataset.activeArgument === 'small_screen'")
  })
  it("runs combined updates, invalid calls and delayed success and failure beside an activity log", {
    local_shiny_browser()
    app <- studio_driver()
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
    # The switch starts off, and shinytest2 waits 30 s for an output to change when an input is set to its own value
    expect_false(app$get_value(input = "task_fail"))
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
    wait_studio_js(
      app,
      sprintf(
        "%s.querySelector('.mascot-bubble')?.textContent.includes('Three rows have no batch date.')",
        studio_live_wait
      )
    )
    app$wait_for_js(
      "document.getElementById('status_text').value === 'Check failed' && !document.getElementById('task_run').disabled"
    )
    expect_match(app$get_value(output = "code_last"), "session = session", fixed = TRUE)
    studio_select_function(app, "mascot_popup_menu")
    app$set_inputs(menu_items = "no equals sign")
    app$set_inputs(menu_on = FALSE)
    wait_studio_js(app, sprintf("%s.mascot.host.state(%s).click.type === 'none'", studio_frame_wait, studio_live_wait))
    expect_false(grepl("observeEvent(input$helper_menu", app$get_value(output = "code_app"), fixed = TRUE))
    app$click(selector = "#open_code")
    app$click(selector = "#log_clear")
    app$wait_for_js(
      "document.getElementById('log').textContent.includes('Nothing yet.') && document.getElementById('wiring_log').textContent.includes('Nothing yet.')"
    )
  })
})

describe("studio actions, menus and generated preview", {
  it("honours labels, tooltips, disabled actions, menu direction and real click and choice events", {
    local_shiny_browser()
    app <- studio_driver()
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
    # The server's answer is the click counted ("1 click") and the wave it sent; the text before any click mentions clicks too
    app$wait_for_js(
      "document.getElementById('click_last').textContent === '1 click' && document.getElementById('code_last').textContent.includes('wave')"
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
    wait_studio_js(
      app,
      sprintf(
        "!!%s.document.querySelector('.mascot-menu:not([hidden]):not(.mascot-motion-copy) [data-item-id=finish]')",
        studio_frame_wait
      )
    )
    app$run_js(sprintf(
      "%s.document.querySelector('.mascot-menu:not([hidden]):not(.mascot-motion-copy) [data-item-id=finish]').click()",
      studio_frame
    ))
    wait_studio_js(
      app,
      sprintf("%s.querySelector('.mascot-bubble')?.textContent.includes('Finish review')", studio_live_wait)
    )
    expect_false(grepl("You chose", app$get_value(output = "code_ui"), fixed = TRUE))
    app$run_js(sprintf("%s.querySelector('.mascot-button').click()", studio_live))
    wait_studio_js(
      app,
      sprintf(
        "!!%s.document.querySelector('.mascot-menu:not([hidden]):not(.mascot-motion-copy) [data-item-id=about]')",
        studio_frame_wait
      )
    )
    # Bootstrap ignores a dismissal while the modal is still fading in: wait for its "shown" event before closing it
    app$run_js(
      "window.modalShown = false; document.addEventListener('shown.bs.modal', () => { window.modalShown = true; }, { once: true });"
    )
    app$run_js(sprintf(
      "%s.document.querySelector('.mascot-menu:not([hidden]):not(.mascot-motion-copy) [data-item-id=about]').click()",
      studio_frame
    ))
    app$wait_for_js("window.modalShown")
    expect_identical(app$get_js("document.querySelector('.modal.show .modal-title')?.textContent"), "About this studio")
    click_now(app, ".modal.show [data-bs-dismiss=modal]")
    # Bootstrap takes "modal-open" off the page once the modal has gone
    app$wait_for_js("!document.querySelector('.modal.show') && !document.body.classList.contains('modal-open')")
  })

  it("rebuilds preview code from controls, returns to the mounted host and opens standalone examples", {
    local_shiny_browser()
    app <- studio_driver(width = 1440, height = 900)
    wait_studio_mood(app, "idle")
    app$run_js(sprintf("window.originalHost = %s", studio_live))
    studio_select_function(app, "mascot_preview")
    wait_studio_preview(app)
    expect_true(app$get_js("document.querySelector('[data-canvas=mascot]').hidden"))
    studio_colour(app, "preview_body", "#1f6feb")
    studio_colour(app, "preview_rim", "#966600")
    app$set_inputs(
      preview_theme_source = "custom",
      preview_width = "phone"
    )
    app$wait_for_js(
      "document.getElementById('code_preview').textContent.includes('body = \"#1f6feb\"')"
    )
    app$wait_for_js("document.querySelector('iframe.pg-preview').classList.contains('is-phone')")
    expect_false(grepl("click =", app$get_value(output = "code_preview"), fixed = TRUE))
    app$run_js(
      "window.sawBuilding = false; window.buildObserver = new MutationObserver(() => {if (document.querySelector('.pg-building')) window.sawBuilding = true;}); window.buildObserver.observe(document.body, {childList:true, subtree:true});"
    )
    app$set_inputs(preview_status = "Auto build status")
    app$wait_for_js("document.getElementById('code_preview').textContent.includes('status = \"Auto build status\"')")
    wait_studio_preview(app)
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

describe("studio function descriptions in the flyout", {
  it("only shows truncated descriptions on hover and closes the previous tooltip", {
    local_shiny_browser()
    app <- studio_driver()
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
  it("keeps keyboard focus on a chip when the server renders the call again", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    # Given keyboard focus on the status chip
    app$run_js("window.oldChip = document.querySelector('[data-call-arg=status]'); oldChip.focus();")
    # When a change elsewhere makes the server render the call again
    app$set_inputs(status_text = "Saved")
    app$wait_for_js(
      "document.querySelector('[data-call-arg=status] .pg-chip-value').textContent.includes('Saved')"
    )
    # Then the new status chip has the focus
    expect_true(app$get_js(
      "!document.body.contains(oldChip) && document.activeElement.dataset.callArg === 'status'"
    ))
  })
  it("edits one value with an argument-local code style and restores the same mounted inputs", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    app$run_js(
      "window.originalSize = document.getElementById('size_px'); window.originalStatus = document.getElementById('status_text')"
    )
    click_now(app, '[data-call-arg=size]')
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
      click_now(app, sprintf('[data-call-arg=%s]', arg))
      app$wait_for_js(sprintf(
        "!document.getElementById('chip_editor').hidden && document.getElementById('chip_title').textContent.startsWith('%s')",
        arg
      ))
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
    click_now(app, '[data-call-arg=status]')
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
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    click_now(app, '[data-call-arg=click]')
    expect_identical(app$get_js("document.getElementById('chip_inspector').textContent"), "Advanced controls")
    expect_identical(app$get_value(input = "click_type"), "menu")
    app$click(selector = "#chip_inspector")
    app$wait_for_js(
      "document.activeElement.id === 'inspector_sidebar' && !document.querySelector('[data-function=mascot_popup_menu]').hidden && document.getElementById('menu_items').getClientRects().length > 0"
    )
    click_now(app, '[data-call-arg=click]')
    app$set_inputs(click_type = "action")
    app$click(selector = "#chip_inspector")
    app$wait_for_js("!document.querySelector('[data-function=mascot_action]').hidden")
    click_now(app, '[data-call-arg=theme]')
    app$click(selector = "#chip_inspector")
    app$wait_for_js(
      "document.querySelector('#theme_mode input:checked') && document.getElementById('theme_mode').getClientRects().length > 0"
    )
    click_now(app, '[data-call-arg=status]')
    app$click(selector = "#chip_help")
    wait_studio_panel(app, "help", "mascot_status")
    app$wait_for_js("document.activeElement.id === 'inspector_sidebar'")
    # The chip's Help opens the helper's own help page, not mascot()'s.
    expect_true(app$get_js(
      "document.querySelector('#function_help [data-guide-function=mascot_status]').textContent.trim().length > 0"
    ))
    click_now(app, '[data-call-arg=bubble]')
    app$click(selector = "#chip_help")
    wait_studio_panel(app, "help", "mascot_bubble")
    app$wait_for_js("document.activeElement.id === 'inspector_sidebar'")
    app$click(selector = "#close_inspector")
    click_now(app, '[data-call-arg=size]')
    app$click(selector = "#chip_inspector")
    app$click(selector = '[data-function=mascot_size] [data-argument=small_screen] .pg-arg-chip')
    app$wait_for_js("!!document.querySelector('.popover.show [data-argument-help=small_screen]')")
    app$click(selector = '.popover.show [data-argument-help=small_screen]')
    wait_studio_panel(app, "help", "mascot_size")
    app$wait_for_js(
      "document.activeElement.id === 'inspector_sidebar' && document.getElementById('function_help').dataset.activeArgument === 'small_screen'"
    )
  })
})

describe("the click chip editor and the Click control", {
  it("opens the helper the Click control names, before the server has drawn the chip again", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    title <- "document.getElementById('inspector_title').textContent"
    pick_click <- function(kind) {
      app$run_js(sprintf(
        "(() => { const s = document.getElementById('click_type'); if (s.selectize) s.selectize.setValue('%s'); else { s.value = '%s'; $(s).trigger('change'); } })()",
        kind,
        kind
      ))
    }
    # Given the click chip editor is open on the menu, and the server has not answered a change of the Click control
    click_now(app, "[data-call-arg=click]")
    app$wait_for_js("!document.getElementById('chip_editor').hidden")
    hold_studio_inputs(app, "click_type")
    # When the control is set to an action, the chip editor opens that helper's controls and help
    pick_click("action")
    click_now(app, "#chip_inspector")
    expect_identical(app$get_js(title), "mascot_action()")
    click_now(app, "[data-call-arg=click]")
    pick_click("menu")
    click_now(app, "#chip_help")
    expect_identical(app$get_js(title), "mascot_popup_menu()")
    wait_studio_panel(app, "help", "mascot_popup_menu")
    # And with no click, the empty action helper, as the chip shows
    click_now(app, "[data-call-arg=click]")
    pick_click("none")
    click_now(app, "#chip_inspector")
    expect_identical(app$get_js(title), "mascot_action()")
    # And the control opens at its own argument
    click_now(app, "[data-call-arg=click]")
    pick_click("menu")
    app$click(selector = "#chip_inspector")
    app$wait_for_js(
      "document.activeElement.id === 'inspector_sidebar' && document.getElementById('menu_items').getClientRects().length > 0"
    )
    expect_gte(release_studio_inputs(app), 1L)
  })
})

describe("the Check contrast button of the studio's colour controls", {
  it("says it is busy until the result of its own click is drawn, and keeps keyboard focus", {
    local_shiny_browser()
    app <- studio_driver(width = 1440, height = 900)
    wait_studio_mood(app, "idle")
    studio_select_function(app, "mascot_theme")
    app$set_inputs(theme_source = "mascot")
    app$wait_for_js("document.getElementById('contrast_check').getClientRects().length > 0")
    button <- "document.getElementById('contrast_check')"
    # When the focused button is clicked, it says so at once, and focus stays on it
    state <- app$get_js(sprintf(
      paste(
        "(() => { const b = %s; b.focus(); b.click();",
        "return [b.textContent, b.getAttribute('aria-busy'), b.getAttribute('aria-disabled'), document.activeElement.id]; })()"
      ),
      button
    ))
    expect_identical(unlist(state), c("Checking\u2026", "true", "true", "contrast_check"))
    # Then it is back once the result shows, and the result is the one for that click
    app$wait_for_js(sprintf("!%s.hasAttribute('aria-busy')", button))
    expect_identical(app$get_js(sprintf("%s.textContent", button)), "Check contrast")
    expect_null(app$get_js(sprintf("%s.getAttribute('aria-disabled')", button)))
    expect_identical(app$get_js("document.activeElement.id"), "contrast_check")
    expect_true(app$get_js("document.getElementById('contrast').textContent.trim().length > 0"))
    expect_identical(app$get_js("document.querySelector('#contrast [data-busy-done]').dataset.busyDone"), "1")
    # And when the server has not answered a second click, the first result is not taken for its answer, and a click
    # while it is busy sends nothing
    hold_studio_inputs(app, "contrast_check")
    app$run_js(sprintf("%s.click(); %s.click();", button, button))
    expect_identical(app$get_js(sprintf("%s.getAttribute('aria-busy')", button)), "true")
    expect_identical(app$get_js("window.studioHold.held.length"), 1L)
    expect_identical(app$get_js("document.querySelector('#contrast [data-busy-done]').dataset.busyDone"), "1")
    expect_identical(release_studio_inputs(app), 1L)
    app$wait_for_js(sprintf(
      "!%s.hasAttribute('aria-busy') && document.querySelector('#contrast [data-busy-done]').dataset.busyDone === '2'",
      button
    ))
  })
})

describe("studio code arguments, chips, anchors and menus", {
  it("keeps top-bar controls mounted and gives every chip three inspector routes", {
    local_shiny_browser()
    app <- studio_driver()
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
      click_now(app, sprintf('[data-call-arg=%s]', arg))
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
      click_now(app, sprintf('[data-call-arg=%s]', arg))
      app$click(selector = '#chip_inspector')
      expect_identical(app$get_js("document.activeElement.id"), "inspector_sidebar")
      expect_true(app$get_js("[...document.querySelectorAll('select')].every(s=>!s.selectize?.isOpen)"))
      # The Controls route also keeps shared controls in the top bar.
      expect_true(app$get_js(
        "document.getElementById('studio_character_bar').contains(window.topMood) && document.getElementById('studio_character_bar').contains(window.topCharacter)"
      ))
      app$click(selector = '#close_inspector')
    }
    click_now(app, '[data-call-arg=gesture]')
    app$click(selector = '#chip_help')
    wait_studio_panel(app, "help", "mascot_gesture")
    app$wait_for_js("document.getElementById('function_help').dataset.activeArgument === 'name'")
    click_now(app, '[data-call-arg=placement]')
    app$click(selector = '#chip_guide')
    expect_identical(app$get_js("document.getElementById('inspector_view_guide').getAttribute('aria-pressed')"), "true")
    wait_studio_panel(app, "guide", "mascot_placement")
    expect_identical(app$get_js("document.activeElement.id"), "inspector_sidebar")
  })

  it("draws real anchor positions and retains them at phone width and after a character change", {
    local_shiny_browser()
    app <- studio_driver()
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
      wait_studio_js(
        app,
        paste0(
          "(() => {const w=",
          studio_frame_wait,
          ";const el=",
          studio_live_wait,
          ";",
          "const compiled=w.mascot.parts.compile(w.anchorFixture); const channels=w.mascot.parts.resolveChannels(compiled,'idle');const state=w.mascot.parts.frame(compiled, channels, 'full', {x:150,base_y:270});",
          "const layer=",
          overlay,
          ";const rect=el.querySelector('canvas').getBoundingClientRect();",
          "const groups=[...layer.querySelectorAll('g[data-anchor]')];",
          "return groups.every(p=>{const a=state.anchors[p.dataset.anchor]; const d=p.querySelector('circle').getBoundingClientRect(); return Math.abs(d.left+d.width/2-(rect.left+a.matrix[4]/300*rect.width))<1 && Math.abs(d.top+d.height/2-(rect.top+a.matrix[5]/300*rect.height))<1;});})()"
        )
      )
      # Real rendered boxes: no labels overlap each other, the canvas or viewport.
      wait_studio_js(
        app,
        paste0(
          "(() => {const w=",
          studio_frame_wait,
          ";const rect=",
          studio_live_wait,
          ".querySelector('canvas').getBoundingClientRect();",
          "const labels=[...",
          overlay,
          ".querySelectorAll('.pg-anchor-label')].filter(p=>p.getClientRects().length).map(p=>p.getBoundingClientRect());",
          "const overlaps=(a,b)=>a.left<b.right && a.right>b.left && a.top<b.bottom && a.bottom>b.top;",
          "return labels.length>0 && labels.every((r,i)=>r.left>=0 && r.right<=w.innerWidth && r.top>=0 && r.bottom<=w.innerHeight && !overlaps(r,rect) && labels.slice(i+1).every(b=>!overlaps(r,b)));})()"
        )
      )
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
    wait_studio_js(app, paste0(studio_live_wait, ".dataset.character === 'sela'"))
    app$wait_for_js(paste0(overlay, ".querySelectorAll('g[data-anchor]').length === ", nrow(mascot_anchors("sela"))))
    verify("sela")
    app$set_inputs(character = "neer")
    wait_studio_js(app, paste0(studio_live_wait, ".dataset.character === 'neer'"))
    app$wait_for_js(paste0(overlay, ".querySelectorAll('g[data-anchor]').length === ", nrow(mascot_anchors("neer"))))
    verify("neer")
    app$click(selector = '#show_anchors')
    expect_true(app$get_js(paste0(overlay, ".hidden")))
  })

  it("portals selectize menus above clipped editors and restores them when closed", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    click_now(app, '[data-call-arg=click]')
    expect_true(app$get_js("!document.getElementById('click_type').selectize.isOpen"))
    # Let the server answer the chip's click first, so no reply lands while the menu is checked.
    app$wait_for_idle()
    app$run_js(
      "{const body=document.getElementById('chip_editor_body');body.style.maxHeight='60px';body.style.overflow='auto';}"
    )
    app$wait_for_js("document.getElementById('chip_editor_body').clientHeight <= 60")
    # The editor follows its chip whenever its size changes or the page scrolls (a ResizeObserver and scroll handlers,
    # a frame or more later), so it would move back up from where the test places it. Placing it low near the bottom,
    # opening the menu and reading where the menu went all happen in one script, before any of those can run; the
    # menu's placement (positionDropdown) is synchronous.
    menu <- app$get_js(paste(
      "(() => {",
      "const pop = document.getElementById('chip_editor'), s = document.getElementById('click_type').selectize;",
      "pop.style.top = (innerHeight - 130) + 'px'; s.focus(); s.open(); s.positionDropdown();",
      "const d = s.$dropdown[0], r = d.getBoundingClientRect();",
      "return { open: s.isOpen, portal: d.parentElement === document.body, direction: d.dataset.direction,",
      "  inView: r.top >= 0 && r.bottom <= innerHeight,",
      "  above: +getComputedStyle(d).zIndex > +getComputedStyle(pop).zIndex };",
      "})()"
    ))
    # Then the menu opens upwards, in view, above the clipped editor, from a portal in the page's body
    expect_identical(menu, list(open = TRUE, portal = TRUE, direction = "up", inView = TRUE, above = TRUE))
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
    click_now(app, '[data-call-arg=click]')
    app$click(selector = '#chip_inspector')
    expect_identical(app$get_js("document.activeElement.id"), "inspector_sidebar")
    expect_true(app$get_js("[...document.querySelectorAll('select')].every(s=>!s.selectize?.isOpen)"))
  })
})

describe("studio sentence controls and overview", {
  it("groups four labelled selects, plays and replays a gesture, and opens search only when asked", {
    local_shiny_browser()
    app <- studio_driver()
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
    app$click(selector = "#gesture_play")
    app$wait_for_js("window.gestureCalls.length === 3 && window.gestureCalls[2] === 'wave'")
    for (character in c("sela", "neer", "tessa")) {
      app$set_inputs(character = character)
      wait_studio_js(app, paste0(studio_live_wait, ".dataset.character === '", character, "'"))
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
    # Focus alone changes nothing (WCAG 2.2 On Focus); Enter, a click or Ctrl K ask for the search.
    app$run_js("document.getElementById('open_search').focus()")
    Sys.sleep(0.5)
    expect_true(app$get_js("document.getElementById('studio_search').hidden"))
    app$run_js(
      "document.getElementById('open_search').dispatchEvent(new KeyboardEvent('keydown', {key: 'Enter', bubbles: true}))"
    )
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
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    click_now(app, '[data-call-arg=placement]')
    expect_identical(app$get_js("document.getElementById('chip_title').textContent"), "placement =")
    app$click(selector = '[data-chip-overview=placement] button')
    app$wait_for_js("!!document.querySelector('.popover.show .pg-help')")
    expect_match(app$get_js("document.querySelector('.popover.show').textContent"), "Default:", fixed = TRUE)
    expect_true(app$get_js(
      "document.querySelector('.popover.show .pg-help').textContent.trim().length > 0 && document.getElementById('inspector_sidebar').hidden"
    ))
    app$run_js("document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}))")
    app$click(selector = '#chip_help')
    wait_studio_panel(app, "help", "mascot_placement")
    app$wait_for_js("document.activeElement.id === 'inspector_sidebar'")
  })
})

describe("studio inline help and movable anchors", {
  it("shows function titles on keyboard focus and hover without intercepting clicks", {
    local_shiny_browser()
    app <- studio_driver()
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
    app <- studio_driver()
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
    wait_studio_js(app, paste0(studio_live_wait, ".dataset.character === 'sela'"))
    app$set_inputs(character = "tessa")
    wait_studio_js(app, paste0(studio_live_wait, ".dataset.character === 'tessa'"))
    wait_studio_js(
      app,
      paste0(
        "(() => {const g=",
        studio_frame_wait,
        ".document.querySelector('[data-anchor=\"'+testMoved.name+'\"]');const r=g?.querySelector('rect');return r && +r.getAttribute('x')===testMoved.x && +r.getAttribute('y')===testMoved.y;})()"
      )
    )
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
    wait_studio_js(app, paste0(studio_live_wait, ".dataset.character === 'neer'"))
    wait_studio_js(
      app,
      paste0(
        studio_frame_wait,
        ".document.querySelectorAll('.pg-anchor-overlay g[data-anchor]').length === ",
        nrow(mascot_anchors("neer"))
      )
    )
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
    wait_studio_js(app, paste0(studio_live_wait, ".dataset.character === 'tessa'"))
    app$wait_for_js("!document.getElementById('show_anchors').disabled && document.getElementById('no_anchors').hidden")
  })
})

describe("studio phone layout", {
  it("keeps the sentence and tools separate and wraps the call inside the viewport", {
    local_shiny_browser()
    app <- studio_driver(width = 390, height = 844)
    wait_studio_mood(app, "idle")
    app$wait_for_js("document.querySelectorAll('#live_call [data-call-arg]').length > 1")
    browser <- app$get_chromote_session()
    for (width in c(360L, 375L, 430L, 390L, 768L)) {
      browser$Emulation$setDeviceMetricsOverride(
        width = width,
        height = 844L,
        deviceScaleFactor = 1,
        mobile = FALSE
      )
      app$wait_for_js(sprintf("innerWidth === %d", width))
      expect_true(
        app$get_js(paste0(
          "(() => {const t=document.querySelector('.pg-toolbar');",
          "const buttons=[...t.querySelectorAll('button,summary'),t.querySelector('bslib-input-dark-mode').shadowRoot.querySelector('button')];",
          "return t.scrollWidth<=t.clientWidth && buttons.filter(b=>b.getClientRects().length).every(b=>{",
          "const r=b.getBoundingClientRect();return r.width>0 && r.left>=0 && r.right<=innerWidth;});})()"
        )),
        info = paste("utility controls at", width)
      )
      expect_true(
        app$get_js(paste0(
          "document.documentElement.scrollWidth <= innerWidth && ",
          "document.getElementById('open_inspector').getClientRects().length > 0 && ",
          "document.getElementById('open_inspector').closest('#studio_character_bar') !== null && ",
          "getComputedStyle(document.querySelector('.pg-inspector-views')).display === 'none'"
        )),
        info = paste("phone inspector and overflow at", width)
      )
      expect_true(
        app$get_js(paste0(
          "(() => {const f=document.getElementById('live_frame'),w=f.contentWindow,d=w.document;",
          "const s=d.querySelector('.mascot-status'),r=s.getBoundingClientRect(),range=d.createRange();",
          "range.selectNodeContents(s);const text=range.getBoundingClientRect(),frame=f.getBoundingClientRect(),host=document.getElementById('studio_canvas').getBoundingClientRect();",
          "return s.textContent.trim().length>0 && r.left>=0 && r.top>=0 && r.right<=w.innerWidth && r.bottom<=w.innerHeight &&",
          "text.left>=r.left && text.top>=r.top && text.right<=r.right && text.bottom<=r.bottom &&",
          "frame.top+r.top>=host.top && frame.top+r.bottom<=host.bottom;})()"
        )),
        info = paste("complete host status at", width)
      )
      expect_true(
        app$get_js(paste0(
          "(() => {const labels=[...document.querySelectorAll('#code_style .radio-inline')];",
          "return labels.length===2 && labels.every(label=>{const dot=label.querySelector('input').getBoundingClientRect(),",
          "text=label.querySelector('span').getBoundingClientRect();return Math.abs((dot.top+dot.bottom-text.top-text.bottom)/2)<4;});})()"
        )),
        info = paste("radio alignment at", width)
      )
      expect_true(
        app$get_js(paste0(
          "(() => {const chip=document.querySelector('[data-call-arg=bubble]'),code=chip.querySelector('code'),",
          "value=chip.querySelector('.pg-chip-value'),range=document.createRange();range.selectNodeContents(value);",
          "const text=range.getBoundingClientRect(),r=chip.getBoundingClientRect();",
          "return value.textContent.includes('mascot_bubble(') && getComputedStyle(code).overflow==='visible' && text.top>=r.top && text.bottom<=r.bottom;})()"
        )),
        info = paste("bubble helper descenders at", width)
      )
    }
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
    click_now(app, '[data-call-arg=size]')
    app$wait_for_js("!document.getElementById('chip_editor').hidden")
    expect_true(app$get_js(
      "(() => {const r=document.getElementById('chip_editor').getBoundingClientRect();return r.left>=0 && r.top>=0 && r.right<=innerWidth && r.bottom<=innerHeight;})()"
    ))
    expect_true(app$get_js(
      "(() => {const c=document.getElementById('chip_editor_scroll');return getComputedStyle(c).overflowY==='auto' && [...document.querySelectorAll('#chip_editor button')].filter(b=>b.getClientRects().length).every(b=>b.getBoundingClientRect().height>=40);})()"
    ))
  })
})

describe("studio inspector rail", {
  it("toggles modes, synchronises panel tabs and returns Escape focus to the active mode", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    expect_identical(app$get_js("document.querySelectorAll('[data-inspector-view]').length"), 3L)
    for (name in c("controls", "help", "guide")) {
      selector <- paste0("#inspector_view_", name)
      app$click(selector = selector)
      expect_true(app$get_js(sprintf(
        paste0(
          "!document.getElementById('inspector_sidebar').hidden && ",
          "document.querySelectorAll('[data-inspector-view][aria-pressed=true]').length === 1 && ",
          "document.getElementById('inspector_view_%1$s').getAttribute('aria-pressed') === 'true' && ",
          "document.getElementById('inspector_tab_%1$s').getAttribute('aria-selected') === 'true' && ",
          "!document.getElementById('inspector_%1$s').hidden"
        ),
        name
      )))
      app$click(selector = selector)
      expect_true(app$get_js(paste0(
        "document.getElementById('inspector_sidebar').hidden && ",
        "document.querySelectorAll('[data-inspector-view][aria-pressed=true]').length === 0"
      )))
    }
    app$click(selector = "#inspector_view_controls")
    app$click(selector = "#inspector_view_help")
    expect_identical(app$get_js("document.getElementById('inspector_tab_help').getAttribute('aria-selected')"), "true")
    app$click(selector = "#inspector_tab_guide")
    expect_identical(app$get_js("document.getElementById('inspector_view_guide').getAttribute('aria-pressed')"), "true")
    app$run_js("document.dispatchEvent(new KeyboardEvent('keydown', {key:'Escape',bubbles:true}))")
    expect_true(app$get_js("document.getElementById('inspector_sidebar').hidden"))
    expect_identical(app$get_js("document.activeElement.id"), "inspector_view_guide")
    app$click(selector = "#studio_menu summary")
    app$wait_for_js("document.querySelector('#studio_menu summary').getAttribute('aria-expanded') === 'true'")
    expect_true(app$get_js(
      "document.getElementById('studio_menu').open && document.getElementById('studio_keys').getClientRects().length > 0"
    ))
    app$run_js("document.dispatchEvent(new KeyboardEvent('keydown', {key:'Escape',bubbles:true}))")
    app$wait_for_js("document.querySelector('#studio_menu summary').getAttribute('aria-expanded') === 'false'")
  })

  it("shares rail dimensions and reserves room beside the inspector on desktop and tablet", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    browser <- app$get_chromote_session()
    for (size in list(c(1280L, 720L), c(1366L, 768L), c(1440L, 900L), c(861L, 768L), c(999L, 768L), c(1100L, 768L))) {
      browser$Emulation$setDeviceMetricsOverride(
        width = size[1],
        height = size[2],
        deviceScaleFactor = 1,
        mobile = FALSE
      )
      app$wait_for_js(sprintf(
        "innerWidth === %d && document.getElementById('studio_right_rail').parentElement.id === 'studio_shell'",
        size[1]
      ))
      expect_true(
        app$get_js(paste0(
          "(() => {const l=document.querySelector('.pg-rail'),r=document.getElementById('studio_right_rail'),",
          "a=l.getBoundingClientRect(),b=r.getBoundingClientRect(),t=document.getElementById('studio_character_bar').getBoundingClientRect();",
          "return a.width===56 && b.width===a.width && a.top===14 && b.top===a.top && ",
          "getComputedStyle(l).borderRadius==='14px' && getComputedStyle(r).borderRadius===getComputedStyle(l).borderRadius && ",
          "t.right<=b.left-14 && !document.getElementById('open_inspector').getClientRects().length && ",
          "[...r.querySelectorAll('[data-inspector-view]')].every(x=>{const c=x.getBoundingClientRect();",
          "return c.width===40 && c.height===40 && getComputedStyle(x).borderRadius==='10px';});})()"
        )),
        info = paste("rail geometry at", size[1])
      )
      app$click(selector = "#inspector_view_controls")
      expect_true(
        app$get_js(paste0(
          "(() => {const p=document.getElementById('inspector_sidebar').getBoundingClientRect(),",
          "r=document.getElementById('studio_right_rail').getBoundingClientRect();",
          "return p.right===r.left-10 && p.top===62 && p.bottom===innerHeight-14 && p.width===344;})()"
        )),
        info = paste("inspector beside rail at", size[1])
      )
      app$click(selector = "#close_inspector")
    }
  })

  it("keeps one mobile Inspector entry and preserves the mounted menu across breakpoints", {
    local_shiny_browser()
    app <- studio_driver(width = 390, height = 844)
    wait_studio_mood(app, "idle")
    app$run_js("window.studioMenuInput = document.getElementById('studio_keys'); studioMenuInput.checked = false")
    app$click(selector = "#open_inspector")
    app$click(selector = "#inspector_tab_help")
    app$run_js("document.dispatchEvent(new KeyboardEvent('keydown', {key:'Escape',bubbles:true}))")
    expect_identical(app$get_js("document.activeElement.id"), "open_inspector")
    app$click(selector = "#open_inspector")
    expect_true(app$get_js("!document.getElementById('inspector_help').hidden"))
    app$click(selector = "#close_inspector")
    browser <- app$get_chromote_session()
    for (width in c(1280L, 375L, 1440L, 768L)) {
      browser$Emulation$setDeviceMetricsOverride(width = width, height = 844L, deviceScaleFactor = 1, mobile = FALSE)
      app$wait_for_js(sprintf(
        "innerWidth === %d && document.getElementById('studio_right_rail').parentElement.id === '%s'",
        width,
        if (width <= 860) "studio_phone_tools" else "studio_shell"
      ))
      expect_true(app$get_js(paste0(
        "document.querySelectorAll('#studio_keys').length===1 && ",
        "document.getElementById('studio_keys')===studioMenuInput && !studioMenuInput.checked"
      )))
    }
  })
})

describe("studio host choices, reading tabs, dock and examples browser", {
  it("expands only reading tabs, remembers the choice and collapses before closing", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    app$click(selector = "#inspector_view_controls")
    expect_true(app$get_js(
      "!document.querySelector('#inspector_controls [data-expand-inspector], #inspector_sidebar > .pg-surface-head [data-expand-inspector]')"
    ))
    app$click(selector = "#inspector_tab_help")
    app$wait_for_js("!!document.querySelector('#function_help .card-header #expand_inspector svg')")
    expect_identical(app$get_js("document.getElementById('expand_inspector').textContent.trim()"), "")
    app$run_js("window.centreBeforeExpansion=document.getElementById('studio_centre').getBoundingClientRect().toJSON()")
    app$click(selector = "#expand_inspector")
    expect_true(app$get_js(paste0(
      "(() => {const p=document.getElementById('inspector_sidebar'),r=document.getElementById('studio_right_rail');",
      "const b=p.getBoundingClientRect(); return p.classList.contains('is-expanded') && ",
      "Math.abs(b.width-Math.min(580,innerWidth*.45))<1 && b.top===62 && b.right===r.getBoundingClientRect().left-10 && ",
      "document.getElementById('expand_inspector').getAttribute('aria-expanded')==='true';})()"
    )))
    expect_true(app$get_js(
      "JSON.stringify(centreBeforeExpansion)===JSON.stringify(document.getElementById('studio_centre').getBoundingClientRect().toJSON())"
    ))
    app$click(selector = "#inspector_tab_controls")
    expect_identical(app$get_js("document.getElementById('inspector_sidebar').getBoundingClientRect().width"), 344L)
    app$click(selector = "#inspector_tab_guide")
    expect_true(app$get_js("document.getElementById('inspector_sidebar').classList.contains('is-expanded')"))
    app$run_js(
      "document.getElementById('inspector_sidebar').dispatchEvent(new KeyboardEvent('keydown',{key:'E',shiftKey:true,bubbles:true}))"
    )
    expect_false(app$get_js("document.getElementById('inspector_sidebar').classList.contains('is-expanded')"))
    app$wait_for_js("!!document.getElementById('expand_inspector_guide')?.getClientRects().length")
    app$click(selector = "#expand_inspector_guide")
    app$run_js("document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}))")
    expect_true(app$get_js(
      "!document.getElementById('inspector_sidebar').hidden && !document.getElementById('inspector_sidebar').classList.contains('is-expanded')"
    ))
    app$run_js("document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}))")
    expect_true(app$get_js(
      "document.getElementById('inspector_sidebar').hidden && document.activeElement.id==='inspector_view_guide'"
    ))
    browser <- app$get_chromote_session()
    browser$Emulation$setDeviceMetricsOverride(width = 390L, height = 844L, deviceScaleFactor = 1, mobile = FALSE)
    app$wait_for_js("document.getElementById('studio_right_rail').parentElement.id==='studio_phone_tools'")
    app$click(selector = "#open_inspector")
    app$click(selector = "#expand_inspector_guide")
    expect_true(app$get_js(
      "document.getElementById('inspector_sidebar').getBoundingClientRect().height > innerHeight*.95"
    ))
  })

  it("matches dock type to the sentence and supplies focus and reduced-motion feedback", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    app$get_chromote_session()$Input$dispatchMouseEvent(type = "mouseMoved", x = 40, y = 40)
    expect_identical(
      app$get_js("getComputedStyle(document.getElementById('function_index_tooltip')).visibility"),
      "visible"
    )
    app$run_js("document.getElementById('all_functions').focus()")
    expect_identical(
      app$get_js("getComputedStyle(document.getElementById('function_index_tooltip')).visibility"),
      "visible"
    )
    for (width in c(1280L, 390L)) {
      app$get_chromote_session()$Emulation$setDeviceMetricsOverride(
        width = width,
        height = 844L,
        deviceScaleFactor = 1,
        mobile = FALSE
      )
      app$wait_for_js(sprintf("innerWidth===%d", width))
      # The dock type is fitted on the next animation frames after a resize, so give it a moment.
      offenders_js <- paste0(
        "(() => {const n=parseFloat(getComputedStyle(document.querySelector('.pg-sentence')).fontSize);",
        "return [...document.querySelectorAll('#studio_dock .pg-eyebrow,#studio_dock label,#studio_dock .btn,#studio_dock .pg-call-name')]",
        ".filter(x=>!(Math.abs(parseFloat(getComputedStyle(x).fontSize)-n)<=1 && parseFloat(getComputedStyle(x).fontSize)>=12))",
        ".map(x=>(x.className||x.tagName)+' '+getComputedStyle(x).fontSize+' vs '+n).join(' | ');})()"
      )
      offenders <- app$get_js(offenders_js)
      for (attempt in 1:20) {
        if (identical(offenders, "")) {
          break
        }
        Sys.sleep(0.25)
        offenders <- app$get_js(offenders_js)
      }
      expect_identical(offenders, "")
    }
    app$run_js("document.querySelector('[data-call-arg=status]').focus()")
    expect_identical(app$get_js("getComputedStyle(document.querySelector('[data-call-arg=status]')).cursor"), "pointer")
    expect_identical(
      app$get_js("getComputedStyle(document.querySelector('[data-call-arg=status] .pg-chip-pencil')).opacity"),
      "1"
    )
    app$run_js(paste0(
      "window.chipPulses=[]; window.pulseObserver=new MutationObserver(()=>{",
      "for(const c of document.querySelectorAll('.pg-chip-pulse')) if(!chipPulses.includes(c.dataset.callArg)) chipPulses.push(c.dataset.callArg);});",
      "pulseObserver.observe(document.getElementById('live_call'),{subtree:true,attributes:true,attributeFilter:['class']});"
    ))
    app$set_inputs(mood = "happy")
    app$wait_for_js("chipPulses.includes('mood')")
    click_now(app, "[data-call-arg=status]")
    app$set_inputs(status_text = "Edited in popover")
    app$wait_for_js("chipPulses.includes('status')")
    app$click(selector = "#chip_inspector")
    app$run_js("chipPulses.length=0")
    app$set_inputs(status_text = "Edited in inspector")
    app$wait_for_js("chipPulses.includes('status')")
    app$wait_for_js("document.querySelector('[data-call-arg=status]').classList.contains('pg-chip-pulse')")
    app$get_chromote_session()$Emulation$setEmulatedMedia(
      features = list(list(name = "prefers-reduced-motion", value = "reduce"))
    )
    app$set_inputs(status_text = "Static feedback")
    app$wait_for_js(
      "document.querySelector('[data-call-arg=status] .pg-chip-value').textContent.includes('Static feedback')"
    )
    expect_identical(
      app$get_js("getComputedStyle(document.querySelector('[data-call-arg=status]')).animationName"),
      "none"
    )
    app$wait_for_js("!document.querySelector('.pg-chip-pulse')")
    app$run_js("document.querySelector('.pg-index-link[data-value=mascot]').click()")
    app$click(selector = "#inspector_tab_help")
    wait_studio_panel(app, "help", "mascot")
    expect_identical(
      app$get_js("getComputedStyle(document.querySelector('#function_help .pg-help-usage')).position"),
      "sticky"
    )
    expect_true(app$get_js("!!document.querySelector('#function_help .pg-arg-name')"))
    app$run_js("document.getElementById('inspector_help').scrollTop=180")
    app$wait_for_js("!!document.querySelector('#function_help .pg-help-usage.is-stuck')")
    app$run_js("pulseObserver.disconnect()")
  })

  it("browses examples in place and restores mounted state, with index and search exits", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    app$set_inputs(mood = "happy")
    wait_studio_mood(app, "happy")
    app$run_js(paste0("window.savedHost=", studio_live, "; window.savedMood=document.getElementById('mood');"))
    expect_identical(app$get_js("Object.keys(document.getElementById('host_mode').selectize.options).length"), 2L)
    click_now(app, "[data-call-arg=status]")
    app$run_js("document.getElementById('more_examples').click()")
    expect_true(app$get_js(paste0(
      "document.getElementById('studio_character_bar').hidden && document.getElementById('studio_dock').hidden && ",
      "document.getElementById('chip_editor').hidden && !document.getElementById('back_to_studio').hidden && ",
      "Math.abs(document.getElementById('studio_canvas').getBoundingClientRect().width-document.getElementById('studio_centre').clientWidth)<1 && ",
      "[...document.querySelectorAll('.pg-rail [data-group]')].every(x=>x.getAttribute('aria-disabled')==='true')"
    )))
    app$click(selector = "#inspector_view_help")
    wait_studio_panel(app, "help", "mascot_example")
    app$click(selector = "#close_inspector")
    app$click(selector = "#back_to_studio")
    expect_true(app$get_js(paste0(
      "!document.getElementById('studio_character_bar').hidden && !document.getElementById('studio_dock').hidden && ",
      "savedMood===document.getElementById('mood') && savedMood.value==='happy' && savedHost===",
      studio_live
    )))
    app$run_js("document.getElementById('more_examples').click()")
    app$click(selector = "#all_functions")
    app$click(selector = '.pg-index-link[data-value="mascot_size"]')
    expect_identical(app$get_js("document.getElementById('studio_canvas').dataset.mode"), "mascot")
    app$click(selector = "#close_inspector")
    app$run_js(
      "document.getElementById('more_examples').click(); document.dispatchEvent(new KeyboardEvent('keydown',{key:'k',ctrlKey:true,bubbles:true}))"
    )
    app$wait_for_js("!document.getElementById('studio_search').hidden")
    app$run_js("document.querySelector('[data-search-function=mascot_theme]').click()")
    expect_identical(app$get_js("document.getElementById('studio_canvas').dataset.mode"), "mascot")
  })
})

describe("studio palette help and warnings", {
  it("opens the helper's own help from a chip and the mascot() inspector from the call name", {
    local_shiny_browser()
    app <- studio_driver(width = 1440, height = 900)
    wait_studio_mood(app, "idle")
    click_now(app, "[data-call-arg=status]")
    app$wait_for_js("!document.getElementById('chip_editor').hidden")
    app$click(selector = "#chip_help")
    wait_studio_panel(app, "help", "mascot_status")
    expect_identical(app$get_js("document.getElementById('function_help').dataset.activeArgument || ''"), "")
    expect_identical(
      app$get_js("document.getElementById('inspector_tab_help').getAttribute('aria-selected')"),
      "true"
    )
    click_now(app, "button.pg-call-name")
    # The call name opens the Controls of mascot(); its Help page is drawn behind them, not shown
    app$wait_for_js(paste(
      "!document.getElementById('inspector_help').hasAttribute('aria-busy') &&",
      "document.querySelector('#function_help [data-guide-function]')?.dataset.guideFunction === 'mascot'"
    ))
    expect_true(app$get_js(
      "!document.querySelector('#studio_inspector [data-function=mascot]').hidden && !document.getElementById('inspector_sidebar').hidden"
    ))
  })
  it("names original colours, preserves exact palette ids and contains tables at 390 pixels", {
    local_shiny_browser()
    app <- studio_driver(width = 390, height = 844)
    wait_studio_mood(app, "idle")
    # Read selected words only: a native select's textContent also contains all unselected options.
    sentence <- "(() => {const root=document.querySelector('.pg-sentence'); return [...root.childNodes].map(n=>n.nodeType===3?n.textContent.trim():n.querySelector('select')?.selectedOptions[0].textContent || n.textContent.trim()).filter(Boolean).slice(0,5).join(' ').replace(/\\s+,/g,',');})()"
    app$wait_for_js(
      "document.querySelector('#palette').selectedOptions[0].textContent === \"Tessa's own colours (night_teal)\""
    )
    expect_match(app$get_js(sentence), "Showing Tessa in Tessa's own colours (night_teal)", fixed = TRUE)
    expect_identical(app$get_js("document.getElementById('palette').title"), "night_teal")
    expect_false(grepl('theme =', app$get_value(output = "code_ui"), fixed = TRUE))
    app$set_inputs(palette = "sea_green")
    app$wait_for_js("document.getElementById('palette').title === 'sea_green'")
    expect_match(app$get_js(sentence), "Showing Tessa in the Sea green palette,", fixed = TRUE)
    expect_identical(app$get_js("document.querySelector('#palette option[value=sea_green]').title"), "sea_green")
    app$wait_for_js("document.getElementById('code_ui').textContent.includes('theme = \"sea_green\"')")
    expect_match(app$get_value(output = "code_ui"), 'theme = "sea_green"', fixed = TRUE)
    app$set_inputs(character = "sela", palette = "original")
    app$wait_for_js(
      "document.querySelector('#palette').selectedOptions[0].textContent === \"Sela's own colours (lilac_violet)\""
    )
    expect_match(app$get_js(sentence), "Showing Sela in Sela's own colours (lilac_violet)", fixed = TRUE)
    studio_select_function(app, "mascot_palettes")
    app$click(selector = "#inspector_tab_guide")
    # The Guide of mascot_theme() has palette tables too: wait for the page of mascot_palettes()
    wait_studio_panel(app, "guide", "mascot_palettes", character = "sela")
    expect_gt(app$get_js("document.querySelector('#guide .pg-palette-table td').getBoundingClientRect().width"), 0)
    expect_true(app$get_js(
      "[...document.querySelectorAll('#guide .pg-palette-table td:not(:nth-child(2))')].every(n=>getComputedStyle(n).whiteSpace==='nowrap')"
    ))
    expect_true(app$get_js(
      "[...document.querySelectorAll('#guide .pg-palette-table')].every(n=>getComputedStyle(n).overflowX==='auto' && n.getBoundingClientRect().right<=innerWidth)"
    ))
    expect_true(app$get_js("document.documentElement.scrollWidth <= innerWidth"))
  })
  it("logs an unknown-palette warning without changing or dropping the live palette", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    app$set_inputs(palette = "sea_green", mood = "happy")
    wait_studio_mood(app, "happy")
    wait_studio_js(
      app,
      paste0(studio_frame_wait, ".mascot.host.state(", studio_live_wait, ").theme.palette === 'sea_green'")
    )
    studio_select_function(app, "update_mascot")
    app$set_inputs(mistake = "An unknown palette in an update")
    app$wait_for_js("document.getElementById('mistake_code').textContent.includes('nothing is dropped')")
    before <- app$get_value(output = "code_ui")
    app$click(selector = "#mistake_run")
    app$wait_for_js("document.querySelector('#wiring_log .is-warning')?.textContent.includes('Unknown palette')")
    log <- app$get_js("document.querySelector('#wiring_log .is-warning').textContent")
    expect_match(log, "left mascot", fixed = TRUE)
    expect_match(log, "unchanged", fixed = TRUE)
    expect_match(log, "each palette belongs to its own character", fixed = TRUE)
    expect_false(grepl("mascot_palette_dropped", log, fixed = TRUE))
    expect_identical(app$get_value(output = "code_ui"), before)
    expect_identical(
      app$get_js(paste0(studio_frame, ".mascot.host.state(", studio_live, ").theme.palette")),
      "sea_green"
    )
    wait_studio_mood(app, "happy")
  })
})

describe("the controls and the server's echo of a change it applied", {
  # The server applies a change a moment after it is made and sets the control to what it applied. When the visitor has
  # changed the control again meanwhile, that echo must not set it back. Each test holds the server's replies back, makes
  # the change, waits until the server has applied it, changes the control again and lets the replies through in the same
  # step in the page, so nothing else can reach the control first. The echo lands a moment after that (Shiny applies a
  # control's update asynchronously), so the test waits for the control to change or for the server to take the new text.
  it("keeps the status text typed after a change, when the echo of that change arrives late", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    hold_studio_replies(app)
    type_studio_text(app, "status_text", "ab")
    wait_studio_reply(app, "!!reply.custom?.['mascot:update']")
    # When "abc" is typed just before the echo of "ab" arrives
    app$run_js(paste(
      "(() => { const field = document.getElementById('status_text'); field.value = 'abc';",
      "field.dispatchEvent(new Event('input', { bubbles: true })); window.studioReplies.release(); })()"
    ))
    wait_studio_js(
      app,
      "document.getElementById('status_text').value !== 'abc' || live.querySelector('.mascot-status')?.textContent.trim() === 'abc'"
    )
    # Then the control still shows what was typed, and the server ends with it
    expect_identical(app$get_js("document.getElementById('status_text').value"), "abc")
    wait_studio_js(app, "live.querySelector('.mascot-status')?.textContent.trim() === 'abc'")
    expect_identical(app$get_js("Shiny.shinyapp.$inputValues.status_text"), "abc")
  })
  it("keeps the mood picked after a change, when the echo of that change arrives late", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    hold_studio_replies(app)
    app$run_js("{ const s = document.getElementById('mood'); s.value = 'happy'; $(s).trigger('change'); }")
    wait_studio_reply(app, "!!reply.custom?.['mascot:update']")
    # When another mood is picked just before the echo of the first arrives
    app$run_js(paste(
      "(() => { const s = document.getElementById('mood'); s.value = 'worried'; $(s).trigger('change');",
      "window.studioReplies.release(); })()"
    ))
    wait_studio_js(app, "document.getElementById('mood').value !== 'worried' || live.dataset.shownMood === 'worried'")
    # Then the control still shows it, and the mascot ends in it
    expect_identical(app$get_js("document.getElementById('mood').value"), "worried")
    wait_studio_mood(app, "worried")
    expect_identical(app$get_js("document.getElementById('mood').value"), "worried")
  })
  it("keeps the bubble text typed in the chip editor, when the echo of an earlier text arrives late", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    open_studio_chip(app, "bubble")
    hold_studio_replies(app)
    type_studio_text(app, "bubble_text", "ab")
    wait_studio_reply(app, "!!reply.custom?.['mascot:update']")
    app$run_js(paste(
      "(() => { const field = document.getElementById('bubble_text'); field.value = 'abc';",
      "field.dispatchEvent(new Event('input', { bubbles: true })); window.studioReplies.release(); })()"
    ))
    wait_studio_js(
      app,
      "document.getElementById('bubble_text').value !== 'abc' || live.querySelector('.mascot-bubble')?.textContent.includes('abc')"
    )
    expect_identical(app$get_js("document.getElementById('bubble_text').value"), "abc")
    wait_studio_js(app, "live.querySelector('.mascot-bubble')?.textContent.includes('abc')")
    expect_identical(app$get_js("document.getElementById('bubble_text').value"), "abc")
  })
})

describe("the copy buttons", {
  # A copy button must copy the text that belongs to what the visitor has changed, never the text an earlier state left
  # in the page while the server has not answered. Each test holds back what the page sends (or makes a change the server
  # holds back by design), clicks Copy, and checks that nothing is copied until the server has answered.
  it("copies the code of the function just picked, not the code of the one before", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    studio_select_function(app, "mascot_moods")
    wait_studio_code(app, "mascot_moods")
    stub_studio_clipboard(app)
    # Given the server has not answered the change of function yet
    hold_studio_inputs(app, c("select_function", "copy_ticket"))
    studio_select_function(app, "mascot_gestures")
    # When Copy is clicked, the button says it waits, and the old code is not copied
    click_now(app, "#code_pin [data-copy=code_function]")
    state <- app$get_js(paste(
      "(() => { const b = document.querySelector('#code_pin [data-copy=code_function]');",
      "return [b.textContent, b.getAttribute('aria-busy'), String(window.copied)]; })()"
    ))
    expect_identical(unlist(state), c("Copying\u2026", "true", "null"))
    # Then the code of the function just picked is copied, once the server has drawn it
    expect_gte(release_studio_inputs(app), 1L)
    app$wait_for_js("window.copied !== null")
    wait_studio_code(app, "mascot_gestures")
    copied <- app$get_js("window.copied")
    expect_match(copied, "mascot_gestures(", fixed = TRUE)
    expect_identical(copied, app$get_js("document.getElementById('code_function').textContent"))
    app$wait_for_js("document.querySelector('#code_pin [data-copy=code_function]').textContent === 'Copied'")
  })
  it("copies the code with the status text typed just before, which the studio applies after a pause", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    stub_studio_clipboard(app)
    # When the status text is typed and Copy is clicked at once (leaving the box sends its change at once)
    app$run_js(paste(
      "(() => { const field = document.getElementById('status_text'); field.value = 'Draft ready';",
      "field.dispatchEvent(new Event('input', { bubbles: true })); field.dispatchEvent(new Event('change', { bubbles: true }));",
      "document.querySelector('#studio_dock [data-copy=code_ui]').click(); })()"
    ))
    # Then the copied code has the status
    app$wait_for_js("window.copied !== null")
    expect_match(app$get_js("window.copied"), 'status = "Draft ready"', fixed = TRUE)
    expect_identical(app$get_js("window.copied"), app$get_js("document.getElementById('code_ui').textContent"))
  })
  it("copies the code of the example just picked, not the one before", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    app$run_js("window.location.search = '?view=examples'")
    app$wait_for_js(
      "!!document.getElementById('example_code') && !!document.getElementById('live_frame') && Shiny.shinyapp.isConnected()"
    )
    stub_studio_clipboard(app)
    before <- app$get_js("document.getElementById('example_code').textContent")
    # Given the server has not answered the pick of another example yet
    hold_studio_inputs(app, c("example_name", "copy_ticket"))
    app$run_js("document.getElementById('example_name').selectize.setValue('form-check')")
    click_now(app, "[data-copy=example_code]")
    expect_identical(app$get_js("String(window.copied)"), "null")
    # Then the code of the example just picked is copied: the server drew it before it answered the copy
    expect_gte(release_studio_inputs(app), 1L)
    app$wait_for_js("window.copied !== null")
    expect_match(app$get_js("document.getElementById('example_call').textContent"), '"form-check"', fixed = TRUE)
    copied <- app$get_js("window.copied")
    expect_false(identical(copied, before))
    expect_identical(copied, app$get_js("document.getElementById('example_code').textContent"))
    # And the button the server drew with the new code says so, although the click was on the one before it
    app$wait_for_js("document.querySelector('[data-copy=example_code]').textContent === 'Copied'")
  })
  it("copies through a selection when the browser refuses the clipboard API", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    # The inspector shows the code of the function, with its Copy button
    studio_select_function(app, "mascot_mood")
    wait_studio_code(app, "mascot_mood")
    # Given a browser that refuses the clipboard API, as in a frame without clipboard access
    app$run_js(paste(
      "window.copied = null;",
      "const refuse = () => Promise.reject(new DOMException('Not allowed', 'NotAllowedError'));",
      "navigator.clipboard.write = refuse; navigator.clipboard.writeText = refuse;",
      "document.execCommand = (command) => {",
      "  if (command === 'copy') window.copied = [...document.querySelectorAll('body > textarea[readonly]')].pop()?.value;",
      "  return true; };"
    ))
    # When the focused Copy button is clicked
    focused <- app$get_js(paste(
      "(() => { const b = document.querySelector('#code_pin [data-copy=code_function]'); b.focus();",
      "const focused = document.activeElement === b; b.click(); return focused; })()"
    ))
    expect_true(focused)
    # Then the code is copied through a selection, the button says it was copied, and it keeps keyboard focus
    app$wait_for_js("document.querySelector('#code_pin [data-copy=code_function]').textContent === 'Copied'")
    expect_identical(app$get_js("window.copied"), app$get_js("document.getElementById('code_function').textContent"))
    expect_true(app$get_js("document.activeElement === document.querySelector('#code_pin [data-copy=code_function]')"))
  })
  it("says so when the server does not answer, and copies nothing", {
    local_shiny_browser()
    app <- studio_driver()
    wait_studio_mood(app, "idle")
    stub_studio_clipboard(app)
    hold_studio_inputs(app, "copy_ticket")
    click_now(app, "#code_pin [data-copy=code_function]")
    app$wait_for_js("document.querySelector('#code_pin [data-copy=code_function]').textContent === 'Copy unavailable'")
    expect_identical(app$get_js("String(window.copied)"), "null")
    expect_null(app$get_js("document.querySelector('#code_pin [data-copy=code_function]').getAttribute('aria-busy')"))
  })
})

describe("the preview page's busy badge", {
  it("stays until the page inside the frame has loaded", {
    local_shiny_browser()
    app <- studio_driver(width = 1440, height = 900)
    wait_studio_mood(app, "idle")
    # Given a record of what the page shows at every frame it draws: is the badge shown, is there a frame, is its page
    # loaded (the page marks a frame data-loaded when that happens)
    app$run_js(paste(
      "window.badgeSamples = [];",
      "const sample = () => { const frame = document.querySelector('iframe.pg-preview');",
      "  window.badgeSamples.push({ badge: !!document.querySelector('.pg-building'), frame: !!frame,",
      "    loaded: frame ? frame.dataset.loaded === 'true' : null });",
      "  requestAnimationFrame(sample); };",
      "sample();"
    ))
    # When the preview page is built, and built again after a change
    studio_select_function(app, "mascot_preview")
    app$wait_for_js("window.badgeSamples.some((s) => s.loaded === true)")
    type_studio_text(app, "preview_status", "Second build")
    app$wait_for_js(
      "document.getElementById('code_preview').textContent.includes('Second build') && !document.querySelector('.pg-building')"
    )
    # Then no drawn frame showed a frame still loading its page without the badge
    early <- app$get_js("window.badgeSamples.filter((s) => !s.badge && s.frame && s.loaded === false).length")
    expect_identical(early, 0L)
    expect_true(app$get_js("window.badgeSamples.some((s) => s.badge && s.frame && s.loaded === false)"))
  })
})
