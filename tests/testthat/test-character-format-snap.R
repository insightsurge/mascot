describe("character_format_parse()", {
  it("checks versions and required capabilities with zero-based paths", {
    data <- format_recipe()
    for (version in c(2, 99, 100000, 0, -1)) {
      data$format_version <- version
      error <- format_problem("version", "$.format_version", character_format_parse(data))
      expect_snapshot(message(conditionMessage(error)))
    }
  })
})
