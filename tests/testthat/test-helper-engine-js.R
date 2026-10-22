describe("page_exception_message()", {
  it("uses the description of an error", {
    details <- list(text = "Uncaught", exception = list(description = "Error: boom\n    at <anonymous>:1:7"))
    expect_identical(page_exception_message(details), "Error: boom\n    at <anonymous>:1:7")
  })

  it("uses the text and the thrown value when a value that is not an error was thrown", {
    details <- list(text = "Uncaught", exception = list(type = "string", value = "x"))
    expect_identical(page_exception_message(details), "Uncaught: x")
    expect_identical(page_exception_message(list(text = "Uncaught", exception = list(type = "object"))), "Uncaught")
  })

  it("never returns an empty message", {
    expect_match(page_exception_message(list()), "not an error", fixed = TRUE)
    expect_match(page_exception_message(list(text = "", exception = list(description = ""))), "not an error")
  })
})
