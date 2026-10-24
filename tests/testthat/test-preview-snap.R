describe("mascot_preview()", {
  it("warns once, keeps colours and lists independent contrast findings in R and on the page", {
    expect_snapshot({
      page <- mascot_preview(mood = "idle", theme = list(body = "white"))
    })
  })
  it("shares build-time errors for every shortcut and malformed helper", {
    expect_snapshot(error = TRUE, mascot_preview(character = "typo"))
    expect_snapshot(error = TRUE, mascot_preview(mood = "typo"))
    expect_snapshot(error = TRUE, mascot_preview(theme = list(eye_whit = "red")))
  })
})
