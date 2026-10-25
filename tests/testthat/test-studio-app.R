studio_app_parts <- function() {
  skip_without_studio_packages("studio")
  app <- shiny::shinyAppDir(system.file("examples", "studio", package = "mascot"))
  list(
    env = environment(app$serverFuncSource()),
    page = as.character(
      app$httpHandler(
        list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = "")
      )$content
    )
  )
}

describe("studio signature routes", {
  it("makes every mascot formal a call chip with an existing function route", {
    parts <- studio_app_parts()
    chip_builder <- get("call_chips", parts$env)
    route <- get("studio_route", parts$env)
    initial <- get("start", parts$env)
    expected <- setdiff(names(formals(mascot)), "...")
    html <- as.character(chip_builder(initial, "short"))
    chips <- regmatches(html, gregexpr('data-call-arg="[^"]+"', html))[[1]]
    expect_length(chips, length(expected) + 1L)
    for (arg in expected) {
      expect_match(html, paste0('data-call-arg="', arg, '"'), fixed = TRUE)
      expect_true(route(arg)$fn %in% getNamespaceExports("mascot"), info = arg)
    }
    expect_match(html, 'data-call-arg="click"', fixed = TRUE)
    expect_false(grepl('data-call-arg="action"', html, fixed = TRUE))
    expect_false(grepl('"Tessa"', html, fixed = TRUE))
    expect_error(route("unknown"), "Assertion on 'arg' failed")
    expect_error(route(1), "Assertion on 'arg' failed")
    expect_error(chip_builder(NULL, "short"), "Assertion on 'state' failed")
    expect_error(chip_builder(initial, "short", 1), "Assertion on 'gesture' failed")
    expect_error(chip_builder(initial, "unknown"), "Assertion on 'style' failed")
  })
  it("gives the click chip one route per kind of click, in the page and in the chip it draws", {
    parts <- studio_app_parts()
    routes <- get("studio_click_routes", parts$env)()
    controls <- get("studio_controls", parts$env)
    expect_named(routes, c("none", "action", "menu"))
    for (kind in names(routes)) {
      route <- routes[[kind]]
      expect_true(route$fn %in% getNamespaceExports("mascot"), info = kind)
      # The control and the argument it sets exist in the studio's control map
      expect_true(sprintf('id="%s"', route$input) %in% controls[[route$fn]][[route$field]], info = kind)
    }
    # The page carries the same table for studio.js
    attribute <- regmatches(parts$page, regexpr('data-click-routes="[^"]*"', parts$page))
    json <- gsub("&quot;", '"', sub('^data-click-routes="(.*)"$', "\\1", attribute), fixed = TRUE)
    expect_identical(jsonlite::fromJSON(json, simplifyVector = FALSE), routes)
    # The chip the server draws for a menu and for an action opens the route of its kind
    code_pair <- get("code_pair", parts$env)
    initial <- get("start", parts$env)
    for (case in list(
      list("menu", quote(mascot_popup_menu(items = c(about = "About")))),
      list("action", quote(mascot_action("Open help")))
    )) {
      initial$click <- code_pair(case[[2]])
      html <- as.character(get("call_chips", parts$env)(initial, "short"))
      chip <- regmatches(html, regexpr('<button[^>]*data-call-arg="click"[^>]*>', html))
      expect_match(chip, sprintf('data-call-function="%s"', routes[[case[[1]]]]$fn), fixed = TRUE)
      expect_match(chip, sprintf('data-call-input="%s"', routes[[case[[1]]]]$input), fixed = TRUE)
    }
  })
  it("searches every export and formal and keeps each input id unique", {
    page <- studio_app_parts()$page
    for (fn in getNamespaceExports("mascot")) {
      expect_match(page, paste0('data-search-function="', fn, '"'), fixed = TRUE)
      for (arg in names(formals(getExportedValue("mascot", fn)))) {
        expect_match(page, paste0('id="search_', fn, '_', gsub("[.]", "dot", arg), '"'), fixed = TRUE)
      }
    }
    search <- as.character(get("studio_search", studio_app_parts()$env)())
    expect_length(
      regmatches(search, gregexpr('role="option"', search, fixed = TRUE))[[1]],
      length(getNamespaceExports("mascot"))
    )
    for (fn in getNamespaceExports("mascot")) {
      expect_match(search, paste0('id="search_', fn, '_function"'), fixed = TRUE)
      for (arg in names(formals(getExportedValue("mascot", fn)))) {
        expect_match(search, paste0('aria-label="Open ', fn, ' at ', arg, '"'), fixed = TRUE)
      }
    }
    expect_unique_ids(page)
    for (text in c('role="combobox"', 'role="listbox"', 'aria-modal="true"', 'id="studio_keys"')) {
      expect_match(page, text, fixed = TRUE)
    }
    expect_length(regmatches(page, gregexpr(' data-group="', page))[[1]], 7L)
  })
})

