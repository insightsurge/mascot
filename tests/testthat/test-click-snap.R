describe("mascot_action()", {
  it("rejects values caught by `...`, including a flag given by position", {
    expect_snapshot(error = TRUE, mascot_action("Open help", FALSE, href = "#help"))
  })
  it("prints a recreating call without defaults", {
    expect_snapshot(print(mascot_action("Open help")))
  })
})

describe("the click argument", {
  it("rejects a named vector of menu choices with a hint to wrap it in mascot_popup_menu()", {
    expect_snapshot(error = TRUE, mascot(id = "helper", click = c(help = "Help", about = "About")))
  })
  it("rejects anything but one non-empty label or a helper", {
    expect_snapshot(error = TRUE, mascot(id = "helper", click = TRUE))
  })
})
