# The drawing engine in inst/www/ has no R file of its own: these tests draw with it in headless Chrome.

skip_without_chrome <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("chromote")
  testthat::skip_if_not_installed("withr")
  testthat::skip_if(is.null(chromote::find_chrome()), "no Chrome or Chromium found")
}

# Opens a blank page with the engine's files loaded and returns a function that evaluates JavaScript there.
local_engine_page <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  www <- system.file("www", package = "mascot")
  scripts <- file.path(
    www,
    c(
      "mascot.js",
      "mascot-draw.js",
      "mascot-motion.js",
      "mascot-parts.js",
      "mascot-geometry.js",
      "mascot-faces.js",
      "mascot-tessa-adapter.js"
    )
  )
  tessa <- system.file("characters", "tessa.json", package = "mascot")
  blob <- testthat::test_path("fixtures", "characters", "blob.json")
  page <- file.path(dir, "page.html")
  writeLines(
    c(
      "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>engine</title></head><body>",
      "<script type=\"application/json\" data-mascot-character=\"tessa\">",
      readLines(tessa, encoding = "UTF-8"),
      "</script>",
      "<script type=\"application/json\" data-mascot-character=\"blob\">",
      readLines(blob, encoding = "UTF-8"),
      "</script>",
      unlist(lapply(c("classic", "screen"), function(id) {
        c(
          sprintf('<script type="application/json" data-mascot-kit="%s">', id),
          readLines(system.file("format", "kits", paste0(id, ".json"), package = "mascot")),
          "</script>"
        )
      })),
      sprintf("<script src=\"file://%s\"></script>", normalizePath(scripts, winslash = "/")),
      "</body></html>"
    ),
    page
  )
  session <- chromote::ChromoteSession$new(parent = test_browser())
  withr::defer(session$close(), envir = env)
  loaded <- session$Page$loadEventFired(wait_ = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(page, winslash = "/")), wait_ = FALSE)
  session$wait_for(loaded)
  function(js) session$Runtime$evaluate(js, returnByValue = TRUE)$result$value
}

# Draws a character from the page on a new canvas and returns the picture as a PNG data URL.
draw_js <- function(pose, frame = 0, character = "tessa") {
  sprintf(
    paste(
      "(() => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "window.mascot.draw(c.getContext('2d'), window.mascot.readCharacter('%s'), { x: 150, baseY: 280, pose: %s, frame: %d });",
      "return c.toDataURL(); })()"
    ),
    character,
    pose,
    frame
  )
}

# Runs `code` in the page and returns the message of the error it throws (or "no error").
error_js <- function(code) {
  sprintf(
    "(() => { const ch = window.mascot.readCharacter('tessa'); try { %s; } catch (e) { return e.message; } return 'no error'; })()",
    code
  )
}

