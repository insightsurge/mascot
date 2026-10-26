# Skips the whole file on CRAN or without Chrome, before any of its code runs.
skip_without_chrome()

# How far the mascot's canvas centre is from the preview card's centre, in CSS pixels.
mascot_offset_js <- paste0(
  "(() => { const c = document.querySelector('#theme_mascot canvas').getBoundingClientRect(); ",
  "const p = document.getElementById('theme_preview').getBoundingClientRect(); ",
  "return Math.abs((c.left + c.right) / 2 - (p.left + p.right) / 2); })()"
)

# The theme view in Chrome, started the way mascot_studio(view = "theme") starts it.
theme_driver <- function(width = 1280, height = 800, env = parent.frame()) {
  checkmate::assert_number(width, lower = 1)
  checkmate::assert_number(height, lower = 1)
  checkmate::assert_environment(env)
  app <- function() NULL
  body(app) <- quote({
    library(mascot)
    mascot::mascot_studio("theme", run = FALSE)
  })
  # The app belongs to the calling test, not to this helper: stop it when that test ends (#445).
  app_driver(app, width = width, height = height, env = env)
}

# Opens a tab of the theme view and waits until its panel shows. The click is repeated until then: a click that lands
# before the page's tab code is ready does nothing.
open_theme_tab <- function(app, tab) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_choice(tab, c("palette", "colours", "brand", "check"))
  app$wait_for_js(sprintf(
    paste0(
      "(() => { const pane = document.querySelector('#theme_tabs + .tab-content > .tab-pane[data-value=\"%1$s\"]'); ",
      "if (pane && pane.classList.contains('active')) return true; ",
      "document.querySelector('#theme_tabs a[data-value=\"%1$s\"]')?.click(); return false; })()"
    ),
    tab
  ))
}

