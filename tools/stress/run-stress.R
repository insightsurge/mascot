# Run from the checkout root. Optional arguments: a two-digit scenario prefix and --strict.
# Each scenario's checks live in its folder's checks.R (a layout folder uses its parent's).
main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  results <- new.env(parent = emptyenv())
  results$failed <- 0L
  results$skipped <- 0L
  results$strict <- "--strict" %in% args
  selection <- setdiff(args, "--strict")
  if (!requireNamespace("shinytest2", quietly = TRUE) || !requireNamespace("chromote", quietly = TRUE)) {
    skip_line(results, "stress: shinytest2 or chromote is unavailable.")
    return(exit_status(results))
  }
  chrome <- tryCatch(chromote::find_chrome(), error = function(error) NULL)
  if (is.null(chrome) || !nzchar(chrome)) {
    skip_line(results, "stress: Chrome is unavailable.")
    return(exit_status(results))
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
    "05-slow-reconnect",
    "06-later",
    "07-dynamic-modules",
    "08-dark-mode",
    "09-bookmark"
  )
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
      skip_line(results, paste(name, "browser:", reason))
    }
    return(exit_status(results))
  }
  on.exit(browser$close(), add = TRUE)
  chromote::set_default_chromote_object(browser)
  cli::cli_inform("Run: {Sys.Date()}; {R.version.string}; checkout {basename(root)}")
  for (name in cases) {
    tryCatch(run_case(root, scratch, name, results), error = function(error) {
      results$failed <- results$failed + 1L
      cli::cat_line(paste("FAIL", name, "launch:", conditionMessage(error)))
    })
  }
  cli::cli_inform(
    "{results$failed} FAIL, {results$skipped} SKIP{if (results$strict) ' (strict: a SKIP fails the run)' else ''}."
  )
  exit_status(results)
}

skip_line <- function(results, text) {
  checkmate::assert_environment(results)
  checkmate::assert_string(text)
  results$skipped <- results$skipped + 1L
  cli::cat_line(paste("SKIP", text))
}

