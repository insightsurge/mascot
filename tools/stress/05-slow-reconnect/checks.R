# After a forced reconnect, Shiny's own client reports outputs "in an unexpected state" (not mascot
# messages). The cap allows four such lines for the one `handled` output.
stress_expected_warnings <- list(pattern = "is in an unexpected state of", max = 4L)

stress_checks <- function(ctx) {
  checkmate::assert_list(ctx, names = "unique")
  app <- ctx$app
  state <- ctx$state
  ctx$check("slow handler with queued clicks", {
    app$run_js(paste0("for(let i=1;i<=6;i++) setTimeout(()=>", "document.getElementById('slow').click(), i*80);"))
    app$wait_for_js("document.getElementById('handled').textContent === '6'", timeout = 30000)
    state("helper", "happy", "Slow 6")
  })
  ctx$check("200 updates with swaps, bubbles and nods in one flush", {
    app$click("burst")
    state("helper", "happy", "Burst 200", character = "neer", bubble = "Bubble 200")
  })
  ctx$check("rapid inputs settle and page responds", {
    app$run_js(paste0(
      "for(let i=1;i<=80;i++) setTimeout(()=>",
      "Shiny.setInputValue('rapid',i,{priority:'event'}), i*5);"
    ))
    state("helper", "thinking", "Rapid 80", character = "neer")
    app$set_inputs(rapid = 81)
    state("helper", "thinking", "Rapid 81", character = "neer")
  })
  session_before <- app$get_js("Shiny.shinyapp.config.sessionId")
  ctx$check("websocket loss shows worried status", {
    app$run_js(paste0(
      "window.dropSeen=false; $(document).one('shiny:disconnected.stress',()=>{",
      "setTimeout(()=>{const e=document.getElementById('helper');",
      "window.dropSeen=e.hasAttribute('data-disconnected') && ",
      "e.querySelector('[role=status]').textContent==='Connection lost. Reload the page to continue.' && ",
      "window.mascot.host.state(e).current.mood==='worried';},0);});",
      "Shiny.shinyapp.$socket.close();"
    ))
    app$wait_for_js("window.dropSeen")
  })
  # Shiny reconnects into a new server session (as on Shiny Server and Connect); the page keeps its DOM.
  ctx$check("reconnect into a new session keeps the page's last state", {
    app$wait_for_js(
      paste0(
        "Shiny.shinyapp.$socket?.readyState===1 && ",
        "!document.getElementById('helper').hasAttribute('data-disconnected')"
      ),
      timeout = 30000
    )
    if (identical(app$get_js("Shiny.shinyapp.config.sessionId"), session_before)) {
      cli::cli_abort("The reconnect reused the old session; this check needs a new one.")
    }
    state("helper", "thinking", "Rapid 81", character = "neer")
  })
  ctx$check("updates reach the mascot after reconnect", {
    app$set_inputs(rapid = 82)
    state("helper", "thinking", "Rapid 82", character = "neer")
  })
}
