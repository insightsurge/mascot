# Save only in a test-owned temporary directory; constructing a preview itself writes nothing.
local_preview_page <- function(page, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  file <- file.path(dir, "preview.html")
  htmltools::save_html(page, file, libdir = file.path(dir, "lib"))
  session <- local_chrome_session(env)
  session$Emulation$setDeviceMetricsOverride(width = 1500, height = 1000, deviceScaleFactor = 1, mobile = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(file)))
  evaluate <- function(code) {
    result <- session$Runtime$evaluate(code, returnByValue = TRUE, awaitPromise = TRUE)
    if (!is.null(result$exceptionDetails)) {
      stop(result$exceptionDetails$exception$description)
    }
    result$result$value
  }
  evaluate(paste0(
    "new Promise((resolve,reject)=>{const start=performance.now();const check=()=>{",
    "if(document.readyState==='complete' && document.querySelector('.mascot')?.dataset.shownMood)",
    "requestAnimationFrame(()=>requestAnimationFrame(resolve));",
    "else if(performance.now()-start>",
    # Shorter than the browser's own limit, so this clearer message is the one that reaches the test.
    browser_timeout - 5000,
    ")reject(new Error('preview did not mount'));",
    "else requestAnimationFrame(check)};check()})"
  ))
  attr(evaluate, "session") <- session
  evaluate
}

describe("mascot_preview() in Chrome", {
  it("draws every labelled mood and size with genuinely light/dark surfaces and steady faces", {
    skip_without_chrome()
    js <- local_preview_page(mascot_preview())
    expect_identical(js("document.querySelectorAll('.mascot canvas').length"), 40L)
    expect_identical(
      unlist(js("Array.from(document.querySelectorAll('.mascot')).map(el=>el.dataset.shownMood)"), use.names = FALSE),
      rep(rep(mascot_moods()$name, each = 4), 2)
    )
    expect_identical(
      unlist(js("Array.from(document.querySelectorAll('.mascot canvas')).map(el=>el.width)"), use.names = FALSE),
      rep(c(160L, 160L, 96L, 24L), 10)
    )
    expect_identical(
      unlist(js("Array.from(document.querySelectorAll('.mascot-status')).map(el=>el.textContent)"), use.names = FALSE),
      rep(
        rep(
          c(
            "Resting, ready for the next piece.",
            "Working out how the parts fit.",
            "That came together nicely.",
            "One part needs a closer look.",
            "Finished, and built to last."
          ),
          each = 4
        ),
        2
      )
    )
    expect_identical(
      unlist(
        js(
          "Array.from(document.querySelectorAll('.mascot-preview-mode')).map(el=>getComputedStyle(el).backgroundColor)"
        ),
        use.names = FALSE
      ),
      c("rgb(255, 255, 255)", "rgb(33, 37, 41)")
    )
    expect_true(js(
      "Array.from(document.querySelectorAll('.mascot')).every(el=>mascot.host.state(el).motion.reduced===true)"
    ))
    expect_true(js(
      "Array.from(document.querySelectorAll('.mascot')).every(el=>el.dataset.floating==='false' && el.querySelector('canvas').getBoundingClientRect().width>=24)"
    ))
    expect_identical(js("typeof window.Shiny"), "undefined")
    expect_true(js(
      "Array.from(document.querySelectorAll('.mascot-bubble-region')).every(el=>getComputedStyle(el).height==='0px' && getComputedStyle(el).visibility==='hidden')"
    ))
  })
  it("draws both supplied palettes despite source mode, keeps warnings and static placement/menu semantics", {
    skip_without_chrome()
    page <- suppressWarnings(mascot_preview(
      mood = "happy",
      size = 96,
      status = "Review complete",
      theme = mascot_theme(
        light = list(body = "white", sleeve = "#B53D78"),
        dark = list(body = "#F2A6CF"),
        mode = "light"
      )
    ))
    js <- local_preview_page(page)
    expect_identical(
      unlist(
        js("Array.from(document.querySelectorAll('.mascot')).map(el=>mascot.host.state(el).colours.body)"),
        use.names = FALSE
      ),
      rep(c("#FFFFFF", "#F2A6CF"), each = 4)
    )
    expect_identical(js("document.querySelectorAll('.mascot-button').length"), 0L)
    expect_identical(js("document.querySelectorAll('[data-mascot-click]').length"), 0L)
    expect_true(js(
      "Array.from(document.querySelectorAll('.mascot')).every(el=>!mascot.host.state(el).placement.floating)"
    ))
    expect_true(js(
      "Array.from(document.querySelectorAll('.mascot-status')).every(el=>el.textContent==='Review complete')"
    ))
    expect_identical(
      js("document.querySelector('.mascot-preview-contrast li').textContent"),
      "body: #FFFFFF against #FFFFFF, 1.00:1 (light)."
    )
    expect_identical(
      unlist(js("Array.from(document.querySelectorAll('.mascot canvas')).map(el=>el.width)"), use.names = FALSE),
      rep(c(96L, 160L, 96L, 24L), 2)
    )
  })
  it("keeps percentage and narrow-screen sizes in the requested column only", {
    skip_without_chrome()
    js <- local_preview_page(mascot_preview(
      mood = "idle",
      size = mascot_size("20%", small_screen = 96)
    ))
    widths <- unlist(js("Array.from(document.querySelectorAll('.mascot canvas')).map(el=>el.width)"), use.names = FALSE)
    expect_identical(widths[c(2:4, 6:8)], rep(c(160L, 96L, 24L), 2))
    expect_true(all(widths[c(1, 5)] >= 24))
    session <- attr(js, "session")
    session$Emulation$setDeviceMetricsOverride(width = 400, height = 900, deviceScaleFactor = 1, mobile = FALSE)
    js("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))")
    expect_identical(
      unlist(js("Array.from(document.querySelectorAll('.mascot canvas')).map(el=>el.width)"), use.names = FALSE),
      rep(c(96L, 160L, 96L, 24L), 2)
    )
    expect_true(js("Array.from(document.querySelectorAll('.mascot')).every(el=>!('detail' in mascot.host.state(el)))"))
  })
})

