describe("mascot_theme()", {
  it("warns once per supplied role and mode without altering low-contrast colours", {
    withr::local_options(mascot.contrast_warnings = TRUE)
    expect_snapshot(
      value <- as_theme_arg(mascot_theme(light = list(body = "white"), dark = list(rim = "#212529")), environment())
    )
    expect_identical(value$light$body, "#FFFFFF")
    expect_identical(value$dark$rim, "#212529")
    expect_equal(theme_contrast("black", "white"), 21)
    expect_equal(theme_contrast("rgba(0,0,0,0)", "white"), 1)
    expect_equal(theme_contrast("#212529", "#212529"), 1)
    expect_no_warning(as_theme_arg(mascot_theme(), environment()))
  })
})
