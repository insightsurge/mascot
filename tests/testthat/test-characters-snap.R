describe("mascot_character()", {
  it("names unknown choices and rejects invalid strings", {
    expect_snapshot(error = TRUE, mascot_character("unknown_character"))
  })
})
