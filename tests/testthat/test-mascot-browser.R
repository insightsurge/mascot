# Skips the whole file on CRAN or without Chrome, before any of its code runs.
skip_without_chrome()

# A page saved by htmltools, as Quarto, R Markdown and mascot_preview() pages are, opened in Chrome. `extra` is HTML
# added after the page's own scripts. `strip` removes the scripts' data-mascot-version attributes, as pandoc before
# 3.7.0.2 does when it embeds scripts in a self-contained page. Returns a function that evaluates JavaScript there;
# console warnings are recorded in window.warnings from the start.
local_version_page <- function(tag, extra = NULL, strip = FALSE, env = parent.frame()) {
  checkmate::assert_character(extra, null.ok = TRUE)
  checkmate::assert_flag(strip)
  skip_without_chrome()
  dir <- withr::local_tempdir(.local_envir = env)
  page <- file.path(dir, "page.html")
  recorder <- htmltools::tags$head(htmltools::tags$script(htmltools::HTML(
    "window.warnings = []; const warn = console.warn; console.warn = (...a) => { warnings.push(a.join(' ')); warn(...a); };"
  )))
  htmltools::save_html(htmltools::tagList(recorder, tag, if (!is.null(extra)) htmltools::HTML(extra)), page)
  if (strip) {
    html <- readLines(page)
    writeLines(gsub('(<script[^>]*) data-mascot-version="[^"]*"', "\\1", html), page)
  }
  session <- local_chrome_session(env)
  loaded <- session$Page$loadEventFired(wait_ = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(page)), wait_ = FALSE)
  session$wait_for(loaded)
  function(js) session$Runtime$evaluate(js, returnByValue = TRUE)$result$value
}

describe("mascot() clicks in a Shiny browser", {
  it("counts action activations in a module and sends no clicks for menus or pictures", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tagList(
          mascot(id = ns("picture"), placement = "inline"),
          mascot(id = ns("helper"), placement = "inline", click = "Open help"),
          shiny::textOutput(ns("clicks")),
          mascot(id = ns("menu"), placement = "inline", click = mascot_popup_menu(c(about = "About"))),
          shiny::textOutput(ns("menu_clicks"))
        )
      }
      shiny::shinyApp(shiny::fluidPage(ui("module")), function(input, output, session) {
        shiny::moduleServer("module", function(input, output, session) {
          output$clicks <- shiny::renderText(if (is.null(input$helper_click)) 0 else input$helper_click)
          output$menu_clicks <- shiny::renderText(if (is.null(input$menu_click)) 0 else input$menu_click)
        })
      })
    })
    app$wait_for_js("!!document.querySelector('#module-menu .mascot-menu-toggle')")
    # Given an action: each click and each Enter on it reaches its module's server.
    app$click(selector = "#module-helper .mascot-button")
    app$wait_for_js("document.getElementById('module-clicks').textContent === '1'")
    app$click(selector = "#module-helper .mascot-button")
    app$wait_for_js("document.getElementById('module-clicks').textContent === '2'")
    app$run_js(
      "const button=document.querySelector('#module-helper .mascot-button');button.focus();
      button.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true}));"
    )
    app$wait_for_js("document.getElementById('module-clicks').textContent === '3'")
    # Menu toggles do not send action clicks.
    app$click(selector = "#module-menu .mascot-menu-toggle")
    app$wait_for_js("mascot.host.state(document.getElementById('module-menu')).menuOpen")
    app$wait_for_idle()
    expect_null(app$get_value(input = "module-menu_click"))
    app$click(selector = "#module-menu .mascot-menu-toggle")
    app$wait_for_js("!mascot.host.state(document.getElementById('module-menu')).menuOpen")
    app$wait_for_idle()
    expect_null(app$get_value(input = "module-menu_click"))
    # A picture sends nothing.
    app$click(selector = "#module-picture canvas")
    app$wait_for_idle()
    expect_null(app$get_value(input = "module-picture_click"))
  })
})

