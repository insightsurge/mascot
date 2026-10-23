describe("session and static mascot specifications", {
  it("U1.9 mounts static UI in independent sessions and rejects foreign dynamic defaults", {
    ui <- mascot("shared", bubble = "Static")
    token <- ui$attribs[["data-mount-token"]]
    a <- protocol_fixture()
    b <- protocol_fixture()
    withr::defer(a$session$close())
    withr::defer(b$session$close())
    mascot_snapshot(protocol_snapshot(token), a$session, "shared")
    mascot_snapshot(protocol_snapshot(token), b$session, "shared")
    a$session$flushReact()
    b$session$flushReact()
    expect_length(a$messages$values, 1)
    expect_length(b$messages$values, 1)
    expect_identical(a$messages$values[[1]]$state$bubble$text, "Static")
    dynamic <- shiny::withReactiveDomain(a$session, mascot("private", status = "A only"))
    foreign <- dynamic$attribs[["data-mount-token"]]
    mascot_snapshot(protocol_snapshot(foreign), b$session, "private")
    expect_null(b$session$userData$mascot_protocol$states$private)
    expect_null(mascot_mount_lookup(b$session, "different", token))
    update_mascot("helper", status = "A", session = a$session)
    update_mascot("helper", status = "B", session = b$session)
    protocol_ready(a)
    protocol_ready(b)
    expect_identical(protocol_record(a)$desired$status$text, "A")
    expect_identical(protocol_record(b)$desired$status$text, "B")
    owner <- a$session$userData$mascot_protocol
    a$session$close()
    expect_null(a$session$userData$mascot_protocol)
    expect_length(ls(owner$states), 0)
    expect_length(owner$mounts, 0)
  })

  it("#424 lets a mascot built in one session work from its cached HTML in another session", {
    a <- protocol_fixture()
    b <- protocol_fixture()
    withr::defer(a$session$close())
    withr::defer(b$session$close())
    ui <- shiny::withReactiveDomain(a$session, mascot(a$id, status = "Cached", placement = "inline"))
    token <- ui$attribs[["data-mount-token"]]
    expect_match(token, "^t[0-9]+-[0-9]+-[0-9]+$")
    expect_false(is.null(mascot_mount_lookup(a$session, a$id, token)))
    expect_null(mascot_mount_lookup(b$session, b$id, token))
    # The specification stays in session A; the process-wide store never holds it.
    expect_null(mascot_template_store()$items[[token]])
    # Session B only has the HTML: its first snapshot asks for the baseline the HTML carries.
    mascot_snapshot(protocol_snapshot(token), b$session, b$id)
    expect_identical(tail(b$messages$values, 1)[[1]]$kind, "template-needed")
    expect_null(b$session$userData$mascot_protocol$states[[b$id]])
    script <- Filter(
      function(tag) inherits(tag, "shiny.tag") && "data-mascot-baseline" %in% names(tag$attribs),
      ui$children
    )[[1]]
    baseline <- jsonlite::fromJSON(as.character(script$children[[1]]), simplifyVector = FALSE)
    baseline$character$json <- as.character(ui$children[[1]]$children[[1]])
    data <- protocol_snapshot(token)
    data$baseline <- baseline
    mascot_snapshot(data, b$session, b$id)
    expect_true(protocol_record(b)$live)
    shown <- protocol_flush(b)
    expect_identical(shown$state$status$text, "Cached")
    update_mascot("helper", mood = "happy", status = "Updated", session = b$session)
    updated <- protocol_flush(b)
    expect_identical(updated$state$mood, "happy")
    expect_identical(updated$state$status$text, "Updated")
    expect_gt(updated$revision, shown$revision)
    # A forged or foreign baseline is still refused, and session A is untouched by B.
    c_ <- protocol_fixture()
    withr::defer(c_$session$close())
    forged <- data
    forged$baseline$status$text <- "Forged"
    mascot_snapshot(forged, c_$session, c_$id)
    expect_null(c_$session$userData$mascot_protocol$states[[c_$id]])
    expect_identical(tail(c_$messages$values, 1)[[1]]$kind, "template-rejected")
    expect_false(isTRUE(protocol_record(a)$live))
  })

  it("#424 keeps visitor-specific content out of the process-wide key cache", {
    store <- mascot_template_store()
    saved <- store$keys
    withr::defer(store$keys <- saved)
    a <- protocol_fixture()
    b <- protocol_fixture()
    withr::defer(a$session$close())
    withr::defer(b$session$close())
    text <- "Hello visitor 424-private"
    for (i in 1:20) {
      ui <- shiny::withReactiveDomain(a$session, mascot(a$id, status = paste(text, i), placement = "inline"))
    }
    token <- ui$attribs[["data-mount-token"]]
    script <- Filter(
      function(tag) inherits(tag, "shiny.tag") && "data-mascot-baseline" %in% names(tag$attribs),
      ui$children
    )[[1]]
    baseline <- jsonlite::fromJSON(as.character(script$children[[1]]), simplifyVector = FALSE)
    baseline$character$json <- as.character(ui$children[[1]]$children[[1]])
    data <- protocol_snapshot(token)
    data$baseline <- baseline
    mascot_snapshot(data, b$session, b$id)
    expect_true(protocol_record(b)$live)
    remembered <- vapply(store$keys, function(entry) grepl(text, entry$identity, fixed = TRUE), logical(1))
    expect_false(any(remembered))
    # The key is the same with or without the cache.
    expect_identical(mascot_template_key("x", remember = FALSE), mascot_template_key("x"))
    expect_error(mascot_template_key("x", remember = NA), "Assertion")
  })

  it("U1.9 shares complete templates, caps unbound LRU entries and pins bound descriptors", {
    store <- mascot_template_store()
    # Restore other tests' read-only templates, not a destructive global reset.
    saved <- as.list(store)
    withr::defer({
      rm(list = ls(store), envir = store)
      list2env(saved, envir = store)
    })
    expect_identical(mascot_unbound_template_limit, 128L)
    store$items <- list()
    store$tick <- 0
    base <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    first <- mascot_mount_token("helper", base, NULL)
    expect_identical(mascot_mount_token("helper", base, NULL), first)
    expect_length(store$items, 1)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    mascot_snapshot(protocol_snapshot(first), f$session, "helper")
    expect_equal(store$items[[first]]$refs, 1)
    for (i in 1:130) {
      base$status <- list(mode = "custom", text = as.character(i))
      mascot_mount_token("helper", base, NULL)
    }
    expect_length(store$items, 129L)
    expect_false(is.null(store$items[[first]]))
    last <- mascot_mount_token("helper", base, NULL)
    # Reusing a template updates LRU, while changing even independent UI fields
    # changes the token. The binding is part of this identity too.
    expect_false(identical(mascot_mount_token("other", base, NULL), last))
    expect_false(is.null(store$items[[last]]))
    f$session$close()
    expect_length(store$items, 128L)
    expect_null(store$items[[first]])
    g <- protocol_fixture()
    withr::defer(g$session$close())
    mascot_snapshot(protocol_snapshot(first), g$session, "helper")
    expect_null(g$session$userData$mascot_protocol$states$helper)
  })

  it("U1.9 reclaims superseded dynamic content and sends self-contained recovery", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    base <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    for (i in 1:100) {
      base$status <- list(mode = "custom", text = as.character(i))
      mascot_mount_token(f$id, base, f$session)
    }
    expect_length(f$session$userData$mascot_protocol$mounts, 1)
    token <- names(f$session$userData$mascot_protocol$mounts)[[1]]
    protocol_ready(f, token = token)
    first <- protocol_flush(f)
    expect_identical(first$state$status$text, "100")
    expect_type(first$state$character$json, "character")
    expect_type(first$state$character$content_token, "character")
    mascot_snapshot(protocol_snapshot(token, lifecycle = "reconcile"), f$session, f$id)
    latest <- protocol_flush(f)
    expect_identical(latest$state$character, first$state$character)
    expect_identical(latest$revision, first$revision)
  })

  it("never wraps a safe counter silently", {
    expect_equal(mascot_counter(9007199254740990), 9007199254740991)
    expect_error(mascot_counter(9007199254740991), "Assertion")
    for (value in list(-1, Inf, NaN, "1", NULL)) {
      expect_error(mascot_counter(value), "Assertion|safe integer")
    }
    for (value in list(-1, Inf, NaN, 1.1, "1", NULL)) {
      expect_false(mascot_safe_counter(value))
    }
  })
})

