# Skips the whole file on CRAN or without Chrome, before any of its code runs.
skip_without_chrome()

describe("update_mascot() in a browser", {
  it("changes mood, sets plain status text and returns it to the mood", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      ui <- shiny::fluidPage(
        mascot(id = "helper"),
        shiny::actionButton("think", "Think"),
        shiny::actionButton("save", "Save"),
        shiny::actionButton("happy", "Happy"),
        shiny::actionButton("reset", "Follow mood")
      )
      server <- function(input, output, session) {
        shiny::observeEvent(input$think, update_mascot("helper", mood = "thinking"))
        shiny::observeEvent(input$save, update_mascot("helper", status = "<b>Saved</b>"))
        shiny::observeEvent(input$happy, update_mascot("helper", mood = "happy"))
        shiny::observeEvent(input$reset, update_mascot("helper", status = mascot_status()))
      }
      shiny::shinyApp(ui, server)
    })
    app$wait_for_js("document.querySelector('#helper').dataset.shownMood === 'idle'")
    app$click("think")
    app$wait_for_js("document.querySelector('#helper').dataset.shownMood === 'thinking'")
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').textContent"),
      "Working out how the parts fit."
    )
    app$click("save")
    app$wait_for_js("document.querySelector('#helper .mascot-status').textContent === '<b>Saved</b>'")
    app$click("happy")
    app$wait_for_js("document.querySelector('#helper').dataset.shownMood === 'happy'")
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').innerHTML"),
      "&lt;b&gt;Saved&lt;/b&gt;"
    )
    app$click("reset")
    app$wait_for_js("document.querySelector('#helper .mascot-status').textContent === 'That came together nicely.'")
    expect_identical(
      app$get_js("document.querySelector('#helper canvas').getAttribute('aria-label')"),
      "Tessa, That came together nicely."
    )
  })
  it("updates a module mascot using its local server id", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      module_ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tagList(mascot(id = ns("helper")), shiny::actionButton(ns("go"), "Go"))
      }
      module_server <- function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          shiny::observeEvent(input$go, update_mascot("helper", mood = "happy"))
        })
      }
      shiny::shinyApp(shiny::fluidPage(module_ui("mod")), function(input, output, session) module_server("mod"))
    })
    app$click("mod-go")
    app$wait_for_js("document.querySelector('#mod-helper').dataset.shownMood === 'happy'")
    expect_identical(
      app$get_js("document.querySelector('#mod-helper .mascot-status').textContent"),
      "That came together nicely."
    )
  })
  it("keeps updates before renderUI and destroys the replaced element's record", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      # A permanent mascot loads the dependency and message handler before the late one exists.
      ui <- shiny::fluidPage(
        mascot(id = "anchor"),
        shiny::uiOutput("slot"),
        shiny::actionButton("prepare", "Prepare"),
        shiny::actionButton("show", "Show")
      )
      server <- function(input, output, session) {
        shiny::observeEvent(input$prepare, {
          update_mascot("late", mood = "thinking")
          update_mascot("late", mood = "happy", status = "Ready")
        })
        output$slot <- shiny::renderUI({
          if (input$show > 0) mascot(id = "late")
        })
      }
      shiny::shinyApp(ui, server)
    })
    app$click("prepare")
    expect_null(app$get_js("document.getElementById('late')"))
    app$click("show")
    app$wait_for_js("document.querySelector('#late')?.dataset.shownMood === 'happy'")
    expect_identical(app$get_js("document.querySelector('#late .mascot-status').textContent"), "Ready")
    app$run_js("window.oldMascot = document.getElementById('late')")
    app$click("show")
    app$wait_for_js(
      "document.getElementById('late') !== window.oldMascot && document.getElementById('late')?.dataset.shownMood === 'happy'"
    )
    expect_null(app$get_js("mascot.host.state(window.oldMascot)"))
    expect_false(app$get_js("window.oldMascot.isConnected"))
    expect_identical(app$get_js("document.querySelector('#late .mascot-status').textContent"), "Ready")
  })
})

