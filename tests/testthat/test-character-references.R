describe("character_format_references()", {
  it("checks all canonical assembled references without promoting the data", {
    for (id in c("tessa", "alpha_visor", "anchor_probe", "study_bot")) {
      data <- character_format_resolve(format_recipe(id))
      graph <- character_format_references(data)
      expect_setequal(names(graph$parts), graph$order)
      expect_false(inherits(data, "mascot_character_data"))
    }
  })

  it("reports missing owners, roles, parents, variants and cycles", {
    data <- character_format_resolve(format_recipe())
    data$anchors$badge$part <- "missing_arm"
    format_problem("missing_reference", "$.anchors.badge.part", character_format_references(data))
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$items[[1]]$fill <- "missing_colour"
    format_problem("missing_reference", "$.parts[0].items[0].fill", character_format_references(data))
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$parent <- "panel"
    format_problem("missing_reference", "$.parts[0].parent", character_format_references(data))
    data <- character_format_resolve(format_recipe())
    data$anchors$badge$variants$typo <- list(at = list(0, 0))
    format_problem("missing_reference", "$.anchors.badge.variants.typo", character_format_references(data))
    data <- character_format_resolve(format_recipe("study_bot"))
    data$face$part <- "missing_head"
    format_problem("missing_reference", "$.face.part", character_format_references(data))
  })

  it("rejects expanded id collisions and two accessories in the same slot", {
    data <- character_format_resolve(format_recipe())
    data$parts[[2]] <- list(id = "wear_badge_disc")
    format_problem("input_type", "$.accessories.badge.parts[0].id", character_format_references(data))
    data <- character_format_resolve(format_recipe())
    data$accessories$other <- data$accessories$badge
    data$wear <- list("badge", "other")
    format_problem("input_type", "$.wear", character_format_references(data))
  })

  it("tunes existing numeric leaves and rejects new keys or altered operations", {
    base <- list(eyes = list(open = list(rx = 3, pupil = list(r = 1, look_range = list(2, 3)), op = "eye_ellipse")))
    result <- character_format_tune(base, list(eyes = list(open = list(rx = 4, pupil = list(look_range = list(5, 6))))))
    expect_identical(result$eyes$open$rx, 4)
    expect_identical(result$eyes$open$pupil$look_range, list(5, 6))
    format_problem("unknown_key", "$.face.tune.extra", character_format_tune(base, list(extra = 1)))
    format_problem(
      "input_type",
      "$.face.tune.eyes.open.op",
      character_format_tune(base, list(eyes = list(open = list(op = 1))))
    )
    expect_error(character_format_parts(1))
    expect_error(character_format_references(1))
  })

  it("enforces declared parts limit counting accessory templates", {
    recipe <- format_recipe()
    part_tmpl <- recipe$parts[[1]]
    recipe$parts <- c(
      list(part_tmpl),
      lapply(2:255, function(i) {
        p <- part_tmpl
        p$id <- paste0("part_", i)
        p
      })
    )
    expect_length(character_format_parts(recipe)$parts, 256L)
    recipe$parts[[256L]] <- part_tmpl
    recipe$parts[[256L]]$id <- "part_256"
    format_problem("budget", "$.parts", character_format_parts(recipe))
  })
})
