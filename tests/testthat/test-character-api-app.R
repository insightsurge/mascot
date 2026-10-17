describe("R4a characters through real Shiny", {
  it("mounts every built-in through mascot() and changes its mood", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      ids <- c("tessa", "sela", "knurl")
      ui <- shiny::fluidPage(shiny::tagList(lapply(ids, function(id) {
        shiny::tagList(
          mascot(id = id, character = id, motion = FALSE),
          shiny::actionButton(paste0(id, "-happy"), "Happy")
        )
      })))
      server <- function(input, output, session) {
        for (id in ids) {
          local({
            current_id <- id
            shiny::observeEvent(input[[paste0(current_id, "-happy")]], update_mascot(current_id, mood = "happy"))
          })
        }
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    for (id in c("tessa", "sela", "knurl")) {
      app$wait_for_js(sprintf("mascot.host.state(document.getElementById('%s')) !== null", id))
      expect_identical(app$get_js(sprintf("document.getElementById('%s').dataset.shownCharacter", id)), id)
      app$click(paste0(id, "-happy"))
      app$wait_for_js(sprintf("document.getElementById('%s').dataset.shownMood === 'happy'", id))
      expect_identical(app$get_js(sprintf("mascot.host.state(document.getElementById('%s')).mood", id)), "happy")
    }
  })

  it("keeps registered and visitor objects separate in two modules and two sessions, and escapes character text", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      file <- system.file("examples", "characters", "study_bot.json", package = "mascot")
      registered <- mascot:::mascot_read_character(file)
      mascot:::mascot_register_character(registered)
      counter <- new.env(parent = emptyenv())
      counter$value <- 0L
      module_ui <- function(id) {
        shiny::tagList(
          shiny::uiOutput(shiny::NS(id, "slot")),
          shiny::actionButton(shiny::NS(id, "happy"), "Happy"),
          shiny::actionButton(shiny::NS(id, "swap"), "Swap custom character")
        )
      }
      ui <- shiny::fluidPage(module_ui("registered"), module_ui("object"), shiny::textOutput("registry"))
      server <- function(input, output, session) {
        counter$value <- counter$value + 1L
        source <- jsonlite::read_json(file)
        source$id <- "visitor_bot"
        source$name <- paste("Visitor", counter$value)
        source$moods$idle$status <- paste0("<b>Visitor ", counter$value, "</b>")
        visitor <- mascot:::mascot_check_character(source)
        module <- function(id, character) {
          shiny::moduleServer(id, function(input, output, session) {
            output$slot <- shiny::renderUI(mascot(session$ns("helper"), character = character, motion = FALSE))
            shiny::observeEvent(input$happy, update_mascot("helper", mood = "happy", gesture = "greet"))
            shiny::observeEvent(input$swap, {
              next_source <- jsonlite::read_json(file)
              next_source$id <- "swapped_bot"
              next_source$name <- "Swapped Bot"
              update_mascot("helper", character = mascot:::mascot_check_character(next_source), mood = "worried")
            })
          })
        }
        module("registered", "study_bot")
        module("object", visitor)
        output$registry <- shiny::renderText(paste(mascot_characters()$id, collapse = ","))
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    ready <- "document.getElementById('object-helper') && window.mascot?.host?.state(document.getElementById('object-helper'))?.snapshot.applied_revision > 0"
    app$wait_for_js(ready)
    expect_identical(app$get_js("document.getElementById('registered-helper').dataset.shownCharacter"), "study_bot")
    expect_identical(
      app$get_js("document.querySelector('#object-helper .mascot-status').textContent"),
      "<b>Visitor 1</b>"
    )
    expect_null(app$get_js("document.querySelector('#object-helper .mascot-status b')"))
    expect_identical(app$get_js("document.getElementById('registry').textContent"), "tessa,sela,knurl,study_bot")
    for (id in c("registered-helper", "object-helper")) {
      expect_true(app$get_js(sprintf(
        "(() => { const c = document.querySelector('#%s canvas');
        const bytes = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
        return bytes.some((v, i) => i %% 4 === 3 && v > 0); })()",
        id
      )))
    }
    # A second WebSocket connection to the very same R process, not a second app.
    second <- chromote::ChromoteSession$new(parent = test_browser())
    withr::defer(second$close())
    loaded <- second$Page$loadEventFired(wait_ = FALSE)
    second$Page$navigate(app$get_js("window.location.href"), wait_ = FALSE)
    second$wait_for(loaded)
    result <- second$Runtime$evaluate(
      paste0(
        "(async()=>{const deadline=Date.now()+30000;while(!(",
        ready,
        ")){",
        "if(Date.now()>deadline)throw Error('second session did not mount');",
        "await new Promise(r=>setTimeout(r,50));}",
        "return [document.querySelector('#object-helper .mascot-status').textContent,",
        "document.getElementById('registry').textContent,",
        "document.getElementById('object-helper').querySelector('canvas').getAttribute('aria-label')];})()"
      ),
      awaitPromise = TRUE,
      returnByValue = TRUE
    )
    expect_null(result$exceptionDetails, info = paste(capture.output(str(result$exceptionDetails)), collapse = "\n"))
    expect_identical(
      unlist(result$result$value),
      c("<b>Visitor 2</b>", "tessa,sela,knurl,study_bot", "Visitor 2, <b>Visitor 2</b>")
    )
    # Two objects with the same character id still retain different content.
    expect_identical(
      app$get_js("document.querySelector('#object-helper .mascot-status').textContent"),
      "<b>Visitor 1</b>"
    )
    app$click("object-happy")
    app$wait_for_js("document.getElementById('object-helper').dataset.shownMood === 'happy'")
    expect_identical(app$get_js("document.querySelector('#object-helper .mascot-status').textContent"), "Done")
    expect_identical(app$get_js("document.querySelector('#registered-helper .mascot-status').textContent"), "Ready")
    app$click("object-swap")
    app$wait_for_js("document.getElementById('object-helper').dataset.shownCharacter === 'swapped_bot'")
    expect_identical(
      app$get_js("document.querySelector('#object-helper .mascot-status').textContent"),
      "Check the result"
    )
    expect_identical(app$get_js("document.getElementById('registry').textContent"), "tessa,sela,knurl,study_bot")
    expect_identical(
      second$Runtime$evaluate(
        "document.querySelector('#object-helper .mascot-status').textContent",
        returnByValue = TRUE
      )$result$value,
      "<b>Visitor 2</b>"
    )
  })
})
