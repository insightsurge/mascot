# Private wire version 1. Additive envelope metadata may be ignored by pages;
# state fields and input snapshots are deliberately closed, checked contracts.
mascot_state_fields <- c(
  "character",
  "mood",
  "status",
  "bubble",
  "size",
  "placement",
  "theme",
  "motion",
  "click",
  "gesture"
)

#' Report a development-only restoration diagnostic
#' @noRd
mascot_diagnostic <- function(class, text) {
  checkmate::assert_string(class)
  checkmate::assert_string(text)
  if (dev_mode()) {
    cli::cli_warn("{text}", class = c(class, "mascot_warning"))
  }
  invisible(NULL)
}

#' Reject a whole runtime call without acquiring any field
#' @noRd
mascot_update_warning <- function(id, reason) {
  checkmate::assert_string(id)
  checkmate::assert_string(reason)
  cli::cli_warn(
    c("{.fn update_mascot} left mascot {.val {id}} unchanged.", "x" = "{reason}"),
    class = c("mascot_update_ignored", "mascot_warning")
  )
}

#' Resolve module addressing once
#' @noRd
mascot_binding_id <- function(session, id) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(id)
  prefix <- session$ns("")
  if (nzchar(prefix) && startsWith(id, prefix)) {
    id <- substring(id, nchar(prefix) + 1L)
  }
  session$ns(id)
}

#' Create one retained id, never a journal of calls
#' @noRd
mascot_id_state <- function(session, id, namespaced = FALSE) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(id)
  checkmate::assert_flag(namespaced)
  key <- if (namespaced) id else mascot_binding_id(session, id)
  owner <- mascot_session(session)
  if (is.null(owner$states[[key]])) {
    owner$states[[key]] <- mascot_state_empty(key)
    # Mock sessions do not run typed input handlers. The observer also makes
    # repeated delivered snapshots harmless in ordinary Shiny sessions.
    prefix <- session$ns("")
    local <- if (nzchar(prefix) && startsWith(key, prefix)) substring(key, nchar(prefix) + 1L) else key
    # An independent scope contributes exclusions when Shiny collects them,
    # before onBookmark callbacks. App calls cannot replace this scope's list.
    private_scope <- session$makeScope(character(0))
    shiny::setBookmarkExclude(local, session = private_scope)
    shiny::observeEvent(
      session$input[[local]],
      {
        mascot_snapshot(session$input[[local]], session, key)
      },
      ignoreInit = FALSE,
      domain = session
    )
  }
  owner$states[[key]]
}

#' Uninstalled initial record, also used to preflight a first snapshot
#' @noRd
mascot_state_empty <- function(key) {
  checkmate::assert_string(key)
  list(
    id = key,
    desired = list(),
    owned = character(),
    context = NULL,
    revision = 0,
    sequence = 0,
    pending = NULL,
    gesture_watermark = 0,
    bubble_revision = 0,
    bubble_serial = 0,
    bubble_watermark = 0,
    dismissed = 0,
    baseline = NULL,
    baseline_identity = NULL,
    baseline_token = NULL,
    generation = 0,
    live = FALSE,
    mount_token = NULL,
    sent = NULL,
    scheduled = FALSE,
    restore = FALSE,
    cold = list()
  )
}

#' Effective normal helper defaults for a declared startup character
#' @noRd
mascot_state_defaults <- function(character) {
  checkmate::assert_list(character, names = "unique")
  list(
    character = character,
    mood = "idle",
    status = list(mode = "mood"),
    bubble = list(clear = TRUE),
    size = unclass(mascot_size()),
    placement = placement_wire(mascot_placement()),
    theme = mascot_empty_theme(),
    motion = as_motion_arg(TRUE, environment()),
    click = list(type = "none")
  )
}

