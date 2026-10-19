describe("R-settled latest mascot state", {
  it("U1.1 rejects mixed target failures atomically, naming the id", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    protocol_ready(f)
    protocol_flush(f)
    update_mascot("helper", gesture = "nod", bubble = "Good", session = f$session)
    before <- protocol_record(f)
    expect_warning(
      send_update(
        f$session,
        "helper",
        list(theme = c(mascot_empty_theme(), list(palette = "missing")), bubble = list(clear = TRUE))
      ),
      "helper",
      class = "mascot_update_ignored"
    )
    expect_identical(protocol_record(f), before)
    expect_warning(
      update_mascot("helper", mood = "missing", status = "Wrong", gesture = "nod", session = f$session),
      "mood"
    )
    expect_identical(protocol_record(f), before)
    expect_warning(
      send_update(f$session, "helper", list(mood = "hapy", status = list(mode = "custom", text = "Wrong"))),
      "hapy"
    )
    expect_identical(protocol_record(f), before)
    for (bad in list(
      list(gesture = "absent", status = list(mode = "custom", text = "Wrong")),
      list(
        click = list(type = "action", label = "Help", tooltip = FALSE, disabled = FALSE, gesture = "absent"),
        bubble = list(clear = TRUE)
      )
    )) {
      expect_warning(send_update(f$session, "helper", bad), "gesture")
      expect_identical(protocol_record(f), before)
    }
    expect_warning(send_update(f$session, "helper", list(unknown = 1, bubble = list(clear = TRUE))), "Unknown")
    expect_warning(
      send_update(f$session, "helper", list(status = list(mode = "custom", text = strrep("x", 262145)))),
      "capacity"
    )
    expect_identical(protocol_record(f), before)
    deep <- "x"
    for (i in 1:34) {
      deep <- list(value = deep)
    }
    expect_warning(send_update(f$session, "helper", list(theme = list(light = deep))), "nesting depth")
    expect_identical(protocol_record(f), before)
    wide <- as.list(rep("x", 10001))
    expect_warning(send_update(f$session, "helper", list(theme = list(light = wide))), "node")
    expect_identical(protocol_record(f), before)
  })

  it("U1.1 coalesces versioned development diagnostics without accepting rejected values", {
    local_mocked_bindings(dev_mode = function() TRUE)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    protocol_ready(f)
    protocol_flush(f)
    before <- protocol_record(f)
    for (i in 1:10) {
      expect_warning(update_mascot("helper", mood = "missing", status = "Wrong", session = f$session), "unchanged")
    }
    expect_identical(protocol_record(f), before)
    expect_length(f$messages$values, 1)
    diagnostic <- protocol_flush(f)
    expect_length(f$messages$values, 2)
    expect_identical(diagnostic$version, 1L)
    expect_identical(diagnostic$kind, "diagnostic")
    expect_identical(diagnostic$generation, before$generation)
    expect_identical(diagnostic$revision, before$revision)
    expect_null(diagnostic$state)
    update_mascot("helper", status = "Kept", session = f$session)
    expect_warning(update_mascot("helper", mood = "missing", status = "Wrong", session = f$session), "unchanged")
    latest <- protocol_flush(f)
    expect_length(f$messages$values, 3)
    expect_identical(latest$state$status$text, "Kept")
    expect_match(latest$problem, "missing")
  })

  it("U1.2 compacts original calls by field owners within conservative guard buckets", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    expect_length(mascot_state_fields, 10)
    for (i in 1:1000) {
      update_mascot("helper", status = as.character(i), session = f$session)
    }
    r <- protocol_record(f)
    expect_length(r$cold$free$calls, 1)
    expect_length(f$messages$values, 0)
    send_update(
      f$session,
      "helper",
      list(mood = "processing", status = list(mode = "custom", text = "Guard predecessor"))
    )
    send_update(
      f$session,
      "helper",
      list(mood = "processing", bubble = list(text = "Together", html = FALSE, closable = TRUE, duration = 5))
    )
    buckets <- protocol_record(f)$cold
    expect_equal(sum(vapply(buckets, function(x) length(x$calls), integer(1))), 3)
    # A different, invalid guard cannot erase a valid predecessor's coupled fields.
    send_update(f$session, "helper", list(mood = "absent", status = list(mode = "custom", text = "Wrong")))
    state <- mascot_state_defaults(protocol_character())
    expect_warning(protocol_ready(f, state = state), "absent")
    r <- protocol_record(f)
    expect_identical(r$desired$status$text, "Guard predecessor")
    expect_identical(r$desired$bubble$text, "Together")
    expect_identical(r$desired$mood, "processing")
    expect_length(r$cold, 0)
    # The free bucket's final value survives when it is the only candidate.
    g <- protocol_fixture()
    withr::defer(g$session$close())
    for (i in 1:1000) {
      update_mascot("helper", status = as.character(i), session = g$session)
    }
    protocol_ready(g)
    expect_identical(protocol_record(g)$desired$status$text, "1000")
  })

  it("U1.2 rejects guard 21 without changing the earlier buffer and replaces whole helpers", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    for (i in 1:20) {
      send_update(
        f$session,
        "helper",
        list(
          theme = c(mascot_empty_theme(), list(palette = paste0("palette_", i))),
          status = list(mode = "custom", text = as.character(i))
        )
      )
    }
    for (i in 1:20) {
      send_update(
        f$session,
        "helper",
        list(
          theme = c(mascot_empty_theme(), list(palette = paste0("palette_", i))),
          bubble = list(text = "Second field", html = FALSE, closable = TRUE, duration = 5)
        )
      )
    }
    expect_equal(sum(vapply(protocol_record(f)$cold, function(bucket) length(bucket$calls), integer(1))), 40)
    before <- protocol_record(f)
    expect_warning(
      send_update(
        f$session,
        "helper",
        list(theme = c(mascot_empty_theme(), list(palette = "overflow")), bubble = list(clear = TRUE))
      ),
      "capacity"
    )
    expect_identical(protocol_record(f), before)
    g <- protocol_fixture()
    withr::defer(g$session$close())
    update_mascot(
      "helper",
      theme = mascot_theme(light = list(body = "#123456")),
      bubble = mascot_bubble("Old", duration = Inf),
      session = g$session
    )
    update_mascot("helper", theme = mascot_theme(), bubble = mascot_bubble("New"), session = g$session)
    protocol_ready(g)
    expect_null(protocol_record(g)$desired$theme$light)
    expect_identical(protocol_record(g)$desired$bubble$duration, 5)
    expect_identical(protocol_record(g)$desired$bubble$text, "New")
  })

  it("U1.3 settles the prefix against the first valid explicit character and never buffers characters", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    x <- protocol_character()
    y <- protocol_character(FALSE, "other_probe")
    send_update(f$session, "helper", list(mood = "processing", status = list(mode = "custom", text = "Scanning")))
    send_update(
      f$session,
      "helper",
      list(
        theme = c(mascot_empty_theme(), list(palette = "absent")),
        bubble = list(text = "Wrong", html = FALSE, closable = TRUE, duration = 5)
      )
    )
    before <- protocol_record(f)
    expect_warning(send_update(f$session, "helper", list(character = x, mood = "absent")), "absent")
    expect_identical(protocol_record(f), before)
    expect_warning(
      send_update(f$session, "helper", list(character = x, status = list(mode = "custom", text = "Later"))),
      "palette"
    )
    expect_identical(protocol_record(f)$desired$status$text, "Later")
    expect_identical(protocol_record(f)$desired$mood, "processing")
    expect_true(all(protocol_record(f)$owned %in% mascot_state_fields))
    expect_length(protocol_record(f)$cold, 0)
    for (i in 1:100) {
      send_update(f$session, "helper", list(character = if (i %% 2) x else y))
    }
    expect_identical(protocol_record(f)$desired$character$id, "other_probe")
    expect_length(protocol_record(f)$cold, 0)
    expect_length(f$messages$values, 0)
    # Emission alone does not change the known target, even while removed.
    token <- protocol_ready(f)
    protocol_flush(f)
    mascot_snapshot(protocol_snapshot(token, lifecycle = "unmounted"), f$session, f$id)
    mascot_mount_token(f$id, mascot_state_defaults(x), f$session)
    expect_warning(
      send_update(f$session, "helper", list(mood = "processing", status = list(mode = "custom", text = "Wrong"))),
      "processing"
    )
    expect_identical(protocol_record(f)$desired$character$id, "other_probe")
  })

  it("U1.4 recomputes every ownership row and adapts unowned palettes and click groups", {
    local_mocked_bindings(dev_mode = function() TRUE)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    x <- protocol_character()
    y <- protocol_character(FALSE, "other_probe")
    baseline <- mascot_state_defaults(x)
    baseline$theme$palette <- "sea"
    baseline$click <- list(type = "action", label = "Help", tooltip = FALSE, disabled = FALSE, gesture = "spin")
    protocol_ready(f, state = baseline)
    protocol_flush(f)
    expect_warning(
      send_update(
        f$session,
        "helper",
        list(
          character = y,
          status = list(mode = "custom", text = "Kept"),
          theme = mascot_empty_theme(),
          size = unclass(mascot_size(96)),
          placement = placement_wire(mascot_placement("inline")),
          motion = as_motion_arg(FALSE, environment())
        )
      ),
      "click",
      class = "mascot_click_dropped"
    )
    expect_identical(protocol_record(f)$desired$theme, mascot_empty_theme())
    newer <- mascot_state_defaults(x)
    newer$mood <- "processing"
    newer$theme$palette <- "sea"
    newer$click <- baseline$click
    expect_warning(protocol_ready(f, 2, state = newer), "click", class = "mascot_click_dropped")
    r <- protocol_record(f)
    expect_identical(r$desired$character$id, "other_probe")
    expect_identical(r$desired$mood, "idle")
    expect_identical(r$desired$status$text, "Kept")
    expect_identical(r$desired$size$size, 96)
    expect_false(r$desired$placement$floating)
    expect_false(r$desired$motion$gestures)
    expect_null(r$desired$click$gesture)
    expect_false("click" %in% r$owned)
    h <- protocol_fixture()
    withr::defer(h$session$close())
    send_update(h$session, "helper", list(character = y))
    # UI palette is valid on its own UI character but unavailable on the
    # server-owned winner. Neither restored field acquires ownership.
    conditions <- character()
    withCallingHandlers(protocol_ready(h, state = baseline), warning = function(w) {
      conditions <<- c(conditions, class(w)[[1]])
      invokeRestart("muffleWarning")
    })
    expect_setequal(conditions, c("mascot_palette_dropped", "mascot_click_dropped"))
    expect_null(protocol_record(h)$desired$theme$palette)
    expect_false(any(c("theme", "click") %in% protocol_record(h)$owned))
    # Unowned character follows the new UI; retained mood follows outgoing fallback.
    g <- protocol_fixture()
    withr::defer(g$session$close())
    protocol_ready(g, state = baseline)
    protocol_flush(g)
    send_update(g$session, "helper", list(mood = "processing"))
    protocol_ready(g, 2, state = mascot_state_defaults(y))
    expect_identical(protocol_record(g)$desired$character$id, "other_probe")
    expect_identical(protocol_record(g)$desired$mood, "thinking")
    expect_false("theme" %in% protocol_record(g)$owned)
    revision <- protocol_record(g)$revision
    token <- protocol_record(g)$mount_token
    protocol_ready(g, 2, token = token)
    expect_identical(protocol_record(g)$revision, revision)
    protocol_ready(
      g,
      3,
      state = mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    )
    expect_gt(protocol_record(g)$revision, revision)
  })

  it("U1.4 maps retained role overrides to the incoming wire vocabulary", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    protocol_ready(f)
    protocol_flush(f)
    update_mascot("helper", theme = list(body_highlight = "#123456"), session = f$session)
    value <- format_recipe()
    value$id <- "role_probe"
    value$colours$body_highlight <- "#abcdef"
    data <- character_check(value)
    send_update(
      f$session,
      "helper",
      list(character = list(id = data$id, name = data$name, json = character_json_write(data)))
    )
    latest <- protocol_flush(f)
    expect_identical(latest$state$theme$light$body_highlight, "#123456")
    expect_null(latest$state$theme$light$bodyHighlight)
    update_mascot("helper", character = "tessa", session = f$session)
    expect_identical(protocol_flush(f)$state$theme$light$body_highlight, "#123456")
    expect_null(protocol_flush(f)$state$theme$light$bodyHighlight)
  })

  it("U1.5-6 progresses without outcomes, ignores old lifecycle, and coalesces explicit reconciliation", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    token <- protocol_ready(f, state = mascot_state_defaults(protocol_character()))
    protocol_flush(f)
    for (i in 1:20) {
      update_mascot("helper", status = as.character(i), session = f$session)
      protocol_flush(f)
    }
    send_update(f$session, "helper", list(mood = "processing", status = list(mode = "custom", text = "Scanning")))
    latest <- protocol_flush(f)
    expect_identical(latest$state$mood, "processing")
    expect_identical(latest$state$status$text, "Scanning")
    expect_identical(latest$state$character$id, "visor_probe")
    count <- length(f$messages$values)
    for (i in 1:20) {
      mascot_snapshot(protocol_snapshot(token), f$session, f$id)
    }
    f$session$flushReact()
    expect_length(f$messages$values, count)
    for (i in 1:20) {
      mascot_snapshot(protocol_snapshot(token, lifecycle = "reconcile"), f$session, f$id)
    }
    protocol_flush(f)
    expect_length(f$messages$values, count + 1L)
    expect_identical(protocol_record(f)$revision, latest$revision)
    for (kind in c("reconcile", "error", "mounted")) {
      mascot_snapshot(protocol_snapshot(token, lifecycle = kind, applied = latest$revision), f$session, f$id)
    }
    f$session$flushReact()
    expect_length(f$messages$values, count + 1L)
    next_token <- protocol_ready(f, 2)
    protocol_flush(f)
    before <- protocol_record(f)
    for (kind in c("ready", "unmounted")) {
      mascot_snapshot(protocol_snapshot(token, lifecycle = kind), f$session, f$id)
    }
    expect_identical(protocol_record(f), before)
    # Terminal even if ready is repeated; merged notices can establish a newer mount.
    mascot_snapshot(protocol_snapshot(next_token, 2, "unmounted"), f$session, f$id)
    protocol_ready(f, 2, token = next_token)
    expect_false(protocol_record(f)$live)
    protocol_ready(f, 4)
    expect_true(protocol_record(f)$live)
    expect_identical(protocol_record(f)$generation, 4)
  })

  it("U1.6 rejects foreign tokens, unsupported snapshots and impossible counters without mutation", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    token <- protocol_ready(f)
    protocol_flush(f)
    before <- protocol_record(f)
    base <- protocol_snapshot(token)
    bad <- list(
      c(base, list(unknown = 1)),
      modifyList(base, list(mount_token = "foreign")),
      modifyList(base, list(applied_revision = 100)),
      modifyList(base, list(gesture_watermark = 1)),
      modifyList(base, list(bubble_watermark = 2)),
      modifyList(base, list(dismissed_bubble_revision = 1))
    )
    for (value in list(-1, Inf, NaN, 1.5, 9007199254740992, "1", NULL)) {
      candidate <- base
      candidate["generation"] <- list(value)
      bad[[length(bad) + 1L]] <- candidate
    }
    for (candidate in bad) {
      mascot_snapshot(candidate, f$session, f$id)
    }
    expect_identical(protocol_record(f), before)
    count <- length(f$messages$values)
    expect_identical(tail(f$messages$values, 1)[[1]]$kind, "template-rejected")
    mascot_snapshot(protocol_snapshot(token, lifecycle = "error"), f$session, f$id)
    f$session$flushReact()
    expect_length(f$messages$values, count)
  })

  it("U1.6 validates a first snapshot before allocating state and never learns a target from unmount", {
    token <- mascot("untouched")$attribs[["data-mount-token"]]
    session <- shiny::MockShinySession$new()
    withr::defer(session$close())
    mascot_snapshot(protocol_snapshot(token, applied = 1), session, "untouched")
    expect_null(session$userData$mascot_protocol)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    update_mascot("helper", status = "Before target", session = f$session)
    state <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    token <- mascot_mount_token(f$id, state, f$session)
    mascot_snapshot(protocol_snapshot(token, lifecycle = "unmounted"), f$session, f$id)
    expect_null(protocol_record(f)$context)
    expect_identical(protocol_record(f)$revision, 0)
    protocol_ready(f, token = token)
    expect_null(protocol_record(f)$context)
    protocol_ready(f, 2, token = token)
    expect_identical(protocol_flush(f)$state$status$text, "Before target")
  })

  it("U1.7 keeps only the latest gesture and consumes an unavailable winner before sending", {
    local_mocked_bindings(dev_mode = function() TRUE)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    update_mascot("helper", gesture = "nod", session = f$session)
    update_mascot("helper", gesture = "wave", session = f$session)
    token <- protocol_ready(f)
    latest <- protocol_flush(f)
    expect_identical(latest$gesture$name, "wave")
    mascot_snapshot(
      protocol_snapshot(
        token,
        lifecycle = "mounted",
        applied = latest$revision,
        gesture = latest$gesture$revision,
        bubble = latest$bubble_revision
      ),
      f$session,
      f$id
    )
    protocol_ready(f, 2)
    expect_null(protocol_flush(f)$gesture)
    x <- protocol_character()
    y <- protocol_character(FALSE, "other_probe")
    send_update(f$session, "helper", list(character = x, gesture = "spin"))
    send_update(
      f$session,
      "helper",
      list(character = y, motion = as_motion_arg(FALSE, environment()), status = list(mode = "custom", text = "Kept"))
    )
    expect_warning(latest <- protocol_flush(f), "cannot play", class = "mascot_gesture_dropped")
    expect_null(latest$gesture)
    expect_identical(latest$state$status$text, "Kept")
    expect_gt(latest$gesture_watermark, 0)
    # The same discard works with an unowned different remount target.
    g <- protocol_fixture()
    withr::defer(g$session$close())
    t <- protocol_ready(g, state = mascot_state_defaults(x))
    protocol_flush(g)
    mascot_snapshot(protocol_snapshot(t, lifecycle = "unmounted"), g$session, g$id)
    send_update(g$session, "helper", list(gesture = "spin"))
    protocol_ready(g, 2, state = mascot_state_defaults(y))
    expect_warning(expect_null(protocol_flush(g)$gesture), "cannot play")
  })

  it("U1.7 discards an incompatible pending gesture before startup or after an explicit unmounted change", {
    local_mocked_bindings(dev_mode = function() TRUE)
    x <- protocol_character()
    y <- protocol_character(FALSE, "other_probe")
    for (mounted in c(FALSE, TRUE)) {
      f <- protocol_fixture()
      withr::defer(f$session$close())
      if (mounted) {
        token <- protocol_ready(f, state = mascot_state_defaults(x))
        protocol_flush(f)
        mascot_snapshot(protocol_snapshot(token, lifecycle = "unmounted"), f$session, f$id)
      }
      send_update(f$session, "helper", list(character = x, gesture = "spin"))
      send_update(f$session, "helper", list(character = y, status = list(mode = "custom", text = "Kept")))
      protocol_ready(f, if (mounted) 2 else 1)
      expect_warning(latest <- protocol_flush(f), "cannot play", class = "mascot_gesture_dropped")
      expect_null(latest$gesture)
      expect_identical(latest$state$status$text, "Kept")
    }
  })

  it("U1.8 gives explicit identical bubbles new revisions but identical UI remounts keep theirs", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    base <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    base$bubble <- list(text = "Hello", html = FALSE, closable = TRUE, duration = 5)
    token <- protocol_ready(f, state = base)
    first <- protocol_flush(f)
    mascot_snapshot(
      protocol_snapshot(
        token,
        lifecycle = "mounted",
        applied = first$revision,
        bubble = first$bubble_revision,
        dismissed = first$bubble_revision
      ),
      f$session,
      f$id
    )
    protocol_ready(f, 2, state = base)
    same <- protocol_flush(f)
    expect_identical(same$bubble_revision, first$bubble_revision)
    expect_identical(same$revision, first$revision)
    base$status <- list(mode = "custom", text = "New UI")
    protocol_ready(f, 3, state = base)
    changed <- protocol_flush(f)
    expect_gt(changed$bubble_revision, same$bubble_revision)
    update_mascot("helper", bubble = "Hello", session = f$session)
    next_bubble <- protocol_flush(f)$bubble_revision
    update_mascot("helper", bubble = "Hello", session = f$session)
    expect_gt(protocol_flush(f)$bubble_revision, next_bubble)
    update_mascot("helper", status = "Status", session = f$session)
    expect_identical(protocol_flush(f)$bubble_revision, next_bubble + 1)
  })
})