describe("mascot_preview() of a format-v1 character in Chrome", {
  it("draws every mood at 160, 160, 96 and 24 px offline, each in the detail band its width asks for", {
    skip_without_chrome()
    character <- runtime_character(runtime_data(edit = function(recipe) {
      recipe$moods$thinking$status <- "Reading the logs"
      recipe
    }))
    page <- mascot_preview(character = character)
    expect_false(grepl("https?://", as.character(page)))
    js <- local_preview_page(page)
    expect_identical(js("document.querySelectorAll('.mascot canvas').length"), 48L)
    expect_identical(js("typeof window.Shiny"), "undefined")
    expect_identical(
      unlist(js("Array.from(document.querySelectorAll('.mascot canvas')).map(el=>el.width)"), use.names = FALSE),
      rep(c(160L, 160L, 96L, 24L), 12)
    )
    # 160 px uses the full band, 96 px the small band, and 24 px the micro band.
    expect_identical(
      unlist(
        js("Array.from(document.querySelectorAll('.mascot')).map(el=>mascot.host.state(el).band)"),
        use.names = FALSE
      ),
      rep(c("full", "full", "small", "micro"), 12)
    )
    # The status and the accessible name come from the character's own moods.
    expect_identical(
      unlist(js("Array.from(document.querySelectorAll('.mascot-status')).map(el=>el.textContent)"), use.names = FALSE),
      rep(rep(c("Idle", "Reading the logs", "Happy", "Worried", "Celebrating", "Processing"), each = 4), 2)
    )
    expect_identical(
      js("document.querySelector('.mascot[data-mood=happy] canvas').getAttribute('aria-label')"),
      "Alpha Two, Happy"
    )
    expect_true(js(
      "Array.from(document.querySelectorAll('.mascot canvas')).every(canvas=>{
        const data=canvas.getContext('2d').getImageData(0,0,canvas.width,canvas.height).data;
        return data.some((value,index)=>index%4===3&&value>0);})"
    ))
    expect_true(js(
      "Array.from(document.querySelectorAll('.mascot')).every(el=>mascot.host.state(el).motion.reduced===true)"
    ))
  })
})

