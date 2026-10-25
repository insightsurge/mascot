describe("mascot_colour_roles()", {
  it("names unknown characters and checks internal contracts", {
    expect_snapshot(error = TRUE, mascot_colour_roles("missing"))
  })
})
