describe("character_format_check()", {
  it("promotes only complete checked reference recipes and records derived evidence", {
    for (id in c("tessa", "alpha_visor", "study_bot", "anchor_probe")) {
      checked <- character_format_check(format_recipe(id))
      expect_s3_class(checked, "mascot_character_data")
      manifest <- attr(checked, "mascot_manifest")
      expect_identical(manifest$identity, character_format_identity(checked))
      expect_identical(manifest$format_version, 1L)
      expect_named(manifest$work, c("full", "small", "micro"))
      expect_true(all(vapply(manifest$fit, function(proof) proof$verified, logical(1))))
      if (id == "study_bot") expect_identical(manifest$playable$wave, "rock")
    }
  })

  it("reproduces the selected first diagnostic on all fourteen invalid recipes", {
    cases <- jsonlite::fromJSON(test_path("fixtures", "format", "diagnostic-expected.json"), simplifyVector = FALSE)
    expect_length(cases, 14)
    for (case in cases) {
      format_problem(
        case$code,
        case$path,
        character_format_check(test_path("fixtures", "format", case$file), from = "file")
      )
    }
  })

  it("rejects a mutated checked list and a forged class instead of trusting metadata", {
    checked <- character_format_check(format_recipe())
    checked$anchors$badge$part <- "missing_owner"
    format_problem("missing_reference", "$.anchors.badge.part", character_format_check(checked))
    forged <- format_recipe()
    forged$moods$happy <- NULL
    class(forged) <- c("mascot_character_data", "list")
    attr(forged, "mascot_manifest") <- list(identity = "claimed")
    format_problem("missing_reference", "$.moods.happy", character_format_check(forged))
  })

  it("rejects omitted used capabilities and unproved authored fit", {
    data <- format_recipe("tessa")
    data$requires <- setdiff(unlist(data$requires), "clip")
    format_problem("capability", "$.requires", character_format_check(data))
    data <- format_recipe()
    data$parts[[1]]$at <- list(180, -60)
    format_problem("budget", "$.frame_fit.full", character_format_check(data))
  })

  it("checks every argument before work", {
    expect_error(character_format_check(function() NULL))
    expect_error(character_format_check(list(), from = "url"))
    expect_error(character_format_check(list(), families = 1))
    expect_error(character_format_check(list(), kits = 1))
    expect_error(character_format_capabilities(1, list(), list()))
    expect_error(character_format_capabilities(list(), 1, list()))
    expect_error(character_format_capabilities(list(), list(), 1))
  })
})
