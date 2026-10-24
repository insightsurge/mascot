describe("mascot_example()", {
  it("checks every argument and names valid examples for unknown names", {
    expect_snapshot(error = TRUE, mascot_example("typo", run = FALSE))
  })
})
