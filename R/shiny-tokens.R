# Private protocol resources are separate from the character catalogue. Nothing
# here stores visitor state outside its session; static templates are read-only.
mascot_templates <- new.env(parent = emptyenv())
# Section 3.16: bound templates are pinned; only unbound templates count here.
mascot_unbound_template_limit <- 128L
# Small immutable content caches; neither grows with session/update history.
mascot_character_cache_limit <- 16L

#' Allocate a finite, connection-safe identifier
#' @noRd
mascot_counter <- function(value) {
  checkmate::assert_number(value, lower = 0, upper = 9007199254740990)
  if (value != floor(value)) {
    cli::cli_abort("Counter must be a safe integer.", class = "mascot_error")
  }
  value + 1
}

#' Lazily initialise the read-only template cache
#' @noRd
mascot_template_store <- function() {
  if (is.null(mascot_templates$items)) {
    mascot_templates$items <- list()
    mascot_templates$serial <- 0
    mascot_templates$tick <- 0
    mascot_templates$limits <- character_format_policy()$input
    mascot_templates$characters <- list()
    mascot_templates$keys <- list()
  }
  mascot_templates
}

#' Evict least recently used unbound specifications
#' @noRd
mascot_template_trim <- function() {
  store <- mascot_template_store()
  free <- names(store$items)[vapply(store$items, function(x) x$refs == 0, logical(1))]
  if (length(free) > mascot_unbound_template_limit) {
    order <- order(vapply(store$items[free], function(x) x$used, numeric(1)))
    removed <- free[order[seq_len(length(free) - mascot_unbound_template_limit)]]
    store$items[removed] <- NULL
    mascot_diagnostic("mascot_template_evicted", "Unbound mascot UI templates evicted from the cache.")
  }
  invisible(NULL)
}

#' Session-local state and resource ownership, including module proxies
#' @noRd
mascot_session <- function(session) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  if (is.null(session$userData$mascot_protocol)) {
    owner <- new.env(parent = emptyenv())
    owner$states <- new.env(parent = emptyenv())
    owner$mounts <- list()
    owner$problems <- list()
    owner$problem_scheduled <- list()
    owner$problem_sent <- list()
    owner$templates <- character()
    owner$serial <- 0
    owner$closed <- FALSE
    session$userData$mascot_protocol <- owner
    # Keep the old inspection name, but no issued-patch journal.
    session$userData$mascot_updates <- owner$states
    session$onSessionEnded(function() {
      owner$closed <- TRUE
      store <- mascot_template_store()
      for (token in owner$templates) {
        store$items[[token]]$refs <- store$items[[token]]$refs - 1
      }
      owner$templates <- character()
      owner$mounts <- list()
      owner$problems <- list()
      owner$problem_scheduled <- list()
      owner$problem_sent <- list()
      rm(list = ls(owner$states, all.names = TRUE), envir = owner$states)
      session$userData$mascot_protocol <- NULL
      session$userData$mascot_updates <- NULL
      mascot_template_trim()
    })
  }
  session$userData$mascot_protocol
}

#' Emit a specification without establishing an id's known target
#' @noRd
mascot_mount_token <- function(id, state, session = shiny::getDefaultReactiveDomain()) {
  checkmate::assert_string(id, min.chars = 1)
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"), null.ok = TRUE)
  spec <- list(id = id, state = state)
  canonical <- spec
  canonical$state$character$json <- mascot_state_character(state$character)$source
  identity <- character_format_identity(canonical)
  store <- mascot_template_store()
  if (is.null(session)) {
    for (token in names(store$items)) {
      if (identical(store$items[[token]]$identity, identity)) {
        store$tick <- mascot_counter(store$tick)
        store$items[[token]]$used <- store$tick
        return(token)
      }
    }
    store$serial <- mascot_counter(store$serial)
    store$tick <- mascot_counter(store$tick)
    # Content-derived identifiers are deterministic, not credentials. Compare
    # full canonical identities above; disambiguate any checksum collision.
    token <- paste0("t", mascot_template_key(identity))
    while (!is.null(store$items[[token]])) {
      token <- paste0(token, "x")
    }
    store$items[[token]] <- list(spec = spec, identity = identity, refs = 0, used = store$tick)
    mascot_template_trim()
    return(token)
  }
  owner <- mascot_session(session)
  record <- mascot_id_state(session, id, namespaced = TRUE)
  if (
    !is.null(record$context) &&
      identical(record$context$wire$id, state$character$id) &&
      !identical(record$context$identity, mascot_state_character(state$character)$identity)
  ) {
    cli::cli_abort("Same character id has different checked content.", class = "mascot_error")
  }
  for (token in names(owner$mounts)) {
    if (identical(owner$mounts[[token]]$identity, identity)) return(token)
  }
  # A dynamic id retains only its latest issued specification and live baseline.
  # An obsolete, never-mounted specification is not a process history.
  for (token in names(owner$mounts)) {
    if (identical(owner$mounts[[token]]$spec$id, id) && !identical(token, record$mount_token)) {
      owner$mounts[[token]] <- NULL
    }
  }
  store$serial <- mascot_counter(store$serial)
  token <- paste0("d", store$serial)
  owner$mounts[[token]] <- list(spec = spec, identity = identity)
  token
}