describe("server bubbles and gestures in a browser", {
  it("shows a server bubble, accepts a gesture and lets the user close it", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      ui <- shiny::fluidPage(mascot(id = "helper"), shiny::actionButton("go", "Go"))
      server <- function(input, output, session) {
        shiny::observeEvent(input$go, {
          update_mascot("helper", bubble = mascot_bubble("Ready", duration = Inf), gesture = "wave")
        })
      }
      shiny::shinyApp(ui, server)
    })
    app$run_js(
      "window.mascotErrors = []; const originalError = console.error;
      console.error = (...args) => { window.mascotErrors.push(args.map(String).join(' ')); originalError(...args); };
      window.addEventListener('error', event => window.mascotErrors.push(event.message));"
    )
    app$click("go")
    app$wait_for_js("document.querySelector('#helper .mascot-bubble-text').textContent === 'Ready'")
    expect_length(app$get_js("window.mascotErrors"), 0)
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).bubble.text"), "Ready")
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').textContent"),
      "Resting, ready for the next piece."
    )
    app$run_js("document.querySelector('#helper .mascot-bubble-close').click()")
    app$wait_for_js("document.querySelector('#helper .mascot-bubble').hidden")
    expect_null(app$get_js("mascot.host.state(document.getElementById('helper')).bubble"))
  })
})

describe("size and placement in a Shiny browser", {
  it("floats, minimises and restores with mouse, Enter and Space while retaining server updates", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      shiny::shinyApp(
        shiny::fluidPage(
          mascot(id = "helper", size = 96, placement = mascot_placement("bottom-right", minimise = TRUE)),
          shiny::actionButton("change", "Change"),
          shiny::actionButton("inline", "Inline"),
          shiny::actionButton("notice", "Notice"),
          shiny::actionButton("remove_notice", "Remove notice")
        ),
        function(input, output, session) {
          shiny::observeEvent(
            input$change,
            update_mascot(
              "helper",
              size = 64,
              mood = "happy",
              placement = mascot_placement("top-left", minimise = TRUE),
              bubble = mascot_bubble("Saved", duration = Inf)
            )
          )
          shiny::observeEvent(input$inline, update_mascot("helper", size = 120, placement = "inline"))
          shiny::observeEvent(input$notice, shiny::showNotification("Saved", id = "mascot-notice", duration = NULL))
          shiny::observeEvent(input$remove_notice, shiny::removeNotification("mascot-notice"))
        }
      )
    })
    app$wait_for_js("document.querySelector('#helper canvas').width === 96 * devicePixelRatio")
    app$click("notice")
    app$wait_for_js("document.getElementById('shiny-notification-mascot-notice') !== null")
    app$wait_for_js(
      "document.getElementById('helper').getBoundingClientRect().bottom <
      document.getElementById('shiny-notification-panel').getBoundingClientRect().top"
    )
    expect_true(app$get_js(
      "document.getElementById('helper').getBoundingClientRect().bottom <=
      document.getElementById('shiny-notification-panel').getBoundingClientRect().top -
      parseFloat(getComputedStyle(document.documentElement).fontSize) + 0.1"
    ))
    app$click("remove_notice")
    app$wait_for_js("document.getElementById('shiny-notification-mascot-notice') === null")
    app$run_js(
      "window.mounts=0; const mount=mascot.mount;
      mascot.mount=(...args)=>{mounts++;return mount(...args);};"
    )
    app$click(selector = "#helper .mascot-minimise")
    app$wait_for_js("document.querySelector('#helper').dataset.minimised === 'true'")
    app$click("change")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).mood === 'happy'")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).bubble.text"), "Saved")
    app$click(selector = "#helper .mascot-restore")
    app$wait_for_js("document.querySelector('#helper canvas').width === 64 * devicePixelRatio")
    expect_identical(app$get_js("document.querySelector('#helper').dataset.position"), "top-left")
    app$wait_for_js("document.querySelector('#helper').dataset.shownMood === 'happy'")
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').textContent"),
      "That came together nicely."
    )
    # Native button activation must work for both keyboard keys, not just synthetic click events.
    browser <- app$get_chromote_session()
    for (key in c("Enter", " ")) {
      app$click(selector = "#helper .mascot-minimise")
      app$wait_for_js("document.querySelector('#helper').dataset.minimised === 'true'")
      app$run_js("document.querySelector('#helper .mascot-restore').focus()")
      code <- if (key == "Enter") "Enter" else "Space"
      number <- if (key == "Enter") 13L else 32L
      browser$Input$dispatchKeyEvent(
        type = "keyDown",
        key = key,
        code = code,
        windowsVirtualKeyCode = number,
        text = if (key == "Enter") "\r" else " "
      )
      browser$Input$dispatchKeyEvent(type = "keyUp", key = key, code = code, windowsVirtualKeyCode = number)
      app$wait_for_js("document.querySelector('#helper').dataset.minimised === 'false'")
      expect_true(app$get_js("document.activeElement===document.querySelector('#helper .mascot-minimise')"))
    }
    app$click("inline")
    app$wait_for_js("document.querySelector('#helper').dataset.floating === 'false'")
    # Restore scales the canvas briefly; measure its layout after that movement ends.
    app$wait_for_js("document.querySelector('#helper canvas').getAnimations().length === 0")
    expect_equal(app$get_js("document.querySelector('#helper canvas').getBoundingClientRect().width"), 120)
    expect_equal(app$get_js("mounts"), 0)
    expect_true(app$get_js("document.querySelector('#helper .mascot-minimise').hidden"))
  })
  it("measures a module mascot when its hidden tab opens and accepts a local-id layout update", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      module_ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tags$div(
          style = "width:400px",
          mascot(id = ns("helper"), size = "20%", placement = "inline"),
          shiny::actionButton(ns("change"), "Change")
        )
      }
      module_server <- function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          shiny::observeEvent(input$change, update_mascot("helper", size = 48, placement = "top-right"))
        })
      }
      shiny::shinyApp(
        shiny::fluidPage(shiny::tabsetPanel(
          id = "tabs",
          shiny::tabPanel("Home", "Start"),
          shiny::tabPanel("Helper", module_ui("mod"))
        )),
        function(input, output, session) module_server("mod")
      )
    })
    app$wait_for_js("mascot.host.state(document.getElementById('mod-helper')) !== null")
    expect_equal(app$get_js("document.querySelector('#mod-helper canvas').getBoundingClientRect().width"), 0)
    app$set_inputs(tabs = "Helper")
    app$wait_for_js("document.querySelector('#mod-helper canvas').getBoundingClientRect().width === 80")
    app$click("mod-change")
    app$wait_for_js("document.querySelector('#mod-helper').dataset.position === 'top-right'")
    expect_equal(app$get_js("document.querySelector('#mod-helper canvas').getBoundingClientRect().width"), 48)
    expect_false(app$get_js("'detail' in mascot.host.state(document.getElementById('mod-helper'))"))
  })
})