#' Obtain checked metadata without registering visitor-created content
#' @noRd
mascot_state_character <- function(wire) {
  checkmate::assert_list(wire, names = "unique")
  checkmate::assert_names(names(wire), permutation.of = c("id", "name", "json"))
  checkmate::assert_string(wire$id, min.chars = 1)
  checkmate::assert_string(wire$name, min.chars = 1)
  checkmate::assert_string(wire$json, min.chars = 1)
  cache <- mascot_template_store()
  hit <- match(wire$json, vapply(cache$characters, function(x) x$wire$json, character(1)))
  if (!is.na(hit)) {
    context <- cache$characters[[hit]]
    if (!identical(wire$id, context$wire$id) || !identical(wire$name, context$wire$name)) {
      cli::cli_abort("Character identity and checked content disagree.", class = "mascot_error")
    }
    return(context)
  }
  if (wire$id %in% builtin_characters()$id && identical(wire$json, character_json(wire$id))) {
    data <- character_catalogue_get(wire$id)
  } else {
    data <- character_format_check(wire$json, from = "text")
  }
  if (!identical(wire$id, data$id) || !identical(wire$name, data$name)) {
    cli::cli_abort("Character identity and checked content disagree.", class = "mascot_error")
  }
  identity <- attr(data, "mascot_manifest")$identity
  context <- list(
    wire = wire,
    data = data,
    identity = identity,
    token = paste0("c", mascot_template_key(identity)),
    source = jsonlite::fromJSON(wire$json, simplifyVector = FALSE),
    roles = names(jsonlite::fromJSON(wire$json, simplifyVector = FALSE)$colours)
  )
  cache$characters <- utils::tail(c(cache$characters, list(context)), mascot_character_cache_limit)
  context
}

#' Adapt a retained mood using its previous character's declared chain
#' @noRd
mascot_state_mood <- function(mood, previous, incoming) {
  checkmate::assert_string(mood)
  checkmate::assert_list(previous, null.ok = TRUE)
  checkmate::assert_list(incoming)
  seen <- character()
  while (!mood %in% names(incoming$moods) && !mood %in% seen) {
    seen <- c(seen, mood)
    next_mood <- previous$moods[[mood]]$fallback
    if (is.null(next_mood)) {
      return("idle")
    }
    mood <- next_mood
  }
  if (mood %in% names(incoming$moods)) mood else "idle"
}

#' Validate or adapt a complete retained theme against its winning character
#' @noRd
mascot_state_theme <- function(theme, data, strict = TRUE, roles = names(data$colours)) {
  checkmate::assert_list(theme, names = "unique")
  checkmate::assert_list(data)
  checkmate::assert_flag(strict)
  checkmate::assert_character(roles, any.missing = FALSE, unique = TRUE, min.len = 1)
  palette <- theme$palette
  if (!is.null(palette)) {
    problem <- theme_palette_problem(palette, data)
    if (!is.null(problem)) {
      if (strict) {
        cli::cli_abort("{problem}", class = "mascot_error")
      }
      cli::cli_warn(
        paste0(
          "Palette {.val {palette}} dropped for character {.val {data$id}}; ",
          "its own colours are used and explicit colours for shared roles are kept."
        ),
        class = c("mascot_palette_dropped", "mascot_warning")
      )
      theme$palette <- NULL
      theme$palette_colours <- NULL
    } else {
      theme$palette_colours <- theme_palette_colours(palette, data)
    }
  }
  for (field in c("light", "dark", "css")) {
    # Legacy camel-case roles are the current engine's spelling.
    valid <- roles
    wrong <- if (!length(theme[[field]])) {
      logical()
    } else {
      !colour_role_names(names(theme[[field]])) %in% colour_role_names(valid)
    }
    if (any(wrong)) {
      if (strict) {
        cli::cli_abort(
          c(
            "Unknown theme colour role {.val {names(theme[[field]])[wrong]}} for {.val {data$id}}.",
            "i" = "Choose {.or {roles}}."
          ),
          class = "mascot_error"
        )
      }
      theme[[field]] <- theme[[field]][!wrong]
      if (!length(theme[[field]])) theme[field] <- list(NULL)
    }
    if (length(theme[[field]])) {
      names(theme[[field]]) <- roles[match(colour_role_names(names(theme[[field]])), colour_role_names(roles))]
      checkmate::assert_names(names(theme[[field]]), type = "unique")
    }
  }
  theme
}

