stress_checks <- function(ctx) {
  checkmate::assert_list(ctx, names = "unique")
  app <- ctx$app
  # Off-screen mascots pause drawing by design, so bring each card into view before checking its face.
  state <- function(i, mood, text) {
    checkmate::assert_count(i, positive = TRUE)
    checkmate::assert_string(mood)
    checkmate::assert_string(text)
    id <- paste0("card", i, "-helper")
    app$run_js(sprintf("document.getElementById('%s').scrollIntoView({block: 'center'})", id))
    ctx$state(id, mood, text)
  }
  ctx$check("thirty added cards each start with their own update", {
    for (i in seq_len(3)) {
      app$click("add")
    }
    for (i in seq_len(30)) {
      state(i, "happy", paste0("card", i, " ready"))
    }
  })
  ctx$check("removed cards are gone; the rest update and catch up when scrolled into view", {
    for (i in seq_len(5)) {
      app$click("remove")
    }
    app$wait_for_js("document.querySelectorAll('.mascot').length === 5")
    app$click("everyone")
    for (i in 26:30) {
      state(i, "thinking", paste0("card", i, " round 1"))
    }
    app$click("add")
    for (i in 31:40) {
      state(i, "happy", paste0("card", i, " ready"))
    }
    values <- app$get_values(export = TRUE)$export
    # Reported, not judged: the package keeps one small record per id until the session ends.
    paste0(
      values$created,
      " ids created, ",
      values$live,
      " live, ",
      values$records,
      " records kept by the package"
    )
  })
}
