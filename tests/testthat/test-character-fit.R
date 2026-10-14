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

  it("matches hand-calculated bounds for a rotated part under host placement", {
    # Hand calculation:
    # 1. Coordinate frame and host placement conventions (policy-v1.json, character-fit.R):
    #    Canvas frame: 300 x 300; ground origin: (150, 270).
    #    Default host placement maps local ground-origin coordinates (x, y) to:
    #      x_host = x + 150
    #      y_host = y + 270
    # 2. Minimal character setup:
    #    One part placed at pivot at = (px = 20, py = -50), rotated by pi / 2.
    #    One item: rect with x = -10, y = -15, w = 30, h = 40 (spans x in [-10, 20], y in [-15, 25]).
    #    Outline width = 0 (no stroke or miter padding).
    #    No motion idle breathing or change tilt/lift.
    # 3. Local rotation at pivot (pi / 2 counter-clockwise in y-down Canvas system):
    #    [tx, ty] = [cos(pi/2)*x - sin(pi/2)*y + px, sin(pi/2)*x + cos(pi/2)*y + py]
    #             = [-y + px, x + py]
    #    tx = 20 - y:
    #      y in [-15, 25]  => tx in [20 - 25, 20 - (-15)] = [-5, 35]
    #    ty = -50 + x:
    #      x in [-10, 20]  => ty in [-50 + (-10), -50 + 20] = [-60, -30]
    #    Local rotated box: [-5, -60, 35, -30]
    # 4. Host placement:
    #    x_host = tx + 150 in [-5 + 150, 35 + 150] = [145, 185]
    #    y_host = ty + 270 in [-60 + 270, -30 + 270] = [210, 240]
    #    Exact expected host bounds: [145, 210, 185, 240]
    # 5. Documented implementation slack:
    #    pad = max(1, abs(bounds)) * .Machine$double.eps * 128
    #        = 240 * 2.220446e-16 * 128 = 6.82121024e-12
    probe <- format_recipe("anchor_probe")
    probe$accessories <- NULL
    probe$anchors <- NULL
    probe$wear <- NULL
    probe$lod <- NULL
    probe$gestures <- list(
      nod = list(description = "Nod", frames = 18, tracks = list()),
      wave = list(description = "Wave", frames = 18, tracks = list())
    )
    for (m in names(probe$moods)) {
      probe$moods[[m]]$channels <- list()
    }
    probe$motion <- list(
      idle = list(breathe = 0),
      change = list(angle = 0, height = 0)
    )
    probe$parts <- list(
      list(
        id = "panel",
        at = list(20, -50),
        rotate = pi / 2,
        layer = 1,
        items = list(
          list(
            id = "surface",
            shape = "rect",
            x = -10,
            y = -15,
            w = 30,
            h = 40,
            fill = "body"
          )
        )
      )
    )
    probe$outline <- list(width = 0)

    data <- character_format_resolve(probe)
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    fit <- character_format_fit(data, graph, behaviour, "full")

    exact <- c(145, 210, 185, 240)
    pad <- max(1, abs(exact)) * .Machine$double.eps * 128

    expect_true(fit$verified)
    expect_lte(fit$bounds[[1L]], exact[[1L]])
    expect_lte(fit$bounds[[2L]], exact[[2L]])
    expect_gte(fit$bounds[[3L]], exact[[3L]])
    expect_gte(fit$bounds[[4L]], exact[[4L]])
    expect_lte(max(abs(fit$bounds - exact)), pad + 1e-12)
    expect_equal(fit$bounds, exact, tolerance = pad + 1e-12)
  })
})