#' Check target-dependent click action groups independently
#' @noRd
mascot_state_click <- function(click, data, strict = TRUE) {
  checkmate::assert_list(click, names = "unique")
  checkmate::assert_list(data)
  checkmate::assert_flag(strict)
  # Current click helpers have only independent action/menu groups. Future
  # character-dependent groups declare their callable mood/gesture here.
  for (field in intersect(c("mood", "gesture"), names(click))) {
    available <- if (field == "mood") names(data$moods) else names(data$gestures)
    if (!click[[field]] %in% available) {
      if (strict) {
        cli::cli_abort("Unavailable click {.val {field}} {.val {click[[field]]}}.")
      }
      mascot_diagnostic(
        "mascot_click_dropped",
        paste0("Unavailable click ", field, " group cleared for '", data$id, "'.")
      )
      click[[field]] <- NULL
    }
  }
  click
}

#' Prepare a whole immutable patch before committing any part of it
#' @noRd
mascot_state_prepare <- function(record, patch, restore = FALSE) {
  checkmate::assert_list(record, names = "unique")
  checkmate::assert_list(patch, names = "unique")
  checkmate::assert_flag(restore)
  if (length(setdiff(names(patch), mascot_state_fields))) {
    cli::cli_abort("Unknown update field.", class = "mascot_error")
  }
  context <- if (is.null(patch$character)) record$context else mascot_state_character(patch$character)
  if (is.null(context)) {
    cli::cli_abort("No known character context.", class = "mascot_error")
  }
  if (
    !is.null(record$context) &&
      identical(context$wire$id, record$context$wire$id) &&
      !identical(context$identity, record$context$identity)
  ) {
    cli::cli_abort("Same character id has different checked content.", class = "mascot_error")
  }
  next_state <- record$desired
  if (!length(next_state)) {
    next_state <- mascot_state_defaults(context$wire)
  }
  previous <- record$context$data
  for (field in setdiff(names(patch), "gesture")) {
    next_state[field] <- patch[field]
  }
  next_state$character <- context$wire
  changed <- !identical(record$context$identity, context$identity)
  if (!restore && !is.null(patch$mood) && !patch$mood %in% names(context$data$moods)) {
    abort_choice(patch$mood, names(context$data$moods), "mood", "mood", environment())
  }
  if (is.null(patch$mood) || restore) {
    next_state$mood <- mascot_state_mood(next_state$mood, previous, context$data)
  }
  if (!is.null(patch$gesture) && !patch$gesture %in% names(context$data$gestures)) {
    abort_choice(patch$gesture, names(context$data$gestures), "gesture", "gesture", environment())
  }
  next_state$click <- mascot_state_click(next_state$click, context$data, !restore && !is.null(patch$click))
  next_state$theme <- mascot_state_theme(
    next_state$theme,
    context$data,
    !restore && !is.null(patch$theme),
    context$roles
  )
  list(desired = next_state, context = context, changed = changed)
}

#' Commit only a completely prepared public call
#' @noRd
mascot_state_accept <- function(record, patch) {
  checkmate::assert_list(record, names = "unique")
  checkmate::assert_list(patch, names = "unique")
  prepared <- mascot_state_prepare(record, patch)
  revision <- mascot_counter(record$revision)
  bubble <- if (is.null(patch$bubble)) record$bubble_serial else mascot_counter(record$bubble_serial)
  record$desired <- prepared$desired
  record$context <- prepared$context
  record$revision <- revision
  record$owned <- union(record$owned, setdiff(names(patch), "gesture"))
  if (!is.null(patch$character) && prepared$changed) {
    record$owned <- union(record$owned, "mood")
  }
  if (!is.null(patch$gesture)) {
    if (!is.null(record$pending)) {
      record$gesture_watermark <- max(record$gesture_watermark, record$pending$revision)
    }
    record$pending <- list(name = patch$gesture, revision = revision)
  }
  if (!is.null(patch$bubble)) {
    record$bubble_serial <- bubble
    record$bubble_revision <- bubble
  }
  record
}

