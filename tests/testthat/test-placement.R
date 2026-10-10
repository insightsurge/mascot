describe("mascot_placement()", {
  it("normalises every shortcut to one position and floats bottom-right by default", {
    expect_identical(
      mascot_placement(),
      structure(list(position = "bottom-right", minimise = TRUE, drag = FALSE), class = "mascot_placement")
    )
    expect_identical(as_placement_arg("inline", environment()), mascot_placement("inline"))
    expect_identical(as_placement_arg("floating", environment()), mascot_placement())
    for (corner in c("top-left", "top-right", "bottom-left", "bottom-right")) {
      expect_identical(as_placement_arg(corner, environment()), mascot_placement(corner))
    }
    expect_identical(
      as_placement_arg(list(position = "top-left", minimise = TRUE), environment()),
      mascot_placement("top-left", minimise = TRUE)
    )
    expect_identical(as_placement_arg(list(), environment()), mascot_placement())
    expect_identical(
      as_placement_arg(list(minimise = TRUE), environment()),
      mascot_placement("bottom-right", minimise = TRUE)
    )
    expect_identical(
      as_placement_arg(list(drag = "snap"), environment()),
      mascot_placement("bottom-right", drag = "snap")
    )
    expect_identical(
      as_placement_arg(mascot_placement("bottom-right", minimise = TRUE), environment()),
      mascot_placement("bottom-right", minimise = TRUE)
    )
  })
  it("sends the browser's floating, corner and minimise fields", {
    expect_identical(
      placement_wire(mascot_placement()),
      list(floating = TRUE, position = "bottom-right", minimise = TRUE, drag = FALSE)
    )
    expect_identical(
      placement_wire(mascot_placement("inline")),
      list(floating = FALSE, position = "bottom-right", minimise = FALSE, drag = FALSE)
    )
    expect_identical(
      placement_wire(mascot_placement("top-left", TRUE)),
      list(floating = TRUE, position = "top-left", minimise = TRUE, drag = FALSE)
    )
    expect_identical(
      placement_wire(mascot_placement("bottom-left", drag = "free")),
      list(floating = TRUE, position = "bottom-left", minimise = TRUE, drag = "free")
    )
    expect_error(placement_wire(list(position = "inline")), "mascot_placement")
  })
  it("checks positions, flags and unknown fields", {
    for (x in list(NULL, NA, 1, c(TRUE, FALSE))) {
      expect_error(mascot_placement("bottom-right", minimise = x), "minimise")
    }
    for (x in list(NULL, NA_character_, 1, "left", "floating", c("top-left", "top-right"))) {
      expect_error(mascot_placement(position = x), "position")
    }
    for (x in list(
      NULL,
      NA,
      1,
      "fixed",
      list(snap = TRUE),
      list(floating = TRUE),
      list(TRUE),
      structure(list("top-left", "top-right"), names = c("position", "position"))
    )) {
      expect_error(as_placement_arg(x, environment()), "placement|minimise")
    }
    bad <- mascot_placement()
    bad$position <- "left"
    expect_error(as_placement_arg(bad, environment()), "position")
    bad <- mascot_placement()
    bad$typo <- TRUE
    expect_error(as_placement_arg(bad, environment()), "fields")
    expect_error(as_placement_arg("inline", NULL), "call")
    expect_error(as_placement_arg(list(position = "left"), environment()), "position.*top-left")
    expect_error(as_placement_arg(list(position = "top-left", minimise = NA), environment()), "minimise.*TRUE or FALSE")
    expect_error(as_placement_arg(structure(1, class = "mascot_placement"), environment()), "placement")
    expect_snapshot(error = TRUE, mascot_placement("left"))
  })
  it("accepts drag modes with a corner, in the helper and the named-list shortcut", {
    expect_identical(mascot_placement("top-left", drag = "snap")$drag, "snap")
    expect_identical(mascot_placement("bottom-right", minimise = TRUE, drag = "free")$drag, "free")
    expect_identical(
      as_placement_arg(list(position = "top-left", drag = "snap"), environment()),
      mascot_placement("top-left", drag = "snap")
    )
    expect_identical(
      as_placement_arg(list(position = "top-right", minimise = TRUE, drag = FALSE), environment()),
      mascot_placement("top-right", minimise = TRUE)
    )
    expect_identical(
      format(mascot_placement("bottom-right", drag = "snap")),
      'mascot_placement(position = "bottom-right", minimise = TRUE, drag = "snap")'
    )
  })
  it("rejects TRUE, unknown and malformed drag values", {
    for (x in list(NULL, NA, NA_character_, 1, c("snap", "free"), list("snap"))) {
      expect_error(mascot_placement("bottom-right", drag = x), "drag")
    }
    expect_error(mascot_placement("bottom-right", drag = TRUE), "TRUE.*not accepted")
    expect_error(mascot_placement("bottom-right", drag = "fixed"), "\"fixed\" is not a drag mode")
    expect_error(abort_drag("left", NULL), "call")
    for (x in list(
      list(position = "top-left", drag = TRUE),
      list(position = "top-left", drag = "fixed"),
      list(position = "top-left", drag = NA),
      list(position = "top-left", drag = NULL)
    )) {
      expect_false(is.null(placement_problem(x)))
      expect_error(as_placement_arg(x, environment()), "drag|placement")
    }
    expect_match(placement_problem(list(position = "top-left", drag = TRUE)), "got TRUE. Use \"snap\"")
    expect_match(placement_problem(list(position = "top-left", drag = "fixed")), 'got "fixed".$')
    old <- mascot_placement("top-left")
    old$drag <- NULL
    expect_match(placement_problem(old), "position, minimise and drag fields")
    expect_snapshot(error = TRUE, mascot_placement("bottom-right", drag = TRUE))
    expect_snapshot(error = TRUE, mascot_placement("bottom-right", drag = "fixed"))
    expect_snapshot(error = TRUE, mascot(id = "a", placement = list(position = "top-left", drag = TRUE)))
  })
  it("silently disables inline defaults and informs about each explicit control", {
    expect_error(inform_placement_ignored(1), "args")
    expect_error(inform_placement_ignored(NA_character_), "args")
    expect_silent(inline <- mascot_placement("inline"))
    expect_identical(inline$minimise, FALSE)
    expect_identical(inline$drag, FALSE)
    expect_silent(as_placement_arg(list(position = "inline"), environment()))
    for (value in c(TRUE, FALSE)) {
      expect_message(
        result <- mascot_placement("inline", minimise = value),
        "minimise.*no effect.*inline",
        class = "mascot_placement_ignored"
      )
      expect_identical(result, inline)
    }
    for (value in list("snap", "free", FALSE)) {
      expect_message(
        result <- mascot_placement("inline", drag = value),
        "drag.*no effect.*inline",
        class = "mascot_placement_ignored"
      )
      expect_identical(result, inline)
    }
    expect_snapshot(invisible(mascot_placement("inline", minimise = TRUE)))
    expect_snapshot(invisible(mascot_placement("inline", drag = "snap")))
    expect_snapshot(invisible(mascot_placement("inline", minimise = TRUE, drag = "free")))
    # Even a helper with active controls cannot send those controls inline.
    inline$minimise <- TRUE
    inline$drag <- "snap"
    expect_identical(
      placement_wire(inline),
      list(floating = FALSE, position = "bottom-right", minimise = FALSE, drag = FALSE)
    )
    expect_identical(mascot_placement(minimise = FALSE)$minimise, FALSE)
  })
  it("writes the drag mode for the browser and drops it for inline mascots", {
    html <- as.character(mascot(id = "a", placement = list(position = "top-left", drag = "snap")))
    expect_match(html, 'data-drag="snap"', fixed = TRUE)
    expect_match(html, 'data-position="top-left"', fixed = TRUE)
    expect_match(as.character(mascot(id = "a")), 'data-drag="false"', fixed = TRUE)
  })
})