describe("studio demonstration server routes", {
  it("starts the live studio and example source handlers together for either URL view", {
    parts <- studio_app_parts()
    initial <- list(
      character = "tessa",
      mood = "idle",
      gesture = "",
      status_text = "",
      code_style = "short",
      bubble_text = "Hello",
      bubble_html = FALSE,
      bubble_forever = FALSE,
      bubble_duration = 5,
      bubble_closable = TRUE,
      theme_source = "own",
      theme_mode = "auto",
      `colours-css_roles` = character(),
      `colours-css_value` = "#123456",
      position = "inline",
      minimise = TRUE,
      drag = "none",
      size_unit = "px",
      size_px = 160,
      small_mode = "auto",
      small_px = 72,
      idle = "follow",
      mood_change = "follow",
      gestures = "follow",
      swap = "follow",
      minimising = "follow",
      restoring = "follow",
      messages = "follow",
      others = TRUE,
      action_on = FALSE,
      menu_on = FALSE,
      menu_items = "",
      menu_direction = "auto",
      mistake = "Misspell an argument"
    )
    for (view in c("studio", "examples")) {
      shiny::testServer(get("server", parts$env), {
        do.call(
          session$setInputs,
          c(
            initial,
            list(
              tabs = view,
              host_mode = "mascot",
              example_name = "form-check",
              example_run = FALSE
            )
          )
        )
        expect_match(output$live_host$html, 'id="live_frame"', fixed = TRUE)
        expect_match(output$example_result$html, 'id="example_code"', fixed = TRUE)
        saved <- output$code_ui
        session$setInputs(gesture = "wave")
        expect_match(output$code_last, 'gesture = "wave"', fixed = TRUE)
        expect_identical(output$code_ui, saved)
        session$setInputs(gesture_replay = "wave")
        expect_match(output$code_last, 'gesture = "wave"', fixed = TRUE)
        expect_identical(output$code_ui, saved)
        session$setInputs(gesture = "")
        expect_identical(output$code_ui, saved)
      })
    }
  })
  it("filters both character tables and shows update activity inside its inspector", {
    parts <- studio_app_parts()
    expect_match(parts$page, 'id="wiring_log"', fixed = TRUE)
    expect_match(parts$page, 'id="send_many"', fixed = TRUE)
    expect_match(parts$page, 'id="mistake_run"', fixed = TRUE)
    expect_match(parts$page, 'id="task_run"', fixed = TRUE)
    initial <- list(
      character = "tessa",
      mood = "idle",
      status_text = "",
      code_style = "short",
      bubble_text = "Hello",
      bubble_html = FALSE,
      bubble_forever = FALSE,
      bubble_duration = 5,
      bubble_closable = TRUE,
      theme_source = "own",
      theme_mode = "auto",
      `colours-css_roles` = character(),
      `colours-css_value` = "#123456",
      position = "inline",
      minimise = TRUE,
      drag = "none",
      size_unit = "px",
      size_px = 160,
      small_mode = "auto",
      small_px = 72,
      idle = "follow",
      mood_change = "follow",
      gestures = "follow",
      swap = "follow",
      minimising = "follow",
      restoring = "follow",
      messages = "follow",
      others = TRUE,
      action_on = FALSE,
      menu_on = FALSE,
      menu_items = "",
      menu_direction = "auto",
      mistake = "Misspell an argument"
    )
    shiny::testServer(get("studio_server", parts$env), {
      do.call(session$setInputs, initial)
      expect_match(output$live_call$html, 'data-call-function="mascot_popup_menu"', fixed = TRUE)
      expect_false(grepl("click =", output$code_ui, fixed = TRUE))
      session$setInputs(size_px = 208, status_text = "Draft checked")
      session$elapse(700)
      session$setInputs(chip_style = list(arg = "size", style = "helper"))
      expect_match(output$code_ui, "size = mascot_size(208)", fixed = TRUE)
      expect_match(output$code_ui, 'status = "Draft checked"', fixed = TRUE)
      expect_identical(input$code_style, "short")
      session$setInputs(code_style = "helper")
      session$setInputs(chip_style = list(arg = "status", style = "short"))
      expect_match(output$code_ui, "size = mascot_size(208)", fixed = TRUE)
      expect_match(output$code_ui, 'status = "Draft checked"', fixed = TRUE)
      session$setInputs(chip_reset = "size")
      expect_identical(state$size$short, formals(mascot)$size)
      expect_false(grepl("size =", output$code_ui, fixed = TRUE))
      session$setInputs(chip_reset = "status")
      expect_identical(state$status$short, quote(mascot_status()))
      expect_false(grepl("status =", output$code_ui, fixed = TRUE))
      session$setInputs(code_style = "short")
      session$setInputs(
        click_type = "action",
        action_label = "Open report",
        action_tooltip = TRUE,
        action_disabled = FALSE
      )
      session$elapse(700)
      expect_match(output$live_call$html, 'data-call-function="mascot_action"', fixed = TRUE)
      session$setInputs(chip_reset = "click")
      expect_identical(live_demo$click$short, quote(mascot_action()))
      for (family in mascot_families()$id) {
        session$setInputs(list_family = family, select_function = "mascot_characters")
        expected <- mascot_characters(family = family)
        expect_identical(family_listing(), expected)
        expect_match(output$family_listing$html, expected$id[1], fixed = TRUE)
        expect_identical(output$family_listing$html, output$characters_table$html)
        expect_match(output$code_function, paste0('family = "', family, '"'), fixed = TRUE)
      }
      session$setInputs(list_family = "")
      expect_identical(family_listing(), mascot_characters())
      session$setInputs(send_many = 1)
      expect_match(output$wiring_log$html, "Review complete", fixed = TRUE)
      expect_identical(output$wiring_log$html, output$log$html)
      session$setInputs(helper_minimised = TRUE)
      expect_identical(output$minimised_last, "TRUE: minimised")
      expect_match(output$wiring_log$html, "input$helper_minimised", fixed = TRUE)
      expect_match(output$wiring_log$html, "The mascot was minimised.", fixed = TRUE)
      session$setInputs(helper_minimised = FALSE)
      expect_identical(output$minimised_last, "FALSE: not minimised")
      expect_match(output$wiring_log$html, "The mascot is no longer minimised.", fixed = TRUE)
      expect_false(grepl("The visitor restored", output$wiring_log$html, fixed = TRUE))
      session$setInputs(log_clear = 1)
      expect_match(output$wiring_log$html, "Nothing yet.", fixed = TRUE)
    })
  })
})

