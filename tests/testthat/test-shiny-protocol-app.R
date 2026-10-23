describe("latest state over real Shiny transport", {
  it("restores through renderUI, preserves dismissal and delivers repeated lifecycle events", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      ui <- shiny::fluidPage(
        mascot("static", motion = FALSE),
        shiny::uiOutput("slot"),
        shiny::textOutput("events"),
        shiny::actionButton("hundred", "One hundred"),
        shiny::actionButton("remount", "Remount"),
        shiny::actionButton("remove", "Remove"),
        shiny::actionButton("show", "Show"),
        shiny::actionButton("prepare", "Prepare"),
        shiny::actionButton("bubble", "Bubble"),
        shiny::actionButton("changed_ui", "Changed UI"),
        shiny::actionButton("happy", "Happy"),
        shiny::actionButton("follow", "Follow mood"),
        shiny::actionButton("invalid", "Invalid")
      )
      server <- function(input, output, session) {
        visible <- shiny::reactiveVal(TRUE)
        edition <- shiny::reactiveVal(0)
        changed <- shiny::reactiveVal(FALSE)
        delivered <- shiny::reactiveVal(0)
        output$slot <- shiny::renderUI({
          edition()
          if (visible()) {
            mascot(
              "helper",
              placement = "inline",
              motion = FALSE,
              bubble = mascot_bubble(if (changed()) "Changed UI" else "Hello", duration = Inf)
            )
          }
        })
        shiny::observeEvent(input$helper, delivered(delivered() + 1))
        output$events <- shiny::renderText(delivered())
        shiny::observeEvent(input$hundred, {
          for (i in 1:100) {
            update_mascot("helper", status = paste("Status", i))
          }
        })
        shiny::observeEvent(input$remount, edition(edition() + 1))
        shiny::observeEvent(input$remove, visible(FALSE))
        shiny::observeEvent(input$show, visible(TRUE))
        shiny::observeEvent(input$prepare, update_mascot("helper", gesture = "nod", status = "Prepared"))
        shiny::observeEvent(
          input$bubble,
          update_mascot("helper", bubble = mascot_bubble("Hello", duration = Inf))
        )
        shiny::observeEvent(input$changed_ui, {
          changed(TRUE)
          edition(edition() + 1)
        })
        shiny::observeEvent(input$happy, update_mascot("helper", mood = "happy"))
        shiny::observeEvent(input$follow, update_mascot("helper", status = mascot_status()))
        shiny::observeEvent(
          input$invalid,
          withr::with_envvar(
            c(TESTTHAT = "false"),
            withr::with_options(list(shiny.devmode = TRUE), update_mascot("helper", mood = "missing", status = "Wrong"))
          )
        )
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    app$wait_for_js("mascot.host.state(document.getElementById('helper'))?.snapshot.applied_revision > 0")
    app$run_js(
      "window.lifecycle=[];const originalInput=Shiny.setInputValue;
      Shiny.setInputValue=(name,value,options)=>{if(name==='helper:mascot.state') lifecycle.push({value:{...value},options});
        return originalInput(name,value,options);};
      window.gestures=[];const mount=mascot.mount;mascot.mount=(...args)=>{const c=mount(...args),g=c.gesture;
        c.gesture=name=>{gestures.push(name);return g(name);};return c;};
      window.helper=()=>document.getElementById('helper');window.read=()=>mascot.host.state(helper());"
    )
    app$run_js("helper().querySelector('.mascot-bubble-close').click()")
    app$wait_for_js("read().snapshot.dismissed_bubble_revision > 0")
    app$click("hundred")
    app$wait_for_js("helper().querySelector('.mascot-status').textContent === 'Status 100'")
    revision <- app$get_js("read().snapshot.applied_revision")
    app$run_js("window.previous=helper()")
    app$click("remount")
    app$wait_for_js("helper()!==previous && read()?.snapshot.applied_revision > 0")
    expect_identical(app$get_js("helper().querySelector('.mascot-status').textContent"), "Status 100")
    expect_identical(app$get_js("helper().querySelector('canvas').getAttribute('aria-label')"), "Tessa, Status 100")
    expect_identical(app$get_js("read().snapshot.applied_revision"), revision)
    expect_null(app$get_js("read().bubble"))
    expect_true(app$get_js(
      "(() => {const unmount=lifecycle.findIndex(e=>e.value.lifecycle==='unmounted');
      const next=lifecycle.findIndex((e,i)=>i>unmount && e.value.lifecycle==='ready');
      return unmount>=0 && next>unmount && lifecycle.every(e=>e.options.priority==='event');})()"
    ))
    # Repeated identical reconciliation snapshots must each reach the R input.
    delivered <- app$get_js("Number(document.getElementById('events').textContent)")
    app$run_js("mascot.host.reconcile(helper())")
    app$wait_for_js(sprintf("Number(document.getElementById('events').textContent)>%d", delivered))
    delivered <- app$get_js("Number(document.getElementById('events').textContent)")
    app$run_js("mascot.host.reconcile(helper())")
    app$wait_for_js(sprintf("Number(document.getElementById('events').textContent)>%d", delivered))
    app$click("changed_ui")
    app$wait_for_js("read()?.bubble?.text === 'Changed UI'")
    app$click("bubble")
    app$wait_for_js("read().bubble?.text === 'Hello'")
    app$run_js("helper().querySelector('.mascot-bubble-close').click()")
    app$click("bubble")
    app$wait_for_js("read().bubble?.text === 'Hello'")
    app$click("remove")
    app$wait_for_js("helper() === null")
    app$click("prepare")
    app$run_js(
      "const last=lifecycle.filter(e=>e.value.lifecycle==='unmounted').at(-1).value;
      mascot.host.receive({version:1,id:'helper',generation:last.generation,revision:10000,
        state:{},gesture:{name:'wave',revision:10000},gesture_watermark:0,bubble_revision:0,restore:false})"
    )
    app$click("show")
    app$wait_for_js("read()?.status.text === 'Prepared'")
    expect_identical(app$get_js("helper().querySelector('canvas').getAttribute('aria-label')"), "Tessa, Prepared")
    expect_length(app$get_js("gestures"), 0) # disabled gesture is consumed while other fields install
    expect_gt(app$get_js("read().snapshot.gesture_watermark"), 0)
    app$click("follow")
    app$click("happy")
    app$wait_for_js("helper().dataset.shownMood==='happy'")
    expect_identical(
      app$get_js("helper().querySelector('.mascot-status').textContent"),
      "That came together nicely."
    )
    expect_identical(
      app$get_js("helper().querySelector('canvas').getAttribute('aria-label')"),
      "Tessa, That came together nicely."
    )
    revision <- app$get_js("read().snapshot.applied_revision")
    app$click("invalid")
    app$wait_for_js("read().problem?.includes('missing')")
    expect_identical(app$get_js("read().snapshot.applied_revision"), revision)
    expect_identical(app$get_js("read().mood"), "happy")
    expect_match(app$get_js("helper().querySelector('canvas').getAttribute('aria-label')"), "missing")
    # The real Shiny binding must reject the second id before it publishes a
    # competing input; subsequent server state still reaches the original.
    app$run_js(
      "window.duplicateWarnings=[];const warn=console.warn;console.warn=(...args)=>{duplicateWarnings.push(args.join(' '));warn(...args);};
      window.duplicateContainer=document.createElement('div');window.duplicate=helper().cloneNode(true);
      duplicate.classList.remove('shiny-bound-input');
      duplicateContainer.append(duplicate);document.body.append(duplicateContainer);Shiny.bindAll(duplicateContainer);"
    )
    app$wait_for_js("duplicateWarnings.some(message=>message.includes('duplicate live mascot id'))")
    expect_null(app$get_js("mascot.host.state(duplicate)"))
    expect_false(app$get_js("duplicate.classList.contains('shiny-bound-input')"))
    app$click("hundred")
    app$wait_for_js("helper().querySelector('.mascot-status').textContent==='Status 100'")
    expect_identical(app$get_js("read().status.text"), "Status 100")
    app$run_js("Shiny.unbindAll(duplicateContainer);duplicateContainer.remove()")
  })
})

