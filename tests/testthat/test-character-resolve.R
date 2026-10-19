describe("character_format_resolve()", {
  it("copies family defaults and complete kits while preserving palette origins", {
    source <- format_recipe("study_bot")
    expected <- format_recipe("study_bot-resolved")
    result <- character_format_resolve(source)
    expect_identical(character_format_identity(result), character_format_identity(expected))
    expect_identical(result$palette_sources$sea_glass, "character")
    expect_identical(result$palette_sources$night_screen, "family")
    expect_length(result$family_definition$defaults, 0)
    expect_identical(result$face$kit_definition$id, "screen")
    expect_false(inherits(result, "mascot_character_data"))
  })

  it("replaces named gestures atomically, merges mood fields and replaces arrays", {
    source <- format_recipe("study_bot")
    source$family_definition$defaults$moods <- list(
      idle = list(description = "Inherited", status = "Family ready", channels = list("head.x" = 2))
    )
    source$moods$idle <- list(status = "Local ready", channels = list("head.y" = 3))
    result <- character_format_resolve(source)
    expect_identical(result$moods$idle$description, "Inherited")
    expect_identical(result$moods$idle$status, "Local ready")
    expect_identical(result$moods$idle$channels, list("head.x" = 2, "head.y" = 3))
    expect_identical(names(result$gestures$wave$tracks), "hand_r.rotate")
    expect_false("root.rotate" %in% names(result$gestures$wave$tracks))
    expect_identical(character_format_merge(list(1, 2), list(3)), list(3))
    expect_null(character_format_merge(list(a = 1), NULL))
    expect_identical(character_format_merge(list(a = 1, b = 2), list(a = NULL)), list(a = NULL, b = 2))
  })

  it("opts out of inherited palettes without silently dropping unknown ones", {
    source <- format_recipe("study_bot")
    source$palettes["night_screen"] <- list(NULL)
    result <- character_format_resolve(source)
    expect_false("night_screen" %in% names(result$palettes))
    expect_false("night_screen" %in% names(result$palette_sources))
    source$palettes["typo"] <- list(NULL)
    format_problem("missing_reference", "$.palettes.typo", character_format_resolve(source))
  })

  it("does not reapply live families or kits to saved resolved snapshots", {
    expected <- format_recipe("study_bot-resolved")
    family <- list(id = "visorfolk", name = "Changed", description = "Current catalogue label", defaults = list())
    kit <- character_format_kits()$screen
    kit$description <- "Changed authoring defaults"
    result <- character_format_resolve(expected, families = list(visorfolk = family), kits = list(screen = kit))
    expect_identical(character_format_identity(result), character_format_identity(expected))
    expected$face$kit_definition <- NULL
    format_problem("missing_reference", "$.face.kit_definition", character_format_resolve(expected))
  })

  it("requires source-declared core moods and honest family and provenance data", {
    source <- format_recipe("study_bot")
    source$moods$happy <- NULL
    source$family_definition$defaults$moods <- list(happy = list(description = "Happy", status = "Done"))
    format_problem("missing_reference", "$.moods.happy", character_format_resolve(source))
    source <- format_recipe("study_bot")
    source$family_definition$id <- "another_family"
    format_problem("family", "$.family_definition.id", character_format_resolve(source))
    source <- format_recipe("study_bot")
    known <- source$family_definition
    known$name <- "Conflicting family"
    format_problem(
      "family",
      "$.family_definition",
      character_format_resolve(source, families = list(visorfolk = known))
    )
    source$palette_sources <- list()
    format_problem("input_type", "$.palette_sources", character_format_resolve(source))
    data <- format_recipe()
    data$palette_sources <- NULL
    format_problem("input_type", "$.palette_sources", character_format_resolve(data))
  })

  it("rejects family anatomy and source lookup gaps", {
    source <- format_recipe("study_bot")
    source$family_definition$defaults$gestures$wave$tracks <- list("hand_r.rotate" = list(list(0, 0), list(1, 0)))
    format_problem(
      "invalid_channel",
      "$.family_definition.defaults.gestures.wave.tracks.hand_r.rotate",
      character_format_resolve(source)
    )
    source <- format_recipe("study_bot")
    source$family_definition <- NULL
    format_problem("family", "$.family", character_format_resolve(source))

    # Family gesture cannot declare member-specific needs
    source <- format_recipe("study_bot")
    source$family_definition$defaults$gestures$wave$needs <- list("member_hand")
    format_problem(
      "family",
      "$.family_definition.defaults.gestures.wave.needs",
      character_format_resolve(source)
    )
  })

  it("validates resolved snapshots, palette reservation, and face kit matching", {
    # Resolved character recipe missing embedded family_definition
    snap <- format_recipe("study_bot-resolved")
    snap$family_definition <- NULL
    format_problem("family", "$.family_definition", character_format_resolve(snap))

    # Resolved character recipe cannot have non-empty defaults in snapshot
    snap <- format_recipe("study_bot-resolved")
    snap$family_definition$defaults <- list(moods = list())
    format_problem("family", "$.family_definition.defaults", character_format_resolve(snap))

    # Palette named 'original' is reserved for native palette
    source <- format_recipe("study_bot")
    source$palettes$original <- list(description = "Original", light = list(body = "#ffffff"))
    format_problem("input_type", "$.palettes.original", character_format_resolve(source))

    # A name for the character's own colours must differ from original and from every palette
    source <- format_recipe("study_bot")
    source$native_palette <- "original"
    format_problem("duplicate_id", "$.native_palette", character_format_resolve(source))
    source$native_palette <- "sea_glass"
    format_problem("duplicate_id", "$.native_palette", character_format_resolve(source))
    source$native_palette <- "glass_pine"
    expect_identical(character_format_resolve(source)$native_palette, "glass_pine")

    # Palette sources provenance must match palettes exactly
    snap <- format_recipe("study_bot-resolved")
    snap$palette_sources$extraneous <- "character"
    format_problem("input_type", "$.palette_sources", character_format_resolve(snap))

    # Character declaring face must select a kit
    source <- format_recipe("study_bot")
    source$face$kit <- NULL
    format_problem("missing_reference", "$.face.kit", character_format_resolve(source))

    # Embedded kit definition id must match selected kit id
    snap <- format_recipe("study_bot-resolved")
    snap$face$kit_definition$id <- "different_kit_id"
    format_problem("missing_reference", "$.face.kit_definition.id", character_format_resolve(snap))
  })

  it("checks helper arguments and keeps array order in canonical identity", {
    expect_error(character_format_resolve(1))
    expect_error(character_format_resolve(list(), families = 1))
    expect_error(character_format_resolve(list(), kits = 1))
    expect_error(character_format_identity(1))
    expect_identical(character_format_identity(list(a = 1, b = 2)), character_format_identity(list(b = 2, a = 1)))
    expect_false(identical(
      character_format_identity(list(a = list(1, 2))),
      character_format_identity(list(a = list(2, 1)))
    ))
  })
})

describe("B2 reserved palette ids", {
  it("rejects every style alias in source and resolved characters", {
    for (id in c("minimal", "pastel", "vivid", "corporate", "earthy", "night")) {
      for (fixture in c("study_bot", "study_bot-resolved")) {
        source <- format_recipe(fixture)
        source$palettes[[id]] <- list(description = "Reserved", light = list(body = "#ffffff"))
        if (isTRUE(source$resolved)) {
          source$palette_sources[[id]] <- "character"
        }
        format_problem("input_type", paste0("$.palettes.", id), character_format_resolve(source))
      }
    }
  })
})