describe("floating mascots in dynamic module UI", {
  it("preserves tab visibility, avoids duplicate bindings and tears down the original controller on replacement", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      module_ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tagList(shiny::actionButton(ns("replace"), "Replace"), shiny::uiOutput(ns("dynamic")))
      }
      module_server <- function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          output$dynamic <- shiny::renderUI({
            shiny::tags$div(
              `data-generation` = input$replace,
              style = "transform:translateZ(0);width:300px;height:300px",
              mascot(
                id = session$ns("helper"),
                size = 64,
                placement = mascot_placement("bottom-right", minimise = TRUE)
              )
            )
          })
        })
      }
      shiny::shinyApp(
        shiny::fluidPage(
          mascot(id = "loader", size = 24, placement = "inline"),
          shiny::tabsetPanel(id = "tabs", shiny::tabPanel("Home", "Home"), shiny::tabPanel("Helper", module_ui("mod")))
        ),
        function(input, output, session) module_server("mod")
      )
    })
    app$click(selector = "a[data-value='Helper']")
    app$wait_for_js("Shiny.shinyapp.$inputValues['.clientdata_output_mod-dynamic_hidden'] === false")
    app$wait_for_js("document.querySelector('#mod-helper canvas')?.getBoundingClientRect().width === 64")
    app$run_js("window.old=document.getElementById('mod-helper')")
    expect_true(app$get_js("old.parentElement===document.body"))
    expect_equal(app$get_js("document.querySelectorAll('.mascot-source.shiny-bound-input').length"), 1)
    expect_false(app$get_js("old.classList.contains('shiny-bound-input')"))
    app$click(selector = "#mod-replace")
    app$wait_for_js(
      "document.getElementById('mod-helper') !== old && mascot.host.state(old) === null"
    )
    expect_equal(app$get_js("document.querySelectorAll('#mod-helper').length"), 1)
    expect_equal(app$get_js("document.querySelectorAll('.mascot-source.shiny-bound-input').length"), 1)
    expect_false(app$get_js("old.isConnected"))
    # Hidden tab, then shown again: checked through the mascot itself (its canvas collapses and comes back). Shiny's
    # own output-hidden flag can stay stale after a second tab switch in headless Chrome (seen with an inline mascot
    # too), so the replacement above runs while the tab is still open.
    app$click(selector = "a[data-value='Home']")
    app$wait_for_js("document.querySelector('#mod-helper canvas').getBoundingClientRect().width === 0")
    app$click(selector = "a[data-value='Helper']")
    app$wait_for_js("document.querySelector('#mod-helper canvas').getBoundingClientRect().width === 64")
    app$run_js(
      "window.current=document.getElementById('mod-helper');Shiny.unbindAll(document.getElementById('mod-dynamic'))"
    )
    app$wait_for_js("mascot.host.state(current) === null")
    expect_equal(app$get_js("document.querySelectorAll('.mascot-source').length"), 0)
  })
})

