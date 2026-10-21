# Format-v1 characters mounted through the real host. Custom checked data stays internal: mascot() and update_mascot()
# take a `mascot_character` list that carries its own `json` (the route U1's tests use), never the checked data itself.

# The character helper object for checked data.
runtime_character <- function(data = catalogue_alpha_two()) {
  checkmate::assert_class(data, "mascot_character_data")
  structure(list(id = data$id, name = data$name, json = character_json_write(data)), class = "mascot_character")
}

# A checked copy of a fixture recipe (Alpha Visor, whose screen kit has no pupils, or `base = "tessa"`, whose classic
# kit has them) under another id, edited by `edit` (a function of the recipe list).
runtime_data <- function(id = "alpha_two", name = "Alpha Two", edit = identity, base = "alpha_visor") {
  checkmate::assert_string(id)
  checkmate::assert_string(name)
  checkmate::assert_function(edit)
  checkmate::assert_string(base)
  recipe <- format_recipe(base)
  recipe$id <- id
  recipe$name <- name
  character_format_check(edit(recipe))
}

# A second face character that lacks the "processing" mood, so a swap needs the fallback chain, and words its own
# statuses so a test can tell which character's status is on show.
runtime_other <- function(id = "alpha_three", name = "Alpha Three") {
  runtime_data(id, name, function(recipe) {
    recipe$moods$processing <- NULL
    recipe$moods$idle$status <- "Standing by"
    recipe$moods$thinking$status <- "Pondering"
    recipe
  })
}

# The faceless reference character (no gaze, no face kit, no ground shadow).
runtime_faceless <- function() {
  wire <- protocol_character()
  structure(list(id = wire$id, name = wire$name, json = wire$json), class = "mascot_character")
}

# A page with the packaged engine files in the dependency's order and one real mascot() tag per entry of `tags`.
# `characters` become window.CHARACTERS (id -> { id, name, json }), the form a swap patch takes. `before_mount` runs
# after the host script and before the host mounts, so spies see the first draw. Returns a function that evaluates
# JavaScript (promises awaited); the Chrome session is attribute "session".
local_runtime_page <- function(
  tags = list(mascot("a", character = runtime_character(), motion = FALSE, placement = "inline")),
  characters = list(),
  reduced = TRUE,
  scheme = "light",
  viewport = NULL,
  before_mount = NULL,
  shiny_stub = FALSE,
  env = parent.frame()
) {
  checkmate::assert_list(tags)
  checkmate::assert_list(characters)
  checkmate::assert_flag(reduced)
  checkmate::assert_choice(scheme, c("light", "dark"))
  checkmate::assert_string(before_mount, null.ok = TRUE)
  checkmate::assert_flag(shiny_stub)
  skip_without_chrome()
  dir <- withr::local_tempdir(.local_envir = env)
  www <- system.file("www", package = "mascot", mustWork = TRUE)
  scripts <- file.path(www, mascot_dependency()$script)
  wires <- lapply(characters, function(x) list(id = x$id, name = x$name, json = x$json))
  names(wires) <- vapply(characters, function(x) x$id, character(1))
  page <- file.path(dir, "runtime.html")
  writeLines(
    c(
      '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>runtime</title>',
      sprintf('<link rel="stylesheet" href="file://%s">', normalizePath(file.path(www, "mascot.css"))),
      "</head><body>",
      vapply(tags, as.character, character(1)),
      sprintf("<script>window.CHARACTERS=%s;</script>", jsonlite::toJSON(wires, auto_unbox = TRUE)),
      if (shiny_stub) "<script>window.menuEvents=[];window.Shiny={setInputValue:(...a)=>menuEvents.push(a)};</script>",
      sprintf('<script src="file://%s"></script>', normalizePath(scripts)),
      if (!is.null(before_mount)) sprintf("<script>%s</script>", before_mount),
      "</body></html>"
    ),
    page
  )
  session <- local_chrome_session(env)
  session$Emulation$setEmulatedMedia(
    features = list(
      list(name = "prefers-reduced-motion", value = if (reduced) "reduce" else "no-preference"),
      list(name = "prefers-color-scheme", value = scheme)
    )
  )
  if (!is.null(viewport)) {
    session$Emulation$setDeviceMetricsOverride(
      width = viewport[[1]],
      height = viewport[[2]],
      deviceScaleFactor = 1,
      mobile = FALSE
    )
  }
  loaded <- session$Page$loadEventFired(wait_ = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(page)), wait_ = FALSE)
  session$wait_for(loaded)
  evaluate <- function(js) {
    result <- session$Runtime$evaluate(js, returnByValue = TRUE, awaitPromise = TRUE)
    if (!is.null(result$exceptionDetails)) {
      stop(result$exceptionDetails$exception$description)
    }
    result$result$value
  }
  attr(evaluate, "session") <- session
  evaluate
}