describe("the engine version", {
  version <- as.character(utils::packageVersion("mascot"))

  it("is the package version in a page saved by htmltools and in mascot_preview()", {
    js <- local_version_page(mascot("a", placement = "inline"))
    expect_identical(js("window.mascot.version"), version)
    expect_identical(js("window.warnings.length"), 0L)
    js <- local_version_page(mascot_preview())
    expect_identical(js("window.mascot.version"), version)
  })

  it("comes from the mascot element when the page dropped the script's attribute", {
    expect_identical(mascot("a")$attribs$`data-mascot-version`, version)
    js <- local_version_page(mascot("a", placement = "inline"), strip = TRUE)
    expect_identical(js("document.querySelector('script[data-mascot-version]')"), NULL)
    expect_identical(js("window.mascot.version"), version)
  })

  it("is the package version in a rendered R Markdown page", {
    testthat::skip_if_not_installed("rmarkdown")
    testthat::skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
    skip_without_chrome()
    dir <- withr::local_tempdir()
    source <- file.path(dir, "page.Rmd")
    writeLines(
      c(
        "---",
        "title: Version",
        "output:",
        "  html_document:",
        "    self_contained: false",
        "---",
        "",
        "```{r, echo = FALSE}",
        "mascot::mascot('a', placement = 'inline')",
        "```"
      ),
      source
    )
    output <- rmarkdown::render(source, quiet = TRUE, envir = new.env(), intermediates_dir = dir)
    session <- local_chrome_session()
    loaded <- session$Page$loadEventFired(wait_ = FALSE)
    session$Page$navigate(paste0("file://", normalizePath(output)), wait_ = FALSE)
    session$wait_for(loaded)
    expect_identical(session$Runtime$evaluate("window.mascot.version", returnByValue = TRUE)$result$value, version)
  })

  it("is the package version in a Shiny app, also when the mascot arrives through renderUI()", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      shiny::shinyApp(
        shiny::fluidPage(shiny::uiOutput("later")),
        function(input, output, session) {
          output$later <- shiny::renderUI(mascot("helper", placement = "inline"))
        }
      )
    })
    app$wait_for_js("window.mascot?.host?.state(document.getElementById('helper')) != null")
    expect_identical(app$get_js("window.mascot.version"), version)
  })

  it("keeps the first engine and warns once when a page loads a second engine of another version", {
    www <- normalizePath(system.file("www", "mascot.js", package = "mascot"))
    again <- function(v) sprintf('<script src="file://%s" data-mascot-version="%s"></script>', www, v)
    js <- local_version_page(mascot("a", placement = "inline"), extra = c(again(version), again("99.0.0")))
    warnings <- js("window.warnings")
    expect_identical(js("window.mascot.version"), version)
    # The same version again is no conflict; the other version is named with the one that stays in use.
    expect_length(warnings, 1)
    expect_match(warnings[[1]], sprintf("engine version 99.0.0 after version %s", version), fixed = TRUE)
    expect_match(warnings[[1]], "Load one version of mascot per page", fixed = TRUE)
  })
})

