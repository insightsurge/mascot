# Throwaway diagnostics for the CI repro branch: prints facts about the runner's Chrome. Never merged.

probe_print <- function(label, value) {
  message("PROBE ", label, ": ", jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", digits = NA))
}

probe_env_js <- "(() => {
  const mq = (q) => matchMedia(q).matches;
  const d = document.createElement('div');
  d.style.cssText = 'position:absolute;top:-999px;width:100px;height:100px;overflow:scroll';
  document.body.append(d);
  const scrollbar = d.offsetWidth - d.clientWidth;
  d.remove();
  return {
    ua: navigator.userAgent, dpr: devicePixelRatio, inner: [innerWidth, innerHeight],
    client: [document.documentElement.clientWidth, document.documentElement.clientHeight],
    screen: [screen.width, screen.height], maxTouchPoints: navigator.maxTouchPoints,
    hover_hover: mq('(hover: hover)'), hover_none: mq('(hover: none)'),
    pointer_fine: mq('(pointer: fine)'), pointer_coarse: mq('(pointer: coarse)'), pointer_none: mq('(pointer: none)'),
    any_hover: mq('(any-hover: hover)'), any_pointer_fine: mq('(any-pointer: fine)'),
    reduced_motion: mq('(prefers-reduced-motion: reduce)'), dark: mq('(prefers-color-scheme: dark)'),
    scrollbar, body_font: getComputedStyle(document.body).fontFamily
  };
})()"

probe_raf_js <- "new Promise((resolve) => { const t = []; const f = (ts) => { t.push(ts); if (t.length < 61) requestAnimationFrame(f); else { const d = t.slice(1).map((x, i) => Math.round((x - t[i]) * 10) / 10); resolve({ deltas: d, max: Math.max(...d), over66: d.filter((x) => x > 66.7).length }); } }; requestAnimationFrame(f); })"

