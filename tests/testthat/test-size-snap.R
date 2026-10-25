describe("mascot_size()", {
  it("rejects every invalid size with a useful message naming valid forms", {
    expect_snapshot(error = TRUE, mascot_size("24px"))
    expect_snapshot(error = TRUE, mascot_size(23))
    expect_snapshot(error = TRUE, mascot_size(120, small_screen = "bad"))
  })
})
