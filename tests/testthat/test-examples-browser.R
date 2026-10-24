# A literal scenario name is embedded so the child R process needs no test globals.
example_driver <- function(name, width = 1100, env = parent.frame()) {
  checkmate::assert_string(name)
  checkmate::assert_number(width, lower = 1)
  checkmate::assert_environment(env)
  testthat::skip_if_not_installed("bslib")
  app_function <- function() NULL
  body(app_function) <- substitute(
    {
      library(mascot)
      shiny::shinyAppDir(system.file("examples", NAME, package = "mascot"))
    },
    list(NAME = name)
  )
  # The app belongs to the calling test, not to this helper: stop it when that test ends (#445).
  app_driver(app_function, width = width, height = 900, env = env)
}

wait_example_mood <- function(app, id, mood) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(id)
  checkmate::assert_string(mood)
  app$wait_for_js(sprintf("document.getElementById('%s')?.dataset.shownMood === '%s'", id, mood))
  expect_identical(app$get_js(sprintf("document.getElementById('%s').dataset.shownMood", id)), mood)
}

describe("bundled example apps", {
  it("the form-check example names invalid fields and becomes happy when both pass", {
    local_shiny_browser()
    app <- example_driver("form-check")
    wait_example_mood(app, "helper", "worried")
    expect_match(app$get_js("document.querySelector('#helper .mascot-status').textContent"), "2 fields")
    app$set_inputs(sample = "Sample A", quantity = 12)
    wait_example_mood(app, "helper", "happy")
    expect_identical(app$get_js("document.getElementById('checks').textContent"), "Both fields pass.")
    app$set_inputs(quantity = 0)
    wait_example_mood(app, "helper", "worried")
    expect_match(app$get_js("document.querySelector('#helper .mascot-status').textContent"), "1 field")
  })
  it("the long-task example shows thinking then success and retains an error message", {
    local_shiny_browser()
    app <- example_driver("long-task")
    wait_example_mood(app, "helper", "idle")
    # Record browser-observed transitions even if the server completes before a poll.
    app$run_js(
      "window.seenMoods=[];new MutationObserver(()=>seenMoods.push(document.getElementById('helper').dataset.shownMood)).observe(document.getElementById('helper'),{attributes:true,attributeFilter:['data-shown-mood']})"
    )
    app$click("start")
    # The task runs as a promise, so the app answers while it works.
    wait_example_mood(app, "helper", "thinking")
    expect_match(app$get_js("document.getElementById('result').textContent"), "Reviewing the sample")
    wait_example_mood(app, "helper", "happy")
    expect_match(app$get_js("document.getElementById('result').textContent"), "all 120 rows")
    expect_true(app$get_js("seenMoods.includes('thinking')"))
    app$set_inputs(fail = TRUE)
    app$click("start")
    wait_example_mood(app, "helper", "worried")
    expect_match(app$get_js("document.querySelector('#helper .mascot-bubble').textContent"), "Check the source data")
    expect_true(app$get_js("mascot.host.state(document.getElementById('helper')).bubble.remaining === null"))
    app$set_inputs(fail = FALSE)
    app$click("start")
    wait_example_mood(app, "helper", "happy")
    expect_null(app$get_js("mascot.host.state(document.getElementById('helper')).bubble"))
  })
  it("the modules example updates each module's helper and returns completion to the parent", {
    local_shiny_browser()
    app <- example_driver("modules")
    wait_example_mood(app, "first-helper", "worried")
    wait_example_mood(app, "second-helper", "worried")
    wait_example_mood(app, "parent", "worried")
    app$set_inputs(`first-ready` = TRUE)
    wait_example_mood(app, "first-helper", "happy")
    wait_example_mood(app, "second-helper", "worried")
    wait_example_mood(app, "parent", "worried")
    app$set_inputs(`second-ready` = TRUE)
    wait_example_mood(app, "parent", "happy")
    expect_true(app$get_js("mascot.host.state(document.getElementById('parent')).placement.floating"))
  })
})

