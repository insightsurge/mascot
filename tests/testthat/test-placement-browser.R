describe("dragging in a Shiny browser", {
  it("reports a snapped corner in a module and a free drop point, and a placement update replaces them", {
    local_shiny_browser()
    app <- app_driver(
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
              update_mascot("helper", placement = mascot_placement("bottom-right", drag = "free"))
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