describe("target-specific diagnostics", {
  it("names the invalid value and the checked character's available choices", {
    state <- mascot_state_empty("helper")
    wire <- protocol_character()
    state <- mascot_state_accept(state, list(character = wire))
    expect_error(mascot_state_prepare(state, list(mood = "hapy")), "processing.*hapy", class = "mascot_error")
    expect_error(mascot_state_prepare(state, list(gesture = "jump")), "spin.*jump", class = "mascot_error")
    expect_error(
      mascot_state_prepare(state, list(theme = list(palette = "absent"))),
      "absent.*sea",
      class = "mascot_error"
    )
    expect_error(
      mascot_state_prepare(state, list(theme = list(light = list(bdoy = "#123456")))),
      "bdoy.*body",
      class = "mascot_error"
    )
  })
})

describe("palette state across public updates", {
  it("warns and accepts no part of an unknown-palette update, and resets with original", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    update_mascot("helper", character = "knurl", theme = "orbit", session = f$session)
    before <- protocol_record(f)$desired
    expect_warning(
      update_mascot("helper", theme = "oribt", status = "Discard me", session = f$session),
      "oribt.*knurl.*orbit.*Did you mean",
      class = "mascot_update_ignored"
    )
    expect_identical(protocol_record(f)$desired, before)
    update_mascot("helper", theme = NULL, session = f$session)
    expect_identical(protocol_record(f)$desired, before)
    update_mascot("helper", theme = "original", session = f$session)
    theme <- protocol_record(f)$desired$theme
    expect_identical(theme$palette, "original")
    expect_null(theme$light)
    expect_null(theme$palette_colours$light)
  })
  it("drops unsupported palettes with an always-on warning and keeps only shared explicit roles", {
    withr::local_options(mascot.contrast_warnings = FALSE)
    local_mocked_bindings(dev_mode = function() FALSE)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    update_mascot(
      "helper",
      character = "knurl",
      theme = mascot_theme(
        palette = "orbit",
        light = list(body = "#123456", screen = "#102030"),
        dark = list(body = "#654321"),
        css = list(body = "--shared", screen = "--screen")
      ),
      session = f$session
    )
    expect_warning(
      update_mascot("helper", character = "neer", session = f$session),
      "orbit.*neer.*explicit colours",
      class = "mascot_palette_dropped"
    )
    theme <- protocol_record(f)$desired$theme
    expect_null(theme$palette)
    expect_null(theme$palette_colours)
    expect_identical(theme$light, list(body = "#123456"))
    expect_identical(theme$dark, list(body = "#654321"))
    expect_identical(theme$css, list(body = "--shared"))
    protocol_ready(f)
    expect_identical(protocol_flush(f)$state$theme, theme)
  })
  it("adds the characters that have a dropped palette to the warning", {
    withr::local_options(mascot.contrast_warnings = FALSE)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    update_mascot("helper", character = "sela", theme = "azure", session = f$session)
    expect_warning(
      update_mascot("helper", character = "tessa", session = f$session),
      'Palette "azure" dropped for character "tessa".*Character "sela" has a palette called "azure"',
      class = "mascot_palette_dropped"
    )
    expect_null(protocol_record(f)$desired$theme$palette)
  })
  it("keeps a shared id using the incoming character's palette and accepts a palette with a swap", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    update_mascot("helper", character = "tessa", theme = "peach", session = f$session)
    expect_no_warning(update_mascot("helper", character = "sela", session = f$session))
    theme <- protocol_record(f)$desired$theme
    expect_identical(theme$palette, "peach")
    expect_identical(theme$palette_colours$light$hair_purple, "#2B305C")
    expect_null(theme$palette_colours$light$accessory)
    expect_no_warning(update_mascot("helper", character = "neer", theme = "lagoon", session = f$session))
    expect_identical(protocol_record(f)$desired$theme$palette, "lagoon")
  })
  it("resolves a buffered palette once the first UI character is known", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    update_mascot("helper", theme = "orbit", session = f$session)
    wire <- list(id = "knurl", name = "Knurl", json = character_json("knurl"))
    baseline <- mascot_state_defaults(wire)
    protocol_ready(f, state = baseline)
    expect_identical(protocol_record(f)$desired$theme$palette_colours$light$body, "#F8FAFC")
  })
})

