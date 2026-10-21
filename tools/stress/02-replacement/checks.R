# Duplicate-id diagnostics are deliberate here; count them so a storm still fails.
# The 2026-10-21 run logged one; the cap allows one more bind attempt.
stress_expected_warnings <- list(pattern = "duplicate live mascot id|Duplicate input binding", max = 2L)

stress_checks <- function(ctx) {
  checkmate::assert_list(ctx, names = "unique")
  app <- ctx$app
  state <- ctx$state
  replace <- ctx$replace
  # Keep every server envelope: the stale test replays one, the gesture test reads them all.
  app$run_js(paste0(
    "window.envelopes=[];window.oldDispatch=Shiny.shinyapp.dispatchMessage;",
    "Shiny.shinyapp.dispatchMessage=function(data){",
    "const m=typeof data==='string'?JSON.parse(data):data;",
    "if(m.custom && m.custom['mascot:update']?.state){",
    "window.lastEnvelope=JSON.parse(JSON.stringify(m.custom['mascot:update']));",
    "window.envelopes.push(window.lastEnvelope);}",
    "return window.oldDispatch.call(this,data);};"
  ))
  ctx$check("twenty replacements retain latest state", {
    for (i in seq_len(20)) {
      app$click("change")
      state("same", "happy", paste("Update", i))
      replace("same")
      state("same", "happy", paste("Update", i))
    }
  })
  ctx$check("update while absent then insert", {
    app$click("remove")
    app$wait_for_js("document.querySelectorAll('[id=\"same\"]').length === 0")
    app$click("change")
    app$click("insert")
    state("same", "happy", "Update 21")
  })
  ctx$check("duplicate does not take ownership", {
    app$click("duplicate")
    app$wait_for_js("document.querySelectorAll('#same').length === 2")
    app$click("change")
    state("same", "happy", "Update 22")
    stopifnot(isTRUE(app$get_js("window.mascot.host.state(document.querySelectorAll('#same')[1]) === null")))
    state("other", "idle", "Untouched")
  })
  ctx$check("old generation cannot update replacement", {
    app$run_js("window.staleEnvelope=JSON.parse(JSON.stringify(window.lastEnvelope));")
    app$click("remove")
    app$wait_for_js("document.querySelectorAll('[id=\"same\"]').length === 0")
    replace("same")
    state("same", "happy", "Update 22")
    stopifnot(isTRUE(app$get_js(paste0(
      "window.staleEnvelope.generation !== ",
      "window.mascot.host.state(document.getElementById('same')).snapshot.generation"
    ))))
    app$run_js(paste0(
      "window.staleEnvelope.revision=999999;",
      "window.staleEnvelope.state.mood='worried';",
      "window.staleEnvelope.state.status={mode:'custom',text:'Stale'};",
      "window.mascot.host.receive(window.staleEnvelope);"
    ))
    state("same", "happy", "Update 22")
    state("other", "idle", "Untouched")
  })
  ctx$check("swap, bubble and nod survive replacement; the nod plays once", {
    app$click("rich")
    state("same", "celebrating", "Rich", character = "sela", bubble = "Saved")
    # The page reports a consumed gesture through its watermark.
    app$wait_for_js("window.mascot.host.state(document.getElementById('same')).snapshot.gesture_watermark > 0")
    played <- app$get_js("window.mascot.host.state(document.getElementById('same')).snapshot.gesture_watermark")
    app$run_js("window.envelopes=[];")
    for (i in seq_len(3)) {
      replace("same")
      state("same", "celebrating", "Rich", character = "sela", bubble = "Saved")
    }
    replays <- app$get_js(sprintf(
      "window.envelopes.filter(e=>e.id==='same' && e.gesture && e.gesture.revision>%s).length",
      played
    ))
    if (!identical(as.integer(replays), 0L)) {
      cli::cli_abort("{replays} replacement envelope{?s} offered the played nod again.")
    }
    paste(length(app$get_js("window.envelopes")), "replacement envelopes, none offered the nod again")
  })
  ctx$check("a dismissed bubble stays dismissed through replacement", {
    app$run_js("document.querySelector('#same .mascot-bubble-close').click()")
    app$wait_for_js("window.mascot.host.state(document.getElementById('same')).bubble === null")
    replace("same")
    state("same", "celebrating", "Rich", character = "sela")
    stopifnot(isTRUE(app$get_js("window.mascot.host.state(document.getElementById('same')).bubble === null")))
  })
  ctx$check("floating mascot replaced and removed", {
    for (i in seq_len(5)) {
      app$click("change_float")
      state("floater", "thinking", paste("Float", i))
      replace("floater", button = "replace_float")
      state("floater", "thinking", paste("Float", i))
      stopifnot(isTRUE(app$get_js("document.querySelectorAll('[id=\"floater\"]').length === 1")))
    }
    app$click("remove_float")
    app$wait_for_js("document.querySelectorAll('[id=\"floater\"]').length === 0")
    state("same", "celebrating", "Rich", character = "sela")
  })
}
