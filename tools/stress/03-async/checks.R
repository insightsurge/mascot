stress_checks <- function(ctx) {
  checkmate::assert_list(ctx, names = "unique")
  app <- ctx$app
  state <- ctx$state
  ctx$check("observers during ExtendedTask", {
    app$click("start", wait_ = FALSE)
    state("helper", "thinking", "Running")
    app$click("first", wait_ = FALSE)
    state("helper", "worried", "First")
    app$click("second", wait_ = FALSE)
    state("helper", "thinking", "Second")
    ctx$replace("helper")
    state("helper", "thinking", "Second")
    app$click("finish", wait_ = FALSE)
    app$wait_for_js("document.getElementById('task_status').textContent === 'success'")
    state("helper", "happy", "Complete")
  })
  ctx$check("observer after completion and replacement", {
    ctx$replace("helper")
    state("helper", "happy", "Complete")
    app$click("first")
    state("helper", "worried", "First")
    app$click("third")
    state("helper", "happy", "Final")
  })
}
