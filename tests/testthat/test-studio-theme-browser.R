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

# Keeps the colour binding's 250 ms timer waiting, even on a slow test machine. Immediate input sends still work and
# can cancel their waiting timer. Timers with other delays run normally. Stopping the driver clears the hold.
hold_theme_colour_debounce <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$run_js(paste(
    "(() => { const set = window.setTimeout.bind(window), clear = window.clearTimeout.bind(window);",
    "const hold = window.themeColourDebounce = { timers: new Map(), next: -1,",
    "  release() { window.setTimeout = set; window.clearTimeout = clear;",
    "    const waiting = [...this.timers.values()]; this.timers.clear(); waiting.forEach((run) => run()); } };",
    "window.setTimeout = (run, delay, ...args) => {",
    "  if (delay !== 250) return set(run, delay, ...args);",
    "  const id = hold.next--; hold.timers.set(id, () => run(...args)); return id; };",
    "window.clearTimeout = (id) => { if (!hold.timers.delete(id)) clear(id); }; })()"
  ))
}

# Shiny draws asynchronously. Finish each held reply before dispatching the next, as its socket queue does; keep
# incoming replies held during the drain.
release_theme_replies <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$get_js(paste(
    "(async () => { const hold = window.studioReplies;",
    "while (hold.held.length) await hold.dispatch(hold.held.shift());",
    "hold.on = false; return true; })()"
  ))
  invisible(NULL)
}

describe("actions with a colour still waiting in the theme view", {
  # #574 case 1
  it("copies the colour edited immediately before Copy", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    open_theme_tab(app, "colours")
    app$wait_for_js("Shiny.shinyapp.$inputValues['colours-light_body'] !== undefined")
    stub_studio_clipboard(app)
    hold_theme_colour_debounce(app)
    app$run_js(paste(
      "(() => { const field = document.getElementById('colours-light_body'); field.value = '#123456';",
      "field.dispatchEvent(new Event('input', { bubbles: true }));",
      "document.querySelector('[data-copy=theme_code]').click(); })()"
    ))
    app$wait_for_js("window.copied !== null")
    expect_match(app$get_js("window.copied"), 'body = "#123456"', fixed = TRUE)
    expect_identical(app$get_js("window.copied"), app$get_js("document.getElementById('theme_code').textContent"))
  })

  # #574 case 1
  it("builds every mood with the colour edited immediately before Show every mood", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    open_theme_tab(app, "check")
    app$wait_for_js("Shiny.shinyapp.$inputValues['colours-light_body'] !== undefined")
    hold_theme_colour_debounce(app)
    app$run_js(paste(
      "(() => { const field = document.getElementById('colours-light_body'); field.value = '#123456';",
      "field.dispatchEvent(new Event('input', { bubbles: true }));",
      "document.getElementById('check_preview').click(); })()"
    ))
    app$wait_for_js(paste(
      "!!document.querySelector('#check_preview_ui [data-busy-done]') &&",
      "!document.getElementById('check_preview').hasAttribute('aria-busy')"
    ))
    expect_match(
      app$get_js("document.querySelector('#check_preview_ui .theme-code-text').textContent"),
      'body = "#123456"',
      fixed = TRUE
    )
    expect_false(app$get_js("document.getElementById('check_preview_ui').textContent.includes('settings changed')"))
  })

  # #574 case 1
  it("checks the colour edited immediately before Check contrast", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    open_theme_tab(app, "check")
    app$wait_for_js("Shiny.shinyapp.$inputValues['colours-light_rim'] !== undefined")
    hold_theme_colour_debounce(app)
    # This rim colour has low contrast on the light page: the contrast result must list it.
    app$run_js(paste(
      "(() => { const field = document.getElementById('colours-light_rim'); field.value = '#f5e6c8';",
      "field.dispatchEvent(new Event('input', { bubbles: true }));",
      "document.getElementById('check_contrast').click(); })()"
    ))
    app$wait_for_js(paste(
      "!!document.querySelector('#check_contrast_ui [data-busy-done]') &&",
      "!document.getElementById('check_contrast').hasAttribute('aria-busy')"
    ))
    result <- app$get_js("document.getElementById('check_contrast_ui').textContent")
    expect_match(result, "hard to see", fixed = TRUE)
    expect_match(tolower(result), "#f5e6c8", fixed = TRUE)
    expect_false(grepl("settings changed", result, fixed = TRUE))
  })
})