describe("palette wire assertions", {
  it("checks the palette id before buffering an update", {
    expect_error(mascot_wire_check(list(theme = list(palette = 1))), "palette")
    expect_error(mascot_wire_check(list(theme = list(palette = "not-an-id"))), "palette")
  })
})

describe("B2 mount diagnostics and private inputs", {
  it("adds the development overlay when a buffered update fails at mount", {
    local_mocked_bindings(dev_mode = function() TRUE)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    update_mascot("helper", mood = "missing", session = f$session)
    expect_warning(protocol_ready(f), class = "mascot_update_ignored")
    latest <- protocol_flush(f)
    expect_match(latest$problem, "mascot: .*missing")
    expect_identical(latest$state$mood, "idle")
  })
  it("keeps private inputs visible to reactiveValuesToList but excludes them from bookmarks", {
    shiny::testServer(
      function(input, output, session) {
        shiny::setBookmarkExclude("existing", session)
        mascot_id_state(session, "helper")
        session$setInputs(helper = list(version = 1L), ordinary = "kept")
        values <- shiny::isolate(shiny::reactiveValuesToList(input))
        expect_true("helper" %in% names(values))
        expect_equal(values$ordinary, "kept")
        expect_true(all(c("existing", "helper") %in% session$getBookmarkExclude()))
        expect_false("ordinary" %in% session$getBookmarkExclude())
      },
      {}
    )
  })
})