#' Look up only a specification issued for this binding and session
#' @noRd
mascot_mount_lookup <- function(session, id, token) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(id, min.chars = 1)
  checkmate::assert_string(token, min.chars = 1)
  owner <- session$userData$mascot_protocol
  entry <- if (is.null(owner)) NULL else owner$mounts[[token]]
  if (is.null(entry)) {
    entry <- mascot_template_store()$items[[token]]
  }
  if (is.null(entry) || !identical(entry$spec$id, id)) {
    return(NULL)
  }
  entry
}

#' Pin a validated static template until the session disconnects
#' @noRd
mascot_mount_retain <- function(session, token) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(token, min.chars = 1)
  owner <- mascot_session(session)
  store <- mascot_template_store()
  if (!is.null(store$items[[token]]) && !token %in% owner$templates) {
    owner$templates <- c(owner$templates, token)
    store$items[[token]]$refs <- store$items[[token]]$refs + 1
  }
  invisible(NULL)
}

#' Deterministic data-only template key (full identities still decide equality)
#' @noRd
mascot_template_key <- function(identity) {
  checkmate::assert_string(identity)
  store <- mascot_template_store()
  for (entry in store$keys) {
    if (identical(entry$identity, identity)) return(entry$key)
  }
  bytes <- as.integer(charToRaw(identity))
  left <- right <- 0
  for (byte in bytes) {
    left <- (left * 31 + byte) %% 2147483647
    right <- (right * 131 + byte) %% 2147483629
  }
  key <- paste0(
    format(left, scientific = FALSE, trim = TRUE),
    "-",
    format(right, scientific = FALSE, trim = TRUE),
    "-",
    length(bytes)
  )
  store$keys <- utils::tail(c(store$keys, list(list(identity = identity, key = key))), mascot_character_cache_limit)
  key
}

#' Release a superseded baseline; the new descriptor already owns its values
#' @noRd
mascot_mount_release <- function(session, token) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(token, null.ok = TRUE)
  if (is.null(token)) {
    return(invisible(NULL))
  }
  owner <- mascot_session(session)
  owner$mounts[[token]] <- NULL
  if (token %in% owner$templates) {
    owner$templates <- setdiff(owner$templates, token)
    store <- mascot_template_store()
    store$items[[token]]$refs <- store$items[[token]]$refs - 1
    mascot_template_trim()
  }
  invisible(NULL)
}

#' Preserve original UI defaults for a cross-process static-template handshake
#' @noRd
mascot_baseline_tag <- function(state, token) {
  checkmate::assert_list(state, names = "unique")
  checkmate::assert_string(token)
  if (!startsWith(token, "t")) {
    return(NULL)
  }
  # Character JSON already has its own inert script; send it only on recovery.
  state$character$json <- NULL
  text <- jsonlite::toJSON(state, auto_unbox = TRUE, null = "null", digits = NA)
  htmltools::tags$script(
    type = "application/json",
    `data-mascot-baseline` = "",
    htmltools::HTML(gsub("</", "<\\/", text, fixed = TRUE))
  )
}

#' Check an unknown static template without allocating visitor state
#' @noRd
mascot_mount_recover <- function(session, id, token, baseline) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(id, min.chars = 1)
  checkmate::assert_string(token, min.chars = 1)
  checkmate::assert_list(baseline, names = "unique")
  checkmate::assert_names(names(baseline), permutation.of = setdiff(mascot_state_fields, "gesture"))
  mascot_baseline_check(baseline)
  prepared <- mascot_state_prepare(list(desired = list(), context = NULL), baseline)
  spec <- list(id = id, state = prepared$desired)
  canonical <- spec
  canonical$state$character$json <- prepared$context$source
  identity <- character_format_identity(canonical)
  # Checksums identify content, not authority. Collision suffixes are allocated
  # locally; the complete checked identity remains the equality criterion.
  expected <- paste0("t", mascot_template_key(identity))
  if (!identical(sub("x+$", "", token), expected)) {
    cli::cli_abort("UI baseline and mount token disagree.", class = "mascot_error")
  }
  list(spec = spec, identity = identity, recovered = TRUE)
}

