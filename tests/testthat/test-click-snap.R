describe("mascot_action()", {
  it("rejects values caught by `...`, including a flag given by position", {
    expect_error(mascot_action("Open help", FALSE), "Unexpected arguments.*unnamed")
    expect_error(mascot_action("Open help", key = "h"), "Unexpected arguments.*key")
    expect_snapshot(error = TRUE, mascot_action("Open help", FALSE, href = "#help"))
  })
  it("prints a recreating call without defaults", {
    expect_snapshot(print(mascot_action("Open help")))
    expect_identical(format(mascot_action()), "mascot_action()")
  })
})

describe("the click argument", {
  it("rejects a named vector of menu choices with a hint to wrap it in mascot_popup_menu()", {
    expect_error(as_click_arg(c(help = "Help"), environment()), "named vector.*mascot_popup_menu\\(\\)")
    expect_snapshot(error = TRUE, mascot(id = "helper", click = c(help = "Help", about = "About")))
  })
  it("rejects anything but one non-empty label or a helper", {
    for (bad in list(TRUE, FALSE, 1, "", NA_character_, c("Help", "About"), list("Help"), character())) {
      expect_error(as_click_arg(bad, environment()), "click.*one non-empty label")
    }
    expect_snapshot(error = TRUE, mascot(id = "helper", click = TRUE))
  })
})