describe("mascot_preview() bubbles in Chrome", {
  it("keeps every bubble inside its own cell at each size, in light and dark, wide or narrow and scrolled", {
    skip_without_chrome()
    # Bubble boxes that leave their own cell, or show over another cell, as "cell" or "cell/other" indexes. Each
    # panel's table scrolls sideways and clips what is out of view, so only the visible parts are compared.
    overlaps <- "(() => {
      const cells = [...document.querySelectorAll('.mascot-preview-cell')];
      const visible = el => {
        const box = el.getBoundingClientRect(), clip = el.closest('.mascot-preview-scroll').getBoundingClientRect();
        return {left: Math.max(box.left, clip.left), right: Math.min(box.right, clip.right),
          top: Math.max(box.top, clip.top), bottom: Math.min(box.bottom, clip.bottom)};
      };
      const shown = cells.map(visible);
      const inside = (a, b) => a.left >= b.left - 0.5 && a.right <= b.right + 0.5 &&
        a.top >= b.top - 0.5 && a.bottom <= b.bottom + 0.5;
      const touch = (a, b) => a.left < b.right - 0.5 && a.right > b.left + 0.5 &&
        a.top < b.bottom - 0.5 && a.bottom > b.top + 0.5;
      const problems = [];
      cells.forEach((cell, i) => {
        const bubble = cell.querySelector('.mascot-bubble');
        if (bubble.hidden) return problems.push('hidden ' + i);
        if (!inside(bubble.getBoundingClientRect(), cell.getBoundingClientRect())) problems.push(String(i));
        const box = visible(bubble);
        shown.forEach((other, j) => { if (j !== i && touch(box, other)) problems.push(i + '/' + j); });
      });
      return problems;
    })()"
    settle <- "new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))"
    message <- "A longer message that wraps over several lines in the bubble."
    for (size in list(160, 24, mascot_size("20%"))) {
      js <- local_preview_page(mascot_preview(size = size, bubble = mascot_bubble(message, duration = Inf)))
      # Both panels (light and dark), every mood and all four size columns carry a bubble.
      expect_identical(js("document.querySelectorAll('.mascot-preview-cell .mascot-bubble:not([hidden])').length"), 40L)
      expect_identical(unlist(js(overlaps)), NULL, info = deparse1(unclass(size)))
      # A narrow window scrolls the tables sideways; bubbles in cells out of view must not move into view.
      session <- attr(js, "session")
      session$Emulation$setDeviceMetricsOverride(width = 700, height = 1000, deviceScaleFactor = 1, mobile = FALSE)
      js(settle)
      expect_true(js(
        "[...document.querySelectorAll('.mascot-preview-scroll')].every(el => el.scrollWidth > el.clientWidth)"
      ))
      expect_identical(unlist(js(overlaps)), NULL, info = deparse1(unclass(size)))
      js("document.querySelectorAll('.mascot-preview-scroll').forEach(el => { el.scrollLeft = el.scrollWidth; })")
      js(settle)
      expect_identical(unlist(js(overlaps)), NULL, info = deparse1(unclass(size)))
    }
  })
})

describe("bslib preview dark surface in Chrome", {
  it("paints the dark panel with body-bg-dark", {
    skip_without_chrome()
    skip_if_not_installed("bslib")
    theme <- bslib::bs_theme(version = 5, bg = "#fefefe", fg = "#222222")
    background <- bslib::bs_get_variables(theme, "body-bg-dark")[[1]]
    rgb <- grDevices::col2rgb(background)
    expected <- paste0("rgb(", paste(rgb[, 1], collapse = ", "), ")")
    expect_warning(page <- mascot_preview(mood = "idle", theme = theme), class = "mascot_contrast")
    js <- local_preview_page(page)
    expect_identical(
      js("getComputedStyle(document.querySelector('.mascot-preview-mode[data-bs-theme=dark]')).backgroundColor"),
      expected
    )
  })
})
