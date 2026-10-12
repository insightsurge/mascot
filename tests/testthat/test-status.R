describe("mascot_status()", {
  it("keeps a NULL text element and accepts plain text", {
    expect_identical(mascot_status(), structure(list(text = NULL), class = "mascot_status"))
    expect_length(mascot_status(), 1)
    expect_identical(mascot_status("Saving")$text, "Saving")
  })
  it("rejects empty text and non-strings", {
    for (x in list("", 1, NA_character_, character(), c("one", "two"))) {
      expect_error(mascot_status(x), "Assertion on 'text' failed")
    }
  })
  it("removes the HTML class so markup is shown as text", {
    text <- mascot_status(htmltools::HTML("<b>Saving</b>"))$text
    expect_identical(text, "<b>Saving</b>")
    expect_false(inherits(text, "html"))
  })
})


describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_status(text = 1), "text", class = "mascot_error")
  })
  it("adds mascot_error to the registered format and print methods", {
    expect_error(format.mascot_status(1), "x", class = "mascot_error")
    expect_error(print.mascot_status(1), "x", class = "mascot_error")
  })
})
