stress_checks <- function(ctx) {
  checkmate::assert_list(ctx, names = "unique")
  app <- ctx$app
  ctx$check("the bookmark URL carries the note but not the mascot", {
    app$set_inputs(note = "stress")
    app$click("change")
    ctx$state("helper", "worried", "Changed 1")
    app$click("bookmark")
    app$wait_for_js("window.location.search.includes('_inputs_')")
    search <- utils::URLdecode(app$get_js("window.location.search"))
    if (!grepl("note=\"stress\"", search, fixed = TRUE)) {
      cli::cli_abort("The bookmark lost the note: {search}")
    }
    if (grepl("helper", search, fixed = TRUE)) {
      cli::cli_abort("The bookmark contains the mascot's private input: {search}")
    }
  })
  ctx$check("a restored session sets the mascot from onRestore()", {
    app$run_js("window.location.reload()")
    app$wait_for_js("!!window.Shiny?.shinyapp?.isConnected?.() && !!document.getElementById('helper')")
    ctx$state("helper", "happy", "Restored stress")
    stopifnot(identical(app$get_js("document.getElementById('note').value"), "stress"))
  })
}