describe("studio code arguments, chips, anchors and menus", {
  it("separates comma-delimited arguments from one-off gesture code", {
    parts <- studio_app_parts()
    chips <- get("call_chips", parts$env)(get("start", parts$env), "short")
    html <- as.character(chips)
    args <- setdiff(names(formals(mascot)), "...")
    expect_length(regmatches(html, gregexpr('class="pg-call-comma"', html))[[1]], length(args) + 1L)
    # Each comma is a sibling after the closing button, never part of its hit area.
    expect_length(
      regmatches(html, gregexpr('</button>\\s*<span class="pg-call-comma">,</span>', html))[[1]],
      length(args)
    )
    expect_match(html, 'data-call-arg="gesture"', fixed = TRUE)
    signature <- names(formals(mascot))
    positions <- vapply(
      signature,
      function(arg) {
        pattern <- if (arg == "...") 'class="pg-call-dots"' else paste0('data-call-arg="', arg, '"')
        regexpr(pattern, html, fixed = TRUE)[[1]]
      },
      integer(1)
    )
    expect_true(all(diff(positions) > 0))
    expect_match(html, 'title="status = NULL"', fixed = TRUE)
    # Unset values display the exported defaults, in either style, including NULL.
    initial <- get("start", parts$env)
    defaults <- get("defaults", parts$env)
    for (style in c("short", "helper")) {
      unset <- lapply(defaults, get("code_pair", parts$env))
      defaults_html <- as.character(get("call_chips", parts$env)(unset, style))
      for (arg in names(defaults)) {
        expected <- paste(arg, "=", deparse1(formals(mascot)[[arg]]))
        expect_match(
          defaults_html,
          paste0('title="', htmltools::htmlEscape(expected, attribute = TRUE), '"'),
          fixed = TRUE
        )
      }
      initial$status <- NULL
      expect_match(as.character(get("call_chips", parts$env)(initial, style)), 'title="status = NULL"', fixed = TRUE)
    }
    expect_match(html, 'title="demo only, not an argument of mascot()"', fixed = TRUE)
    expect_match(html, '</button>\\s*<span>\\)</span>\\s*$', perl = TRUE)
    gesture <- get("gesture_chip", parts$env)
    expect_match(as.character(gesture()), "none yet", fixed = TRUE)
    expect_match(as.character(gesture("wave")), 'mascot_gesture(&quot;wave&quot;)', fixed = TRUE)
    expect_error(gesture(1), "Assertion on 'name' failed")
    for (id in c("show_anchors", "chip_title", "chip_inspector", "chip_help", "chip_guide")) {
      expect_match(parts$page, paste0('id="', id, '"'), fixed = TRUE)
    }
    expect_false(grepl('id="chip_question"', parts$page, fixed = TRUE))
    expect_match(parts$page, 'id="show_anchors"', fixed = TRUE)
  })
})