describe("the theme view in a browser", {
  it("switches tabs, draws the chosen palette, copies its code and links back from the studio", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    # The header is one line: title, sentence, page switch, Start again; the sentence has the studio's text size.
    middles <- app$get_js(paste0(
      "['.theme-title', '.pg-sentence', '#page_mode', '#reset_all'].map((s) => { ",
      "const r = document.querySelector(s).getBoundingClientRect(); return (r.top + r.bottom) / 2; })"
    ))
    expect_lt(diff(range(unlist(middles))), 12)
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.pg-sentence')).fontSize"), "14px")
    # The mascot is centred in its card, also at phone width.
    expect_lt(app$get_js(mascot_offset_js), 3)
    # Phone width narrows the preview area to 375px and back.
    area <- "document.querySelector('.theme-preview-area').getBoundingClientRect().width"
    wide <- app$get_js(area)
    expect_gt(wide, 400)
    app$click(selector = "#preview_phone")
    app$wait_for_js("document.getElementById('theme_preview').classList.contains('is-phone')")
    expect_lte(app$get_js(area), 375)
    expect_identical(app$get_js("document.getElementById('preview_phone').getAttribute('aria-pressed')"), "true")
    expect_lt(app$get_js(mascot_offset_js), 3)
    app$click(selector = "#preview_phone")
    app$wait_for_js("!document.getElementById('theme_preview').classList.contains('is-phone')")
    expect_equal(app$get_js(area), wide)
    # The live code runs across the bottom, under the preview and the tabs.
    expect_true(app$get_js(paste0(
      "(() => { const box = (s) => document.querySelector(s).getBoundingClientRect(); ",
      "const code = box('.theme-code'), main = box('.theme-main'); ",
      "return code.top >= box('.theme-right').bottom && code.top >= box('.theme-preview').bottom && ",
      "Math.abs(code.width - main.width) < 2; })()"
    )))
    # Each tab shows its own panel.
    for (tab in c("colours", "brand", "check", "palette")) {
      open_theme_tab(app, tab)
    }
    # A palette card recolours the live mascot and the code.
    coral <- mascot_colour_roles("tessa", palette = "coral_navy")
    app$click(selector = "label.theme-palette-card:has(input[value=coral_navy])")
    app$wait_for_js("mascot.host.state(document.getElementById('theme_mascot')).theme.palette === 'coral_navy'")
    expect_identical(
      tolower(app$get_js("mascot.host.state(document.getElementById('theme_mascot')).colours.body")),
      tolower(coral$colour[coral$role == "body"])
    )
    app$wait_for_value(output = "theme_code", ignore = list(NULL, 'mascot("helper")'))
    expect_identical(app$get_value(output = "theme_code"), 'mascot("helper", theme = "coral_navy")')
    expect_identical(app$get_js("document.getElementById('start_from').value"), "coral_navy")
    # Copy puts the code shown on the clipboard.
    stub_studio_clipboard(app)
    app$click(selector = "[data-copy=theme_code]")
    app$wait_for_js("window.copied !== null")
    expect_identical(app$get_js("window.copied"), app$get_value(output = "theme_code"))
    # The studio's More menu opens this view in a new tab.
    link <- app$get_js(paste0(
      "fetch('?view=studio').then((r) => r.text()).then((html) => {",
      "const a = new DOMParser().parseFromString(html, 'text/html').getElementById('more_theme');",
      "return a ? [a.getAttribute('href'), a.target, a.textContent] : null; })"
    ))
    expect_identical(unlist(link), c("?view=theme", "_blank", "Theme a mascot"))
  })
  it("copies the code of the palette just clicked, not the code the page showed a moment before", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    open_theme_tab(app, "palette")
    app$wait_for_js("!!document.querySelector('label.theme-palette-card:has(input[value=coral_navy])')")
    stub_studio_clipboard(app)
    # When a palette card and Copy are clicked one right after the other, the page still shows the code before the card
    app$run_js(paste(
      "(() => { document.querySelector('label.theme-palette-card:has(input[value=coral_navy])').click();",
      "document.querySelector('[data-copy=theme_code]').click(); })()"
    ))
    # Then the code of the palette is what is copied
    app$wait_for_js("window.copied !== null")
    expect_identical(app$get_js("window.copied"), 'mascot("helper", theme = "coral_navy")')
    app$wait_for_js("document.querySelector('[data-copy=theme_code]').textContent === 'Copied'")
  })
  it("stacks the preview, the tabs and the code on a phone, and keeps the preview in view", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver(width = 375, height = 812)
    # A phone's scroll bars float over the page. A desktop window this narrow can keep a 15 px scroll bar (Linux,
    # Windows, a Mac with a mouse), and the tabs then scroll sideways, as designed for screens too narrow for them.
    app$get_chromote_session()$set_viewport_size(375, 812, mobile = TRUE)
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    top <- function(selector) app$get_js(sprintf("document.querySelector('%s').getBoundingClientRect().top", selector))
    expect_lt(top(".theme-preview"), top(".theme-stack"))
    expect_lt(top(".theme-stack"), top(".theme-right"))
    expect_lt(top(".theme-right"), top(".theme-code"))
    # The small preview shows the mascot centred in its card.
    expect_lt(app$get_js(mascot_offset_js), 3)
    # The page switch and Start again sit side by side at their own size, under the sentence.
    buttons <- app$get_js(paste0(
      "['#page_mode', '#reset_all'].map((s) => { const r = document.querySelector(s).getBoundingClientRect(); ",
      "return [r.top, r.width]; })"
    ))
    expect_lt(abs(buttons[[1]][[1]] - buttons[[2]][[1]]), 4)
    expect_lt(buttons[[1]][[2]] + buttons[[2]][[2]], 250)
    expect_true(app$get_js(
      "document.querySelector('.theme-page').scrollWidth <= document.querySelector('.theme-page').clientWidth"
    ))
    # The four tabs fit on one line.
    expect_true(app$get_js(
      "(() => { const n = document.querySelector('#theme_tabs'); return n.scrollWidth <= n.clientWidth; })()"
    ))
    # Scrolled down to the tabs, the preview stays at the top.
    app$run_js("document.querySelector('.theme-page').scrollTop = 900")
    app$wait_for_js("document.querySelector('.theme-page').scrollTop > 0")
    expect_lt(abs(top(".theme-preview")), 2)
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.theme-preview')).position"), "sticky")
  })
})

