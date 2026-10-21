stress_checks <- function(ctx) {
  checkmate::assert_list(ctx, names = "unique")
  app <- ctx$app
  ctx$check("update from later() arrives without another input", {
    app$click("schedule")
    ctx$state("helper", "happy", "From later 1")
  })
  ctx$check("update from a promise arrives without another input", {
    app$click("promise")
    ctx$state("helper", "thinking", "From promise 1")
  })
}
