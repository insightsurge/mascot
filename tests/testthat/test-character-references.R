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
    expect_error(character_effect_ranges(1))
    expect_error(character_effect_ranges(list(), path = 1))
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

  it("validates accessory local ids, parenting and dependency cycles", {
    # Local accessory part ids must be unique
    recipe <- format_recipe()
    recipe$accessories$badge$parts[[2]] <- recipe$accessories$badge$parts[[1]]
    format_problem("input_type", "$.accessories.badge.parts", character_format_references(recipe))

    # Accessory part parenting to nonexistent local part
    recipe <- format_recipe()
    recipe$accessories$badge$parts[[1]]$parent <- "nonexistent_parent"
    format_problem(
      "missing_reference",
      "$.accessories.badge.parts[0].parent",
      character_format_references(recipe)
    )

    # Accessory anchor must be declared in character anchors
    recipe <- format_recipe()
    recipe$accessories$badge$anchor <- "missing_anchor"
    format_problem("missing_reference", "$.accessories.badge.anchor", character_format_references(recipe))

    # Part dependency cycle between two parts
    recipe <- format_recipe()
    recipe$parts[[1]]$parent <- "panel2"
    recipe$parts[[2]] <- list(
      id = "panel2",
      parent = "panel",
      at = list(0, 0),
      layer = 1,
      items = list()
    )
    format_problem("missing_reference", "$.parts[0].parent", character_format_references(recipe))
  })

  it("enforces tuning contracts on numeric leaves and array shapes", {
    base <- list(eyes = list(open = list(rx = 3, pupil = list(look_range = list(2, 3)))))

    # Non-numeric value for numeric leaf
    format_problem(
      "input_type",
      "$.face.tune.eyes.open.rx",
      character_format_tune(base, list(eyes = list(open = list(rx = "string"))))
    )

    # Length mismatch on leaf
    format_problem(
      "input_type",
      "$.face.tune.eyes.open.rx",
      character_format_tune(base, list(eyes = list(open = list(rx = c(3, 4)))))
    )

    # Non-list tune
    format_problem("input_type", "$.face.tune", character_format_tune(base, 42))

    # Named/unnamed mismatch
    format_problem("input_type", "$.face.tune", character_format_tune(base, list(1, 2)))

    # Array length mismatch in unnamed array
    arr_base <- list(list(1, 2))
    format_problem("input_type", "$.face.tune.1", character_format_tune(arr_base, list(list(1, 2, 3))))
  })

  it("checks colour descriptions, dark mode palette, and paint ordering", {
    # Undeclared role in colour_descriptions
    data <- character_format_resolve(format_recipe())
    data$colour_descriptions <- list(undeclared_role = "Description")
    format_problem("missing_reference", "$.colour_descriptions.undeclared_role", character_format_references(data))

    # Undeclared role in dark mode overrides
    data <- character_format_resolve(format_recipe())
    data$modes$dark$colours <- list(undeclared_dark = "#000000")
    format_problem("missing_reference", "$.modes.dark.colours.undeclared_dark", character_format_references(data))

    # Gradient stops must be sorted by offset
    data <- character_format_resolve(format_recipe())
    data$paints <- list(
      gradient = list(
        type = "linear",
        from = list(0, 0),
        to = list(1, 1),
        stops = list(list(0.8, "body"), list(0.2, "outline"))
      )
    )
    format_problem("input_type", "$.paints.gradient.stops", character_format_references(data))

    # Radial paint outer radius r1 must be at least inner radius r0
    data <- character_format_resolve(format_recipe())
    data$paints <- list(
      radial = list(
        type = "radial",
        c0 = list(0, 0),
        r0 = 50,
        c1 = list(0, 0),
        r1 = 10,
        stops = list(list(0, "body"), list(1, "outline"))
      )
    )
    format_problem("input_type", "$.paints.radial.r1", character_format_references(data))

    # Paint stop referencing undeclared paint
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$items[[1]]$fill <- list(paint = "missing_paint")
    format_problem("missing_reference", "$.parts[0].items[0].fill.paint", character_format_references(data))
  })

  it("enforces spatial bounds, unique variant items, glow emitters, and switch variants", {
    # Part pivot exceeds +/-4096
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$at <- list(5000, 0)
    format_problem("input_type", "$.parts[0].at", character_format_references(data))

    # Part scale exceeds [-16, 16]
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$scale <- list(20, 20)
    format_problem("input_type", "$.parts[0].scale", character_format_references(data))

    # Part variant named "default" is reserved
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$variants$default <- list()
    format_problem("input_type", "$.parts[0].variants.default", character_format_references(data))

    # Duplicate item ids within variant
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$items[[2]] <- data$parts[[1]]$items[[1]]
    format_problem("input_type", "$.parts[0].items", character_format_references(data))

    # Glow emitter item must be present in every selectable variant
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$glow <- list(item = "surface", colour = "accent", blur = 5)
    data$parts[[1]]$variants$raised <- list(list(
      id = "other",
      shape = "rect",
      x = 0,
      y = 0,
      w = 10,
      h = 10,
      fill = "body"
    ))
    format_problem("missing_reference", "$.parts[0].glow.item", character_format_references(data))

    # Part switch variant must be declared in variants
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$switch <- list(channel = "panel.x", above = 0, variant = "missing_variant")
    format_problem("missing_reference", "$.parts[0].switch.variant", character_format_references(data))

    # Item target must name geometry present in the target part
    data <- character_format_resolve(format_recipe())
    data$lod$small$hide <- list("panel.missing_item")
    format_problem("missing_reference", "$.lod.small.hide", character_format_references(data))
  })

  it("checks anchor coordinates, accessory wear slots and LOD variants", {
    # Anchor coordinates within +/-4096
    data <- character_format_resolve(format_recipe())
    data$anchors$badge$at <- list(0, 5000)
    format_problem("input_type", "$.anchors.badge.at", character_format_references(data))

    # Anchor scale at most 16
    data <- character_format_resolve(format_recipe())
    data$anchors$badge$scale <- 20
    format_problem("input_type", "$.anchors.badge.scale", character_format_references(data))

    # Wear undeclared accessory
    data <- character_format_resolve(format_recipe())
    data$wear <- list("undeclared_acc")
    format_problem("missing_reference", "$.wear", character_format_references(data))

    # Accessory colour mapping undeclared role
    data <- character_format_resolve(format_recipe())
    data$accessories$badge$colours <- list(missing_col = "body")
    format_problem("missing_reference", "$.accessories.badge.colours.missing_col", character_format_references(data))

    # LOD hide undeclared part
    data <- character_format_resolve(format_recipe())
    data$lod$small$hide <- list("ghost_part")
    format_problem("missing_reference", "$.lod.small.hide", character_format_references(data))

    # LOD variant undeclared
    data <- character_format_resolve(format_recipe())
    data$lod$small$variants <- list(panel = "ghost_variant")
    format_problem("missing_reference", "$.lod.small.variants.panel", character_format_references(data))
  })

  it("validates face kit defaults, required styles and anatomical constraints", {
    # Face coordinates within +/-4096
    data <- character_format_resolve(format_recipe("study_bot"))
    data$face$at <- list(5000, 0)
    format_problem("input_type", "$.face.at", character_format_references(data))

    # Face scale at most 16
    data <- character_format_resolve(format_recipe("study_bot"))
    data$face$scale <- 25
    format_problem("input_type", "$.face.scale", character_format_references(data))

    # Face default style undeclared in kit
    data <- character_format_resolve(format_recipe("study_bot"))
    data$face$kit_definition$defaults$eyes <- "ghost_style"
    format_problem("missing_reference", "$.face.kit_definition.defaults.eyes", character_format_references(data))

    # Closed eye style required for blinking
    data <- character_format_resolve(format_recipe("study_bot"))
    data$face$kit_definition$eye_styles$closed <- NULL
    format_problem("missing_reference", "$.face.kit_definition.eye_styles.closed", character_format_references(data))

    # Empty brow style 'none' must have width zero
    data <- character_format_resolve(format_recipe("study_bot"))
    data$face$kit_definition$brow_styles$none$width <- 3.5
    format_problem("input_type", "$.face.kit_definition.brow_styles.none", character_format_references(data))

    # Face colour mapped to undeclared kit role
    data <- character_format_resolve(format_recipe("study_bot"))
    data$face$colours <- list(unsupported_role = "body")
    format_problem("invalid_colour", "$.face.colours.unsupported_role", character_format_references(data))

    # Pupil radius cannot exceed eye radii min(rx, ry)
    data <- character_format_resolve(format_recipe("tessa"))
    data$face$kit_definition$eye_styles$open$pupil$r <- 25
    format_problem("input_type", "$.face.kit_definition.eye_styles.open.pupil.r", character_format_references(data))

    # Eyelid slant magnitude cannot exceed ry
    data <- character_format_resolve(format_recipe("tessa"))
    data$face$kit_definition$eye_styles$open$slant <- 25
    format_problem("input_type", "$.face.kit_definition.eye_styles.open.slant", character_format_references(data))
  })

  it("checks kit effects and bounds track-mode effect channels", {
    # Undeclared kit effect used by character
    data <- character_format_resolve(format_recipe("study_bot"))
    data$effects$ghost_effect <- list(anchor = "badge")
    format_problem("missing_reference", "$.effects.ghost_effect", character_format_references(data))

    # Effect anchor undeclared
    data <- character_format_resolve(format_recipe("study_bot"))
    data$effects$sparkle <- list(anchor = "missing_anchor")
    format_problem("missing_reference", "$.effects.sparkle.anchor", character_format_references(data))

    # Unsupported effect operation/mode combination
    data <- character_format_resolve(format_recipe("study_bot"))
    data$face$kit_definition$effects$sparkle$mode <- "progress"
    format_problem("input_type", "$.face.kit_definition.effects.sparkle.mode", character_format_references(data))

    # Progress mode effect with disallowed reduced_items
    data <- character_format_resolve(format_recipe("study_bot"))
    data$face$kit_definition$effects$sweat$reduced_items <- list()
    format_problem("input_type", "$.face.kit_definition.effects.sweat.reduced_items", character_format_references(data))

    # Non-track mode effect declaring frames or tracks
    data <- character_format_resolve(format_recipe("study_bot"))
    data$face$kit_definition$effects$sweat$frames <- 30
    format_problem("input_type", "$.face.kit_definition.effects.sweat.frames", character_format_references(data))

    # Track-mode effect validation via character_effect_ranges()
    # Hand calculation:
    # Track has opacity in [0, 0.8] and scale_x in [1, 2.5]
    # Expected returned ranges: opacity = [0, 1], scale_x = [1, 2.5]
    track_effect <- list(
      op = "sparkle_star",
      mode = "track",
      at = list(0, 0),
      items = list(list(shape = "circle", r = 2, fill = "accent")),
      frames = 24,
      tracks = list(
        opacity = list(mode = "set", keys = list(list(0, 0), list(0.5, 0.8), list(1, 0))),
        scale_x = list(mode = "set", keys = list(list(0, 1), list(0.5, 2.5), list(1, 1)))
      )
    )
    ranges <- character_effect_ranges(track_effect)
    expect_equal(ranges$opacity, c(0, 1))
    expect_equal(ranges$scale_x, c(1, 2.5))

    # Disallowed fields on track mode
    bad_fields <- track_effect
    bad_fields$travel <- 20
    format_problem("input_type", "$.effect.travel", character_effect_ranges(bad_fields))

    # Track-mode effect track mode must be 'set'
    bad_track_mode <- track_effect
    bad_track_mode$tracks$opacity$mode <- "add"
    format_problem("invalid_channel", "$.effect.tracks.opacity", character_effect_ranges(bad_track_mode))

    # Track keys times must start at 0 and end at 1
    bad_keys <- track_effect
    bad_keys$tracks$opacity$keys <- list(list(0.1, 0), list(1, 0))
    format_problem("invalid_channel", "$.effect.tracks.opacity", character_effect_ranges(bad_keys))

    # Track values outside allowable channel limits
    bad_val <- track_effect
    bad_val$tracks$opacity$keys <- list(list(0, 0), list(0.5, 2.5), list(1, 0))
    format_problem("invalid_channel", "$.effect.tracks.opacity", character_effect_ranges(bad_val))
  })

  it("covers parent references, custom shapes, face styles, iris, and track positions", {
    # Part parent not in ids
    recipe <- format_recipe("anchor_probe")
    recipe$parts[[1]]$parent <- "ghost_parent"
    format_problem("missing_reference", "$.parts[0].parent", character_format_parts(recipe))

    # Item target with invalid part reference in clip
    recipe_clip <- character_format_resolve(format_recipe("study_bot"))
    recipe_clip$face$clip <- "ghost_part.surface"
    format_problem("missing_reference", "$.face.clip", character_format_references(recipe_clip))

    # Custom reusable shapes
    recipe_shape <- format_recipe("anchor_probe")
    recipe_shape$shapes <- list(box = list(shape = "rect", x = 0, y = 0, w = 10, h = 10, fill = "body"))
    recipe_shape$parts[[1]]$items[[2]] <- list(id = "sub", shape = "ref", use = "box")
    expect_silent(character_format_references(character_format_resolve(recipe_shape)))

    # Face iris, custom mouth styles, and tune during character_format_references
    tessa <- character_format_resolve(format_recipe("tessa"))
    tessa$face$eyes$iris <- "body"
    tessa$face$styles$mouth <- list(smile = character_format_kits()$classic$mouth_styles$smile)
    tessa$face$tune <- list(eyes = list(open = list(rx = 18)))
    expect_silent(character_format_references(tessa))

    # Non-ellipse eye style with stroke
    visor <- character_format_resolve(format_recipe("alpha_visor"))
    visor$face$styles$eyes <- list(
      star = list(op = "eye_path", d = "M0 0 L1 1", stroke = "feature", fill = "feature")
    )
    expect_silent(character_format_references(visor))

    # Track effect missing frames or tracks
    format_problem(
      "input_type",
      "$.effect",
      character_effect_ranges(list(op = "sparkle_star", mode = "track", at = list(0, 0), items = list()))
    )

    # Track position channel within +/-4096 limits
    # Hand calculation:
    # Keys increase from (0, 0) to (1, 10)
    # Range of x values is c(0, 10)
    pos_effect <- list(
      op = "sparkle_star",
      mode = "track",
      at = list(0, 0),
      items = list(list(shape = "circle", r = 2, fill = "accent")),
      frames = 12,
      tracks = list(x = list(mode = "set", keys = list(list(0, 0), list(1, 10))))
    )
    ranges <- character_effect_ranges(pos_effect)
    expect_equal(ranges$x, c(0, 10))
  })
})