#' Conservative target guards keep complete original cold-start calls
#' @noRd
mascot_state_buffer <- function(record, patch) {
  checkmate::assert_list(record, names = "unique")
  checkmate::assert_list(patch, names = "unique")
  dependent <- patch[intersect(c("mood", "gesture", "theme", "click"), names(patch))]
  # Only shared mood/gesture vocabularies and character-independent clicks are
  # proved universal. Retain all other data, never just the last invalid guard.
  if (!is.null(dependent$mood) && dependent$mood %in% mood_table()$name) {
    dependent$mood <- NULL
  }
  if (!is.null(dependent$gesture) && dependent$gesture %in% gesture_table()$name) {
    dependent$gesture <- NULL
  }
  if (!is.null(dependent$click) && !any(c("mood", "gesture") %in% names(dependent$click))) {
    dependent$click <- NULL
  }
  if (!is.null(dependent$theme) && all(vapply(dependent$theme, is.null, logical(1)))) {
    dependent$theme <- NULL
  }
  guard <- if (length(dependent)) character_format_identity(dependent) else "free"
  if (is.null(record$cold[[guard]]) && guard != "free" && sum(names(record$cold) != "free") >= 20L) {
    cli::cli_abort("Unresolved character guard capacity (20) exceeded.")
  }
  sequence <- mascot_counter(record$sequence)
  bucket <- record$cold[[guard]]
  if (is.null(bucket)) {
    bucket <- list(calls = list(), owners = list())
  }
  for (field in names(patch)) {
    bucket$owners[[field]] <- sequence
  }
  bucket$calls[[as.character(sequence)]] <- list(sequence = sequence, patch = patch)
  keep <- as.character(unique(unlist(bucket$owners, use.names = FALSE)))
  bucket$calls <- bucket$calls[intersect(names(bucket$calls), keep)]
  record$cold[[guard]] <- bucket
  record$sequence <- sequence
  record
}

#' Settle the bounded retained prefix against one declared startup context
#' @noRd
mascot_state_settle <- function(record, session = NULL) {
  checkmate::assert_list(record, names = "unique")
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"), null.ok = TRUE)
  calls <- unlist(lapply(record$cold, function(bucket) unname(bucket$calls)), recursive = FALSE)
  if (length(calls)) {
    calls <- calls[order(vapply(calls, function(call) call$sequence, numeric(1)))]
    for (call in calls) {
      record <- tryCatch(mascot_state_accept(record, call$patch), error = function(error) {
        warning_id <- if (is.null(session)) record$id else substring(record$id, nchar(session$ns("")) + 1L)
        mascot_update_warning(warning_id, conditionMessage(error))
        if (dev_mode() && !is.null(session)) {
          mascot_problem(session, record$id, paste0("mascot: ", warning_id, ": ", conditionMessage(error)))
        }
        record
      })
    }
  }
  record$cold <- list()
  record
}

