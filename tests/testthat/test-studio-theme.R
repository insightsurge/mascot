# The theme view of the studio app (mascot_studio("theme")) in brief: the tests CRAN runs. Its detailed tests are in
# test-studio-theme-extended.R and its browser tests in test-studio-theme-browser.R.
describe("the theme view, in brief", {
  it("draws its page with the preview, the code and no duplicate ids", {
    page <- theme_parts()$page
    expect_match(page, "<title>Theme a mascot</title>", fixed = TRUE)
    for (id in c("character", "mood", "theme_code", "theme_mascot")) {
      expect_match(page, paste0('id="', id, '"'), fixed = TRUE, info = id)
    }
    expect_unique_ids(page)
  })
  it("keeps the code in step with a palette picked from the cards", {
    shiny::testServer(theme_parts()$env$theme_view_server, {
      session$setInputs(character = "tessa", mood = "idle", code_style = "short")
      expect_identical(output$theme_code, 'mascot("helper")')
      session$setInputs(palette_grid = "coral_navy")
      expect_identical(output$theme_code, 'mascot("helper", theme = "coral_navy")')
    })
  })
})