describe("reference resolution beyond the default recipes", {
  it("rejects an absent parent and resolves declared reusable geometry", {
    data <- character_format_resolve(format_recipe())
    data$parts[[1]]$parent <- "missing_parent"
    format_problem("missing_reference", "$.parts[0].parent", character_format_references(data))

    data <- character_format_resolve(format_recipe())
    data$shapes <- list(disc = list(shape = "circle", r = 4, fill = "body"))
    data$parts[[1]]$items[[1]] <- list(id = "surface", shape = "ref", use = "disc")
    graph <- character_format_references(data)
    expect_identical(graph$parts$panel$items[[1]]$use, "disc")
    # A clip/hide address names both a declared part and an item; a valid item
    # name cannot make an absent owning part valid.
    data$lod$small$hide <- list("missing_part.surface")
    format_problem("missing_reference", "$.lod.small.hide", character_format_references(data))
  })

  it("applies a complete eye replacement before numeric tuning and checks iris roles", {
    data <- character_format_resolve(format_recipe("tessa"))
    original <- data$face$kit_definition$eye_styles$open
    replacement <- original
    replacement$rx <- 18
    data$face$styles <- list(eyes = list(open = replacement))
    data$face$tune <- list(eyes = list(open = list(rx = 20)))
    graph <- character_format_references(data)
    expect_equal(graph$kit$eye_styles$open$rx, 20)
    expect_equal(graph$kit$eye_styles$open$ry, original$ry)
    expect_equal(data$face$kit_definition$eye_styles$open$rx, original$rx)
    data$face$eyes$iris <- "missing_iris"
    format_problem("missing_reference", "$.face.eyes.iris", character_format_references(data))
  })

  it("requires complete effect tracks and includes their absolute travel extrema", {
    format_problem("input_type", "$.effect", character_effect_ranges(list(op = "sparkle_star", mode = "track")))
    # The motion goes from the origin to (-12,8) and back. Its box must include
    # both endpoints and that independently chosen middle point.
    effect <- list(
      op = "sparkle_star",
      mode = "track",
      frames = 12,
      tracks = list(
        x = list(list(0, 0), list(0.5, -12), list(1, 0)),
        y = list(list(0, 0), list(0.5, 8), list(1, 0))
      )
    )
    ranges <- character_effect_ranges(effect)
    expect_equal(ranges$x, c(-12, 0))
    expect_equal(ranges$y, c(0, 8))
  })
})