describe("private bookmark exclusions", {
  it("survives later app exclusions at root and in nested modules", {
    shiny::testServer(
      function(input, output, session) {
        nested <- session$makeScope("outer")$makeScope("inner")
        update_mascot("helper", mood = "happy", session = session)
        update_mascot("helper", mood = "happy", session = nested)
        shiny::setBookmarkExclude("x", session = session)
        shiny::setBookmarkExclude("password", session = nested)
        # Shiny doBookmark() collects this list before running onBookmark callbacks.
        excluded <- session$getBookmarkExclude()
        expect_true(all(c("helper", "outer-inner-helper", "x", "outer-inner-password") %in% excluded))
        expect_false("ordinary" %in% excluded)
      },
      {}
    )
  })
})


describe("real Shiny bookmark collection", {
  it("collects private exclusions after later app and module replacements", {
    # Only the transport is inert; scope and exclusion collection use ShinySession.
    session <- getFromNamespace("ShinySession", "shiny")$new(list(
      request = list(),
      send = function(...) NULL,
      close = function(...) NULL
    ))
    withr::defer(session$close())
    nested <- session$makeScope("outer")$makeScope("inner")
    update_mascot("helper", mood = "happy", session = session)
    update_mascot("helper", mood = "happy", session = nested)
    shiny::setBookmarkExclude("x", session = session)
    shiny::setBookmarkExclude("password", session = nested)
    expect_true(all(c("helper", "outer-inner-helper", "x", "outer-inner-password") %in% session$getBookmarkExclude()))
  })
})
