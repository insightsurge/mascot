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
    error <- format_problem(
      "budget",
      "$.budgets.micro.painted_items",
      character_format_work(data, graph, behaviour, "micro")
    )
    # 31 copies of the panel's one item, in its default and raised variants, are counted against micro's 30.
    limit <- character_format_policy()$bands$micro$painted_items
    expect_gt(error$value, limit)
    expect_identical(
      error$fix,
      paste0(
        "The micro band needs ",
        error$value,
        " painted_items, more than its limit of ",
        limit,
        ". Reduce expanded drawing work in this band."
      )
    )
  })

  it("rejects lod.full as an unknown key at its path, since full is not an authored override", {
    data <- character_format_resolve(format_recipe())
    data$lod$full <- list(hide = list())
    format_problem("unknown_key", "$.lod.full", character_format_resolve(data))
  })

  it("refuses authored micro glow with code budget at the root path, never silently drawing or dropping it", {
    data <- character_format_resolve(format_recipe())
    data$lod$micro$glow <- TRUE
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    format_problem("budget", "$", character_format_work(data, graph, behaviour, "micro"))
  })

  it("counts emission-only geometry as one painted item and its primitive path numbers", {
    data <- character_format_resolve(format_recipe())
    item <- list(
      id = "glow_emitter",
      shape = "circle",
      r = 10
    )
    data$parts[[1]]$items[[length(data$parts[[1]]$items) + 1L]] <- item
    for (v in names(data$parts[[1]]$variants)) {
      data$parts[[1]]$variants[[v]][[length(data$parts[[1]]$variants[[v]]) + 1L]] <- item
    }
    data$parts[[1]]$glow <- list(
      item = "glow_emitter",
      colour = "accent",
      blur = 6,
      alpha = 1
    )
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    work <- character_format_work(data, graph, behaviour)
    expect_equal(work[["glow_emitters"]], 1)
    expect_equal(work[["blur_design_units"]], 6)
  })

  it("suppresses glow emitters and blur when glow alpha is zero", {
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$glow <- list(
      item = data$parts[[1]]$items[[1]]$id,
      colour = "accent",
      blur = 6,
      alpha = 0
    )
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    work <- character_format_work(data, graph, behaviour)
    expect_equal(work[["glow_emitters"]], 0)
    expect_equal(work[["blur_design_units"]], 0)
  })

  it("counts a glow stroke that only a mood adds to a fill-only glowing item", {
    data <- character_format_resolve(format_recipe())
    item <- data$parts[[1]]$items[[1]]
    item$stroke <- NULL
    data$parts[[1]]$items[[1]] <- item
    data$parts[[1]]$glow <- list(item = item$id, colour = "accent", blur = 4, alpha = 1)
    work <- function(data) {
      graph <- character_format_references(data)
      character_format_work(data, graph, character_format_behaviour(data, graph))
    }
    resting <- work(data)
    key <- paste0(data$parts[[1]]$id, ".", item$id)
    data$moods[[1]]$items <- stats::setNames(list(list(stroke = names(data$colours)[[1]])), key)
    stroked <- work(data)
    # One more pass for the stroke itself and one more for its glow.
    expect_equal(stroked[["paint_passes"]] - resting[["paint_passes"]], 2)
  })

  it("does not increment gradient uses for solid glow emission", {
    data <- character_format_resolve(format_recipe())
    data$paints <- list(
      radial_fade = list(
        type = "radial",
        centre = list(0, 0),
        r1 = 20,
        stops = list(list(0, "accent", 1), list(1, "accent", 0))
      )
    )
    data$parts[[1]]$items[[1]]$fill <- list(paint = "radial_fade")
    data$parts[[1]]$glow <- list(
      item = data$parts[[1]]$items[[1]]$id,
      colour = "accent",
      blur = 4,
      alpha = 1
    )
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    work <- character_format_work(data, graph, behaviour)
    expect_equal(work[["gradient_uses"]], 1)
    expect_equal(work[["glow_emitters"]], 1)
  })

  it("counts fill and stroke emitter as separate passes in drawing-work accounting", {
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$items[[1]]$stroke <- "accent"
    data$parts[[1]]$items[[1]]$width <- 2
    data$parts[[1]]$glow <- list(
      item = data$parts[[1]]$items[[1]]$id,
      colour = "accent",
      blur = 4,
      alpha = 1
    )
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    work <- character_format_work(data, graph, behaviour)
    expect_equal(work[["paint_passes"]], 6)
    expect_equal(work[["glow_emitters"]], 1)
    expect_equal(work[["painted_items"]], 2)
  })
})
