describe("mascot_character()", {
  it("names unknown choices and rejects invalid strings", {
    expect_snapshot(error = TRUE, mascot_character("unknown_character"))
    for (x in list(1, NULL, NA_character_, character(), c("tessa", "tessa"), "")) {
      expect_error(mascot_character(x), "Assertion on 'id' failed")
    }
    expect_error(mascot_character("{oops"), "not a character", fixed = TRUE)
  })
})