# JavaScript helpers for deterministic player tests, installed once per page: a standalone canvas and paused
# controller whose frames are drawn by seek(), and a pixel summary that distinguishes pictures.
install_runtime_helpers <- function(js) {
  js(
    r"(
    window.T = {
      canvas(size = 300) {
        const c = document.createElement('canvas');
        c.width = c.height = size;
        c.getContext('2d').setTransform(size / 300, 0, 0, size / 300, 0, 0);
        document.body.append(c);
        return c;
      },
      // A paused controller: frames are drawn only where the test seeks.
      loaded: {},
      load(id) { return T.loaded[id] ??= JSON.parse(CHARACTERS[id].json); },
      player(name, options = {}, size = 300) {
        const character = T.load(name);
        const canvas = T.canvas(size);
        const events = [];
        const controller = mascot.mount(canvas, character, {
          x: 150, baseY: 270, reduced: false, onChange: (s) => events.push(s), ...options
        });
        controller.pause();
        return { character, canvas, controller, events };
      },
      // Number of painted pixels and a cheap checksum of the canvas.
      picture(canvas) {
        const data = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
        let ink = 0, sum = 0;
        for (let i = 0; i < data.length; i += 4) {
          if (data[i + 3]) ink++;
          sum = (sum * 31 + data[i] + 3 * data[i + 1] + 7 * data[i + 2] + 13 * data[i + 3]) % 1000000007;
        }
        return { ink, sum };
      },
      // The largest alpha value on the canvas: the opacity of a composited swap frame, times 255.
      maxAlpha(canvas) {
        const data = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
        let top = 0;
        for (let i = 3; i < data.length; i += 4) top = Math.max(top, data[i]);
        return top;
      },
      pixel(canvas, x, y) { return [...canvas.getContext('2d').getImageData(x, y, 1, 1).data]; },
      frames: async (n = 2) => { for (let i = 0; i < n; i++) await new Promise(requestAnimationFrame); }
    };
    true
  )"
  )
  invisible(js)
}

# Hands characters to an app that shinytest2 starts in another R process: it reads them from the file named by
# MASCOT_I1_CHARACTERS (a list of `mascot_character` objects), because test helpers do not exist there.
local_app_characters <- function(characters, env = parent.frame()) {
  checkmate::assert_list(characters, names = "unique")
  file <- withr::local_tempfile(fileext = ".rds", .local_envir = env)
  saveRDS(characters, file)
  withr::local_envvar(c(MASCOT_I1_CHARACTERS = file), .local_envir = env)
  invisible(file)
}

# What a character says for each mood, read from its own checked data: the expectation a browser must agree with.
runtime_statuses <- function(character) {
  checkmate::assert_class(character, "mascot_character")
  data <- jsonlite::fromJSON(character$json, simplifyVector = FALSE)
  list(
    name = character$name,
    statuses = lapply(data$moods, function(mood) mood$status)
  )
}