describe("theme in a Shiny browser", {
  it("follows a bslib dark-mode input with no mode argument or server theme updates", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- app_driver(function() {
      library(mascot)
      shiny::shinyApp(
        bslib::page_fluid(
          bslib::input_dark_mode(id = "dark_mode", mode = "light"),
          mascot(id = "helper", theme = mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"))),
          shiny::actionButton("reset", "Character colours")
        ),
        function(input, output, session) {
          shiny::observeEvent(input$reset, update_mascot("helper", theme = mascot_theme()))
        }
      )
    })
    app$wait_for_js("window.mascot?.host?.state(document.getElementById('helper'))?.colours.body === '#1F6FEB'")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).mode"), "light")
    app$run_js(
      "window.drawnBodies=[];{ const origGeo=mascot.geometry.draw; mascot.geometry = { ...mascot.geometry, draw: (ctx,c,s,colours,o)=>{if (colours?.body) drawnBodies.push(colours.body); return origGeo(ctx,c,s,colours,o);}}; }"
    )
    app$run_js("document.getElementById('dark_mode').shadowRoot.querySelector('button').click()")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body === '#9EC5FE'")
    app$wait_for_js("drawnBodies.at(-1)==='#9EC5FE'")
    expect_identical(app$get_js("document.documentElement.dataset.bsTheme"), "dark")
    app$run_js("document.getElementById('dark_mode').shadowRoot.querySelector('button').click()")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body === '#1F6FEB'")
    app$click("reset")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body === null")
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').textContent"),
      "Resting, ready for the next piece."
    )
  })
})

describe("motion in a Shiny browser", {
  it("changes motion from an app setting without replacing the canvas", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      shiny::shinyApp(
        shiny::fluidPage(
          mascot(id = "helper"),
          shiny::checkboxInput("animate", "Animate mascot", TRUE),
          shiny::actionButton("happy", "Happy")
        ),
        function(input, output, session) {
          shiny::observeEvent(input$animate, update_mascot("helper", motion = input$animate))
          shiny::observeEvent(input$happy, update_mascot("helper", mood = "happy"))
        }
      )
    })
    app$wait_for_js("window.mascot?.host?.state(document.getElementById('helper')) !== null")
    app$run_js("window.originalCanvas=document.querySelector('#helper canvas')")
    app$set_inputs(animate = FALSE)
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).motion.reduced === true")
    app$click("happy")
    app$wait_for_js("document.getElementById('helper').dataset.shownMood === 'happy'")
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').textContent"),
      "That came together nicely."
    )
    expect_true(app$get_js("document.querySelector('#helper canvas') === originalCanvas"))
    app$set_inputs(animate = TRUE)
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).motion.reduced === null")
    expect_identical(app$get_js("document.getElementById('helper').dataset.reduced"), "auto")
  })
})

