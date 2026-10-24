describe("character_format_parse()", {
  it("checks versions and required capabilities with zero-based paths", {
    data <- format_recipe()
    for (version in c(2, 99, 100000, 0, -1)) {
      data$format_version <- version
      error <- format_problem("version", "$.format_version", character_format_parse(data))
      expect_identical(error$value, version)
      expected <- if (version > 1) {
        paste0(
          "This file is format version ",
          format(version, scientific = FALSE),
          "; this mascot version supports 1. Update the package, or use a version-1 file."
        )
      } else {
        paste0(
          "Format version ",
          version,
          " is not a supported version; this mascot version supports 1. Use a version-1 file."
        )
      }
      expect_identical(error$fix, expected)
      expect_snapshot(message(conditionMessage(error)))
    }
    data$format_version <- NULL
    format_problem("input_type", "$.format_version", character_format_parse(data))
    data <- format_recipe()
    data$requires[[5]] <- "particles"
    format_problem("capability", "$.requires[4]", character_format_parse(data))
    data$requires <- list("parts", "parts")
    format_problem("input_type", "$.requires", character_format_parse(data))
  })
})
