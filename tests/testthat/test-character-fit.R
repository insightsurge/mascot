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

  it("handles world-coordinates upright and no_flip orientation filters", {
    # Hand calculation for interval orientation filtering:
    # parent identity matrix: norm = 1, translation = (10, 20)
    # local translation = (5, -5)
    # With upright = TRUE, no_flip = FALSE:
    #   filtered matrix removes parent rotation, keeping y-axis positive and x-axis in [-norm, norm]
    identity <- list(c(1, 1), c(0, 0), c(0, 0), c(1, 1), c(10, 10), c(20, 20))
    attr(identity, "norm") <- 1
    local <- list(c(1, 1), c(0, 0), c(0, 0), c(1, 1), c(5, 5), c(-5, -5))
    attr(local, "norm") <- 1

    upright_res <- character_interval_filter(identity, local, upright = TRUE, no_flip = FALSE)
    # Under the identity parent, local translation puts the pivot at (15,15).
    # A point (2,3) must land at (17,18); conservative intervals may be wider.
    box <- character_interval_box(c(2, 3, 2, 3), upright_res)
    expect_lte(box[[1]], 17)
    expect_lte(box[[2]], 18)
    expect_gte(box[[3]], 17)
    expect_gte(box[[4]], 18)
    expect_equal(upright_res[[5L]], c(15, 15))
    expect_equal(upright_res[[6L]], c(15, 15))

    # Test with no_flip = TRUE
    noflip_res <- character_interval_filter(identity, local, upright = FALSE, no_flip = TRUE)
    expect_equal(noflip_res[[5L]], c(15, 15))
    expect_equal(noflip_res[[6L]], c(15, 15))

    # Test character fit with part declaring keep_upright = TRUE and no_flip = TRUE
    probe <- format_recipe("anchor_probe")
    probe$parts[[1]]$keep_upright <- TRUE
    probe$parts[[1]]$no_flip <- TRUE
    data <- character_format_resolve(probe)
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    fit <- character_format_fit(data, graph, behaviour, "full")
    expect_true(fit$verified)
    expect_equal(fit$reason, "conservative_authored_interval_bound")

    # Argument validation on character_interval_filter
    expect_error(character_interval_filter(1, local, TRUE, TRUE))
    expect_error(character_interval_filter(identity, 1, TRUE, TRUE))
    expect_error(character_interval_filter(identity, local, 1, TRUE))
    expect_error(character_interval_filter(identity, local, TRUE, 1))
  })

  it("detects shadow lift singularity and non-finite interval overflows", {
    # Shadow singularity: ground shadow present and root lift descends to <= -200
    probe <- format_recipe("anchor_probe")
    probe$ground$shadow <- list(rx = 40, ry = 8, colour = "outline")
    probe$moods$idle$channels <- list("root.lift" = -205)
    data <- character_format_resolve(probe)
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    fit <- character_format_fit(data, graph, behaviour, "full")
    expect_false(fit$verified)
    expect_identical(fit$reason, "shadow_lift_singularity")

    # Non-finite values in interval arithmetic trigger budget abort
    format_problem("budget", "$.geometry", character_interval(c(0, Inf), c(1, 1)))
    huge_mat <- list(c(1e200, 1e200), c(0, 0), c(0, 0), c(1e200, 1e200), c(0, 0), c(0, 0))
    format_problem("budget", "$.geometry", character_interval_matrix(huge_mat, huge_mat))
  })

  it("certifies empty artwork as verified with NULL bounds", {
    probe <- format_recipe("anchor_probe")
    probe$parts[[1]]$items <- list()
    probe$accessories <- NULL
    probe$wear <- NULL
    data <- character_format_resolve(probe)
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    fit <- character_format_fit(data, graph, behaviour, "micro")
    expect_true(fit$verified)
    expect_null(fit$bounds)
  })

  it("bounds track-mode effects under character fit", {
    data <- character_format_resolve(format_recipe("study_bot"))
    data$face$kit_definition$effects$sparkle <- list(
      op = "sparkle_star",
      mode = "track",
      at = list(0, 0),
      items = list(list(shape = "circle", r = 2, fill = "accent")),
      frames = 18,
      tracks = list(
        opacity = list(mode = "set", keys = list(list(0, 0), list(0.5, 1), list(1, 0))),
        scale_x = list(mode = "set", keys = list(list(0, 1), list(0.5, 2), list(1, 1))),
        scale_y = list(mode = "set", keys = list(list(0, 1), list(0.5, 2), list(1, 1)))
      )
    )
    data$effects$sparkle <- list(anchor = "badge")
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    fit <- character_format_fit(data, graph, behaviour, "full")
    expect_true(fit$verified)
  })
})
