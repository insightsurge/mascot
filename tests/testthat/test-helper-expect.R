describe("expect_near()", {
  it("passes within the absolute distance and fails beyond it, naming both values", {
    expect_success(expect_near(9, 8, 1))
    expect_success(expect_near(c(7.5, 8.5), c(8, 8), 0.5))
    # A relative tolerance of 1 would accept 15 for 8; this check does not.
    expect_failure(expect_near(15, 8, 1), "is 15, not within 1 of 8")
    expect_failure(expect_near(-8, 8, 1))
  })
  it("checks its arguments", {
    expect_error(expect_near("8", 8, 1), "object")
    expect_error(expect_near(8, c(8, 9), 1), "expected")
    expect_error(expect_near(8, 8, -1), "within")
  })
})
describe("expect_unique_ids()", {
  it("passes when two bslib tab sets draw the same number, and fails on any other repeated id", {
    skip_if_not_installed("bslib")
    # Given two tab sets made to share one random number, as bslib does about once in 9,000 pages
    tabs <- function() as.character(bslib::navset_tab(bslib::nav_panel("A", "a"), bslib::nav_panel("B", "b")))
    first <- tabs()
    second <- tabs()
    number <- function(html) regmatches(html, regexpr("(?<=data-tabsetid=\")[0-9]+", html, perl = TRUE))
    second <- gsub(number(second), number(first), second, fixed = TRUE)
    page <- paste(first, second, '<div id="code_tray_body"></div>')
    expect_match(page, paste0('id="tab-', number(first), '-1".*id="tab-', number(first), '-1"'))
    # Then the generated ids do not fail the check, while a repeated id of the page's own still does
    expect_success(expect_unique_ids(page))
    expect_failure(
      expect_unique_ids(paste(page, '<p id="code_tray_body"></p>')),
      "These ids appear more than once: code_tray_body."
    )
    expect_failure(expect_unique_ids('<a id="tab-panel"></a><b id="tab-panel"></b>'), "tab-panel")
  })
  it("checks its argument", {
    expect_error(expect_unique_ids(c("a", "b")), "html")
  })
})