describe("the forced mode in a browser", {
  it("comes back after a round trip through bs_theme()", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    open_theme_tab(app, "colours")
    app$wait_for_js("!!document.querySelector('input[name=mode][value=dark]')")
    # Given Force the mascot: dark
    app$click(selector = "input[name=mode][value=dark]")
    app$wait_for_js("document.getElementById('theme_code').textContent.includes('mode = \"dark\"')")
    # When the theme goes to bs_theme() and back
    open_theme_tab(app, "brand")
    app$click(selector = "[data-event=brand_source][data-value=bslib]")
    app$wait_for_js("document.getElementById('theme_code').textContent.includes('bs_theme')")
    expect_true(app$get_js("document.querySelector('input[name=mode][value=dark]').checked"))
    app$click(selector = "#brand_source [data-event=brand_source][data-value=mascot]")
    # Then the radio and the code say dark again
    app$wait_for_js("document.getElementById('theme_code').textContent.includes('mode = \"dark\"')")
    app$wait_for_js("!document.querySelector('#mode_ui fieldset').disabled")
    expect_true(app$get_js("document.querySelector('input[name=mode][value=dark]').checked"))
    expect_identical(app$get_value(input = "mode"), "dark")
  })
})

describe("the colour tiles in a browser", {
  it("show the reset only on a changed tile, and hide the own-colour hint", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    open_theme_tab(app, "colours")
    app$wait_for_js("!!document.getElementById('colours-light_body')")
    tile <- "document.getElementById('colours-light_body').closest('.pg-role')"
    reset_shown <- sprintf("getComputedStyle(%s.querySelector('.pg-role-reset')).display !== 'none'", tile)
    expect_false(app$get_js(reset_shown))
    expect_identical(app$get_js(sprintf("getComputedStyle(%s.querySelector('.pg-role-leader')).display", tile)), "none")
    # Given a changed colour
    app$run_js("const i = document.getElementById('colours-light_body'); i.value = '#c2185b'; $(i).trigger('change');")
    # Then the tile is marked and offers its reset; the reset puts it back
    app$wait_for_js(sprintf("%s.classList.contains('is-changed')", tile))
    expect_true(app$get_js(reset_shown))
    # A keyboard user presses Enter on the reset button: the tile goes back, and the focus moves to its picker.
    app$run_js(sprintf("%s.querySelector('.pg-role-reset').focus()", tile))
    expect_true(app$get_js(sprintf("document.activeElement === %s.querySelector('.pg-role-reset')", tile)))
    chrome <- app$get_chromote_session()
    chrome$Input$dispatchKeyEvent(
      type = "keyDown",
      key = "Enter",
      code = "Enter",
      windowsVirtualKeyCode = 13,
      text = "\r"
    )
    chrome$Input$dispatchKeyEvent(type = "keyUp", key = "Enter", code = "Enter", windowsVirtualKeyCode = 13)
    app$wait_for_js(sprintf("!%s.classList.contains('is-changed')", tile))
    app$wait_for_js("document.activeElement === document.getElementById('colours-light_body')")
    # More parts is one grid of tiles too, with no heading per group.
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.pg-role-group-title')).display"), "none")
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.pg-role-group')).display"), "contents")
    # The tiles sit in a grid of columns.
    expect_gt(
      app$get_js(sprintf(
        "getComputedStyle(%s.parentElement).gridTemplateColumns.split(' ').length",
        tile
      )),
      1
    )
  })
})

describe("the Brand colours tab for a character with no brand parts", {
  it("shows no brand pickers for Neer in a browser", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    open_theme_tab(app, "brand")
    app$wait_for_js("document.getElementById('brand_primary').offsetParent !== null")
    app$set_inputs(character = "neer")
    app$wait_for_js("document.getElementById('brand_primary').offsetParent === null")
    expect_false(app$get_js("[...document.querySelectorAll('.theme-brand-sample')].some((b) => b.offsetParent)"))
    app$click(selector = "[data-event=go_tab][data-value=colours]")
    app$wait_for_js("document.querySelector('#theme_tabs a[data-value=colours]').classList.contains('active')")
  })
})