describe("mascot() character data in the browser", {
  # JavaScript: the character each listed mascot is mounted with, or null when it did not mount.
  mounted_js <- function(ids) {
    sprintf(
      "[%s].map(id => mascot.host.state(document.getElementById(id))?.character ?? null)",
      paste0("'", ids, "'", collapse = ",")
    )
  }
  # JavaScript: how many data blocks of each character the page has, and how many sit inside a mascot.
  blocks_js <- paste0(
    "(() => { const all = [...document.querySelectorAll('script[data-mascot-character]')];",
    "const count = {}; for (const el of all) count[el.dataset.mascotCharacter] = (count[el.dataset.mascotCharacter] || 0) + 1;",
    "return { count, inside: all.filter(el => el.closest('.mascot')).map(el => el.dataset.mascotCharacter) }; })()"
  )
  bot_path <- system.file("examples", "characters", "study_bot.json", package = "mascot")

  it("mounts every mascot of a saved page from one copy per built-in character", {
    bot <- mascot_character(mascot_read_character(bot_path))
    page <- htmltools::tagList(
      lapply(1:5, function(i) mascot(paste0("t", i), placement = "inline", motion = FALSE)),
      mascot("s", character = "sela", placement = "inline", motion = FALSE),
      mascot("bot", character = bot, placement = "inline", motion = FALSE)
    )
    js <- local_version_page(page)
    expect_identical(
      unlist(js(mounted_js(c(paste0("t", 1:5), "s", "bot")))),
      c(rep("tessa", 5), "sela", "study_bot")
    )
    blocks <- js(blocks_js)
    expect_identical(blocks$count, list(tessa = 1L, sela = 1L, study_bot = 1L))
    expect_identical(unlist(blocks$inside), "study_bot")
    expect_identical(js("window.warnings.length"), 0L)
  })

  it("mounts from a self-contained R Markdown page", {
    testthat::skip_if_not_installed("rmarkdown")
    testthat::skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
    skip_without_chrome()
    dir <- withr::local_tempdir()
    source <- file.path(dir, "page.Rmd")
    writeLines(
      c(
        "---",
        "title: Characters",
        "output:",
        "  html_document:",
        "    self_contained: true",
        "---",
        "",
        "```{r, echo = FALSE}",
        "htmltools::tagList(",
        "  mascot::mascot('a', placement = 'inline'),",
        "  mascot::mascot('b', placement = 'inline'),",
        "  mascot::mascot('c', character = 'sela', placement = 'inline')",
        ")",
        "```"
      ),
      source
    )
    output <- rmarkdown::render(source, quiet = TRUE, envir = new.env(), intermediates_dir = dir)
    session <- local_chrome_session()
    loaded <- session$Page$loadEventFired(wait_ = FALSE)
    session$Page$navigate(paste0("file://", normalizePath(output)), wait_ = FALSE)
    session$wait_for(loaded)
    js <- function(code) session$Runtime$evaluate(code, returnByValue = TRUE)$result$value
    expect_identical(unlist(js(mounted_js(c("a", "b", "c")))), c("tessa", "tessa", "sela"))
    expect_identical(js(blocks_js)$count, list(tessa = 1L, sela = 1L))
  })

  it("mounts in a Shiny app, renderUI() and its re-renders, insertUI() and a modal", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      bot <- mascot_character(mascot_read_character(
        system.file("examples", "characters", "study_bot.json", package = "mascot")
      ))
      shiny::shinyApp(
        shiny::fluidPage(
          mascot("first", placement = "inline", motion = FALSE),
          mascot("second", placement = "inline", motion = FALSE),
          shiny::actionButton("again", "Again"),
          shiny::actionButton("insert", "Insert"),
          shiny::actionButton("modal", "Modal"),
          shiny::uiOutput("cards"),
          shiny::div(id = "slot")
        ),
        function(input, output, session) {
          output$cards <- shiny::renderUI({
            status <- paste("Render", input$again)
            htmltools::tagList(
              mascot("card1", status = status, placement = "inline", motion = FALSE),
              mascot("card2", character = "sela", status = status, placement = "inline", motion = FALSE)
            )
          })
          shiny::observeEvent(input$insert, {
            shiny::insertUI("#slot", ui = mascot("inserted", character = "knurl", placement = "inline", motion = FALSE))
          })
          shiny::observeEvent(input$modal, {
            shiny::showModal(shiny::modalDialog(
              mascot("in_modal", character = "neer", placement = "inline", motion = FALSE),
              mascot("bot", character = bot, placement = "inline", motion = FALSE)
            ))
          })
        }
      )
    })
    app$wait_for_js("mascot.host.state(document.getElementById('card2')) != null")
    expect_identical(
      unlist(app$get_js(mounted_js(c("first", "second", "card1", "card2")))),
      c("tessa", "tessa", "tessa", "sela")
    )
    expect_identical(app$get_js(blocks_js)$count, list(tessa = 1L, sela = 1L))
    # A re-render replaces the cards; the page keeps one copy of each character.
    app$click("again")
    app$wait_for_js("document.querySelector('#card1 .mascot-status').textContent === 'Render 1'")
    app$wait_for_js("mascot.host.state(document.getElementById('card2')) != null")
    expect_identical(unlist(app$get_js(mounted_js(c("card1", "card2")))), c("tessa", "sela"))
    expect_identical(app$get_js(blocks_js)$count, list(tessa = 1L, sela = 1L))
    app$click("insert")
    app$wait_for_js("mascot.host.state(document.getElementById('inserted')) != null")
    expect_identical(app$get_js(mounted_js("inserted"))[[1]], "knurl")
    app$click("modal")
    app$wait_for_js("mascot.host.state(document.getElementById('bot')) != null")
    expect_identical(unlist(app$get_js(mounted_js(c("in_modal", "bot")))), c("neer", "study_bot"))
    blocks <- app$get_js(blocks_js)
    expect_identical(blocks$count, list(tessa = 1L, sela = 1L, knurl = 1L, neer = 1L, study_bot = 1L))
    expect_identical(unlist(blocks$inside), "study_bot")
  })
})
