describe("mascot_colour_roles()", {
  it("lists description colours in order with snake case and brand slots", {
    value <- mascot_colour_roles()
    expect_identical(value, mascot_colour_roles("tessa"))
    expect_s3_class(value, "data.frame")
    expect_named(value, c("role", "colour", "brand_slot"))
    expect_equal(nrow(value), 20)
    expect_identical(value$role[3], "eye_white")
    expect_identical(value$role[9], "body_highlight")
    expect_identical(value$colour[value$role == "body"], "#3f8a66")
    expect_identical(value$brand_slot[value$role == "body"], "primary")
    expect_identical(value$role[value$brand_slot %in% "secondary"], c("rim", "accessory"))
    expect_true(all(is.na(value$brand_slot[!value$role %in% c("body", "rim", "accessory")])))
    description <- character_colour_data("tessa")
    expect_identical(unname(unlist(description$colours)), value$colour)
    expect_identical(colour_role_registry(), colour_role_registry("tessa"))
    expect_identical(colour_role_registry(), value$role)
  })
  it("names unknown characters and checks internal contracts", {
    expect_snapshot(error = TRUE, mascot_colour_roles("missing"))
    for (x in list(NULL, 1, "", NA_character_, c("tessa", "tessa"))) {
      expect_error(mascot_colour_roles(x), "Assertion on 'character' failed")
    }
    expect_error(character_colour_data("missing"), "'id'")
    expect_error(colour_role_names(NA_character_), "'names'")
    expect_error(colour_role_registry("missing"), "'character'")
    expect_identical(colour_role_names(character()), character())
  })
})