describe("the Check tab's slow buttons in a browser", {
  it("say they are busy until their result shows", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    open_theme_tab(app, "check")
    for (case in list(
      c("check_contrast", "Checking…", "Check contrast"),
      c("check_preview", "Building…", "Show every mood")
    )) {
      # When the focused button is clicked, it says so at once, and keeps keyboard focus
      state <- app$get_js(sprintf(
        paste(
          "(() => { const b = document.getElementById('%s'); b.focus(); b.click();",
          "return [b.textContent, b.getAttribute('aria-busy'), b.getAttribute('aria-disabled'), document.activeElement.id]; })()"
        ),
        case[[1]]
      ))
      expect_identical(unlist(state), c(case[[2]], "true", "true", case[[1]]), info = case[[1]])
      # Then it is back once the result shows
      app$wait_for_js(sprintf("!document.getElementById('%s').hasAttribute('aria-busy')", case[[1]]))
      expect_identical(app$get_js(sprintf("document.getElementById('%s').textContent", case[[1]])), case[[3]])
      expect_null(app$get_js(sprintf("document.getElementById('%s').getAttribute('aria-disabled')", case[[1]])))
      expect_true(app$get_js(sprintf("document.getElementById('%s_ui').textContent.trim().length > 0", case[[1]])))
    }
  })
  it("keep Show every mood busy until the page inside its frame has loaded", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    open_theme_tab(app, "check")
    # Given a record of what the page shows at every frame it draws: is the button busy, is there a frame, is its page
    # loaded (the page marks a frame data-loaded when that happens)
    app$run_js(paste(
      "window.buttonSamples = [];",
      "const sample = () => { const frame = document.querySelector('iframe.theme-preview-page');",
      "  window.buttonSamples.push({ busy: document.getElementById('check_preview').hasAttribute('aria-busy'),",
      "    frame: !!frame, loaded: frame ? frame.dataset.loaded === 'true' : null });",
      "  requestAnimationFrame(sample); };",
      "sample();"
    ))
    # When it is clicked, once and again
    for (click in 1:2) {
      click_studio_busy(app, "check_preview")
    }
    # Then no drawn frame showed a frame still loading its page with the button free
    early <- app$get_js("window.buttonSamples.filter((s) => !s.busy && s.frame && s.loaded === false).length")
    expect_identical(early, 0L)
    expect_true(app$get_js("window.buttonSamples.some((s) => s.busy && s.frame && s.loaded === false)"))
  })
  it("stay busy until the result of their own click is drawn, whatever the server says in between", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    # Given a slow button and its output. The script plays the server's side; each step waits for a later task, as
    # Shiny's asynchronous drawing would.
    states <- app$get_js(paste(
      "(async () => {",
      "document.body.insertAdjacentHTML('beforeend', '<button id=\"slow\" data-busy-label=\"Working\"",
      "data-busy-output=\"slow_ui\">Run</button><div id=\"slow_ui\"></div>');",
      "const b = document.getElementById('slow'), states = [];",
      "const note = () => states.push(b.textContent + ' ' + b.hasAttribute('aria-disabled'));",
      "const later = () => new Promise((resolve) => setTimeout(resolve, 0));",
      "const draw = (text, click) =>",
      "  $('#slow_ui').html(`<p>${text}</p><span hidden data-busy-done=\"${click}\"></span>`);",
      # When it is clicked during an earlier update, which then ends
      "$(document).trigger('shiny:busy'); b.click(); note(); $(document).trigger('shiny:idle'); await later(); note();",
      "const click = Number(b.dataset.busyClick);",
      # and the answer to an earlier click (or to a settings change) is drawn
      "draw('Old', click - 1); await later(); note();",
      # and the value for this click arrives, which Shiny draws only afterwards
      "$('#slow_ui').trigger($.Event('shiny:value', { name: 'slow_ui', value: {} })); await later(); note();",
      # and then it is drawn
      "draw('Done', click); await later(); note();",
      "return states; })()"
    ))
    # Then it stays busy until the result of its own click shows
    expect_identical(unlist(states), c(rep("Working true", 4), "Run false"))
  })
  it("come back once their output shows an error, and number each click anew", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    result <- app$get_js(paste(
      "(async () => {",
      "document.body.insertAdjacentHTML('beforeend', '<button id=\"slow\" data-busy-label=\"Working\"",
      "data-busy-output=\"slow_ui\">Run</button><div id=\"slow_ui\"></div>');",
      "const b = document.getElementById('slow'), states = [], clicks = [];",
      "const note = () => states.push(b.textContent + ' ' + b.hasAttribute('aria-disabled'));",
      "const later = () => new Promise((resolve) => setTimeout(resolve, 0));",
      "const fail = () => $('#slow_ui').trigger($.Event('shiny:error', { name: 'slow_ui', error: { message: 'x' } }));",
      # When it is clicked and its output shows an error, twice
      "for (let i = 0; i < 2; i++) {",
      "  b.click(); clicks.push(b.dataset.busyClick); note(); fail(); await later(); note();",
      "}",
      "return { states, clicks, left: b.dataset.busyClick === undefined }; })()"
    ))
    # Then it comes back each time, and the second click has a number of its own
    expect_identical(unlist(result$states), rep(c("Working true", "Run false"), 2))
    expect_length(unique(unlist(result$clicks)), 2L)
    expect_true(result$left)
  })
})