describe("brand samples and immediate copying in the theme view", {
  it("applies a sample without reporting the server-set brand pickers as edits", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    open_theme_tab(app, "brand")
    app$wait_for_js("Shiny.shinyapp.$inputValues.brand_secondary !== undefined")
    stub_studio_clipboard(app)
    hold_theme_colour_debounce(app)
    app$run_js(paste(
      "window.brandEdits = [];",
      "$(document).on('shiny:inputchanged.brandEdits', (event) => {",
      "if (['brand_primary', 'brand_secondary'].includes(event.name)) window.brandEdits.push(event.name); });",
      "document.querySelector('[data-event=brand_sample][data-value=\"#0f766e,#c2410c\"]').click();"
    ))
    app$wait_for_js(paste(
      "document.getElementById('brand_primary').value === '#0f766e' &&",
      "document.getElementById('brand_secondary').value === '#c2410c'"
    ))
    # Release any debounce the messages started, then Copy also flushes any picker marked as waiting.
    app$run_js(paste(
      "window.themeColourDebounce.release();",
      "document.querySelector('[data-copy=theme_code]').click();"
    ))
    app$wait_for_js("window.copied !== null")
    expect_length(app$get_js("window.brandEdits"), 0L)
    expect_identical(
      app$get_js("window.copied"),
      'mascot("helper", theme = list(body = "#0f766e", rim = "#c2410c"))'
    )
    # Returning to the colour held before the sample is a real edit, even without an echo of the sample.
    studio_colour(app, "brand_primary", "#1f6feb")
    app$run_js("window.copied = null; document.querySelector('[data-copy=theme_code]').click()")
    app$wait_for_js("window.copied !== null")
    expect_match(app$get_js("window.copied"), 'body = "#1f6feb"', fixed = TRUE)
  })

  # #574 case 2
  it("copies a sample pair before the pickers can report it back", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    open_theme_tab(app, "brand")
    app$wait_for_js("Shiny.shinyapp.$inputValues.brand_secondary !== undefined")
    stub_studio_clipboard(app)
    hold_theme_colour_debounce(app)
    hold_studio_replies(app)
    app$run_js(paste(
      "document.querySelector('[data-event=brand_sample][data-value=\"#0f766e,#c2410c\"]').click();",
      "document.querySelector('[data-copy=theme_code]').click();"
    ))
    wait_studio_reply(app, "!!reply.custom?.['studio:copy']")
    release_theme_replies(app)
    app$wait_for_js("window.copied !== null")
    expect_identical(
      app$get_js("window.copied"),
      'mascot("helper", theme = list(body = "#0f766e", rim = "#c2410c"))'
    )
  })
})

