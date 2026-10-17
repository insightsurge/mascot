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
  it("keeps the shipped mood statuses equal to the shared status labels", {
    tessa <- character_catalogue_builtin("tessa")
    for (mood in mood_table()$name) {
      expect_identical(character_catalogue_status(tessa, mood), mood_label(mood))
      expect_identical(tessa$moods[[mood]]$description, mood_table()$description[mood_table()$name == mood])
    }
  })
})

describe("character_catalogue_ids() and character_catalogue_get()", {
  it("lists shipped ids first and registered ids in registration order", {
    local_empty_registry()
    expect_identical(character_catalogue_ids(), c("tessa", "sela", "knurl"))
    character_data_register(character_format_check(format_recipe("anchor_probe")))
    character_data_register(character_format_check(format_recipe("study_bot")))
    expect_identical(character_catalogue_ids(), c("tessa", "sela", "knurl", "anchor_probe", "study_bot"))
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
      character_catalogue_resolve("neer", environment()),
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
