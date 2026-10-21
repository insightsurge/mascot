# Checks for the plain, golem-style and rhino-style layouts; run-stress.R supplies the context.
stress_checks <- function(ctx) {
  checkmate::assert_list(ctx, names = "unique")
  app <- ctx$app
  ctx$check("eight modules isolated after rapid tabs", {
    app$run_js("for(let i=1;i<=8;i++) document.querySelector('[data-value=\"'+i+'\"]').click();")
    for (i in seq_len(8)) {
      app$click(paste0("m", i, "-review-change"))
    }
    for (i in seq_len(8)) {
      ctx$state(paste0("m", i, "-review-helper"), "happy", paste0("m", i, "-review-helper 1"))
    }
    app$click("m4-review-change")
    for (i in seq_len(8)) {
      ctx$state(
        paste0("m", i, "-review-helper"),
        if (i == 4) "worried" else "happy",
        paste0("m", i, "-review-helper ", if (i == 4) 2 else 1)
      )
    }
  })
}