describe("studio sentence controls and overview", {
  it("renders inline sentence words with help-page tooltips and per-argument Rd overviews", {
    parts <- studio_app_parts()
    for (id in c("character", "palette", "mood", "gesture")) {
      expect_match(parts$page, paste0('<select[^>]*aria-label="', tools::toTitleCase(id), '"[^>]*id="', id, '"'))
    }
    expect_match(
      parts$page,
      'class="pg-sentence" role="group" aria-label="Character, palette, mood and one-off gesture"',
      fixed = TRUE
    )
    expect_match(parts$page, 'placeholder="Search functions and arguments"', fixed = TRUE)
    expect_match(parts$page, 'id="gesture_play"', fixed = TRUE)
    expect_match(parts$page, 'id="mood_article">in an', fixed = TRUE)
    expect_match(parts$page, "mood, with", fixed = TRUE)
    expect_match(parts$page, "Play it again", fixed = TRUE)
    for (id in c("character", "palette", "mood", "gesture")) {
      fn <- if (id == "palette") "mascot_palettes" else paste0("mascot_", id)
      expect_match(parts$page, paste0('aria-describedby="', id, '_tooltip"'), fixed = TRUE)
      expect_match(parts$page, paste0(fn, "()"), fixed = TRUE)
      expect_match(
        parts$page,
        htmltools::htmlEscape(get("help_page", parts$env)(fn)$title),
        fixed = TRUE
      )
    }
    expect_equal(nrow(mascot_anchors("neer")), 14L)
    for (id in c("reset_anchors", "no_anchors")) {
      expect_match(parts$page, paste0('id="', id, '"'), fixed = TRUE)
    }
    for (arg in setdiff(names(formals(mascot)), "...")) {
      expect_match(parts$page, paste0('data-chip-overview="', arg, '"'), fixed = TRUE)
      overview <- as.character(get("arg_popover_body", parts$env)("mascot", arg))
      expect_match(overview, "Default:", fixed = TRUE)
      expect_match(overview, "pg-help", fixed = TRUE)
    }
    for (colour in c("red", "yellow", "green")) {
      expect_match(parts$page, paste0('class="pg-light-', colour, '"'), fixed = TRUE)
    }
  })
})

describe("studio inspector rail", {
  it("renders three labelled toolbar buttons and keeps the mobile opener out of the top strip", {
    parts <- studio_app_parts()
    rail <- as.character(get("studio_right_rail", parts$env)())
    expect_match(rail, 'role="toolbar" aria-label="Inspector views"', fixed = TRUE)
    expect_false(grepl('role="tab', rail, fixed = TRUE))
    for (name in c("controls", "help", "guide")) {
      expect_match(rail, paste0('id="inspector_view_', name, '"'), fixed = TRUE)
      expect_match(rail, paste0('title="', tools::toTitleCase(name), '"'), fixed = TRUE)
      expect_match(rail, paste0('aria-label="', tools::toTitleCase(name), '"'), fixed = TRUE)
    }
    expect_length(regmatches(rail, gregexpr('aria-pressed="false"', rail, fixed = TRUE))[[1]], 3L)
    expect_length(regmatches(rail, gregexpr('aria-controls="inspector_sidebar"', rail, fixed = TRUE))[[1]], 4L)
    expect_match(rail, 'aria-label="More" aria-haspopup="menu" aria-expanded="false"', fixed = TRUE)
    expect_match(rail, 'id="open_inspector"', fixed = TRUE)
    expect_match(rail, 'id="studio_keys"', fixed = TRUE)
    expect_match(as.character(get("studio_topright", parts$env)()), 'id="studio_phone_tools"', fixed = TRUE)
    for (bad in list(NULL, NA_character_, 1, "unknown", c("help", "guide"))) {
      expect_error(get("studio_inspector_icon", parts$env)(bad), "Assertion on 'name' failed")
    }
  })
})