describe("popup menu in a Shiny browser", {
  it("receives repeated choices in a module and opens the app's modal", {
    local_shiny_browser()
    app <- app_driver(function() {
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
          count <- shiny::reactiveVal(0L)
          shiny::observeEvent(input$helper_menu, {
            count(count() + 1L)
            shiny::showModal(shiny::modalDialog(paste("Choice", input$helper_menu), easyClose = TRUE))
          })
          output$count <- shiny::renderText(count())
        })
      })
    })
    app$wait_for_js("!!document.querySelector('#module-helper .mascot-menu-toggle')")
    for (i in 1:2) {
      app$click(selector = "#module-helper .mascot-menu-toggle")
      app$click(selector = "#module-helper [role=menuitem]")
      app$wait_for_js(sprintf("document.getElementById('module-count').textContent === '%s'", i))
      app$wait_for_js("!!document.querySelector('.modal.in, .modal.show')")
      expect_match(app$get_js("document.querySelector('.modal-body').textContent"), "Choice about")
      app$click(selector = ".modal-footer button")
      app$wait_for_js("!document.querySelector('.modal.in, .modal.show')")
    }
  })
})

describe("documented Shiny settings", {
  it("runs the help example for idle movement and a nod", {
    local_shiny_browser()
    rd <- local_help_page("mascot_motion_settings")
    con <- textConnection("code", "w", local = TRUE)
    tools::Rd2ex(rd, out = con)
    close(con)
    find_app <- function(x) {
      if (!is.call(x) && !is.expression(x)) {
        return(NULL)
      }
      if (is.call(x) && identical(x[[1]], quote(shiny::shinyApp))) {
        return(x)
      }
      for (part in as.list(x)) {
        found <- find_app(part)
        if (!is.null(found)) return(found)
      }
      NULL
    }
    expression <- find_app(parse(text = code))
    expect_false(is.null(expression))
    app_function <- function() NULL
    body(app_function) <- substitute(
      {
        library(mascot)
        APP
      },
      list(APP = expression)
    )
    app <- app_driver(app_function)
    app$wait_for_js("!!window.mascot?.host?.state(document.getElementById('helper'))")
    app$set_inputs(idle = FALSE)
    app$wait_for_js("document.getElementById('helper').dataset.idle==='false'")
    app$click("nod")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).mood === 'idle'")
    expect_identical(app$get_js("document.getElementById('helper').dataset.idle"), "false")
    app$set_inputs(idle = TRUE)
    app$wait_for_js("document.getElementById('helper').dataset.idle==='true'")
  })
  it("runs the complete module help block and receives repeated choices", {
    local_shiny_browser()
    rd <- local_help_page("mascot_popup_menu")
    details <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\details"), rd)[[1]]
    block <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\preformatted"), details)[[1]]
    expressions <- parse(text = paste(unlist(block), collapse = ""))
    app_function <- function() NULL
    body(app_function) <- as.call(c(list(quote(`{`), quote(library(mascot))), as.list(expressions)))
    app <- app_driver(app_function)
    app$wait_for_js("!!document.querySelector('#demo-helper .mascot-menu-toggle')")
    for (i in 1:2) {
      app$click(selector = "#demo-helper .mascot-menu-toggle")
      app$click(selector = "#demo-helper [role=menuitem]")
      app$wait_for_js("!!document.querySelector('.modal.in, .modal.show')")
      expect_match(app$get_js("document.querySelector('.modal-body').textContent"), "About this app")
      app$click(selector = ".modal-footer button")
      app$wait_for_js("!document.querySelector('.modal.in, .modal.show')")
    }
  })
})