#' Schedule one replaceable latest envelope for this id and flush
#' @noRd
mascot_state_schedule <- function(session, key) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(key)
  owner <- mascot_session(session)
  record <- owner$states[[key]]
  if (record$scheduled || !record$live) {
    return(invisible(NULL))
  }
  record$scheduled <- TRUE
  owner$states[[key]] <- record
  session$onFlushed(
    function() {
      if (owner$closed) {
        return(invisible(NULL))
      }
      record <- owner$states[[key]]
      record$scheduled <- FALSE
      if (!record$live) {
        owner$states[[key]] <- record
        return(invisible(NULL))
      }
      # Resolve an accepted action against the final character, including a
      # same-flush character change or an unowned remount baseline.
      if (!is.null(record$pending) && !record$pending$name %in% names(record$context$data$gestures)) {
        mascot_diagnostic(
          "mascot_gesture_dropped",
          paste0(
            "Gesture '",
            record$pending$name,
            "' discarded for mascot '",
            key,
            "': the winning character cannot play it."
          )
        )
        record$gesture_watermark <- max(record$gesture_watermark, record$pending$revision)
        record$pending <- NULL
      }
      state <- record$desired
      # Target-dependent click groups are an internal extension point; the
      # current public helpers expose independent actions/menus only. Keep
      # their availability metadata outside the closed native-click payload.
      click_groups <- state$click[intersect(c("mood", "gesture"), names(state$click))]
      state$click[c("mood", "gesture")] <- NULL
      # Always self-contained: safe after page cache reclamation or lost acks.
      state$character$content_token <- record$context$token
      envelope <- list(
        version = 1L,
        id = key,
        generation = record$generation,
        revision = record$revision,
        state = state,
        gesture = record$pending,
        gesture_watermark = record$gesture_watermark,
        bubble_revision = record$bubble_revision,
        restore = record$restore,
        problem = owner$problems[[key]]
      )
      if (length(click_groups)) {
        envelope$extensions <- list(click_groups = click_groups)
      }
      record$sent <- list(
        revision = record$revision,
        gesture = max(record$gesture_watermark, if (is.null(record$pending)) 0 else record$pending$revision),
        bubble = record$bubble_revision
      )
      record$restore <- FALSE
      owner$states[[key]] <- record
      owner$problem_sent[[key]] <- list(
        generation = record$generation,
        revision = record$revision,
        problem = envelope$problem
      )
      session$sendCustomMessage("mascot:update", envelope)
    },
    once = TRUE
  )
  invisible(NULL)
}

#' Coalesce development overlays separately from accepted state and revisions
#' @noRd
mascot_problem <- function(session, key, text) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(key)
  checkmate::assert_string(text, min.chars = 1)
  owner <- mascot_session(session)
  owner$problems[[key]] <- text
  if (isTRUE(owner$problem_scheduled[[key]])) {
    return(invisible(NULL))
  }
  owner$problem_scheduled[[key]] <- TRUE
  session$onFlushed(
    function() {
      if (owner$closed) {
        return(invisible(NULL))
      }
      owner$problem_scheduled[[key]] <- NULL
      record <- owner$states[[key]]
      problem <- owner$problems[[key]]
      if (!is.null(record) && record$live && !is.null(problem)) {
        # An already scheduled complete state carries this overlay itself.
        diagnostic <- list(generation = record$generation, revision = record$revision, problem = problem)
        if (record$scheduled || identical(owner$problem_sent[[key]], diagnostic)) {
          return(invisible(NULL))
        }
        owner$problem_sent[[key]] <- diagnostic
        session$sendCustomMessage(
          "mascot:update",
          list(
            version = 1L,
            kind = "diagnostic",
            id = key,
            generation = record$generation,
            revision = record$revision,
            problem = problem
          )
        )
      }
    },
    once = TRUE
  )
  invisible(NULL)
}

#' Validate safe counters without accepting fractional or infinite values
#' @noRd
mascot_safe_counter <- function(value) {
  isTRUE(checkmate::check_number(value, lower = 0, upper = 9007199254740991)) && value == floor(value)
}