describe("CI probe", {
  it("prints the runner's Chrome environment in the studio at 1280 x 720", {
    local_shiny_browser()
    skip_without_studio_packages("studio")
    app_path <- normalizePath(system.file("examples", "studio", package = "mascot", mustWork = TRUE))
    fn <- function() NULL
    body(fn) <- substitute({ library(mascot); shiny::shinyAppDir(PATH) }, list(PATH = app_path))
    app <- app_driver(fn, width = 1280, height = 720)
    wait_studio_js(app, "live.dataset.shownMood === 'idle'", timeout = 90000)
    probe_print("chrome", app$get_chromote_session()$Browser$getVersion()$product)
    probe_print("studio env", app$get_js(probe_env_js))
    probe_print("studio raf", app$get_js(probe_raf_js))
    probe_print("frame env", app$get_js(paste0(
      "(() => { const w = document.getElementById('live_frame').contentWindow; return {inner: [w.innerWidth, w.innerHeight], client: [w.document.documentElement.clientWidth, w.document.documentElement.clientHeight], hover_hover: w.matchMedia('(hover: hover)').matches, pointer_fine: w.matchMedia('(pointer: fine)').matches}; })()"
    )))
    # The function-title tooltip: its pointer-events with focus.
    app$run_js("document.getElementById('character').focus()")
    probe_print("tooltip on focus", app$get_js(
      "(() => { const s = getComputedStyle(document.getElementById('character_tooltip')); return [s.visibility, s.pointerEvents]; })()"
    ))
    app$run_js("document.activeElement.blur()")
    rect <- app$get_js(
      "(() => {const r=document.getElementById('character').getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2};})()"
    )
    browser <- app$get_chromote_session()
    browser$Input$dispatchMouseEvent(type = "mouseMoved", x = rect$x, y = rect$y)
    Sys.sleep(1)
    probe_print("tooltip on hover", app$get_js(
      "(() => { const s = getComputedStyle(document.getElementById('character_tooltip')); return [s.visibility, s.pointerEvents, document.querySelector('.pg-sentence-word:hover') !== null]; })()"
    ))
    # The same hover with a mouse-like device emulated.
    browser$Emulation$setEmulatedMedia(features = list(list(name = "hover", value = "hover"), list(name = "pointer", value = "fine")))
    browser$Input$dispatchMouseEvent(type = "mouseMoved", x = 0, y = 0)
    browser$Input$dispatchMouseEvent(type = "mouseMoved", x = rect$x, y = rect$y)
    Sys.sleep(1)
    probe_print("tooltip on hover, hover emulated", app$get_js(
      "(() => { const s = getComputedStyle(document.getElementById('character_tooltip')); return [s.visibility, s.pointerEvents, matchMedia('(hover: hover)').matches]; })()"
    ))
    succeed()
  })

  it("prints the snap drop in the studio", {
    local_shiny_browser()
    skip_without_studio_packages("studio")
    app_path <- normalizePath(system.file("examples", "studio", package = "mascot", mustWork = TRUE))
    fn <- function() NULL
    body(fn) <- substitute({ library(mascot); shiny::shinyAppDir(PATH) }, list(PATH = app_path))
    app <- app_driver(fn, width = 1280, height = 720)
    wait_studio_js(app, "live.dataset.shownMood === 'idle'", timeout = 90000)
    frame <- "document.getElementById('live_frame').contentWindow"
    live <- paste0(frame, ".document.getElementById('helper')")
    app$click(selector = "#all_functions")
    app$click(selector = '.pg-index-link[data-value="mascot_placement"]')
    app$wait_for_js("document.getElementById('drag')")
    app$set_inputs(position = "bottom-right")
    app$wait_for_js(sprintf("%s.mascot.host.state(%s).placement.floating", frame, live))
    app$set_inputs(drag = "snap")
    app$wait_for_js(sprintf("%s.mascot.host.state(%s).placement.drag === 'snap'", frame, live))
    probe_print("before drop", app$get_js(sprintf(
      "(() => { const w = %s, el = %s, c = el.querySelector('canvas'), r = c.getBoundingClientRect(), a = el.querySelector('.mascot-actions'); return {inner: [w.innerWidth, w.innerHeight], client: [w.document.documentElement.clientWidth, w.document.documentElement.clientHeight], canvas: [r.left, r.top, r.width, r.height], el: el.getBoundingClientRect(), actions: a ? [getComputedStyle(a).opacity, getComputedStyle(a).pointerEvents, a.getBoundingClientRect()] : null, hit: (() => { const h = w.document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2); return h ? h.className || h.tagName : null; })(), placement: w.mascot.host.state(el).placement}; })()",
      frame, live
    )))
    app$run_js(sprintf(
      "(() => { const w = %s, el = %s, c = el.querySelector('canvas'), r = c.getBoundingClientRect(); window.probeEvents = [];
        for (const t of ['pointerdown','pointermove','pointerup','lostpointercapture','pointercancel','click']) el.addEventListener(t, (e) => probeEvents.push([t, e.isTrusted, e.defaultPrevented, el.dataset.dragging || '']), true);
        const press = (type, x, y) => c.dispatchEvent(new w.PointerEvent(type, {bubbles:true, cancelable:true, pointerId:1, button:0, isPrimary:true, clientX:x, clientY:y}));
        press('pointerdown', r.left+r.width/2, r.top+r.height/2); window.probeMid = {dragging: el.dataset.dragging || '', state: !!w.mascot.host.state(el)}; press('pointermove', 80, 80); window.probeMid2 = {dragging: el.dataset.dragging || '', placed: el.dataset.placed || '', el: el.getBoundingClientRect()}; press('pointerup', 80, 80); })()",
      frame, live
    ))
    Sys.sleep(3)
    probe_print("after drop", app$get_js(sprintf(
      "(() => { const w = %s, el = %s; return {events: probeEvents, mid: probeMid, mid2: probeMid2, el: el.getBoundingClientRect(), placement: w.mascot.host.state(el).placement, last: document.getElementById('position_last').textContent, input: Shiny.shinyapp.$inputValues.helper_position ?? null}; })()",
      frame, live
    )))
    probe_print("logs", tail(as.character(format(app$get_logs())), 40))
    succeed()
  })

  it("prints the theme view's tabs on a phone", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    fn <- function() NULL
    body(fn) <- quote({ library(mascot); mascot::mascot_studio("theme", run = FALSE) })
    app <- app_driver(fn, width = 375, height = 812)
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    probe_print("theme env", app$get_js(probe_env_js))
    probe_print("theme tabs", app$get_js(
      "(() => { const n = document.querySelector('#theme_tabs'), p = document.querySelector('.theme-page'); return {tabs: [n.scrollWidth, n.clientWidth, n.offsetWidth], page: [p.scrollWidth, p.clientWidth, p.offsetWidth, getComputedStyle(p).overflowY, p.scrollHeight > p.clientHeight], body: [document.body.scrollWidth, document.body.clientWidth], links: [...n.querySelectorAll('.nav-link')].map((a) => [a.textContent.trim(), a.getBoundingClientRect().width, getComputedStyle(a).fontFamily, getComputedStyle(a).fontSize, getComputedStyle(a).paddingLeft]), gap: getComputedStyle(n).gap, fonts: [...document.fonts].filter((f) => f.status === 'loaded').map((f) => f.family)}; })()"
    ))
    browser <- app$get_chromote_session()
    browser$Emulation$setDeviceMetricsOverride(width = 375, height = 812, deviceScaleFactor = 0, mobile = TRUE)
    Sys.sleep(1)
    probe_print("theme tabs, mobile emulated", app$get_js(
      "(() => { const n = document.querySelector('#theme_tabs'), p = document.querySelector('.theme-page'); return {tabs: [n.scrollWidth, n.clientWidth], page: [p.scrollWidth, p.clientWidth, p.offsetWidth], inner: innerWidth}; })()"
    ))
    succeed()
  })

  it("prints the Check tab's busy sequence", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    fn <- function() NULL
    body(fn) <- quote({ library(mascot); mascot::mascot_studio("theme", run = FALSE) })
    app <- app_driver(fn, width = 1280, height = 800)
    app$wait_for_js("!!mascot.host.state(document.getElementById('theme_mascot'))")
    app$run_js("window.probeLog = []; const t0 = performance.now(); window.probeT0 = t0; $(document).on('shiny:busy shiny:idle shiny:value shiny:error shiny:message', (e) => probeLog.push([Math.round(performance.now() - t0), e.type, e.target.id || '', e.type === 'shiny:message' ? Object.keys(e.message || {}).join(',') : '']));")
    app$run_js("document.querySelector('#theme_tabs a[data-value=check]').click(); probeLog.push([Math.round(performance.now() - probeT0), 'tab clicked', '', '']);")
    app$run_js("document.getElementById('check_contrast').click(); probeLog.push([Math.round(performance.now() - probeT0), 'check clicked', '', '']);")
    app$wait_for_js("!document.getElementById('check_contrast').disabled")
    probe_print("busy log", app$get_js("[probeLog, document.getElementById('check_contrast_ui').textContent.trim().length]"))
    Sys.sleep(3)
    probe_print("busy log later", app$get_js("[probeLog, document.getElementById('check_contrast_ui').textContent.trim().length]"))
    succeed()
  })

  it("prints animation frame timing on an engine page", {
    skip_without_chrome()
    js <- local_host_page(reduced = FALSE, placement = "inline", viewport = c(800, 600))
    probe_print("host page env", js(probe_env_js))
    probe_print("host page raf", js(probe_raf_js))
    succeed()
  })
})
