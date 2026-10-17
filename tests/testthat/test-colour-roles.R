describe("mascot_colour_roles()", {
  it("lists description colours in order with snake case and follow rules", {
    value <- mascot_colour_roles()
    expect_identical(value, mascot_colour_roles("tessa"))
    expect_s3_class(value, "data.frame")
    expect_named(value, c("role", "colour", "follows", "shade", "description", "brand"))
    expect_equal(nrow(value), 20)
    expect_identical(value$role[3], "eye_white")
    expect_identical(value$role[9], "body_highlight")
    expect_identical(value$colour[value$role == "body"], "#3f8a66")
    expect_identical(value$follows[value$role == "limb"], "rim, body")
    expect_identical(value$shade[value$role == "body_highlight"], "lighter")
    expect_identical(value$shade[value$role == "accessory_detail"], "darker")
    expect_identical(value$shade[value$role == "sleeve"], "same")
    expect_true(all(is.na(value$follows[value$role %in% c("body", "rim", "outline")])))
    description <- character_colour_data("tessa")
    expect_identical(unname(unlist(description$colours)), value$colour)
    expect_identical(colour_role_registry("tessa"), value$role)
    # With no character, the registry is every built-in's roles: Tessa's first, then the others' new ones.
    every <- unique(unlist(lapply(builtin_characters()$id, colour_role_registry)))
    expect_identical(colour_role_registry(), every)
    expect_identical(colour_role_registry()[seq_along(value$role)], value$role)
  })
  it("returns the same first four columns as the legacy reader of the shipped description", {
    # The checked recipe replaced the old file as the source; the output a user sees must not change.
    legacy <- character_colour_data("tessa")
    engine <- names(legacy$colours)
    follows <- shade <- rep(NA_character_, length(engine))
    for (role in names(legacy$follows)) {
      rule <- legacy$follows[[role]]
      follows[engine == role] <- paste(colour_role_names(unlist(rule$from)), collapse = ", ")
      shade[engine == role] <- if (is.null(rule$shade)) "same" else rule$shade
    }
    expected <- data.frame(
      role = colour_role_names(engine),
      colour = unname(unlist(legacy$colours)),
      follows = follows,
      shade = shade
    )
    expect_identical(mascot_colour_roles()[1:4], expected)
  })
  it("gives no built-in character a role named like a theme mode, so every role can be themed", {
    for (id in builtin_characters()$id) {
      expect_false(any(colour_role_registry(id) %in% c("light", "dark", "default")), info = id)
    }
    expect_true("lamp" %in% mascot_colour_roles("knurl")$role)
    expect_no_error(mascot_theme(light = list(lamp = "#ff0000"), dark = list(lamp_happy = "#00ff00")))
  })
  it("names unknown characters and checks internal contracts", {
    expect_snapshot(error = TRUE, mascot_colour_roles("missing"))
    for (x in list(NULL, 1, "", NA_character_, c("tessa", "tessa"))) {
      expect_error(mascot_colour_roles(x), "Assertion on 'character' failed")
    }
    expect_error(character_colour_data("missing"), "must be one of", class = "mascot_error_choice")
    expect_error(colour_role_names(NA_character_), "'names'")
    expect_error(colour_role_registry("missing"), "must be one of", class = "mascot_error_choice")
    expect_identical(colour_role_names(character()), character())
  })
})


describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_colour_roles(character = 1), "character", class = "mascot_error")
  })
})
