describe("independent R expanded drawing-work bounds", {
  it("reproduces all twelve reference metric rows within conservative area rounding", {
    expected <- jsonlite::fromJSON(test_path("fixtures", "format", "work-expected.json"), simplifyVector = FALSE)
    for (row in expected$rows) {
      data <- character_format_resolve(format_recipe(row$character))
      graph <- character_format_references(data)
      behaviour <- character_format_behaviour(data, graph)
      actual <- character_format_work(data, graph, behaviour, row$band)
      for (metric in setdiff(names(actual), "inflated_glow_area_ratio")) {
        expect_equal(unname(actual[[metric]]), row$maxima[[metric]], info = paste(row$character, row$band, metric))
      }
      expect_equal(
        actual[["inflated_glow_area_ratio"]],
        row$maxima$inflated_glow_area_ratio,
        tolerance = 1e-11,
        info = paste(row$character, row$band, "glow bound")
      )
    }
  })

  it("does not add mutually exclusive variants or accessories together", {
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$variants$raised[[2]] <- list(shape = "circle", r = 2, fill = "accent")
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    expect_equal(character_format_work(data, graph, behaviour)[["painted_items"]], 3)
    data$accessories$other <- data$accessories$badge
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    expect_equal(character_format_work(data, graph, behaviour)[["painted_items"]], 3)
  })

  it("includes scaled reusable-shape outlines in conservative geometry bounds", {
    shape <- list(disc = list(shape = "circle", r = 3, outline = TRUE))
    box <- character_work_box(list(shape = "ref", use = "disc", x = 10, scale = 2), shape, list(width = 2))
    expect_equal(box, c(2, -8, 18, 8))
  })

  it("rejects over-budget micro geometry rather than silently hiding it", {
    data <- character_format_resolve(format_recipe())
    data$lod$micro$hide <- list()
    data$parts[[1]]$items <- rep(data$parts[[1]]$items, 31)
    for (index in seq_along(data$parts[[1]]$items)) {
      data$parts[[1]]$items[[index]]$id <- paste0("item_", index)
    }
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    format_problem("budget", "$.budgets.micro.painted_items", character_format_work(data, graph, behaviour, "micro"))
  })
})
