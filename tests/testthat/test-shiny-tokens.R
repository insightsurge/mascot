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
    store$serial <- store$tick <- 0
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