describe("prerendered Shiny template recovery", {
  it("shows an absent template's UI bubble and server updates, and visibly refuses a forged baseline", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      orphan <- mascot(
        "orphan",
        motion = FALSE,
        bubble = mascot_bubble("From UI", duration = Inf),
        theme = list(body = "#123456"),
        click = mascot_action("Help")
      )
      forged <- mascot("forged", motion = FALSE, bubble = "Wrong")
      for (i in seq_along(forged$children)) {
        child <- forged$children[[i]]
        if (inherits(child, "shiny.tag") && "data-mascot-baseline" %in% names(child$attribs)) {
          child$children[[1]] <- htmltools::HTML(sub(
            '"size":160',
            '"size":-1',
            as.character(child$children[[1]]),
            fixed = TRUE
          ))
          forged$children[[i]] <- child
        }
      }
      ui <- shiny::fluidPage(orphan, forged, shiny::actionButton("update", "Update"))
      # Simulate render-time UI built in a different R process, including a
      # restarted server behind a cached page. No token exists at session start.
      store <- mascot:::mascot_template_store()
      store$items <- list()
      shiny::shinyApp(ui, function(input, output, session) {
        shiny::observeEvent(input$update, update_mascot("orphan", mood = "happy", status = "Recovered"))
      })
    })
    withr::defer(app$stop())
    app$wait_for_js("mascot.host.state(document.getElementById('orphan'))?.bubble?.text === 'From UI'")
    expect_false(app$get_js("document.querySelector('#orphan .mascot-bubble').hidden"))
    expect_gt(app$get_js("mascot.host.state(document.getElementById('orphan')).snapshot.applied_revision"), 0)
    app$click("update")
    app$wait_for_js("document.querySelector('#orphan .mascot-status').textContent === 'Recovered'")
    expect_identical(
      app$get_js("document.querySelector('#orphan canvas').getAttribute('aria-label')"),
      "Tessa, Recovered"
    )
    app$wait_for_js("mascot.host.state(document.getElementById('forged'))?.problem?.includes('could not be verified')")
    expect_equal(app$get_js("mascot.host.state(document.getElementById('forged')).snapshot.applied_revision"), 0)
    expect_match(
      app$get_js("document.querySelector('#forged canvas').getAttribute('aria-label')"),
      "could not be verified"
    )
  })
})
