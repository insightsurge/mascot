# Private protocol fixtures use real checked format data, never the catalogue
# as a store for visitor state. Character labels stand in for later built-ins.
protocol_character <- function(extra = TRUE, id = "visor_probe") {
  value <- format_recipe()
  value$id <- id
  value$name <- "Alpha Visor"
  if (extra) {
    value$moods$processing <- list(
      description = "Scanning.",
      status = "Scanning",
      fallback = "thinking",
      channels = list()
    )
    value$gestures$spin <- value$gestures$rock
    value$palettes$sea <- list(description = "Sea.", light = list(body = "#123456"), dark = list(body = "#abcdef"))
    value$palette_sources$sea <- "character"
  }
  data <- character_check(value)
  list(id = data$id, name = data$name, json = character_json_write(data))
}

protocol_fixture <- function() {
  session <- shiny::MockShinySession$new()
  messages <- new.env(parent = emptyenv())
  messages$values <- list()
  session$sendCustomMessage <- function(type, message) {
    messages$values[[length(messages$values) + 1L]] <- message
  }
  list(session = session, id = session$ns("helper"), messages = messages)
}

protocol_snapshot <- function(
  token,
  generation = 1,
  lifecycle = "ready",
  applied = 0,
  gesture = 0,
  bubble = 0,
  dismissed = 0
) {
  list(
    version = 1L,
    generation = generation,
    mount_token = token,
    lifecycle = lifecycle,
    applied_revision = applied,
    gesture_watermark = gesture,
    bubble_watermark = bubble,
    dismissed_bubble_revision = dismissed
  )
}

protocol_ready <- function(fixture, generation = 1, state = NULL, token = NULL, ...) {
  if (is.null(token)) {
    if (is.null(state)) {
      state <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    }
    token <- mascot_mount_token(fixture$id, state, fixture$session)
  }
  invisible(mascot_snapshot(protocol_snapshot(token, generation, ...), fixture$session, fixture$id))
  token
}

protocol_record <- function(fixture) fixture$session$userData$mascot_protocol$states[[fixture$id]]
protocol_flush <- function(fixture) {
  fixture$session$flushReact()
  tail(fixture$messages$values, 1)[[1]]
}

install_bubble_clock <- function(js) {
  js(
    "(() => {
    let now = 0, next = 0;
    const timers = new Map();
    window.performance.now = () => now;
    window.setTimeout = (fn, delay) => { const id = ++next; timers.set(id, {fn, due: now + delay}); return id; };
    window.clearTimeout = id => timers.delete(id);
    window.bubbleClock = {
      advance(ms) { now += ms; },
      tick(ms) { now += ms; for (const [id,timer] of [...timers]) if (timer.due <= now) { timers.delete(id); timer.fn(); } },
      count() { return timers.size; }
    };
    return true;
  })()"
  )
}
