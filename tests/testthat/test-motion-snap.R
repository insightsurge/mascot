describe("mascot_motion_settings()", {
  it("rejects every invalid flag and extra argument with mascot_error", {
    expect_snapshot(error = TRUE, as_motion_arg("sometimes", environment()))
  })

  it("prints only the supplied settings and returns the helper invisibly", {
    expect_snapshot(print(mascot_motion_settings(messages = "menu", others = FALSE)))
  })
})