describe("studio character bar", {
  it("holds all four drop-downs and Play it again in the main area at 375 pixels", {
    local_shiny_browser()
    app <- example_driver("studio", width = 375)
    app$wait_for_js(
      "document.querySelector('#studio_centre #studio_character_bar #character') &&
      document.querySelector('#studio_centre #studio_character_bar #mood')"
    )
    expect_true(app$get_js(
      "document.querySelector('#studio_centre #studio_character_bar').contains(document.getElementById('character')) &&
      document.querySelector('#studio_centre #studio_character_bar').contains(document.getElementById('mood'))"
    ))
    for (id in c("character", "palette", "mood", "gesture")) {
      expect_true(app$get_js(sprintf("document.querySelector('#studio_character_bar select#%s') !== null", id)))
    }
    expect_true(app$get_js("document.querySelector('#studio_character_bar #gesture_play') !== null"))
    expect_true(app$get_js("document.documentElement.scrollWidth <= window.innerWidth"))
    app$set_inputs(character = "knurl")
    app$wait_for_js("document.getElementById('character').value === 'knurl'")
    app$wait_for_js("[...document.querySelector('#palette').options].some(o => o.value === 'orbit')")
    app$set_inputs(palette = "orbit")
    app$wait_for_js("document.getElementById('code_ui').textContent.includes('theme = \"orbit\"')")
    app$set_inputs(character = "neer")
    app$wait_for_js(
      "document.querySelector('#palette').value === 'original' && [...document.querySelector('#palette').options].some(o => o.value === 'lagoon')"
    )
    expect_false(app$get_js("[...document.querySelector('#palette').options].some(o => o.value === 'orbit')"))
    expect_true(app$get_js("document.documentElement.scrollWidth <= window.innerWidth"))
  })
})

describe("studio narrow layout", {
  it("shows the canvas and the mascot at phone and tablet widths without horizontal scrolling", {
    local_shiny_browser()
    check_width <- function(width) {
      checkmate::assert_number(width, lower = 1)
      app <- example_driver("studio", width = width)
      on.exit(app$stop())
      wait_studio_js(app, "live.dataset.shownMood === 'idle'")
      # The bug collapsed the canvas to zero height while its width stayed normal.
      sizes <- app$get_js(
        "(() => {
          const centre = document.getElementById('studio_canvas').getBoundingClientRect();
          const host = document.getElementById('live_frame').getBoundingClientRect();
          const mascot = document.getElementById('live_frame').contentDocument.querySelector('#helper .mascot-canvas').getBoundingClientRect();
          return {centre: centre.height, host: host.height, mascot: mascot.height};
        })()"
      )
      expect_gt(sizes$centre, 200, label = paste("canvas height at", width, "px"))
      expect_gt(sizes$host, 0, label = paste("host height at", width, "px"))
      expect_gt(sizes$mascot, 0, label = paste("mascot height at", width, "px"))
      expect_true(app$get_js("document.documentElement.scrollWidth <= window.innerWidth"), info = paste("width", width))
    }
    for (width in c(375, 560, 768)) {
      check_width(width)
    }
  })
})

describe("framework examples", {
  it("runs golem runtime helpers with two independent nested modules", {
    skip_if_not_installed("golem")
    local_shiny_browser()
    app <- example_driver("golem")
    app$wait_for_js("document.querySelector('h1').textContent === 'Reviews in golem'")
    app$wait_for_js("!!mascot.host.state(document.getElementById('first-review-helper'))")
    app$click("first-review-complete")
    app$wait_for_js(
      "mascot.host.state(document.getElementById('first-review-helper')).status.text === 'Review complete'"
    )
    expect_identical(app$get_js("mascot.host.state(document.getElementById('first-review-helper')).mood"), "happy")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('second-review-helper')).mood"), "idle")
    app$click(selector = "#first-review-helper .mascot-menu-toggle")
    app$click(selector = "#first-review-helper [role=menuitem]")
    app$wait_for_js("document.getElementById('first-review-choice').textContent === 'about'")
    expect_identical(app$get_value(output = "first-review-choice"), "about")
    expect_identical(app$get_js("document.getElementById('second-review-choice').textContent"), "")
    app$click("second-review-complete")
    app$wait_for_js("mascot.host.state(document.getElementById('second-review-helper')).mood === 'happy'")
    expect_equal(app$get_js("document.querySelectorAll('script[src$=\"/mascot-host.js\"]').length"), 1)
  })
  it("runs plain Shiny view modules in the rhino-shaped folder", {
    local_shiny_browser()
    app <- example_driver("rhino")
    app$wait_for_js("!!mascot.host.state(document.getElementById('second-review-helper'))")
    app$click("second-review-complete")
    app$wait_for_js("mascot.host.state(document.getElementById('second-review-helper')).mood === 'happy'")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('first-review-helper')).mood"), "idle")
    app$click(selector = "#second-review-helper .mascot-menu-toggle")
    app$click(selector = "#second-review-helper [role=menuitem]")
    app$wait_for_js("document.getElementById('second-review-choice').textContent === 'about'")
    expect_identical(app$get_value(output = "second-review-choice"), "about")
    expect_identical(app$get_js("document.getElementById('first-review-choice').textContent"), "")
  })
})

