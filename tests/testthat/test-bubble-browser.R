describe("speech bubbles in a Shiny browser", {
  it("lets clicks through reserved space while keeping the bubble interactive", {
    local_shiny_browser()
    app <- app_driver(
      function() {
        library(mascot)
        shiny::shinyApp(
          shiny::fluidPage(
            mascot("helper", placement = "inline", status = "Ready"),
            shiny::actionButton("go", "Click me"),
            shiny::textOutput("clicks"),
            shiny::actionButton("show", "Show bubble")
          ),
          function(input, output, session) {
            output$clicks <- shiny::renderText(input$go)
            shiny::observeEvent(input$show, {
              update_mascot(
                "helper",
                bubble = mascot_bubble(
                  paste(rep("A message long enough to scroll.", 30), collapse = " "),
                  duration = Inf,
                  closable = TRUE
                )
              )
            })
          }
        )
      },
      width = 800,
      height = 600
    )
    app$wait_for_js("mascot.host.state(document.getElementById('helper')) !== null")

    # The button's centre is covered by the empty region on the unfixed page (#506).
    expect_true(app$get_js(
      "(() => { const button = document.getElementById('go'), r = button.getBoundingClientRect();
      return button.contains(document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2)); })()"
    ))
    expect_true(app$get_js(
      "(() => { const button = document.getElementById('go').getBoundingClientRect(),
        region = document.querySelector('#helper .mascot-bubble-region').getBoundingClientRect(),
        x = button.left + button.width / 2, y = button.top + button.height / 2;
      return x > region.left && x < region.right && y > region.top && y < region.bottom; })()"
    ))
    app$click("go")
    app$wait_for_js("document.getElementById('clicks').textContent === '1'")
    expect_identical(app$get_value(output = "clicks"), "1")

    app$click("show")
    app$wait_for_js("!document.querySelector('#helper .mascot-bubble').hidden")
    app$wait_for_js("document.querySelector('#helper .mascot-bubble').getAnimations().length === 0")
    expect_true(app$get_js(
      "(() => { const bubble = document.querySelector('#helper .mascot-bubble'),
        r = bubble.getBoundingClientRect();
      return bubble.contains(document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2)); })()"
    ))
    # Above the bubble and beyond the mascot's width, the reserved region still lets clicks through.
    expect_true(app$get_js(
      "(() => { const region = document.querySelector('#helper .mascot-bubble-region'),
        r = region.getBoundingClientRect(), bubble = region.firstElementChild.getBoundingClientRect(),
        mascot = document.getElementById('helper').getBoundingClientRect(), x = r.right - 1, y = r.top + 1;
      return x > mascot.right && y < bubble.top && !region.contains(document.elementFromPoint(x, y)); })()"
    ))
    text_centre <- app$get_js(
      "(() => { const text = document.querySelector('#helper .mascot-bubble-text'),
        r = text.getBoundingClientRect();
      return {x: r.left + r.width / 2, y: r.top + r.height / 2,
        scrollable: text.scrollHeight > text.clientHeight,
        receivesPointer: text.contains(document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2))}; })()"
    )
    expect_true(text_centre$scrollable)
    expect_true(text_centre$receivesPointer)
    app$get_chromote_session()$Input$dispatchMouseEvent(
      type = "mouseWheel",
      x = text_centre$x,
      y = text_centre$y,
      deltaX = 0,
      deltaY = 100
    )
    app$wait_for_js("document.querySelector('#helper .mascot-bubble-text').scrollTop > 0")

    app$click(selector = "#helper .mascot-bubble-close")
    app$wait_for_js("document.querySelector('#helper .mascot-bubble').hidden")
    expect_null(app$get_js("mascot.host.state(document.getElementById('helper')).bubble"))
    app$click("go")
    app$wait_for_js("document.getElementById('clicks').textContent === '2'")
    expect_identical(app$get_value(output = "clicks"), "2")
  })
})