describe("the Check tab's slow buttons and the silent errors Shiny sends when the tab is shown", {
  it("stay busy when a silent validation error for their output arrives after the click", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    result <- app$get_js(paste(
      "(async () => {",
      "document.body.insertAdjacentHTML('beforeend', '<button id=\"slow\" data-busy-label=\"Working\"",
      "data-busy-output=\"slow_ui\">Run</button><div id=\"slow_ui\"></div>');",
      "const b = document.getElementById('slow'), states = [];",
      "const note = () => states.push(b.textContent + ' ' + b.hasAttribute('aria-disabled'));",
      "const later = () => new Promise((resolve) => setTimeout(resolve, 0));",
      "const fail = (error) => $('#slow_ui').trigger($.Event('shiny:error', { name: 'slow_ui', error }));",
      # When it is clicked and the stale silent error for its output (as Shiny sends it, with no message) arrives
      "b.click(); note();",
      "fail({ message: '', type: ['shiny.silent.error', 'validation'] }); await later(); note();",
      "fail({ message: 'x', type: ['shiny.silent.error'] }); await later(); note();",
      # and then the result of its own click is drawn
      "$('#slow_ui').html(`<p>Done</p><span hidden data-busy-done=\"${b.dataset.busyClick}\"></span>`); await later(); note();",
      "return states; })()"
    ))
    # Then it stays busy until its result shows
    expect_identical(unlist(result), c(rep("Working true", 3), "Run false"))
  })
})

describe("a translucent colour typed half way, in a browser", {
  it("gets a note under its text box until it is valid", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    app$set_inputs(character = "knurl")
    open_theme_tab(app, "colours")
    app$wait_for_js("!!document.getElementById('colours-light_shine_translucent')")
    box <- "document.getElementById('colours-light_shine_translucent')"
    app$run_js(sprintf("const b = %s; b.value = 'rgba(1,2'; $(b).trigger('change');", box))
    app$wait_for_js("!!document.getElementById('colours-light_shine_translucent_problem')")
    expect_identical(app$get_js(sprintf("%s.getAttribute('aria-invalid')", box)), "true")
    expect_match(
      app$get_js("document.getElementById('colours-light_shine_translucent_problem').textContent"),
      "Not a valid colour yet",
      fixed = TRUE
    )
    app$run_js(sprintf("const b = %s; b.value = 'rgba(1, 2, 3, 0.5)'; $(b).trigger('change');", box))
    app$wait_for_js("!document.getElementById('colours-light_shine_translucent_problem')")
    expect_null(app$get_js(sprintf("%s.getAttribute('aria-invalid')", box)))
  })
})