#' Validate untrusted native UI fields with the same helper checks as mascot()
#' @noRd
mascot_baseline_check <- function(state) {
  checkmate::assert_list(state, names = "unique")
  mascot_wire_check(state)
  context <- mascot_state_character(state$character)
  checkmate::assert_names(
    names(state$status),
    permutation.of = if (state$status$mode == "mood") "mode" else c("mode", "text")
  )
  if (isTRUE(state$bubble$clear)) {
    checkmate::assert_names(names(state$bubble), permutation.of = "clear")
  }
  problem <- size_problem(structure(state$size, class = "mascot_size"))
  if (!is.null(problem)) {
    cli::cli_abort("{problem}", class = "mascot_error")
  }
  p <- state$placement
  checkmate::assert_list(p, names = "unique")
  checkmate::assert_names(names(p), permutation.of = c("floating", "position", "minimise", "drag"))
  checkmate::assert_flag(p$floating)
  checkmate::assert_flag(p$minimise)
  checkmate::assert_choice(p$position, c("bottom-right", "top-left", "top-right", "bottom-left"))
  checkmate::assert_true(identical(p$drag, FALSE) || p$drag %in% c("snap", "free"))
  checkmate::assert_true(p$floating || (p$position == "bottom-right" && !p$minimise && identical(p$drag, FALSE)))
  m <- state$motion
  checkmate::assert_list(m, names = "unique")
  checkmate::assert_names(names(m), permutation.of = names(as_motion_arg(TRUE, environment())))
  checkmate::assert_true(is.null(m$reduced) || identical(m$reduced, TRUE))
  for (field in setdiff(names(m), c("reduced", "messages"))) {
    checkmate::assert_flag(m[[field]])
  }
  checkmate::assert_list(m$messages, names = "unnamed")
  for (message in m$messages) {
    checkmate::assert_string(message)
  }
  checkmate::assert_subset(unlist(m$messages), c("bubble", "tooltip", "menu"))
  checkmate::assert_character(unlist(m$messages), any.missing = FALSE, unique = TRUE, null.ok = TRUE)
  click <- state$click
  checkmate::assert_list(click, names = "unique")
  checkmate::assert_choice(click$type, c("none", "action", "menu"))
  checked <- switch(
    click$type,
    none = list(type = "none"),
    action = click_wire(mascot_action(click$label, tooltip = click$tooltip, disabled = click$disabled)),
    menu = click_wire(mascot_popup_menu(
      unlist(click$items),
      direction = click$direction,
      label = click$label,
      tooltip = click$tooltip
    ))
  )
  checkmate::assert_true(identical(character_format_identity(click), character_format_identity(checked)))
  theme <- state$theme
  checkmate::assert_list(theme, names = "unique")
  checkmate::assert_subset(names(mascot_empty_theme()), names(theme))
  checkmate::assert_subset(names(theme), c(names(mascot_empty_theme()), "palette", "palette_colours"))
  if (!is.null(theme$palette)) {
    problem <- theme_palette_problem(theme$palette, context$data)
    if (!is.null(problem)) {
      cli::cli_abort("{problem}", class = "mascot_error")
    }
    checkmate::assert_true(is.null(theme$brand))
    checkmate::assert_true(identical(theme$palette_colours, theme_palette_colours(theme$palette, context$data)))
  } else {
    checkmate::assert_true(is.null(theme$palette_colours))
  }
  checkmate::assert_choice(theme$mode, c("auto", "light", "dark"), null.ok = TRUE)
  for (field in c("light", "dark", "css")) {
    map <- theme[[field]]
    if (!is.null(map)) {
      checkmate::assert_list(map, names = "unique", min.len = 1)
      if (field != "css") {
        for (role in names(map)) {
          checkmate::assert_string(map[[role]])
          checkmate::assert_true(identical(map[[role]], theme_colour(map[[role]], role)))
        }
      }
      names(map) <- colour_role_names(names(map))
    }
    problem <- theme_map_problem(map, field, colour_role_names(context$roles), field == "css")
    if (!is.null(problem)) cli::cli_abort("{problem}", class = "mascot_error")
  }
  if (!is.null(theme$brand)) {
    checkmate::assert_list(theme$brand, names = "unique")
    checkmate::assert_names(names(theme$brand), permutation.of = c("primary", "secondary"))
    for (field in names(theme$brand)) {
      checkmate::assert_string(theme$brand[[field]])
      checkmate::assert_true(identical(theme$brand[[field]], theme_colour(theme$brand[[field]], field)))
    }
  }
  invisible(NULL)
}
