stress_checks <- function(ctx) {
  checkmate::assert_list(ctx, names = "unique")
  app <- ctx$app
  ctx$check("the first session takes an update", {
    app$wait_for_js("!!document.getElementById('cached')")
    app$click("change")
    ctx$state("cached", "happy", "Updated 1")
  })
  # The page loads again: a new session of the same R process, whose renderUI() output comes from the cache.
  ctx$check("a second session shows the cached mascot with its status", {
    app$run_js("window.location.reload()")
    app$wait_for_js("!!document.getElementById('cached')", timeout = 30000)
    ctx$state("cached", "idle", "Cached")
  })
  ctx$check("a second session takes an update", {
    # The new page is connected and its mascot has sent its first snapshot before the button is used.
    app$wait_for_js("Shiny.shinyapp.$socket?.readyState===1 && !!Shiny.shinyapp.$inputValues['cached:mascot.state']")
    # A DOM click: app$click() did not register on the reloaded page in this scenario.
    app$run_js("document.getElementById('change').click()")
    ctx$state("cached", "happy", "Updated 1")
  })
}