describe("retained mascot updates", {
  it("recovers startup, earlier-cycle and same-cycle updates for the first renderUI mascots, playing gestures once", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      # Record real controller calls, including ones made while dynamic dependencies load.
      recorder <- shiny::tags$script(htmltools::HTML(
        "window.gestures=[];window.mascot={};
        Object.defineProperty(window.mascot,'mount',{configurable:true,set(fn){
          Object.defineProperty(this,'mount',{configurable:true,writable:true,value:(...args)=>{
            const p=fn(...args),gesture=p.gesture;
            p.gesture=name=>{gestures.push({id:args[0].closest('.mascot').id,name,
              mood:args[0].closest('.mascot').dataset.mood,character:p.current().character});return gesture(name);};return p;
          }});}});"
      ))
      ui <- shiny::fluidPage(
        recorder,
        shiny::actionButton("prepare", "Prepare"),
        shiny::actionButton("show", "Show"),
        shiny::uiOutput("slot")
      )
      server <- function(input, output, session) {
        visible <- shiny::reactiveVal(FALSE)
        update_mascot("startup", mood = "happy", gesture = "wave")
        shiny::observeEvent(input$prepare, {
          update_mascot("earlier", mood = "thinking", status = "Earlier", gesture = "nod")
          update_mascot("earlier", mood = "happy", gesture = "wave")
        })
        shiny::observeEvent(input$show, {
          update_mascot("same", mood = "happy", status = "Same cycle", gesture = "nod")
          visible(TRUE)
        })
        output$slot <- shiny::renderUI({
          if (visible()) shiny::tagList(mascot(id = "startup"), mascot(id = "earlier"), mascot(id = "same"))
        })
      }
      shiny::shinyApp(ui, server)
    })
    expect_null(app$get_js("document.querySelector('.mascot')"))
    app$click("prepare")
    app$click("show")
    app$wait_for_js("window.gestures.length === 3")
    app$wait_for_js("['startup','earlier','same'].every(id=>document.getElementById(id).dataset.shownMood==='happy')")
    for (id in c("startup", "earlier", "same")) {
      expect_identical(app$get_js(sprintf("document.getElementById('%s').dataset.shownMood", id)), "happy")
    }
    expect_identical(app$get_js("document.querySelector('#earlier .mascot-status').textContent"), "Earlier")
    expect_identical(app$get_js("document.querySelector('#same .mascot-status').textContent"), "Same cycle")
    expect_identical(app$get_js("gestures.find(x=>x.id==='earlier').name"), "wave")
    expect_identical(app$get_js("gestures.find(x=>x.id==='same').name"), "nod")
    expect_true(app$get_js("gestures.every(x=>x.mood==='happy' && x.character==='tessa')"))
    # A stale re-send and a replacement must both preserve the one-off contract.
    app$run_js(
      "const el=document.getElementById('earlier');
      mascot.host.receive({id:'earlier',patch:{gesture:'wave'},revision:1,gestureRevision:1,replay:true});
      Shiny.unbindAll(document.getElementById('slot'));
      Shiny.bindAll(document.getElementById('slot'));"
    )
    app$wait_for_idle()
    expect_equal(app$get_js("gestures.length"), 3)
  })
})

describe("bubble visibility in Shiny tabs", {
  it("pauses a timed bubble in a hidden tab and resumes its remaining lifetime", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      ui <- shiny::fluidPage(shiny::tabsetPanel(
        id = "tabs",
        shiny::tabPanel("Helper", mascot(id = "helper"), shiny::actionButton("say", "Say")),
        shiny::tabPanel("Other", "Other tab")
      ))
      server <- function(input, output, session) {
        shiny::observeEvent(input$say, update_mascot("helper", bubble = mascot_bubble("Timed", duration = 3)))
      }
      shiny::shinyApp(ui, server)
    })
    app$click("say")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).bubble !== null")
    app$click(selector = "a[data-value='Other']")
    app$wait_for_js("document.querySelector('#helper canvas').getBoundingClientRect().width===0")
    remaining <- app$get_js("mascot.host.state(document.getElementById('helper')).bubble.remaining")
    expect_gt(remaining, 0)
    # Move the page's clock 3.5 seconds on (longer than the bubble's 3) instead of waiting: a countdown still
    # running while hidden would now read 0, while a paused one keeps its time.
    app$run_js(
      "window.realNow=performance.now.bind(performance);performance.now=()=>realNow()+3500;"
    )
    expect_equal(app$get_js("mascot.host.state(document.getElementById('helper')).bubble.remaining"), remaining)
    app$run_js("performance.now=window.realNow")
    app$click(selector = "a[data-value='Helper']")
    app$wait_for_js("document.querySelector('#helper canvas').getBoundingClientRect().width>0")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).bubble.text"), "Timed")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).bubble === null")
  })
})

