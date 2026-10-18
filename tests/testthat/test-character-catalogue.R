describe("character_catalogue_builtin()", {
  it("checks the shipped Tessa recipe once and returns the cached result afterwards", {
    first <- character_catalogue_builtin("tessa")
    expect_s3_class(first, "mascot_character_data")
    expect_identical(first$id, "tessa")
    expect_identical(first$family, "hexonians")
    expect_true(isTRUE(first$resolved))
    expect_identical(character_catalogue_builtin("tessa"), first)
    expect_identical(character_catalogue_get("tessa"), first)
  })
  it("rejects an id that is not shipped", {
    expect_error(character_catalogue_builtin("study_bot"), "Assertion on 'id' failed")
  })
  it("ships a recipe whose colour roles match the legacy Tessa description", {
    legacy <- character_colour_data("tessa")
    expect_identical(
      colour_role_names(names(legacy$colours)),
      names(character_catalogue_builtin("tessa")$colours)
    )
    expect_identical(
      unname(unlist(legacy$colours)),
      unname(unlist(character_catalogue_builtin("tessa")$colours))
    )
    expect_identical(
      unname(unlist(legacy$brand)),
      unname(unlist(character_catalogue_builtin("tessa")$brand))
    )
  })
  it("keeps the shared mood descriptions and gives Tessa her own status lines", {
    tessa <- character_catalogue_builtin("tessa")
    voice <- c(
      idle = "Resting, ready for the next piece.",
      thinking = "Working out how the parts fit.",
      happy = "That came together nicely.",
      worried = "One part needs a closer look.",
      celebrating = "Finished, and built to last."
    )
    for (mood in mood_table()$name) {
      expect_identical(character_catalogue_status(tessa, mood), voice[[mood]])
      expect_identical(tessa$moods[[mood]]$description, mood_table()$description[mood_table()$name == mood])
    }
  })
})

describe("character_catalogue_ids() and character_catalogue_get()", {
  it("lists shipped ids first and registered ids in registration order", {
    local_empty_registry()
    expect_identical(character_catalogue_ids(), c("tessa", "sela", "knurl", "neer"))
    character_data_register(character_format_check(format_recipe("anchor_probe")))
    character_data_register(character_format_check(format_recipe("study_bot")))
    expect_identical(character_catalogue_ids(), c("tessa", "sela", "knurl", "neer", "anchor_probe", "study_bot"))
    expect_identical(character_catalogue_get("study_bot")$id, "study_bot")
    expect_true(character_catalogue_is_builtin("tessa"))
    expect_false(character_catalogue_is_builtin("study_bot"))
  })
  it("checks its arguments", {
    expect_error(character_catalogue_get(1), "Assertion on 'id' failed")
    expect_error(character_catalogue_is_builtin(""), "Assertion on 'id' failed")
  })
})

describe("character_catalogue_resolve()", {
  it("accepts an id, a helper and checked data through one path", {
    local_empty_registry()
    from_id <- character_catalogue_resolve("tessa", environment())
    expect_identical(character_catalogue_resolve(mascot_character("tessa"), environment()), from_id)
    custom <- character_format_check(format_recipe("study_bot"))
    expect_identical(character_catalogue_resolve(custom, environment())$id, "study_bot")
    character_data_register(custom)
    expect_identical(character_catalogue_resolve("study_bot", environment())$id, "study_bot")
  })
  it("verifies supplied checked data again, because R lists can be changed", {
    custom <- character_format_check(format_recipe("study_bot"))
    custom$parts <- list()
    expect_error(character_catalogue_resolve(custom, environment()), class = "mascot_error_character")
  })
  it("names unknown ids at the caller and rejects other types", {
    expect_error(
      character_catalogue_resolve("unknown_character", environment()),
      "must be one of",
      class = "mascot_error"
    )
    expect_error(character_catalogue_resolve(1, environment()), "Assertion on 'character' failed")
    expect_error(character_catalogue_resolve(NULL, environment()), "Assertion on 'character' failed")
    expect_error(character_catalogue_resolve("tessa", 1), "Assertion on 'call' failed")
  })
})

describe("character_catalogue_status()", {
  it("returns the status written for the mood", {
    custom <- catalogue_alpha_two()
    expect_identical(character_catalogue_status(custom, "processing"), "Processing")
    expect_identical(character_catalogue_status(custom, "idle"), custom$moods$idle$status)
  })
  it("names a mood the character does not declare", {
    format_problem("missing_reference", "$.moods.sleepy", character_catalogue_status(catalogue_alpha_two(), "sleepy"))
    expect_error(character_catalogue_status(list(), "idle"), "Assertion on 'data' failed")
    expect_error(character_catalogue_status(catalogue_alpha_two(), ""), "Assertion on 'mood' failed")
  })
})

describe("character_catalogue_assert()", {
  it("accepts the three forms and the NULL it is told about", {
    expect_silent(character_catalogue_assert("tessa"))
    expect_silent(character_catalogue_assert(mascot_character()))
    expect_silent(character_catalogue_assert(catalogue_alpha_two()))
    expect_silent(character_catalogue_assert(NULL, nullable = TRUE))
    expect_error(character_catalogue_assert(NULL), "Assertion on 'character' failed")
    expect_error(character_catalogue_assert("tessa", nullable = NA), "Assertion on 'nullable' failed")
  })
})


describe("character_palettes()", {
  it("shares cached definitions between every public palette consumer without reading files again", {
    data <- character_catalogue_get("knurl")
    expect_identical(character_palettes("knurl"), character_palettes(data))
    expect_identical(character_palettes(mascot_character("knurl")), data$palettes)
    invisible(lapply(character_catalogue_ids(), character_catalogue_get))
    local_mocked_bindings(
      character_json = function(...) stop("Unexpected JSON read"),
      character_format_check = function(...) stop("Unexpected character check")
    )
    expect_identical(mascot_palettes("knurl")$name, c("original", names(data$palettes)))
    expect_match(mascot_characters()$palettes[mascot_characters()$id == "knurl"], "original, orbit")
    expect_identical(mascot_colour_roles("knurl", palette = "orbit")$colour[[1]], "#F8FAFC")
    expect_null(theme_palette_problem("orbit", data))
    expect_identical(as_theme_arg("orbit", environment(), "knurl")$palette_colours$light$body, "#F8FAFC")
  })
  it("accepts unclassed internal format data and checks the lookup input", {
    expect_identical(character_palettes(list()), character_object())
    for (value in list(NULL, 1, "", NA_character_)) {
      expect_error(character_palettes(value), "character")
    }
  })
})
