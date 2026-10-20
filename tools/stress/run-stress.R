# Run from the checkout root. Optional argument: 01, 02, 03, 04 or 05.
main <- function() {
  if (!requireNamespace("shinytest2", quietly = TRUE) || !requireNamespace("chromote", quietly = TRUE)) {
    cli::cli_inform("SKIP stress: shinytest2 or chromote is unavailable.")
    return(0L)
  }
  chrome <- tryCatch(chromote::find_chrome(), error = function(error) NULL)
  if (is.null(chrome) || !nzchar(chrome)) {
    cli::cli_inform("SKIP stress: Chrome is unavailable.")
    return(0L)
  }
  root <- normalizePath(".")
  checkmate::assert_file_exists(file.path(root, "DESCRIPTION"))
  scratch <- tempfile("stress-")
  dir.create(scratch)
  withr::local_envvar(c(TMPDIR = scratch, NOT_CRAN = "true"))
  withr::local_options(list(chromote.timeout = 60))
  cases <- c(
    "01-modules",
    "01-modules/golem",
    "01-modules/rhino",
    "02-replacement",
    "03-async",
    "04-dom-overlays",
    "05-slow-reconnect"
  )
  selection <- commandArgs(trailingOnly = TRUE)
  if (length(selection)) {
    cases <- cases[startsWith(cases, selection[[1]])]
  }
  if (!length(cases)) {
    cli::cli_abort("No scenario matches the supplied argument.")
  }
  for (name in cases) {
    files <- list.files(
      file.path(root, "tools", "stress", name),
      pattern = "[.]R$",
      recursive = TRUE,
      full.names = TRUE
    )
    for (file in files) {
      invisible(parse(file))
    }
    cli::cat_line(paste("PASS", name, "syntax: R files parse (static check only)"))
  }
  browser <- tryCatch(chromote::Chromote$new(), error = function(error) error)
  if (inherits(browser, "error")) {
    reason <- gsub("[\r\n]+", " ", conditionMessage(browser))
    for (name in cases) {
      cli::cat_line(paste("SKIP", name, "browser:", reason))
    }
    return(0L)
  }
  on.exit(browser$close(), add = TRUE)
  chromote::set_default_chromote_object(browser)
  results <- new.env(parent = emptyenv())
  results$failed <- 0L
  cli::cli_inform("Run: {Sys.Date()}; {R.version.string}; checkout {basename(root)}")
  for (name in cases) {
    tryCatch(run_case(root, scratch, name, results), error = function(error) {
      results$failed <- results$failed + 1L
      cli::cat_line(paste("FAIL", name, "launch:", conditionMessage(error)))
    })
  }
  as.integer(results$failed > 0L)
}

