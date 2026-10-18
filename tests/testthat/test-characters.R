describe("mascot_character()", {
  it("selects Tessa by default or explicitly", {
    expect_identical(mascot_character(), mascot_character("tessa"))
    expect_s3_class(mascot_character(), "mascot_character")
    expect_identical(unclass(mascot_character()), list(id = "tessa", name = "Tessa"))
  })
  it("shows the selected id in a recreating call, including registered characters", {
    local_empty_registry()
    plain <- format_recipe("study_bot")
    plain$id <- "lab_buddy"
    mascot_register_character(mascot_check_character(plain))
    for (id in c("tessa", "lab_buddy")) {
      helper <- mascot_character(id)
      expect_identical(format(helper), paste0('mascot_character("', id, '")'))
      expect_identical(eval(parse(text = format(helper))), helper)
      expect_identical(capture.output(print(helper)), format(helper))
      expect_invisible(print(helper))
    }
  })
  it("names unknown choices and rejects invalid strings", {
    expect_snapshot(error = TRUE, mascot_character("unknown_character"))
    for (x in list(1, NULL, NA_character_, character(), c("tessa", "tessa"), "")) {
      expect_error(mascot_character(x), "Assertion on 'id' failed")
    }
    expect_error(mascot_character("{oops"), "not a character", fixed = TRUE)
  })
})

describe("character_json()", {
  it("reads valid JSON and escapes closing script sequences", {
    skip_if_not_installed("jsonlite")
    text <- character_json("tessa")
    expect_type(text, "character")
    expect_length(text, 1)
    expect_identical(jsonlite::fromJSON(text)$id, "tessa")
    expect_false(grepl("</", text, fixed = TRUE))
    # The real character has no closing tag: inject one at the text-reading seam.
    local_mocked_bindings(readLines = function(...) '{"text":"</script></div>"}', .package = "base")
    escaped <- character_json("tessa")
    expect_identical(escaped, '{"text":"<\\/script><\\/div>"}')
    expect_identical(jsonlite::fromJSON(escaped)$text, "</script></div>")
  })
  it("keeps every built-in character's moods in the shared order", {
    skip_if_not_installed("jsonlite")
    for (id in builtin_characters()$id) {
      expect_identical(names(jsonlite::fromJSON(character_json(id))$moods), mascot_moods()$name)
    }
    expect_error(character_json("missing"), "Assertion on 'id' failed")
  })
})

describe("abort_choice()", {
  it("checks its internal contract", {
    expect_error(abort_choice(1, "idle", "mood", "mood", environment()), "'value'")
    expect_error(abort_choice("bad", NA_character_, "mood", "mood", environment()), "'valid'")
    expect_error(abort_choice("bad", "idle", 1, "mood", environment()), "'arg'")
    expect_error(abort_choice("bad", "idle", "mood", 1, environment()), "'what'")
    expect_error(abort_choice("bad", "idle", "mood", "mood", NULL), "'call'")
  })
})


describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_character(id = 1), "id", class = "mascot_error")
  })
  it("adds mascot_error to the registered format and print methods", {
    expect_error(format.mascot_character(1), "x", class = "mascot_error")
    expect_error(print.mascot_character(1), "x", class = "mascot_error")
  })
})

describe("shipped palette roles and contrast", {
  it("sets only existing leader roles and keeps the silhouette and face above 3:1 on a light page", {
    for (id in builtin_characters()$id) {
      data <- character_colour_data(id)
      for (palette in c("original", names(data$palettes))) {
        for (mode in c("light", "dark")) {
          roles <- names(data$palettes[[palette]][[mode]])
          expect_true(all(roles %in% names(data$colours)), info = paste(id, palette, mode))
          expect_length(intersect(roles, names(data$follows)), 0)
        }
        colours <- mascot_colour_roles(id, palette = palette)
        colour <- stats::setNames(colours$colour, colours$role)
        second <- intersect(c("outline_second", "outline_light"), names(colour))
        edge <- max(c(
          theme_contrast(colour[["outline"]], colour[["body"]]),
          vapply(second, function(role) theme_contrast(colour[[role]], colour[["body"]]), numeric(1))
        ))
        expect_gte(edge, 3, label = paste(id, palette, "body edge"))
        expect_gte(theme_contrast(colour[["outline"]], "#ffffff"), 3, label = paste(id, palette, "page edge"))
        face <- if (id == "knurl") {
          "screen"
        } else if (id == "neer") {
          "eye_white"
        } else {
          "body"
        }
        expect_gte(theme_contrast(colour[["feature"]], colour[[face]]), 3, label = paste(id, palette, "face"))
        if (id == "neer") {
          expect_gte(theme_contrast(colour[["brow"]], colour[["body"]]), 3, label = paste(id, palette, "brows"))
        }
        # Knurl's visor is a gradient: both ends must keep face features readable.
        if (id == "knurl") {
          expect_gte(
            theme_contrast(colour[["feature"]], colour[["screen_glow"]]),
            3,
            label = paste(id, palette, "visor glow")
          )
        }
      }
    }
  })
})
