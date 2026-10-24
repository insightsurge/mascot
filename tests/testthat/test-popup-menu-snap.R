describe("mascot_popup_menu()", {
  it("rejects every invalid item, id, label and tooltip value with the argument named", {
    expect_snapshot(error = TRUE, mascot_popup_menu(c("bad id" = "Help")))
  })
  it("rejects values caught by `...`, including a direction given by position", {
    expect_snapshot(error = TRUE, mascot_popup_menu(c(a = "A"), "top", extra = TRUE))
  })
  it("rejects invalid directions and malformed helpers with snapshots", {
    expect_snapshot(error = TRUE, mascot_popup_menu(direction = "center"))
  })
})
