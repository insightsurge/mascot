describe("independent R character geometry", {
  it("counts absolute path operands with repeated commands and scientific notation", {
    path <- character_path("M1e1,-.5 2 3 L4 5 Q6 7 8 9 C0 1 2 3 4 5 Z")
    expect_identical(vapply(path, `[[`, character(1), "op"), c("M", "L", "L", "Q", "C", "Z"))
    expect_equal(sum(vapply(path, function(x) length(x$values), integer(1))), 16)
    for (d in c("L0 0", "M", "M0 0 Q1 2 3", "M0 0 C1 2 L3 4", "M0 0 ?1 2", "M0 0 l1 1")) {
      expect_error(character_path(d), class = "mascot_error_character")
    }
    format_problem("non_finite", "$.d", character_path("M0 0 L1e400 1"))
  })

  it("computes conservative control-point boxes and primitive numbers", {
    expect_equal(character_geometry(list(shape = "circle", r = 2))$box, c(-2, -2, 2, 2))
    expect_equal(character_geometry(list(shape = "ellipse", rx = 2, ry = 3, rotate = pi / 2))$box, c(-3, -2, 3, 2))
    expect_equal(character_geometry(list(shape = "rect", w = 2, h = 3))$numbers, 4)
    expect_equal(character_geometry(list(shape = "round_rect", w = 2, h = 3, r = 1))$numbers, 8)
    expect_equal(character_geometry(list(shape = "hexagon", r = 2, corner = 1))$numbers, 36)
    expect_equal(
      character_geometry(list(shape = "polyline", points = list(list(0, 0), list(1, 2)), stroke = "ink"))$box,
      c(0, 0, 1, 2)
    )
    expect_equal(character_geometry(list(shape = "path", d = "M0 0 Q20 -40 10 10"))$box, c(0, -40, 20, 10))
    expect_equal(
      character_geometry(
        list(shape = "ref", use = "disc", x = 10, scale = 2),
        list(disc = list(shape = "circle", r = 3))
      )$box,
      c(4, -6, 16, 6)
    )
  })

  it("rejects unknown refs, forbidden geometry and unsafe bounds", {
    format_problem("missing_reference", "$.item.use", character_shape(list(shape = "ref", use = "missing")))
    format_problem(
      "unknown_key",
      "$.item.r",
      character_shape(list(shape = "ref", use = "disc", r = 4), list(disc = list(shape = "circle", r = 2)))
    )
    format_problem(
      "input_type",
      "$.item",
      character_geometry(list(shape = "polyline", points = list(list(0, 0), list(1, 1)), fill = "ink"))
    )
    format_problem("input_type", "$.item.r", character_geometry(list(shape = "circle", r = 0)))
    expect_error(character_path(1))
    expect_error(character_path("M0 0", path = 1))
    expect_error(character_shape(1))
    expect_error(character_shape(list(), shapes = 1))
    expect_error(character_shape(list(), path = 1))
    expect_error(character_geometry(1))
    expect_error(character_geometry(list(), shapes = 1))
    expect_error(character_geometry(list(), path = 1))
  })
})