#' Reconcile a private lifecycle snapshot without trusting browser defaults
#' @noRd
mascot_snapshot <- function(data, session, name) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(name)
  # data is untrusted transport input; malformed values must leave records intact.
  fields <- c(
    "version",
    "generation",
    "mount_token",
    "lifecycle",
    "applied_revision",
    "gesture_watermark",
    "bubble_watermark",
    "dismissed_bubble_revision"
  )
  if (
    !is.list(data) ||
      !setequal(setdiff(names(data), "baseline"), fields) ||
      anyDuplicated(names(data)) ||
      !identical(data$version, 1L) && !identical(data$version, 1) ||
      !all(vapply(
        data[c("generation", "applied_revision", "gesture_watermark", "bubble_watermark", "dismissed_bubble_revision")],
        mascot_safe_counter,
        logical(1)
      )) ||
      data$generation == 0 ||
      !isTRUE(checkmate::check_string(data$mount_token, min.chars = 1)) ||
      !isTRUE(checkmate::check_choice(data$lifecycle, c("ready", "mounted", "unmounted", "reconcile", "error")))
  ) {
    return(data)
  }
  entry <- mascot_mount_lookup(session, name, data$mount_token)
  if (is.null(entry)) {
    # Only content-derived static tokens can cross a render/server process
    # boundary. Dynamic tokens remain strictly session-owned.
    if (data$lifecycle %in% c("ready", "reconcile") && grepl("^t[0-9]+-[0-9]+-[0-9]+x*$", data$mount_token)) {
      entry <- tryCatch(mascot_mount_recover(session, name, data$mount_token, data$baseline), error = function(error) {
        NULL
      })
    }
    if (is.null(entry)) {
      session$sendCustomMessage(
        "mascot:update",
        list(
          version = 1L,
          kind = if (is.null(data$baseline) && startsWith(data$mount_token, "t")) {
            "template-needed"
          } else {
            "template-rejected"
          },
          id = name,
          generation = data$generation,
          revision = 0,
          mount_token = data$mount_token,
          problem = "Mascot UI baseline could not be verified. Rebuild the page with this package version."
        )
      )
      return(data)
    }
  }
  owner <- session$userData$mascot_protocol
  record <- if (is.null(owner)) NULL else owner$states[[name]]
  if (is.null(record)) {
    record <- mascot_state_empty(name)
  }
  if (
    data$generation < record$generation ||
      data$generation == record$generation && (!record$live || !identical(record$mount_token, data$mount_token))
  ) {
    return(data)
  }
  newer <- data$generation > record$generation
  if (newer && !data$lifecycle %in% c("ready", "reconcile", "unmounted")) {
    return(data)
  }
  # Watermarks can survive a lost acknowledgement, but never outrun an issued
  # action/bubble. An unseen generation has not applied any state yet.
  sent <- record$sent
  max_gesture <- if (is.null(sent)) 0 else sent$gesture
  max_bubble <- if (is.null(sent)) 0 else sent$bubble
  if (
    data$applied_revision > (if (newer || is.null(sent)) 0 else sent$revision) ||
      data$gesture_watermark > max_gesture ||
      data$gesture_watermark > record$gesture_watermark && data$gesture_watermark != max_gesture ||
      data$bubble_watermark > max_bubble ||
      data$dismissed_bubble_revision > data$bubble_watermark
  ) {
    return(data)
  }
  if (newer && data$lifecycle == "unmounted") {
    # A merged/lost ready may leave only its terminal notice. Record the dead
    # generation, but an unmount alone never chooses a startup/baseline target.
    record$generation <- data$generation
    record$mount_token <- data$mount_token
    record$live <- FALSE
    record$sent <- NULL
  } else if (newer) {
    baseline <- entry$spec$state
    candidate <- record
    # UI values do not become owned: copy only the unowned groups.
    for (field in setdiff(names(baseline), record$owned)) {
      candidate$desired[field] <- baseline[field]
    }
    if (is.null(candidate$context)) {
      candidate$context <- mascot_state_character(candidate$desired$character)
    }
    prepared <- tryCatch(mascot_state_prepare(candidate, candidate$desired, restore = TRUE), error = function(error) {
      NULL
    })
    if (is.null(prepared)) {
      return(data)
    }
    candidate$desired <- prepared$desired
    candidate$context <- prepared$context
    changed <- !identical(record$baseline_identity, entry$identity)
    if (changed && !"bubble" %in% record$owned) {
      candidate$bubble_serial <- mascot_counter(candidate$bubble_serial)
      candidate$bubble_revision <- candidate$bubble_serial
    }
    if (changed || candidate$revision == 0) {
      candidate$revision <- mascot_counter(candidate$revision)
    }
    candidate$baseline <- baseline
    candidate$baseline_identity <- entry$identity
    candidate$baseline_token <- data$mount_token
    candidate$generation <- data$generation
    candidate$mount_token <- data$mount_token
    candidate$live <- data$lifecycle != "unmounted"
    candidate$sent <- NULL
    candidate$restore <- TRUE
    previous_token <- record$baseline_token
    record <- mascot_state_settle(candidate, session)
    if (isTRUE(entry$recovered)) {
      owner <- mascot_session(session)
      owner$mounts[[data$mount_token]] <- entry
    }
    mascot_mount_retain(session, data$mount_token)
    if (!identical(previous_token, data$mount_token)) mascot_mount_release(session, previous_token)
  }
  record$gesture_watermark <- max(record$gesture_watermark, data$gesture_watermark)
  record$bubble_watermark <- max(record$bubble_watermark, data$bubble_watermark)
  record$dismissed <- max(record$dismissed, data$dismissed_bubble_revision)
  if (!is.null(record$pending) && record$pending$revision <= record$gesture_watermark) {
    record$pending <- NULL
  }
  if (data$lifecycle == "unmounted") {
    record$live <- FALSE
  }
  mascot_id_state(session, name, namespaced = TRUE)
  owner <- mascot_session(session)
  owner$states[[name]] <- record
  # An error is an implementation disagreement, never a resend trigger.
  recover <- is.null(record$sent) || record$sent$revision < record$revision || data$lifecycle == "reconcile"
  behind <- data$applied_revision < record$revision && recover
  if (record$live && data$lifecycle != "error" && (newer || behind)) {
    mascot_state_schedule(session, name)
  }
  data
}