describe("dragging in a Shiny browser", {
  it("reports a snapped corner in a module and a free drop point, and a placement update replaces them", {
    local_shiny_browser()
    app <- shinytest2::AppDriver$new(
      function() {
        library(mascot)
        module_ui <- function(id) {
          ns <- shiny::NS(id)
          shiny::tagList(
            mascot(id = ns("helper"), size = 80, placement = mascot_placement("bottom-right", drag = "snap")),
            shiny::textOutput(ns("where")),
            shiny::actionButton(ns("reset"), "Reset")
          )
        }
        module_server <- function(id) {
          shiny::moduleServer(id, function(input, output, session) {
            output$where <- shiny::renderText(paste("corner", input$helper_position))
            shiny::observeEvent(
              input$reset,
              updateMascot("helper", placement = mascot_placement("bottom-right", drag = "free"))
            )
          })
        }
        shiny::shinyApp(
          shiny::fluidPage(
            module_ui("mod"),
            mascot(id = "free", size = 80, placement = mascot_placement("top-left", drag = "free")),
            shiny::textOutput("free_where")
          ),
          function(input, output, session) {
            module_server("mod")
            output$free_where <- shiny::renderText({
              shiny::req(input$free_position)
              paste(input$free_position$x, input$free_position$y)
            })
          }
        )
      },
      width = 800,
      height = 600
    )
    withr::defer(app$stop())
    app$wait_for_js("mascot.host.state(document.getElementById('mod-helper')) !== null")
    app$run_js(
      "window.dragBy=(id,dx,dy)=>{const c=document.querySelector('#'+id+' canvas'),r=c.getBoundingClientRect();
      const x=r.left+r.width/2,y=r.top+r.height/2,send=(type,px,py)=>c.dispatchEvent(new PointerEvent(type,
      {bubbles:true,cancelable:true,pointerId:1,button:0,isPrimary:true,clientX:px,clientY:py}));
      send('pointerdown',x,y);send('pointermove',x+dx/2,y+dy/2);send('pointermove',x+dx,y+dy);send('pointerup',x+dx,y+dy);};
      dragBy('mod-helper',-600,-450);"
    )
    app$wait_for_js("document.getElementById('mod-helper').dataset.position === 'top-left'")
    app$wait_for_value(output = "mod-where", ignore = list("", "corner "))
    expect_identical(app$get_value(output = "mod-where"), "corner top-left")
    expect_identical(app$get_value(input = "mod-helper_position"), "top-left")
    # The snap animates (no reduced motion here); the corner sits 1rem in (Bootstrap 3 sets 1rem to 10px).
    app$wait_for_js("document.getElementById('mod-helper').getAnimations().length === 0")
    rem <- app$get_js("parseFloat(getComputedStyle(document.documentElement).fontSize)")
    expect_equal(app$get_js("document.getElementById('mod-helper').getBoundingClientRect().left"), rem)
    start <- app$get_js("document.getElementById('free').getBoundingClientRect().top")
    expect_equal(start, rem)
    app$run_js("dragBy('free',300,200)")
    app$wait_for_value(output = "free_where", ignore = list(""))
    expect_identical(app$get_value(output = "free_where"), paste(rem + 300, rem + 200))
    expect_equal(app$get_value(input = "free_position"), list(x = rem + 300, y = rem + 200))
    expect_equal(app$get_js("document.getElementById('free').getBoundingClientRect().top"), rem + 200)
    app$click("mod-reset")
    app$wait_for_js("document.getElementById('mod-helper').dataset.drag === 'free'")
    expect_identical(app$get_js("document.getElementById('mod-helper').dataset.position"), "bottom-right")
    expect_null(app$get_js("document.getElementById('mod-helper').dataset.placed ?? null"))
  })
})