describe("studio host choices, reading tabs, dock and examples browser", {
  it("offers two host choices, discoverable functions, editable chips and structured Help", {
    parts <- studio_app_parts()
    page <- parts$page
    expect_match(
      page,
      sprintf('title="Function index (all %d functions)"', length(get("studio_guide", parts$env))),
      fixed = TRUE
    )
    expect_match(page, 'id="function_index_tooltip"', fixed = TRUE)
    expect_match(page, "More examples", fixed = TRUE)
    expect_match(page, "Back to studio", fixed = TRUE)
    expect_match(page, "Click an argument to edit it", fixed = TRUE)
    expect_false(grepl("Example source", page, fixed = TRUE))
    expect_match(get("welcome", parts$env), "function index (the m button)", fixed = TRUE)
    help <- as.character(get("function_help", parts$env)("mascot"))
    expect_match(help, 'class="pg-help-usage"', fixed = TRUE)
    expect_match(help, 'class="pg-arg-name"', fixed = TRUE)
    expect_match(help, 'id="expand_inspector"', fixed = TRUE)
    expect_match(help, 'class="pg-card-expand"', fixed = TRUE)
    expect_match(help, 'aria-label="Expand panel"', fixed = TRUE)
    expect_error(get("studio_expand_icon", parts$env)(NULL), "Assertion on 'id' failed")
    expect_error(get("function_card", parts$env)("mascot", expand = "wide"), "Assertion on 'expand' failed")
    expect_false(grepl('id="expand_inspector"', page, fixed = TRUE))
    guide <- as.character(get("selected_guide", parts$env)("mascot"))
    expect_match(guide, 'id="expand_inspector_guide"', fixed = TRUE)
    expect_false(grepl("bslib-full-screen-enter", guide, fixed = TRUE))
    chips <- as.character(get("call_chips", parts$env)(get("start", parts$env), "short"))
    expect_match(chips, 'class="pg-chip-pencil"', fixed = TRUE)
  })

  it("never emits options-only helper calls from code builders and displays updated guide cards", {
    dir <- dirname(mascot_example("studio", run = FALSE))
    env <- new.env()
    sys.source(file.path(dir, "R", "guide.R"), envir = env)
    sys.source(file.path(dir, "R", "shared-help.R"), envir = env)
    sys.source(file.path(dir, "R", "data.R"), envir = env)
    sys.source(file.path(dir, "R", "shared-data.R"), envir = env)
    sys.source(file.path(dir, "R", "shared-ui.R"), envir = env)
    sys.source(file.path(dir, "R", "ui.R"), envir = env)
    sys.source(file.path(dir, "R", "guide-md.R"), envir = env)
    sys.source(file.path(dir, "R", "code.R"), envir = env)
    expect_identical(env$code_action("", disabled = TRUE)$helper, quote(mascot_action()))
    expect_identical(env$code_action(NULL, disabled = TRUE)$helper, quote(mascot_action()))
    expect_identical(eval(env$code_action("", disabled = TRUE)$helper), mascot_action())

    expect_identical(env$code_menu(character(), direction = "top")$helper, quote(mascot_popup_menu()))
    expect_identical(env$code_menu(NULL, direction = "top")$helper, quote(mascot_popup_menu()))
    expect_identical(eval(env$code_menu(character(), direction = "top")$helper), mascot_popup_menu())

    expect_identical(env$code_bubble("", FALSE, 10, FALSE)$helper, quote(mascot_bubble()))
    expect_identical(env$code_bubble(NULL, FALSE, 10, FALSE)$helper, quote(mascot_bubble()))
    expect_identical(eval(env$code_bubble("", FALSE, 10, FALSE)$helper), mascot_bubble())

    action_guide <- as.character(env$selected_guide("mascot_action"))
    expect_match(action_guide, "Options need their main argument.", fixed = TRUE)
    expect_match(action_guide, "An empty call removes it.", fixed = TRUE)

    menu_guide <- as.character(env$selected_guide("mascot_popup_menu"))
    expect_match(menu_guide, "input$&lt;id&gt;_menu vs input$&lt;id&gt;_click", fixed = TRUE)
    expect_match(menu_guide, "Options need their main argument.", fixed = TRUE)
    expect_match(menu_guide, "An empty call removes it.", fixed = TRUE)

    bubble_guide <- as.character(env$selected_guide("mascot_bubble"))
    expect_match(bubble_guide, "Options need their main argument.", fixed = TRUE)
    expect_match(bubble_guide, "An empty call removes it.", fixed = TRUE)

    theme_guide <- as.character(env$selected_guide("mascot_theme"))
    expect_match(theme_guide, "A bs_theme() always uses mode = \"auto\"", fixed = TRUE)

    update_guide <- as.character(env$selected_guide("update_mascot"))
    expect_match(update_guide, "Reset table: what each argument resets to", fixed = TRUE)
    expect_match(update_guide, "Each non-NULL argument replaces its whole setting", fixed = TRUE)
    expect_match(update_guide, "mascot_update_ignored", fixed = TRUE)

    preview_guide <- as.character(env$selected_guide("mascot_preview"))
    expect_match(preview_guide, "160, 96 and 24 px", fixed = TRUE)
  })
})