describe("nested modules across tabs", {
  it("keeps updates, menu inputs, dragging, minimising and motion local, including hidden dynamic UI", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    # Match the other browser tests: load the development package in the child R process.
    app_function <- function() NULL
    body(app_function) <- substitute(
      {
        library(mascot)
        shiny::shinyAppDir(DIR)
      },
      list(DIR = normalizePath(test_path("apps", "modules-tabs")))
    )
    app <- app_driver(app_function, width = 900, height = 700)
    app$run_js("window.helperState=id=>mascot.host.state(document.getElementById(id+'-review-helper'));")
    app$wait_for_js("!!helperState('first') && !!helperState('second')")
    app$wait_for_js("document.getElementById('second-review-helper').dataset.sourceHidden === 'true'")
    # Updating a session$ns() id reaches only that nested module.
    app$click("first-review-go")
    app$wait_for_js("helperState('first').status.text === 'Complete'")
    expect_identical(app$get_js("helperState('first').mood"), "happy")
    expect_identical(app$get_js("helperState('second').mood"), "idle")
    app$click(selector = "#first-review-helper .mascot-menu-toggle")
    app$click(selector = "#first-review-helper [role=menuitem]")
    app$wait_for_js("JSON.parse(document.getElementById('first-review-events').textContent).menu === 'about'")
    events <- jsonlite::fromJSON(app$get_value(output = "first-review-events"))
    expect_identical(events$menu, "about")
    expect_null(events$click)
    expect_null(jsonlite::fromJSON(app$get_value(output = "second-review-events"))$menu)
    # A real pointer drop is received by the nested module's local input.
    app$run_js(
      "(() => {const c=document.querySelector('#first-review-helper canvas'),r=c.getBoundingClientRect();
      const x=r.left+r.width/2,y=r.top+r.height/2,send=(type,px,py)=>c.dispatchEvent(new PointerEvent(type,
      {bubbles:true,cancelable:true,pointerId:1,button:0,isPrimary:true,clientX:px,clientY:py}));
      send('pointerdown',x,y);send('pointermove',x-300,y-200);send('pointermove',x-700,y-500);
      send('pointerup',x-700,y-500);})()"
    )
    app$wait_for_js("JSON.parse(document.getElementById('first-review-events').textContent).position === 'top-left'")
    expect_identical(app$get_js("helperState('second').placement.position"), "bottom-left")
    app$click(selector = "#first-review-helper .mascot-minimise")
    app$wait_for_js("JSON.parse(document.getElementById('first-review-events').textContent).minimised === true")
    expect_false(app$get_js("helperState('second').minimised"))
    app$click(selector = "#first-review-helper .mascot-restore")
    app$wait_for_js("JSON.parse(document.getElementById('first-review-events').textContent).minimised === false")
    app$click("first-review-move")
    app$wait_for_js("helperState('first').placement.position === 'top-right' && !helperState('first').motion.others")
    expect_true(app$get_js("helperState('second').motion.mood_change"))
    expect_false(app$get_js("helperState('second').motion.idle"))
    # The second mascot accepts an update while hidden and keeps it when shown.
    app$click("hidden_update")
    app$wait_for_js("helperState('second').mood === 'thinking'")
    app$click(selector = "a[data-value=Second]")
    app$wait_for_js("document.getElementById('second-review-helper').dataset.sourceHidden === 'false'")
    expect_identical(app$get_js("helperState('second').mood"), "thinking")
    app$click("second-review-go")
    app$wait_for_js("helperState('second').status.text === 'Complete'")
    app$click(selector = "#second-review-helper .mascot-menu-toggle")
    app$click(selector = "#second-review-helper [role=menuitem]")
    app$wait_for_js("JSON.parse(document.getElementById('second-review-events').textContent).menu === 'about'")
    expect_false(app$get_js("helperState('first').menuOpen"))
    app$click("second-review-rebuild")
    app$wait_for_js(
      "document.getElementById('second-review-helper').dataset.generation === '2' && helperState('second')?.mood === 'happy'"
    )
    expect_identical(app$get_js("helperState('first').placement.position"), "top-right")
    expect_false(app$get_js("helperState('first').motion.others"))
    # Static and renderUI mascots share every engine resource, even after remount.
    for (file in c("mascot.js", "mascot-motion.js", "mascot-player.js", "mascot-host.js")) {
      expect_equal(app$get_js(sprintf("document.querySelectorAll('script[src$=\"/%s\"]').length", file)), 1)
    }
    expect_equal(app$get_js("document.querySelectorAll('link[href$=\"/mascot.css\"]').length"), 1)
  })
})
