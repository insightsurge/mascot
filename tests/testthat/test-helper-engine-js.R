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

describe("page_character_blocks()", {
  it("returns each built-in character's head block once and nothing for a custom character", {
    bot <- mascot_character(mascot_read_character(
      system.file("examples", "characters", "study_bot.json", package = "mascot")
    ))
    tags <- list(mascot("a"), mascot("b"), mascot("c", character = "sela"), mascot("d", character = bot))
    expect_identical(
      page_character_blocks(tags),
      c(character_dependency("tessa")$head, character_dependency("sela")$head)
    )
    expect_length(page_character_blocks(list(mascot("d", character = bot))), 0)
    expect_error(page_character_blocks("a"), "Assertion on 'tags' failed")
  })
})