# Host integration page: real packaged assets and real markup, with motion reduced before navigation.
local_host_page <- function(
  env = parent.frame(),
  bubble = NULL,
  reduced = TRUE,
  scheme = "light",
  size = 160,
  placement = "inline",
  viewport = NULL,
  density = 1,
  theme = NULL,
  record_colours = FALSE,
  motion = TRUE,
  click = NULL,
  shiny_menu = FALSE
) {
  dir <- withr::local_tempdir(.local_envir = env)
  www <- system.file("www", package = "mascot")
  all_scripts <- mascot_dependency()$script
  pre_host <- file.path(www, all_scripts[all_scripts != "mascot-host.js"])
  host_script <- file.path(www, "mascot-host.js")
  page <- file.path(dir, "host.html")
  tessa_format_v1 <- paste(
    readLines(system.file("format", "characters", "tessa.json", package = "mascot"), encoding = "UTF-8"),
    collapse = "\n"
  )
  blob_v1 <- sub(
    '"name": "Tessa"',
    '"name": "Blob"',
    sub('"id": "tessa"', '"id": "blob"', tessa_format_v1, fixed = TRUE),
    fixed = TRUE
  )
  blob_v1 <- sub('    "rim": "#d9b35c",\n', "", blob_v1, fixed = TRUE)
  blob_v1 <- gsub('"rim"', '"body"', blob_v1, fixed = TRUE)
  writeLines(
    c(
      '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>host</title>',
      sprintf('<link rel="stylesheet" href="file://%s">', normalizePath(file.path(www, "mascot.css"))),
      '</head><body>',
      as.character(mascot(
        id = "a",
        bubble = bubble,
        size = size,
        placement = placement,
        theme = theme,
        motion = motion,
        click = click
      )),
      '<script type="application/json" data-mascot-character="blob">',
      blob_v1,
      '</script>',
      sprintf('<script src="file://%s"></script>', normalizePath(pre_host)),
      if (record_colours) {
        paste0(
          '<script>window.themeDraws=[];const originalDraw=mascot.draw;',
          'mascot.draw=function(ctx,ch,options){themeDraws.push({character:ch.id,',
          'colours:{...ch.colours,...options.colours},overrides:{...options.colours}});',
          'return originalDraw(ctx,ch,options);};',
          'if (mascot.geometry) { const origGeo = mascot.geometry.draw;',
          'mascot.geometry = { ...mascot.geometry, draw: function(ctx, compiled, state, colours, options) {',
          'if (compiled?.source?.parts?.[0]?.id !== "ground_shadow" && colours?.body) {',
          'const overrides = { ...(options?.overrides ?? {}) };',
          'const coloursWithAliases = { ...colours, bodyHighlight: colours.body_highlight, blushStrong: colours.blush_strong, accessoryDetail: colours.accessory_detail, sparkleOutline: colours.sparkle_outline, eyeWhite: colours.eye_white };',
          'themeDraws.push({character: compiled?.source?.id || "tessa", colours: coloursWithAliases, overrides: overrides});',
          '} return origGeo(ctx, compiled, state, colours, options); } }; }',
          '</script>'
        )
      },
      if (shiny_menu) {
        '<script>window.menuEvents=[];window.Shiny={setInputValue:(...args)=>menuEvents.push(args)};</script>'
      },
      sprintf('<script src="file://%s"></script>', normalizePath(host_script)),
      '</body></html>'
    ),
    page
  )
  session <- chromote::ChromoteSession$new(parent = test_browser())
  withr::defer(session$close(), envir = env)
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
      deviceScaleFactor = density,
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

# Start shinytest2 with its temporary browser files inside R's temporary directory.
local_shiny_browser <- function(env = parent.frame()) {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("shinytest2")
  testthat::skip_if_not_installed("chromote")
  testthat::skip_if_not_installed("withr")
  testthat::skip_if(is.null(chromote::find_chrome()), "no Chrome or Chromium found")
  tmp <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(c(TMPDIR = tmp), .local_envir = env)
}

# Read layout after both style resolution and ResizeObserver delivery.
host_layout <- function(js, code) {
  js(paste0(
    "(async () => { await new Promise(resolve => requestAnimationFrame(() => ",
    "requestAnimationFrame(resolve))); ",
    code,
    " })()"
  ))
}

# Real host and canvas, with a deterministic frame queue around one remount.
host_motion_js <- function(code) {
  paste0(
    "(() => {const el=document.getElementById('a');mascot.host.unmount(el);
",
    "const mount=mascot.mount,draw=mascot.draw,origGeo=mascot.geometry?.draw,raf=window.requestAnimationFrame,cancel=window.cancelAnimationFrame;
",
    "const queued=new Map(),calls=[],players=[];let id=0;
",
    "window.requestAnimationFrame=fn=>{queued.set(++id,fn);return id;};window.cancelAnimationFrame=n=>queued.delete(n);
",
    "mascot.draw=(ctx,ch,options)=>{calls.push({character:ch.id,...options});return draw(ctx,ch,options);};
",
    "if (mascot.geometry) { mascot.geometry = { ...mascot.geometry, draw: (ctx, compiled, state, colours, options) => {
      const p = players[players.length - 1];
      const cur = p?.current?.();
      const chId = compiled?.source?.id || cur?.character || 'tessa';
      if (compiled?.source?.parts?.[0]?.id !== 'ground_shadow') {
        const poseObj = p?._lastPose || {};
        const pose = {
          ...poseObj,
          look: poseObj['face.look_x'] !== undefined && poseObj['face.look_x'] !== null ? poseObj['face.look_x'] : (poseObj.look !== undefined ? poseObj.look : undefined),
          lookY: poseObj['face.look_y'] !== undefined && poseObj['face.look_y'] !== null ? poseObj['face.look_y'] : (poseObj.lookY !== undefined ? poseObj.lookY : undefined)
        };
        calls.push({ character: chId, frame: options?.frame ?? 0, pose, colours: { ...colours } });
      }
      return origGeo(ctx, compiled, state, colours, options);
    } }; }
",
    "mascot.mount=(...args)=>{
      const p=mount(...args);
      players.push(p);
      p._lastPose = {};
      const origUp = p.update;
      if (origUp) {
        p.update = (patch) => {
          if (patch?.pose) {
            p._lastPose = { ...patch.pose };
            const pose = {
              ...patch.pose,
              look: patch.pose['face.look_x'] !== undefined && patch.pose['face.look_x'] !== null ? patch.pose['face.look_x'] : undefined,
              lookY: patch.pose['face.look_y'] !== undefined && patch.pose['face.look_y'] !== null ? patch.pose['face.look_y'] : undefined
            };
            calls.push({ character: p.current()?.character || 'tessa', frame: 0, pose, colours: {} });
          }
          return origUp.call(p, patch);
        };
      }
      return p;
    };
",
    "const send=patch=>mascot.host.receive({id:'a',patch}),state=()=>mascot.host.state(el);
",
    "const fire=t=>{const batch=[...queued.values()];queued.clear();batch.forEach(fn=>fn(t));};
",
    "try{mascot.host.mount(el);const controller=players[0];",
    code,
    "}finally{mascot.host.unmount(el);mascot.mount=mount;mascot.draw=draw;if (origGeo) mascot.geometry = { ...mascot.geometry, draw: origGeo };window.requestAnimationFrame=raf;window.cancelAnimationFrame=cancel;}})()"
  )
}


# Source help during development; installed Rd database in coverage and R CMD check.
local_help_page <- function(topic) {
  checkmate::assert_string(topic)
  name <- paste0(topic, ".Rd")
  path <- testthat::test_path("..", "..", "man", name)
  if (file.exists(path)) tools::parse_Rd(path) else tools::Rd_db("mascot")[[name]]
}