describe("palette choices while a theme reply is waiting", {
  it("does not take the palette cards' own mascots for palette choices", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    open_theme_tab(app, "palette")
    # Each card draws a mascot, which is a Shiny input of its own and reports its state as it is drawn.
    app$wait_for_js(paste(
      "[...document.querySelectorAll('.theme-card-mascot [data-mascot-id], .theme-card-mascot .shiny-bound-input')]",
      ".length > 0"
    ))
    app$wait_for_js("!!mascot.host.state(document.querySelector('.theme-card-mascot .shiny-bound-input'))")
    expect_null(app$get_js("Shiny.shinyapp.$inputValues.theme_palette_revision ?? null"))
    expect_identical(
      app$get_js(
        "document.getElementById('colours-light_body').closest('[data-colour-revision]').dataset.colourRevision"
      ),
      "1"
    )
  })

  it("uses the character's palette options without applying their older selected value", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    open_theme_tab(app, "colours")
    app$set_inputs(start_from = "forest")
    hold_studio_replies(app)
    app$run_js(paste(
      "{ const character = document.getElementById('character'); character.value = 'sela';",
      "$(character).trigger('change'); }"
    ))
    wait_studio_reply(app, "reply.inputMessages?.some((item) => item.id === 'start_from' && item.message.options)")
    app$run_js(paste(
      "{ const menu = document.getElementById('start_from'); menu.value = 'coral_navy'; $(menu).trigger('change'); }"
    ))
    wait_studio_reply(app, "reply.values?.theme_code?.includes('coral_navy')")
    release_theme_replies(app)
    app$wait_for_js("document.getElementById('theme_code').textContent.includes('coral_navy')")
    expect_match(app$get_js("document.getElementById('start_from').options[0].textContent"), "Sela", fixed = TRUE)
    expect_identical(app$get_js("document.getElementById('start_from').value"), "coral_navy")
    stub_studio_clipboard(app)
    app$run_js("document.querySelector('[data-copy=theme_code]').click()")
    app$wait_for_js("window.copied !== null")
    expect_match(app$get_js("window.copied"), 'theme = "coral_navy"', fixed = TRUE)
  })

  it("copies own colours chosen immediately after the server sets the menu to a palette", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    open_theme_tab(app, "palette")
    app$click(selector = "label.theme-palette-card:has(input[value=forest])")
    app$wait_for_js("document.getElementById('start_from').value === 'forest'")
    stub_studio_clipboard(app)
    app$run_js(paste(
      "{ const menu = document.getElementById('start_from'); menu.value = 'original'; $(menu).trigger('change');",
      "document.querySelector('[data-copy=theme_code]').click(); }"
    ))
    app$wait_for_js("window.copied !== null")
    expect_identical(app$get_js("window.copied"), 'mascot("helper")')
  })

  # #574 case 3
  it("keeps the Coral Navy card selected when the reply to Forest from the menu arrives late", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    open_theme_tab(app, "colours")
    app$wait_for_js("Shiny.shinyapp.$inputValues.start_from === 'original'")
    hold_studio_replies(app)
    app$run_js(paste(
      "{ const menu = document.getElementById('start_from'); menu.value = 'forest';",
      "$(menu).trigger('change'); }"
    ))
    wait_studio_reply(app, "reply.values?.theme_code?.includes('forest')")
    open_theme_tab(app, "palette")
    # Keep replies to Coral Navy held too, so they cannot hide a jump back caused by the Forest reply.
    after_reply <- app$get_js(paste(
      "(async () => { document.querySelector('label.theme-palette-card:has(input[value=coral_navy])').click();",
      "const hold = window.studioReplies;",
      "for (const message of hold.held.splice(0)) await hold.dispatch(message);",
      "return document.querySelector('#palette_grid input:checked').value; })()"
    ))
    expect_identical(after_reply, "coral_navy")
  })
})

describe("colour pickers replaced while an edit is waiting", {
  choices <- c(
    menu = "const menu = document.getElementById('start_from'); menu.value = 'forest'; $(menu).trigger('change');",
    card = "document.querySelector('label.theme-palette-card:has(input[value=forest])').click();",
    character = "const character = document.getElementById('character'); character.value = 'sela'; $(character).trigger('change');"
  )
  for (choice in names(choices)) {
    it(paste("keeps a colour edited immediately before a", choice, "choice"), {
      local_shiny_browser()
      skip_if_not_installed("bslib")
      app <- theme_driver()
      open_theme_tab(app, "colours")
      app$wait_for_js("Shiny.shinyapp.$inputValues['colours-light_body'] !== undefined")
      stub_studio_clipboard(app)
      hold_theme_colour_debounce(app)
      app$run_js(paste(
        "(() => { const field = document.getElementById('colours-light_body'); window.pickerBeforeChoice = field;",
        "field.value = '#123456'; field.dispatchEvent(new Event('input', { bubbles: true }));",
        choices[[choice]],
        "})()"
      ))
      app$wait_for_js(paste(
        "document.getElementById('colours-light_body') !== window.pickerBeforeChoice &&",
        "document.getElementById('colours-light_body').value === '#123456'"
      ))
      app$run_js("document.querySelector('[data-copy=theme_code]').click()")
      app$wait_for_js("window.copied !== null")
      expect_match(app$get_js("window.copied"), 'body = "#123456"', fixed = TRUE)
      expect_match(
        app$get_js("window.copied"),
        if (choice == "character") 'character = "sela"' else 'palette = "forest"',
        fixed = TRUE
      )
    })
  }

  # #574 case 4
  it("does not apply an edit from Tessa's old picker to Sela", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    open_theme_tab(app, "colours")
    app$wait_for_js("Shiny.shinyapp.$inputValues['colours-light_body'] !== undefined")
    stub_studio_clipboard(app)
    hold_theme_colour_debounce(app)
    hold_studio_replies(app)
    app$run_js(paste(
      "window.oldThemePicker = document.getElementById('colours-light_body');",
      "const character = document.getElementById('character'); character.value = 'sela'; $(character).trigger('change');"
    ))
    wait_studio_reply(app, "!!reply.values?.['colours-light']")
    # The user still sees Tessa's picker while Sela's layout is on its way.
    app$run_js(paste(
      "window.oldThemePicker.value = '#123456';",
      "window.oldThemePicker.dispatchEvent(new Event('input', { bubbles: true }));"
    ))
    release_theme_replies(app)
    app$wait_for_js(paste(
      "document.getElementById('colours-light_body') !== window.oldThemePicker &&",
      "document.getElementById('theme_code').textContent.includes('sela')"
    ))
    app$run_js(paste(
      "window.themeColourDebounce.release();",
      "document.querySelector('[data-copy=theme_code]').click();"
    ))
    app$wait_for_js("window.copied !== null")
    expect_false(grepl("#123456", app$get_js("window.copied"), fixed = TRUE))
    sela <- mascot_colour_roles("sela")
    expect_identical(
      tolower(app$get_js("document.getElementById('colours-light_body').value")),
      tolower(sela$colour[sela$role == "body"])
    )
  })
})

