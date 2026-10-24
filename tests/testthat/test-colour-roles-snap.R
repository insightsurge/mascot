describe("mascot_colour_roles()", {
  it("names unknown characters and checks internal contracts", {
    expect_snapshot(error = TRUE, mascot_colour_roles("missing"))
    for (x in list(NULL, 1, "", NA_character_, c("tessa", "tessa"))) {
      expect_error(mascot_colour_roles(x), "Assertion on 'character' failed")
    }
    expect_error(character_colour_data("missing"), "must be one of", class = "mascot_error_choice")
    expect_error(colour_role_registry("missing"), "must be one of", class = "mascot_error_choice")
  })
})