describe("studio palette sync", {
  it("shows native palette labels, roles such as hair and badge, resting gestures and guide demonstrations", {
    local_shiny_browser()
    app <- example_driver("studio")
    app$wait_for_js(
      "document.querySelector('#palette option[value=original]')?.textContent === \"Tessa's own colours (night_teal)\""
    )
    expect_identical(app$get_js("document.getElementById('palette').value"), "original")
    expect_identical(app$get_js("document.querySelector('#gesture option:last-child').value"), "shimmer")
    expect_identical(
      app$get_js("document.querySelector('#gesture option:last-child').textContent"),
      "shimmer (resting animation)"
    )
    select_function <- function(fn) {
      if (isTRUE(app$get_js("document.getElementById('function_flyout').hidden"))) {
        app$click(selector = "#all_functions")
      }
      app$click(selector = sprintf('.pg-index-link[data-value="%s"]', fn))
      app$wait_for_js(sprintf("!document.querySelector('#studio_inspector [data-function=%s]').hidden", fn))
    }
    select_function("mascot_theme")
    app$wait_for_js("document.getElementById('colours-light_hair') && document.getElementById('colours-dark_badge')")
    for (role in c("hair", "badge", "iris", "body_shade", "hand")) {
      expect_true(app$get_js(sprintf(
        "!!document.getElementById('colours-light_%s') && !!document.getElementById('colours-dark_%s')",
        role,
        role
      )))
    }
    app$run_js("document.querySelector('[data-inspector-tab=guide]').click()")
    app$wait_for_js(
      "document.querySelector('[data-event=palette_swap]') && document.getElementById('palette_swap_demo')?.dataset.shownCharacter"
    )
    app$run_js("document.querySelector('[data-event=palette_swap][data-value=kept]').click()")
    app$wait_for_js("document.getElementById('palette_swap_result').textContent.includes('coral_navy kept for Sela')")
    app$wait_for_js("document.getElementById('palette_swap_demo').dataset.shownCharacter === 'sela'")
    expect_identical(
      app$get_js("mascot.host.state(document.getElementById('palette_swap_demo')).theme.palette"),
      "coral_navy"
    )
    app$run_js("document.querySelector('[data-event=palette_swap][data-value=dropped]').click()")
    app$wait_for_js("document.getElementById('palette_swap_result').textContent.includes('mascot_palette_dropped:')")
    app$wait_for_js("document.getElementById('palette_swap_demo').dataset.shownCharacter === 'knurl'")
    expect_null(app$get_js("mascot.host.state(document.getElementById('palette_swap_demo')).theme.palette"))
    select_function("mascot_popup_menu")
    # Picking a function shows its Controls; the try buttons are on its Guide, which the server draws once it shows
    app$run_js("document.querySelector('[data-inspector-tab=guide]').click()")
    app$wait_for_js(
      "!document.getElementById('inspector_guide').hasAttribute('aria-busy') && !!document.querySelector('#guide [data-guide-function=mascot_popup_menu] [data-event=menu_long_status]')"
    )
    for (corner in c("top-right", "bottom-right")) {
      app$run_js(sprintf("document.querySelector('[data-event=menu_long_status][data-value=\"%s\"]').click()", corner))
      app$wait_for_js(sprintf("document.querySelector('input[name=position]:checked')?.value === '%s'", corner))
      app$wait_for_js("document.getElementById('status_text').value.startsWith('Review in progress')")
      wait_studio_js(
        app,
        sprintf(
          "live.dataset.position === '%s'",
          corner
        )
      )
      app$run_js(
        "document.getElementById('live_frame').contentDocument.querySelector('#helper button[aria-haspopup=menu]').click()"
      )
      # Real rectangles: the open menu is visible and stays inside the frame, wherever the corner puts it.
      wait_studio_js(
        app,
        paste0(
          "(() => { const d = frame.document; ",
          "const menu = d.getElementById('helper_popup_menu'); if (!menu || menu.hidden) return false; ",
          "const r = menu.getBoundingClientRect(); const w = d.documentElement; ",
          "return r.top >= 0 && r.left >= 0 && r.bottom <= w.clientHeight && r.right <= w.clientWidth; })()"
        )
      )
      app$run_js(
        "document.getElementById('live_frame').contentDocument.querySelector('#helper button[aria-haspopup=menu]').click()"
      )
    }
    app$set_inputs(character = "neer")
    app$run_js("document.getElementById('show_anchors').click()")
    wait_studio_js(app, "frame.document.querySelectorAll('.pg-anchor-label').length === 14")
    app$set_inputs(character = "tessa")
    for (anchor in c("fringe", "lock", "stud_l", "stud_r")) {
      wait_studio_js(
        app,
        sprintf(
          "!!frame.document.querySelector('[data-anchor=\"%s\"]')",
          anchor
        )
      )
    }
  })
})
