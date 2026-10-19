# I1 app scenarios: a checked format-v1 character through real Shiny, in real Chrome. The characters are internal helper
# objects handed to the app process in a file (see helper-runtime.R); nothing here uses a public custom-character API.

# Built when a test first uses them, so a run without Chrome (which skips every test here) pays nothing.
delayedAssign("alpha", runtime_character())
delayedAssign("other", runtime_character(runtime_other()))
delayedAssign("table", list(alpha_two = runtime_statuses(alpha), alpha_three = runtime_statuses(other)))

describe("a format-v1 character through the Shiny state protocol", {
  it("I1 restores the newest status and label after 100 rapid updates and a remount, keeps a dismissed bubble dismissed, and plays a gesture queued while unmounted once", {
    local_shiny_browser()
    local_app_characters(list(alpha = alpha))
    app <- app_driver(function() {
      library(mascot)
      characters <- readRDS(Sys.getenv("MASCOT_I1_CHARACTERS"))
      ui <- shiny::fluidPage(
        shiny::uiOutput("slot"),
        shiny::actionButton("hundred", "One hundred"),
        shiny::actionButton("remount", "Remount"),
        shiny::actionButton("remove", "Remove"),
        shiny::actionButton("show", "Show"),
        shiny::actionButton("prepare", "Prepare"),
        shiny::actionButton("happy", "Happy"),
        shiny::actionButton("follow", "Follow mood")
      )
      server <- function(input, output, session) {
        visible <- shiny::reactiveVal(TRUE)
        edition <- shiny::reactiveVal(0)
        output$slot <- shiny::renderUI({
          edition()
          if (visible()) {
            mascot(
              "helper",
              character = characters$alpha,
              placement = "inline",
              bubble = mascot_bubble("Hello", duration = Inf)
            )
          }
        })
        shiny::observeEvent(input$hundred, {
          for (i in 1:100) {
            update_mascot("helper", status = paste("Status", i))
          }
        })
        shiny::observeEvent(input$remount, edition(edition() + 1))
        shiny::observeEvent(input$remove, visible(FALSE))
        shiny::observeEvent(input$show, visible(TRUE))
        shiny::observeEvent(input$prepare, update_mascot("helper", gesture = "nod", status = "Prepared"))
        shiny::observeEvent(input$happy, update_mascot("helper", mood = "happy"))
        shiny::observeEvent(input$follow, update_mascot("helper", status = mascot_status()))
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    app$wait_for_js("window.mascot?.host.state(document.getElementById('helper'))?.snapshot.applied_revision > 0")
    app$run_js(
      "window.gestures = [];
      const mount = mascot.mount;
      mascot.mount = (...args) => { const c = mount(...args), g = c.gesture;
        c.gesture = (name) => { gestures.push(name); return g(name); }; return c; };
      window.helper = () => document.getElementById('helper');
      window.read = () => mascot.host.state(helper());"
    )
    # It draws as a format-v1 character, and the status and label are the character's own.
    expect_identical(app$get_js("helper().dataset.shownCharacter"), "alpha_two")
    expect_identical(app$get_js("helper().querySelector('.mascot-status').textContent"), "Idle")
    expect_identical(app$get_js("helper().querySelector('canvas').getAttribute('aria-label')"), "Alpha Two, Idle")
    expect_identical(app$get_js("read().band"), "full")
    expect_true(app$get_js(
      "(() => { const c = helper().querySelector('canvas'); const d = c.getContext('2d').getImageData(0,0,c.width,c.height).data;
        return d.some((v, i) => i % 4 === 3 && v > 0); })()"
    ))
    # Given a bubble the visitor dismissed, one hundred updates in one flush, and a remount of the element.
    app$run_js("helper().querySelector('.mascot-bubble-close').click()")
    app$wait_for_js("read().snapshot.dismissed_bubble_revision > 0")
    app$click("hundred")
    app$wait_for_js("helper().querySelector('.mascot-status').textContent === 'Status 100'")
    revision <- app$get_js("read().snapshot.applied_revision")
    app$run_js("window.previous = helper()")
    app$click("remount")
    app$wait_for_js("helper() !== previous && read()?.snapshot.applied_revision > 0")
    # Then the restored status and the label are the newest, with no new call, and the bubble stays dismissed.
    expect_identical(app$get_js("helper().querySelector('.mascot-status').textContent"), "Status 100")
    expect_identical(app$get_js("helper().querySelector('canvas').getAttribute('aria-label')"), "Alpha Two, Status 100")
    expect_identical(app$get_js("read().snapshot.applied_revision"), revision)
    expect_null(app$get_js("read().bubble"))
    expect_true(app$get_js("helper().querySelector('.mascot-bubble').hidden"))
    # Given a gesture and a status accepted while the element is gone, it plays once on the next mount and never again.
    app$click("remove")
    app$wait_for_js("helper() === null")
    app$click("prepare")
    app$click("show")
    app$wait_for_js("read()?.status.text === 'Prepared'")
    expect_identical(unlist(app$get_js("gestures")), "nod")
    expect_identical(app$get_js("helper().querySelector('canvas').getAttribute('aria-label')"), "Alpha Two, Prepared")
    app$click("remount")
    app$wait_for_js(
      "helper() !== previous && read()?.snapshot.applied_revision > 0 && read().status.text === 'Prepared'"
    )
    expect_identical(unlist(app$get_js("gestures")), "nod")
    # The shown mood, the status and the label agree after a mood change that follows the character's own status.
    app$click("follow")
    app$click("happy")
    app$wait_for_js("helper().dataset.shownMood === 'happy'")
    app$wait_for_js("helper().querySelector('.mascot-status').textContent === 'Happy'")
    expect_identical(app$get_js("helper().querySelector('canvas').getAttribute('aria-label')"), "Alpha Two, Happy")
    expect_identical(app$get_js("read().mood"), "happy")
  })

  it("I1 shows a status and label that follow the shown frame through a swap, and the newest state after a remount in the middle of one", {
    local_shiny_browser()
    local_app_characters(list(alpha = alpha, other = other))
    app <- app_driver(function() {
      library(mascot)
      characters <- readRDS(Sys.getenv("MASCOT_I1_CHARACTERS"))
      ui <- shiny::fluidPage(
        shiny::uiOutput("slot"),
        shiny::actionButton("processing", "Processing"),
        shiny::actionButton("swap", "Swap"),
        shiny::actionButton("back", "Back"),
        shiny::actionButton("remount", "Remount")
      )
      server <- function(input, output, session) {
        edition <- shiny::reactiveVal(0)
        output$slot <- shiny::renderUI({
          edition()
          mascot("helper", character = characters$alpha, placement = "inline")
        })
        # The character's own mood, through the internal helper form: the public string form takes the shared moods only.
        shiny::observeEvent(
          input$processing,
          update_mascot("helper", mood = structure(list(name = "processing"), class = "mascot_mood"))
        )
        shiny::observeEvent(input$swap, update_mascot("helper", character = characters$other))
        shiny::observeEvent(input$back, update_mascot("helper", character = characters$alpha))
        shiny::observeEvent(input$remount, edition(edition() + 1))
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    app$wait_for_js("window.mascot?.host.state(document.getElementById('helper'))?.snapshot.applied_revision > 0")
    app$run_js(
      sprintf(
        "window.helper = () => document.getElementById('helper');
        window.read = () => mascot.host.state(helper());
        window.table = %s;
        window.sample = () => { const el = helper(); return el && el.dataset.shownCharacter ? {
          character: el.dataset.shownCharacter, mood: el.dataset.shownMood, swapping: el.dataset.swapping,
          status: el.querySelector('.mascot-status').textContent,
          label: el.querySelector('canvas').getAttribute('aria-label') } : null; };
        window.samples = [];
        window.watch = () => { const s = sample(); if (s) samples.push(s); if (!window.stopWatching) requestAnimationFrame(watch); };
        window.verdict = () => samples.filter((s) => {
          const entry = table[s.character];
          return !(entry && s.status === entry.statuses[s.mood] && s.label === entry.name + ', ' + s.status);
        });",
        jsonlite::toJSON(table, auto_unbox = TRUE)
      )
    )
    app$click("processing")
    app$wait_for_js("helper().dataset.shownMood === 'processing'")
    expect_identical(app$get_js("helper().querySelector('.mascot-status').textContent"), "Processing")
    # Given every animation frame watched, a swap to a character without the processing mood.
    app$run_js("window.stopWatching = false; watch();")
    app$click("swap")
    app$wait_for_js("helper().dataset.swapping === 'true'")
    app$wait_for_js("helper().dataset.shownCharacter === 'alpha_three' && helper().dataset.swapping === 'false'")
    app$run_js("window.stopWatching = true;")
    # Then no frame ever shows one character's status, or label, beside the other's picture.
    expect_equal(app$get_js("verdict().length"), 0)
    # The outgoing character keeps its own mood and status until it has faded out: the target is not shown early.
    expect_identical(
      unique(unlist(app$get_js("samples.filter((s) => s.character === 'alpha_two').map((s) => s.mood)"))),
      "processing"
    )
    expect_identical(
      unique(unlist(app$get_js("samples.filter((s) => s.character === 'alpha_three').map((s) => s.mood)"))),
      "thinking"
    )
    seen <- unlist(app$get_js("samples.map((s) => s.character)"))
    expect_true(all(c("alpha_two", "alpha_three") %in% seen))
    expect_identical(
      seen,
      c(
        seen[seq_len(match("alpha_three", seen) - 1)],
        rep("alpha_three", length(seen) - match("alpha_three", seen) + 1)
      )
    )
    expect_true(any(unlist(app$get_js("samples.map((s) => s.swapping === 'true')"))))
    # The fallback of processing: the incoming character shows its thinking status, as R resolved.
    expect_identical(app$get_js("read().mood"), "thinking")
    expect_identical(app$get_js("helper().querySelector('.mascot-status').textContent"), "Pondering")
    expect_identical(
      app$get_js("helper().querySelector('canvas').getAttribute('aria-label')"),
      "Alpha Three, Pondering"
    )
    # Given a swap back and a remount in the middle of it, the new element shows the newest state with agreeing text.
    app$run_js("window.samples = []; window.stopWatching = false; watch();")
    app$click("back")
    app$wait_for_js("helper().dataset.swapping === 'true'")
    app$run_js("window.previous = helper()")
    app$click("remount")
    app$wait_for_js("helper() !== previous && read()?.snapshot.applied_revision > 0")
    app$wait_for_js("helper().dataset.shownCharacter === 'alpha_two' && helper().dataset.swapping === 'false'")
    app$run_js("window.stopWatching = true;")
    expect_equal(app$get_js("verdict().length"), 0)
    expect_gt(app$get_js("samples.length"), 0)
    expect_identical(app$get_js("helper().querySelector('.mascot-status').textContent"), "Thinking")
    expect_identical(app$get_js("helper().querySelector('canvas').getAttribute('aria-label')"), "Alpha Two, Thinking")
    expect_identical(app$get_js("read().character"), "alpha_two")
    expect_identical(app$get_js("read().mood"), "thinking")
  })

  it("I1 delivers to a nested module once, and keeps a timed bubble's remaining time through a remount", {
    local_shiny_browser()
    local_app_characters(list(alpha = alpha))
    app <- app_driver(function() {
      library(mascot)
      characters <- readRDS(Sys.getenv("MASCOT_I1_CHARACTERS"))
      inner_ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tagList(
          shiny::uiOutput(ns("slot")),
          shiny::actionButton(ns("status"), "Status"),
          shiny::actionButton(ns("remount"), "Remount")
        )
      }
      inner <- function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          edition <- shiny::reactiveVal(0)
          output$slot <- shiny::renderUI({
            edition()
            mascot(
              session$ns("helper"),
              character = characters$alpha,
              placement = "inline",
              bubble = mascot_bubble("Timed", duration = 600)
            )
          })
          shiny::observeEvent(
            input$status,
            update_mascot("helper", status = "From the inner module", session = session)
          )
          shiny::observeEvent(input$remount, edition(edition() + 1))
        })
      }
      ui <- shiny::fluidPage(shiny::tagList(inner_ui("outer-inner")))
      shiny::shinyApp(ui, function(input, output, session) inner("outer-inner"))
    })
    withr::defer(app$stop())
    app$wait_for_js(
      "window.mascot?.host.state(document.getElementById('outer-inner-helper'))?.snapshot.applied_revision > 0"
    )
    app$run_js(
      "window.helper = () => document.getElementById('outer-inner-helper');
      window.read = () => mascot.host.state(helper());"
    )
    app$click("outer-inner-status")
    app$wait_for_js("helper().querySelector('.mascot-status').textContent === 'From the inner module'")
    expect_identical(
      app$get_js("helper().querySelector('canvas').getAttribute('aria-label')"),
      "Alpha Two, From the inner module"
    )
    # One element answers to the one fully qualified id.
    expect_equal(app$get_js("document.querySelectorAll('[id$=\"helper\"]').length"), 1)
    before <- app$get_js("read().bubble.remaining")
    expect_gt(before, 0)
    expect_lte(before, 600)
    app$run_js("window.previous = helper()")
    app$click("outer-inner-remount")
    app$wait_for_js("helper() !== previous && read()?.snapshot.applied_revision > 0")
    app$wait_for_js("helper().querySelector('.mascot-status').textContent === 'From the inner module'")
    after <- app$get_js("read().bubble.remaining")
    # The timer carries on from where it was: the remaining time never grows back to the full duration.
    expect_gt(after, 0)
    expect_lte(after, before)
  })

  it("I1 still sends the four public inputs for a format-v1 character", {
    local_shiny_browser()
    local_app_characters(list(alpha = alpha))
    app <- app_driver(function() {
      library(mascot)
      characters <- readRDS(Sys.getenv("MASCOT_I1_CHARACTERS"))
      ui <- shiny::fluidPage(
        mascot("act", character = characters$alpha, placement = "inline", click = "Open help"),
        shiny::textOutput("clicks"),
        mascot(
          "menu",
          character = characters$alpha,
          placement = "inline",
          click = mascot_popup_menu(c(about = "About", help = "Help"))
        ),
        shiny::textOutput("choice"),
        mascot(
          "float",
          character = characters$alpha,
          placement = mascot_placement("bottom-right", minimise = TRUE, drag = "snap")
        ),
        shiny::textOutput("position"),
        shiny::textOutput("minimised")
      )
      server <- function(input, output, session) {
        output$clicks <- shiny::renderText(if (is.null(input$act_click)) "none" else input$act_click)
        output$choice <- shiny::renderText(if (is.null(input$menu_menu)) "none" else input$menu_menu)
        output$position <- shiny::renderText(if (is.null(input$float_position)) "none" else input$float_position)
        output$minimised <- shiny::renderText(
          if (is.null(input$float_minimised)) "none" else as.character(input$float_minimised)
        )
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    app$wait_for_js(
      "!!document.querySelector('#menu .mascot-menu-toggle') && !!document.querySelector('#float canvas')"
    )
    text <- function(id) app$get_js(sprintf("document.getElementById('%s').textContent", id))
    # An action: every click reaches the server.
    app$click(selector = "#act .mascot-button")
    app$wait_for_js("document.getElementById('clicks').textContent === '1'")
    # A menu: the chosen item reaches the server.
    app$click(selector = "#menu .mascot-menu-toggle")
    app$wait_for_js("mascot.host.state(document.getElementById('menu')).menuOpen")
    app$run_js("document.querySelector('#menu [role=menuitem]:last-child').click()")
    app$wait_for_js("document.getElementById('choice').textContent === 'help'")
    # A floating mascot dropped on another corner reports its position, and minimising reports both ways.
    app$run_js(
      "window.press = (target, type, x, y) => target.dispatchEvent(new PointerEvent(type,
        { bubbles: true, cancelable: true, pointerId: 1, button: 0, isPrimary: true, clientX: x, clientY: y }));
      window.dragBy = (target, dx, dy) => { const r = target.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2;
        press(target, 'pointerdown', x, y); press(target, 'pointermove', x + dx / 2, y + dy / 2);
        press(target, 'pointermove', x + dx, y + dy); press(target, 'pointerup', x + dx, y + dy); };
      dragBy(document.querySelector('#float canvas'), -2000, -2000);"
    )
    app$wait_for_js("document.getElementById('position').textContent === 'top-left'")
    app$run_js("document.querySelector('#float .mascot-minimise').click()")
    app$wait_for_js("document.getElementById('minimised').textContent === 'TRUE'")
    app$run_js("document.querySelector('#float .mascot-restore').click()")
    app$wait_for_js("document.getElementById('minimised').textContent === 'FALSE'")
    expect_identical(text("clicks"), "1")
    expect_identical(text("choice"), "help")
    expect_identical(text("position"), "top-left")
  })
})

describe("named palettes through the real Shiny host", {
  it("changes the drawn colours, keeps a shared palette on a swap and drops an unavailable one", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      ui <- shiny::fluidPage(
        mascot("helper", character = "tessa", motion = FALSE, placement = "inline"),
        shiny::actionButton("palette", "Coral navy"),
        shiny::actionButton("shared", "Sela"),
        shiny::actionButton("drop", "Neer")
      )
      server <- function(input, output, session) {
        shiny::observeEvent(input$palette, update_mascot("helper", theme = "coral_navy"))
        shiny::observeEvent(input$shared, update_mascot("helper", character = "sela"))
        shiny::observeEvent(input$drop, update_mascot("helper", character = "neer"))
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    app$run_js(
      "window.helper = () => document.getElementById('helper'); window.state = () => mascot.host.state(helper());"
    )
    app$wait_for_js("state()?.character === 'tessa' && state().renderedSize > 0")
    before <- app$get_js("helper().querySelector('canvas').toDataURL()")
    app$click("palette")
    app$wait_for_js("state().theme.palette === 'coral_navy' && state().colours.body === '#FFE5D9'")
    # Read pixels as well as retained state: a wire-only test misses an unchanged drawing.
    app$wait_for_js(sprintf(
      "helper().querySelector('canvas').toDataURL() !== %s",
      jsonlite::toJSON(before, auto_unbox = TRUE)
    ))
    expect_identical(app$get_js("state().colours.rim"), "#FF6B6B")
    app$click("shared")
    app$wait_for_js(
      "state().character === 'sela' && state().theme.palette === 'coral_navy' && state().colours.hair_purple === '#1D3557'"
    )
    expect_identical(app$get_js("state().colours.body"), "#FFE5D9")
    app$click("drop")
    app$wait_for_js("state().character === 'neer' && !state().theme.palette")
    expect_null(app$get_js("state().colours.body"))
    expect_null(app$get_js("state().theme.palette_colours"))
    expect_null(app$get_js("state().problem"))
  })
})
