describe("conservative authored frame fit", {
  it("proves the reference artwork fits in every detail band", {
    for (id in c("tessa", "alpha_visor", "anchor_probe", "study_bot")) {
      data <- character_format_resolve(format_recipe(id))
      graph <- character_format_references(data)
      behaviour <- character_format_behaviour(data, graph)
      for (band in c("full", "small", "micro")) {
        result <- character_format_fit(data, graph, behaviour, band)
        expect_true(result$verified, info = paste(id, band, paste(round(result$bounds, 2), collapse = ", ")))
      }
    }
  })

  it("does not certify geometry outside the frame", {
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$at <- list(180, -60)
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    expect_false(character_format_fit(data, graph, behaviour)$verified)
  })

  it("bounds trigonometric extrema and matrix products independently", {
    expect_equal(character_interval_trig(c(0, pi)), c(0, 1), tolerance = 1e-12)
    expect_equal(character_interval_trig(c(0, 2 * pi), TRUE), c(-1, 1))
    expect_equal(character_interval(c(-2, 3), c(-4, 5), "multiply"), c(-12, 15))
    identity <- list(c(1, 1), c(0, 0), c(0, 0), c(1, 1), c(0, 0), c(0, 0))
    expect_equal(character_interval_box(c(-1, -2, 3, 4), identity), c(-1, -2, 3, 4))
  })
})