exit_status <- function(results) {
  checkmate::assert_environment(results)
  as.integer(results$failed > 0L || results$strict && results$skipped > 0L)
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
  checks_file <- file.path(source_dir, "checks.R")
  if (!file.exists(checks_file)) {
    checks_file <- file.path(dirname(source_dir), "checks.R")
  }
  scenario <- new.env()
  sys.source(checks_file, envir = scenario)
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
    # code is a promise evaluated inside the error boundary; a string result is extra detail.
    outcome <- tryCatch(
      list(detail = force(code)),
      error = function(error) list(problem = conditionMessage(error))
    )
    problem <- outcome$problem
    if (!is.null(problem)) {
      actual <- tryCatch(
        app$get_js(paste0(
          "JSON.stringify({connected:Shiny.shinyapp.$socket?.readyState===1,",
          "inputs:Shiny.shinyapp.$inputValues,",
          "mascots:Array.from(document.querySelectorAll('.mascot')).map(e=>{",
          "const s=window.mascot?.host?.state(e);return {id:e.id,",
          "statusText:e.querySelector('[role=status]')?.textContent,",
          "character:s?.character,mood:s?.mood,status:s?.status,bubble:s?.bubble?.text,",
          "current:s?.current,snapshot:s?.snapshot,hidden:s?.hidden,offscreen:s?.offscreen};})})"
        )),
        error = function(error) conditionMessage(error)
      )
      problem <- paste(problem, "Actual browser state:", actual)
      results$failed <- results$failed + 1L
    }
    detail <- if (!is.null(problem)) {
      gsub("[\r\n]+", " ", problem)
    } else if (checkmate::test_string(outcome$detail)) {
      paste("held;", outcome$detail)
    } else {
      "held"
    }
    cli::cat_line(paste(if (is.null(problem)) "PASS" else "FAIL", name, paste0(label, ":"), detail))
    invisible(is.null(problem))
  }
  state <- function(id, mood, text, character = NULL, bubble = NULL) {
    checkmate::assert_string(id)
    checkmate::assert_string(mood)
    checkmate::assert_string(text)
    checkmate::assert_string(character, null.ok = TRUE)
    checkmate::assert_string(bubble, null.ok = TRUE)
    json <- function(x) jsonlite::toJSON(x, auto_unbox = TRUE)
    extra_character <- if (!is.null(character)) {
      sprintf(" && s.character===%s && s.current?.character===%s", json(character), json(character))
    } else {
      ""
    }
    extra_bubble <- if (!is.null(bubble)) sprintf(" && s.bubble?.text===%s", json(bubble)) else ""
    js <- sprintf(
      paste0(
        "(() => {const e=document.getElementById(%s); const s=e && window.mascot.host.state(e);",
        "return !!s && s.mood===%s && s.current?.mood===%s && ",
        "s.status.mode==='custom' && s.status.text===%s && ",
        "e.querySelector('[role=status]')?.textContent===%s%s%s;})()"
      ),
      json(id),
      json(mood),
      json(mood),
      json(text),
      json(text),
      extra_character,
      extra_bubble
    )
    app$wait_for_js(js)
  }
  replace <- function(id, button = "replace") {
    checkmate::assert_string(id)
    checkmate::assert_string(button)
    generation <- app$get_js(sprintf(
      "window.mascot.host.state(document.getElementById(%s))?.snapshot.generation",
      jsonlite::toJSON(id, auto_unbox = TRUE)
    ))
    app$click(button, wait_ = FALSE)
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
  skip <- function(label, reason) {
    checkmate::assert_string(label)
    checkmate::assert_string(reason)
    skip_line(results, paste0(name, " ", label, ": ", reason))
  }
  # A check that fails because of an open package issue: KNOWN while it fails, FAIL once it
  # passes, so the fix PR removes the marker. Neither KNOWN nor its timeout counts as a failure.
  known <- function(label, issue, code) {
    checkmate::assert_string(label)
    checkmate::assert_count(issue, positive = TRUE)
    problem <- tryCatch(
      {
        force(code)
        NULL
      },
      error = function(error) gsub("[\r\n]+", " ", conditionMessage(error))
    )
    if (is.null(problem)) {
      results$failed <- results$failed + 1L
      cli::cat_line(paste0("FAIL ", name, " ", label, ": now passes; close #", issue, " and drop the known marker"))
    } else {
      cli::cat_line(paste0("KNOWN ", name, " ", label, ": #", issue, " (", substr(problem, 1, 160), ")"))
    }
    invisible(is.null(problem))
  }
  scenario$stress_checks(list(
    app = app,
    check = check,
    known = known,
    state = state,
    replace = replace,
    skip = skip,
    scratch = scratch
  ))
  expected <- if (exists("stress_expected_warnings", envir = scenario, inherits = FALSE)) {
    scenario$stress_expected_warnings
  } else {
    list(pattern = NULL, max = 0L)
  }
  check("no unexpected warning or error storm", {
    logs <- app$get_logs()
    # Inspect actual messages, rather than a truncated structure summary.
    rows <- apply(as.data.frame(logs), 1, paste, collapse = " ")
    bad <- rows[grepl("warning|error|exception", rows, ignore.case = TRUE)]
    planned <- if (is.null(expected$pattern)) logical(length(bad)) else grepl(expected$pattern, bad, ignore.case = TRUE)
    if (any(!planned)) {
      cli::cli_abort("{paste(bad[!planned], collapse = ' ')}")
    }
    if (sum(planned) > expected$max) {
      cli::cli_abort("{sum(planned)} expected warnings, more than the {expected$max} allowed: {bad[planned]}")
    }
    if (!is.null(expected$pattern)) paste(sum(planned), "expected warnings, at most", expected$max)
  })
}

quit(status = main())
