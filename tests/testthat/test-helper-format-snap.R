describe("helper format and print methods", {
  it("prints every helper readably and returns it invisibly", {
    helpers <- list(
      mascot_character(),
      mascot_mood(),
      mascot_status("Saving"),
      mascot_bubble("Ready", duration = Inf),
      mascot_gesture("nod"),
      mascot_size("20%"),
      mascot_placement(),
      mascot_theme(light = list(body = "#c2185b")),
      mascot_motion_settings(others = FALSE),
      mascot_popup_menu(c(about = "About")),
      mascot_action("Open help")
    )
    for (helper in helpers) {
      expect_snapshot(print(helper))
    }
  })
})