#' Register the private binding type (no files, timers or visitor state on load)
#' @noRd
.onLoad <- function(libname, pkgname) {
  checkmate::assert_string(libname)
  checkmate::assert_string(pkgname)
  shiny::registerInputHandler("mascot.state", mascot_snapshot, force = TRUE)
}

#' Normalise existing public theme forms at the shared boundary
#' @noRd
mascot_update_theme <- function(x, call, character = NULL) {
  checkmate::assert_environment(call)
  character_catalogue_assert(character, nullable = TRUE)
  as_theme_arg(x, call, character)
}

#' Structural preflight independent of an unknown target
#' @noRd
mascot_wire_check <- function(patch) {
  checkmate::assert_list(patch, names = "unique")
  if (length(setdiff(names(patch), mascot_state_fields))) {
    cli::cli_abort("Unknown update field.", class = "mascot_error")
  }
  # Reuse the approved input policy, including its iterative structural walk.
  # Character content has its own checked-file bounds; do not count the
  # additional JSON string escaping of that content as visitor payload.
  limits <- mascot_template_store()$limits
  character_format_bounds(patch, limits$nesting_depth, limits$structural_nodes)
  payload <- patch
  payload$character <- NULL
  if (nchar(character_format_identity(payload), type = "bytes") > limits$utf8_bytes) {
    cli::cli_abort("Update payload exceeds capacity.")
  }
  for (field in intersect(c("mood", "gesture"), names(patch))) {
    checkmate::assert_string(patch[[field]], pattern = "^[a-z][a-z0-9_]*$")
  }
  if (!is.null(patch$status)) {
    checkmate::assert_choice(patch$status$mode, c("mood", "custom"))
    if (patch$status$mode == "custom") checkmate::assert_string(patch$status$text, min.chars = 1)
  }
  if (!is.null(patch$bubble) && !identical(patch$bubble, list(clear = TRUE))) {
    checkmate::assert_names(names(patch$bubble), permutation.of = c("text", "html", "closable", "duration"))
    checkmate::assert_string(patch$bubble$text, min.chars = 1)
    checkmate::assert_flag(patch$bubble$html)
    checkmate::assert_flag(patch$bubble$closable)
    checkmate::assert_number(patch$bubble$duration, lower = .Machine$double.eps, finite = TRUE, null.ok = TRUE)
  }
  if (!is.null(patch$theme)) {
    checkmate::assert_subset(
      names(patch$theme),
      c("light", "dark", "mode", "css", "brand", "palette", "palette_colours")
    )
    if (!is.null(patch$theme$palette)) checkmate::assert_string(patch$theme$palette, pattern = "^[a-z][a-z0-9_]*$")
  }
  invisible(NULL)
}

#' Complete native-colour reset, including explicit JSON nulls
#' @noRd
mascot_empty_theme <- function() {
  list(light = NULL, dark = NULL, mode = NULL, css = NULL, brand = NULL)
}
