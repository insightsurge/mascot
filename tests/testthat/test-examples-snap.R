describe("mascot_example()", {
  it("checks every argument and names valid examples for unknown names", {
    for (bad in list(NULL, NA_character_, "", 1, c("studio", "modules"))) {
      expect_error(mascot_example(bad, run = FALSE), "Assertion on 'name' failed")
    }
    for (bad in list(NULL, NA, 1, "FALSE", c(TRUE, FALSE))) {
      expect_error(mascot_example("studio", run = bad), "Assertion on 'run' failed")
    }
    expect_snapshot(error = TRUE, mascot_example("typo", run = FALSE))
  })
})