describe("the studio's copy buttons and stamped outputs", {
  it("answers a copy ticket only once the server holds nothing back", {
    parts <- studio_app_parts()
    copy_gate <- get("copy_gate", parts$env)
    pending <- shiny::reactiveVal(TRUE)
    answers <- list()
    shiny::testServer(
      function(input, output, session) {
        session$sendCustomMessage <- function(type, message) {
          answers[[length(answers) + 1L]] <<- list(type = type, ticket = message$ticket)
        }
        copy_gate(input, session, pending = pending)
      },
      {
        # Given a change the server still holds back (a debounced input), two clicks wait for it
        session$setInputs(copy_ticket = 1)
        session$setInputs(copy_ticket = 2)
        expect_length(answers, 0L)
        # When the server has applied it, both are answered, in the order of the clicks
        pending(FALSE)
        session$flushReact()
        expect_identical(
          answers,
          list(list(type = "studio:copy", ticket = 1L), list(type = "studio:copy", ticket = 2L))
        )
        # And a click with nothing held back is answered at once, and only once
        session$setInputs(copy_ticket = 3)
        expect_length(answers, 3L)
        expect_identical(answers[[3]]$ticket, 3L)
        session$flushReact()
        expect_length(answers, 3L)
      }
    )
    expect_error(copy_gate(list(), new.env(), pending = 1), "Assertion on 'pending' failed")
    expect_error(copy_gate(list(), list()), "Assertion on 'session' failed")
  })
  it("stamps an output after the flush that sends it", {
    parts <- studio_app_parts()
    stamp_output <- get("stamp_output", parts$env)
    stamps <- list()
    shiny::testServer(
      function(input, output, session) {
        session$sendCustomMessage <- function(type, message) {
          stamps[[length(stamps) + 1L]] <<- list(type = type, id = message$id, stamp = message$stamp)
        }
        output$shown <- shiny::renderText({
          stamp_output(session, "shown", input$which)
          paste("drawn for", input$which)
        })
      },
      {
        session$setInputs(which = "mascot_mood")
        expect_identical(output$shown, "drawn for mascot_mood")
        expect_identical(stamps, list(list(type = "studio:stamp", id = "shown", stamp = "mascot_mood")))
        session$setInputs(which = "mascot_size")
        expect_identical(output$shown, "drawn for mascot_size")
        expect_length(stamps, 2L)
        expect_identical(stamps[[2]]$stamp, "mascot_size")
      }
    )
    expect_error(stamp_output(list(), "shown", "x"), "Assertion on 'session' failed")
    expect_error(stamp_output(new.env(), "", "x"), "Assertion on 'id' failed")
    expect_error(stamp_output(new.env(), "shown", 1), "Assertion on 'stamp' failed")
  })
})