run_case <- function(root, scratch, name, results) {
  checkmate::assert_directory_exists(root)
  checkmate::assert_directory_exists(scratch)
  checkmate::assert_string(name)
  checkmate::assert_environment(results)
  target <- file.path(scratch, gsub("/", "-", name))
  dir.create(target)
  source_dir <- file.path(root, "tools", "stress", name)
  file.copy(list.files(source_dir, full.names = TRUE), target, recursive = TRUE)
  app_file <- file.path(target, "app.R")
  writeLines(c(sprintf("pkgload::load_all(%s, quiet = TRUE)", deparse(root)), readLines(app_file)), app_file)
  app <- shinytest2::AppDriver$new(
    target,
    name = basename(target),
    load_timeout = 30000,
    timeout = 15000,
    width = 1200,
    height = 900
  )
  on.exit(app$stop(), add = TRUE)
  version <- app$get_chromote_session()$Browser$getVersion()$product
  cli::cli_inform(paste("Browser:", version, "; app", name))
  check <- function(label, code) {
    checkmate::assert_string(label)
    # code is a promise evaluated inside the error boundary.
    problem <- tryCatch(
      {
        force(code)
        NULL
      },
      error = function(error) conditionMessage(error)
    )
    if (!is.null(problem)) {
      actual <- tryCatch(
        app$get_js(paste0(
          "JSON.stringify({connected:Shiny.shinyapp.$socket?.readyState===1,",
          "inputs:Shiny.shinyapp.$inputValues,",
          "mascots:Array.from(document.querySelectorAll('.mascot')).map(e=>{",
          "const s=window.mascot?.host?.state(e);return {id:e.id,",
          "statusText:e.querySelector('[role=status]')?.textContent,",
          "mood:s?.mood,status:s?.status,current:s?.current,snapshot:s?.snapshot,",
          "hidden:s?.hidden,offscreen:s?.offscreen};})})"
        )),
        error = function(error) conditionMessage(error)
      )
      problem <- paste(problem, "Actual browser state:", actual)
      results$failed <- results$failed + 1L
    }
    detail <- if (is.null(problem)) "held" else gsub("[\r\n]+", " ", problem)
    cli::cat_line(paste(if (is.null(problem)) "PASS" else "FAIL", name, paste0(label, ":"), detail))
    invisible(is.null(problem))
  }
  state <- function(id, mood, text) {
    checkmate::assert_string(id)
    checkmate::assert_string(mood)
    checkmate::assert_string(text)
    js <- sprintf(
      paste0(
        "(() => {const e=document.getElementById(%s); const s=e && window.mascot.host.state(e);",
        "return !!s && s.mood===%s && s.current?.mood===%s && ",
        "s.status.mode==='custom' && s.status.text===%s && ",
        "e.querySelector('[role=status]')?.textContent===%s;})()"
      ),
      jsonlite::toJSON(id, auto_unbox = TRUE),
      jsonlite::toJSON(mood, auto_unbox = TRUE),
      jsonlite::toJSON(mood, auto_unbox = TRUE),
      jsonlite::toJSON(text, auto_unbox = TRUE),
      jsonlite::toJSON(text, auto_unbox = TRUE)
    )
    app$wait_for_js(js)
  }
  replace <- function(id) {
    checkmate::assert_string(id)
    generation <- app$get_js(sprintf(
      "window.mascot.host.state(document.getElementById(%s))?.snapshot.generation",
      jsonlite::toJSON(id, auto_unbox = TRUE)
    ))
    app$click("replace", wait_ = FALSE)
    app$wait_for_js(sprintf(
      paste0(
        "(() => {const e=document.getElementById(%s);",
        "const s=e && window.mascot.host.state(e);",
        "return !!s && s.snapshot.generation!==%s;})()"
      ),
      jsonlite::toJSON(id, auto_unbox = TRUE),
      jsonlite::toJSON(generation, auto_unbox = TRUE, null = "null")
    ))
  }
  if (startsWith(name, "01")) {
    check("eight modules isolated after rapid tabs", {
      app$run_js("for(let i=1;i<=8;i++) document.querySelector('[data-value=\"'+i+'\"]').click();")
      for (i in seq_len(8)) {
        app$click(paste0("m", i, "-review-change"))
      }
      for (i in seq_len(8)) {
        state(paste0("m", i, "-review-helper"), "happy", paste0("m", i, "-review-helper 1"))
      }
      app$click("m4-review-change")
      for (i in seq_len(8)) {
        state(
          paste0("m", i, "-review-helper"),
          if (i == 4) "worried" else "happy",
          paste0("m", i, "-review-helper ", if (i == 4) 2 else 1)
        )
      }
    })
  } else if (startsWith(name, "02")) {
    app$run_js(paste0(
      "window.oldDispatch=Shiny.shinyapp.dispatchMessage;",
      "Shiny.shinyapp.dispatchMessage=function(data){",
      "const m=typeof data==='string'?JSON.parse(data):data;",
      "if(m.custom && m.custom['mascot:update']?.state) ",
      "window.lastEnvelope=JSON.parse(JSON.stringify(m.custom['mascot:update']));",
      "return window.oldDispatch.call(this,data);};"
    ))
    check("twenty replacements retain latest state", {
      for (i in seq_len(20)) {
        app$click("change")
        state("same", "happy", paste("Update", i))
        replace("same")
        state("same", "happy", paste("Update", i))
      }
    })
    check("update while absent then insert", {
      app$click("remove")
      app$wait_for_js("document.querySelectorAll('[id=\"same\"]').length === 0")
      app$click("change")
      app$click("insert")
      state("same", "happy", "Update 21")
    })
    check("duplicate does not take ownership", {
      app$click("duplicate")
      app$wait_for_js("document.querySelectorAll('#same').length === 2")
      app$click("change")
      state("same", "happy", "Update 22")
      stopifnot(isTRUE(app$get_js(paste0("window.mascot.host.state(document.querySelectorAll('#same')[1]) === null"))))
      state("other", "idle", "Untouched")
    })
    check("old generation cannot update replacement", {
      app$run_js("window.staleEnvelope=JSON.parse(JSON.stringify(window.lastEnvelope));")
      app$click("remove")
      app$wait_for_js("document.querySelectorAll('[id=\"same\"]').length === 0")
      replace("same")
      state("same", "happy", "Update 22")
      stopifnot(isTRUE(app$get_js(paste0(
        "window.staleEnvelope.generation !== ",
        "window.mascot.host.state(document.getElementById('same')).snapshot.generation"
      ))))
      app$run_js(paste0(
        "window.staleEnvelope.revision=999999;",
        "window.staleEnvelope.state.mood='worried';",
        "window.staleEnvelope.state.status={mode:'custom',text:'Stale'};",
        "window.mascot.host.receive(window.staleEnvelope);"
      ))
      state("same", "happy", "Update 22")
      state("other", "idle", "Untouched")
    })
  } else if (startsWith(name, "03")) {
    check("observers during ExtendedTask", {
      app$click("start", wait_ = FALSE)
      state("helper", "thinking", "Running")
      app$click("first", wait_ = FALSE)
      state("helper", "worried", "First")
      app$click("second", wait_ = FALSE)
      state("helper", "thinking", "Second")
      replace("helper")
      state("helper", "thinking", "Second")
      app$click("finish", wait_ = FALSE)
      app$wait_for_js("document.getElementById('task_status').textContent === 'success'")
      state("helper", "happy", "Complete")
    })
    check("observer after completion and replacement", {
      replace("helper")
      state("helper", "happy", "Complete")
      app$click("first")
      state("helper", "worried", "First")
      app$click("third")
      state("helper", "happy", "Final")
    })
  } else if (startsWith(name, "04")) {
    check("DOM churn and custom input binding", {
      app$click("chaos")
      app$wait_for_js("window.stressMutationsDone && document.querySelectorAll('#noise span').length === 201")
      app$wait_for_js("Shiny.shinyapp.$inputValues.custom === '200'")
      stopifnot(identical(app$get_value(input = "custom"), "200"))
      app$click("change")
      state("helper", "happy", "Update 1")
      stopifnot(isTRUE(app$get_js(paste0(
        "(() => {const c=document.querySelector('#helper canvas');",
        "return c.width>0 && c.height>0 && ",
        "c.getContext('2d').getImageData(0,0,c.width,c.height).data.some(v=>v>0);})()"
      ))))
    })
    check("menu reachable above fixed overlay", {
      app$run_js("document.querySelector('#helper .mascot-button').click()")
      app$wait_for_js("window.mascot.host.state(document.getElementById('helper')).menuOpen")
      stopifnot(isTRUE(app$get_js(paste0(
        "(() => {const e=document.querySelector('[role=menuitem]');",
        "if(!e)return false; const r=e.getBoundingClientRect();",
        "return e.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2));})()"
      ))))
    })
    check("progress and modal updates", {
      app$click("progress")
      state("helper", "thinking", "Progress")
      app$click("modal")
      app$wait_for_js("!!document.querySelector('.modal.show')")
      app$click("change")
      state("helper", "happy", "Update 2")
    })
    app$get_screenshot(file = file.path(scratch, "overlays.png"))
  } else {
    check("slow handler with queued clicks", {
      app$run_js(paste0("for(let i=1;i<=6;i++) setTimeout(()=>", "document.getElementById('slow').click(), i*80);"))
      app$wait_for_js("document.getElementById('handled').textContent === '6'", timeout = 30000)
      state("helper", "happy", "Slow 6")
    })
    check("200 updates in one flush", {
      app$click("burst")
      state("helper", "happy", "Burst 200")
    })
    check("rapid inputs settle and page responds", {
      app$run_js(paste0(
        "for(let i=1;i<=80;i++) setTimeout(()=>",
        "Shiny.setInputValue('rapid',i,{priority:'event'}), i*5);"
      ))
      state("helper", "thinking", "Rapid 80")
      app$set_inputs(rapid = 81)
      state("helper", "thinking", "Rapid 81")
    })
    resumable <- isTRUE(app$get_js("Shiny.shinyapp.$socket.allowReconnect === true"))
    check("websocket loss shows worried status", {
      app$run_js(paste0(
        "window.dropSeen=false; $(document).one('shiny:disconnected.stress',()=>{",
        "setTimeout(()=>{const e=document.getElementById('helper');",
        "window.dropSeen=e.hasAttribute('data-disconnected') && ",
        "e.querySelector('[role=status]').textContent==='Connection lost. Reload the page to continue.' && ",
        "window.mascot.host.state(e).current.mood==='worried';},0);});",
        "Shiny.shinyapp.$socket.close();"
      ))
      app$wait_for_js("window.dropSeen")
    })
    if (!resumable) {
      cli::cat_line(paste(
        "SKIP",
        name,
        "reconnect replays state and accepts updates:",
        "websocket transport does not support session resumption; local runApp uses a raw websocket"
      ))
    } else {
      check("reconnect replays state and accepts updates", {
        app$wait_for_js(
          paste0(
            "Shiny.shinyapp.$socket?.readyState===1 && ",
            "!document.getElementById('helper').hasAttribute('data-disconnected')"
          )
        )
        state("helper", "thinking", "Rapid 81")
        app$set_inputs(rapid = 82)
        state("helper", "thinking", "Rapid 82")
      })
    }
  }
  check("no unexpected warning or error storm", {
    logs <- app$get_logs()
    # Inspect actual messages, rather than a truncated structure summary.
    rows <- apply(as.data.frame(logs), 1, paste, collapse = " ")
    bad <- rows[grepl("warning|error|exception", rows, ignore.case = TRUE)]
    expected_duplicate <- grepl("duplicate live mascot id|Duplicate input binding", bad, ignore.case = TRUE)
    if (startsWith(name, "02")) {
      bad <- bad[!expected_duplicate]
    }
    if (length(bad)) cli::cli_abort(paste(bad, collapse = " "))
  })
}

quit(status = main())