describe("static template recovery", {
  it("recovers an absent template into one session after checking the baseline and content token", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    state <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    state$bubble <- list(text = "Prerendered", html = FALSE, closable = TRUE, duration = NULL)
    token <- mascot_mount_token(f$id, state, NULL)
    store <- mascot_template_store()
    saved <- store$items[[token]]
    withr::defer(store$items[[token]] <- saved)
    store$items[[token]] <- NULL
    update_mascot("helper", status = "Before ready", session = f$session)
    data <- protocol_snapshot(token)
    mascot_snapshot(data, f$session, f$id)
    expect_identical(tail(f$messages$values, 1)[[1]]$kind, "template-needed")
    expect_false(protocol_record(f)$live)
    data$baseline <- state
    mascot_snapshot(data, f$session, f$id)
    latest <- protocol_flush(f)
    expect_true(protocol_record(f)$live)
    expect_identical(latest$state$bubble$text, "Prerendered")
    expect_identical(latest$state$status$text, "Before ready")
    expect_null(store$items[[token]])
    expect_identical(mascot_mount_lookup(f$session, f$id, token)$spec$state, state)
    # Session-owned recovery cannot create a process-wide visitor catalogue.
    g <- protocol_fixture()
    withr::defer(g$session$close())
    expect_null(mascot_mount_lookup(g$session, f$id, token))
    expect_error(mascot_mount_recover(g$session, "other", token, state), "disagree")
    bad <- data
    bad$baseline$mood <- "hapy"
    mascot_snapshot(bad, g$session, f$id)
    expect_null(g$session$userData$mascot_protocol)
    expect_identical(tail(g$messages$values, 1)[[1]]$kind, "template-rejected")
  })

  it("recovers palette UI baselines and rejects forged palette colours", {
    for (theme in list("orbit", "original", mascot_theme(palette = "orbit"))) {
      ui <- mascot("helper", character = "knurl", theme = theme)
      script <- Filter(
        function(tag) {
          inherits(tag, "shiny.tag") && "data-mascot-baseline" %in% names(tag$attribs)
        },
        ui$children
      )[[1]]
      state <- jsonlite::fromJSON(as.character(script$children[[1]]), simplifyVector = FALSE)
      state$character$json <- as.character(ui$children[[1]]$children[[1]])
      token <- ui$attribs[["data-mount-token"]]
      f <- protocol_fixture()
      withr::defer(f$session$close())
      recovered <- mascot_mount_recover(f$session, "helper", token, state)
      expect_identical(recovered$spec$state$theme$palette, state$theme$palette)
      forged <- state
      forged$theme$palette_colours$light <- list(body = "#000000")
      expect_error(mascot_baseline_check(forged), "palette_colours")
      forged$theme$palette <- "absent"
      expect_error(mascot_baseline_check(forged), "absent.*knurl.*orbit", class = "mascot_error")
      forged$theme$palette <- NULL
      expect_error(mascot_baseline_check(forged), "palette")
    }
  })

  it("refuses forged native fields even with a matching content-derived token", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    state <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    bad <- list(
      list(size = list(size = -1, small_screen = NULL)),
      list(placement = list(floating = TRUE, position = "inline", minimise = TRUE, drag = FALSE)),
      list(motion = modifyList(state$motion, list(gestures = "yes"))),
      list(click = list(type = "action", label = "Help", tooltip = "yes", disabled = FALSE)),
      list(theme = modifyList(state$theme, list(light = list(body = "not-a-colour")))),
      list(status = list(mode = "mood", text = "extra")),
      list(motion = c(state$motion[setdiff(names(state$motion), "messages")], list(messages = list(list("bubble"))))),
      list(theme = modifyList(state$theme, list(light = list(body = c(0, 0, 0))))),
      list(theme = modifyList(state$theme, list(light = list()))),
      list(bubble = list(text = "x", html = "yes", closable = TRUE, duration = NULL)),
      list(status = list(mode = "custom", text = strrep("x", 262145)))
    )
    for (patch in bad) {
      candidate <- state
      candidate[names(patch)] <- patch
      token <- mascot_mount_token(f$id, candidate, NULL)
      store <- mascot_template_store()
      store$items[[token]] <- NULL
      expect_error(mascot_mount_recover(f$session, f$id, token, candidate))
    }
    token <- mascot_mount_token(f$id, state, NULL)
    state$character$json <- "{}"
    expect_error(mascot_mount_recover(f$session, f$id, token, state))
    expect_null(f$session$userData$mascot_protocol)
    state$character <- list(id = "tessa", name = "Tessa", json = character_json("tessa"))
    state$placement <- placement_wire(mascot_placement("inline"))
    token <- mascot_mount_token(f$id, state, NULL)
    expect_identical(mascot_mount_recover(f$session, f$id, token, state)$spec$state, state)
    state$click <- as_click_arg(mascot_action("Help"), environment())
    token <- mascot_mount_token(f$id, state, NULL)
    state$click <- rev(state$click)
    expect_silent(mascot_mount_recover(f$session, f$id, token, state))
  })

  it("#494 gives the same content the same token and a changed custom character a new one", {
    source <- format_recipe()
    source$id <- "token_probe"
    source$name <- "Token Probe"
    checked <- character_format_check(source)
    source$name <- "Token Probe Two"
    changed <- character_format_check(source)
    token <- function(character, id = "probe") mascot(id, character = character)$attribs[["data-mount-token"]]
    first <- token(checked)
    expect_match(first, "^t[0-9]+-[0-9]+-[0-9]+$")
    expect_identical(token(checked), first)
    expect_identical(token(mascot_character(checked)), first)
    expect_false(identical(token(changed), first))
    expect_identical(token("tessa"), token("tessa"))
    expect_false(identical(token("tessa"), token("sela")))
    # The token is the key of the complete canonical specification, whose source part is made once per content.
    base <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    full <- list(id = "probe", state = base)
    full$state$character$json <- jsonlite::fromJSON(character_json("tessa"), simplifyVector = FALSE)
    expect_identical(
      mascot_mount_token("probe", base, NULL),
      paste0("t", mascot_template_key(character_format_identity(full), remember = FALSE))
    )
  })

  it("#494 writes the character source piece as it is only in a mount specification's identity", {
    base <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    spec <- list(id = "probe", state = base)
    full <- spec
    full$state$character$json <- list(b = 2, a = list(1, "x"))
    piece <- character_identity_piece(full$state$character$json)
    expect_identical(mascot_spec_identity(spec, piece), character_format_identity(full))
    expect_match(mascot_spec_identity(spec, piece), '"json":{"a":[1,"x"],"b":2}', fixed = TRUE)
    # The same piece as status text is text: it never gives the same identity as other content.
    forged <- spec
    forged$state$status <- list(mode = "custom", text = piece)
    expect_false(identical(mascot_spec_identity(forged, piece), mascot_spec_identity(spec, piece)))
    expect_match(mascot_spec_identity(forged, piece), '"text":"{\\"a\\"', fixed = TRUE)
    expect_error(mascot_spec_identity(spec, "text"), "Assertion")
    expect_error(mascot_spec_identity(list(id = "probe"), piece), "Assertion")
    expect_error(mascot_spec_identity(list(id = "probe", state = list()), piece), "Assertion")
  })

  it("#494 keeps built-in character contexts for the whole process, apart from the custom cache", {
    store <- mascot_template_store()
    saved <- as.list(store)
    withr::defer({
      rm(list = ls(store), envir = store)
      list2env(saved, envir = store)
    })
    store$characters <- store$builtins <- list()
    wire <- list(id = "tessa", name = "Tessa", json = character_json("tessa"))
    first <- mascot_state_character(wire)
    expect_identical(names(store$builtins), "tessa")
    expect_length(store$characters, 0)
    custom <- protocol_character()
    for (i in 1:(mascot_character_cache_limit + 2)) {
      custom$json <- paste0(protocol_character()$json, strrep(" ", i))
      mascot_state_character(custom)
    }
    original <- character_catalogue_get
    calls <- new.env(parent = emptyenv())
    calls$n <- 0L
    local_mocked_bindings(character_catalogue_get = function(...) {
      calls$n <- calls$n + 1L
      original(...)
    })
    expect_identical(mascot_state_character(wire), first)
    expect_identical(calls$n, 0L)
    shipped <- jsonlite::fromJSON(character_json("tessa"), simplifyVector = FALSE)
    expect_identical(as.character(first$source_identity), character_format_identity(shipped))
    wire$name <- "Forged"
    expect_error(mascot_state_character(wire), "disagree")
  })

  it("reuses checked JSON and keys, rejects changed identities and bounds immutable caches", {
    store <- mascot_template_store()
    saved <- as.list(store)
    withr::defer({
      rm(list = ls(store), envir = store)
      list2env(saved, envir = store)
    })
    store$characters <- store$keys <- list()
    wire <- protocol_character()
    original <- character_format_check
    calls <- new.env(parent = emptyenv())
    calls$n <- 0L
    local_mocked_bindings(character_format_check = function(...) {
      calls$n <- calls$n + 1L
      original(...)
    })
    first <- mascot_state_character(wire)
    for (i in 1:100) {
      expect_identical(mascot_state_character(wire), first)
    }
    expect_identical(calls$n, 1L)
    wire$name <- "Forged"
    expect_error(mascot_state_character(wire), "disagree")
    for (i in 1:30) {
      mascot_template_key(paste0("identity-", i))
    }
    expect_lte(length(store$keys), mascot_character_cache_limit)
    wire$name <- first$wire$name
    for (i in 1:18) {
      wire$json <- paste0(first$wire$json, strrep(" ", i))
      mascot_state_character(wire)
    }
    expect_identical(length(store$characters), mascot_character_cache_limit)
  })
})