describe("invalid colour text after a palette redraw", {
  # #574 case 5
  it("keeps the warning beside the invalid value that the redraw preserves", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$set_inputs(character = "knurl")
    open_theme_tab(app, "colours")
    app$wait_for_js("!!document.getElementById('colours-light_shine_translucent')")
    studio_colour(app, "colours-light_shine_translucent", "rgba(1,2")
    app$wait_for_js("!!document.getElementById('colours-light_shine_translucent_problem')")
    app$run_js("window.invalidThemePicker = document.getElementById('colours-light_shine_translucent')")
    palettes <- mascot_palettes("knurl")
    app$set_inputs(start_from = palettes$name[palettes$source != "native"][[1]])
    app$wait_for_js(paste(
      "(() => { const field = document.getElementById('colours-light_shine_translucent');",
      "return field && field !== window.invalidThemePicker && field.value === 'rgba(1,2'; })()"
    ))
    expect_identical(
      app$get_js("document.getElementById('colours-light_shine_translucent').getAttribute('aria-invalid')"),
      "true"
    )
    expect_identical(
      app$get_js("document.getElementById('colours-light_shine_translucent').getAttribute('aria-describedby')"),
      "colours-light_shine_translucent_problem"
    )
    expect_match(
      app$get_js("document.getElementById('colours-light_shine_translucent_problem')?.textContent ?? ''"),
      "Not a valid colour yet",
      fixed = TRUE
    )
  })
})

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
  # #574 case 6
  it("keep Show every mood busy through a held reply and until its frame loads", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- theme_driver()
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    open_theme_tab(app, "check")
    # A mutation observer sees each inserted frame before its load event, even when no animation frame falls in that
    # gap. Holding the server's reply also gives Building a stable state to inspect.
    app$run_js(paste(
      "window.loadingButtons = [];",
      "new MutationObserver(() => { const frame = document.querySelector('#check_preview_ui iframe');",
      "  if (!frame || frame.dataset.loaded === 'true') return;",
      "  const button = document.getElementById('check_preview');",
      "  window.loadingButtons.push({ click: button.dataset.busyClick ?? null,",
      "    busy: button.getAttribute('aria-busy'), disabled: button.getAttribute('aria-disabled') });",
      "}).observe(document.getElementById('check_preview_ui'), { childList: true, subtree: true });"
    ))
    for (build in 1:2) {
      hold_studio_replies(app)
      click <- app$get_js(paste(
        "(() => { const button = document.getElementById('check_preview'); button.click();",
        "return button.dataset.busyClick; })()"
      ))
      wait_studio_reply(app, "!!reply.values?.check_preview_ui")
      # The server has answered, but that answer has not been drawn yet.
      expect_identical(app$get_js("document.getElementById('check_preview').textContent"), "Building\u2026")
      expect_identical(app$get_js("document.getElementById('check_preview').getAttribute('aria-busy')"), "true")
      expect_identical(app$get_js("document.getElementById('check_preview').getAttribute('aria-disabled')"), "true")
      release_theme_replies(app)
      app$wait_for_js(sprintf(
        paste(
          "!!document.querySelector('#check_preview_ui [data-busy-done=\"%s\"]') &&",
          "!!document.querySelector('#check_preview_ui iframe[data-loaded=true]') &&",
          "!document.getElementById('check_preview').hasAttribute('aria-busy')"
        ),
        click
      ))
      expect_true(app$get_js(sprintf(
        "window.loadingButtons.some((sample) => sample.click === '%s')",
        click
      )))
      expect_identical(app$get_js("document.getElementById('check_preview').textContent"), "Show every mood")
    }
    expect_true(app$get_js(
      "window.loadingButtons.every((sample) => sample.busy === 'true' && sample.disabled === 'true')"
    ))
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
