describe("mascot_theme()", {
  it("warns once per supplied role and mode without altering low-contrast colours", {
    withr::local_options(mascot.contrast_warnings = TRUE)
    expect_snapshot(
      value <- as_theme_arg(mascot_theme(light = list(body = "white"), dark = list(rim = "#212529")), environment())
    )
  })
})
