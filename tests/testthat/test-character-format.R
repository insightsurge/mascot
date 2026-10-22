describe("character_format_parse()", {
  it("reads each canonical structural recipe without claiming semantic acceptance", {
    for (id in c("anchor_probe", "tessa", "alpha_visor", "study_bot")) {
      file <- test_path("fixtures", "format", paste0(id, ".json"))
      parsed <- character_format_parse(file, from = "file")
      expect_identical(parsed$id, id)
      expect_type(parsed, "list")
      expect_false(inherits(parsed, "mascot_character_data"))
    }
  })

  it("defaults absent part and kit glow alpha to one for objects, text and files", {
    data <- format_recipe("alpha_visor")
    index <- which(vapply(data$parts, function(part) !is.null(part$glow), logical(1)))[[1]]
    data$parts[[index]]$glow$alpha <- NULL
    data$face$kit_definition$glow$alpha <- NULL
    text <- as.character(jsonlite::toJSON(data, auto_unbox = TRUE, null = "null", digits = NA))
    file <- withr::local_tempfile(fileext = ".json")
    writeLines(text, file)
    for (from in c("list", "text", "file")) {
      input <- switch(from, list = data, text = text, file = file)
      parsed <- character_format_parse(input, from)
      expect_equal(parsed$parts[[index]]$glow$alpha, 1)
      expect_equal(parsed$face$kit_definition$glow$alpha, 1)
    }
    for (value in list(0, 0.4, 1)) {
      data$parts[[index]]$glow$alpha <- value
      data$face$kit_definition$glow$alpha <- value
      parsed <- character_format_parse(data)
      expect_identical(parsed$parts[[index]]$glow$alpha, value)
      expect_identical(parsed$face$kit_definition$glow$alpha, value)
    }
    for (value in list(NULL, -0.1, 1.1, "1")) {
      for (target in c("part", "kit")) {
        bad <- data
        if (target == "part") {
          bad$parts[[index]]$glow["alpha"] <- list(value)
          path <- paste0("$.parts[", index - 1L, "].glow.alpha")
        } else {
          bad$face$kit_definition$glow["alpha"] <- list(value)
          path <- "$.face.kit_definition.glow.alpha"
        }
        format_problem("input_type", path, character_format_parse(bad))
      }
    }
  })

  it("never preserves a caller's checked class or arbitrary attributes", {
    data <- format_recipe()
    class(data) <- c("mascot_character_data", "list")
    attr(data, "untrusted") <- new.env(parent = emptyenv())
    parsed <- character_format_parse(data)
    expect_false(inherits(parsed, "mascot_character_data"))
    expect_null(attr(parsed, "untrusted"))
  })

  it("preserves JSON empty maps, empty arrays, singleton arrays and nullable fields", {
    data <- character_format_parse(test_path("fixtures", "format", "anchor_probe.json"), from = "file")
    expect_identical(names(data$palette_sources), character())
    expect_null(names(data$parts))
    expect_length(data$parts, 1)
    expect_true("face" %in% names(data))
    expect_null(data$face)
    data$wear <- list()
    parsed <- character_format_parse(data)
    expect_identical(parsed$wear, list())
    data$parts[[1]]$items <- list()
    data$gestures$rock$tracks <- list(
      panel.variant = list(mode = "set", keys = list(list(0, NULL), list(0.4, "raised", "step"), list(1, NULL)))
    )
    parsed <- character_format_parse(data)
    expect_length(parsed$gestures$rock$tracks$panel.variant$keys[[1]], 2)
    expect_null(parsed$gestures$rock$tracks$panel.variant$keys[[1]][[2]])
    expect_null(parsed$gestures$rock$tracks$panel.variant$keys[[3]][[2]])
  })

  it("accepts schema-typed singleton R vectors without accepting JSON scalars as arrays", {
    data <- format_recipe()
    data$requires <- "parts"
    expect_identical(character_format_parse(data)$requires, list("parts"))
    text <- jsonlite::toJSON(data, auto_unbox = TRUE, null = "null")
    format_problem("input_type", "$.requires", character_format_parse(as.character(text), "text"))
    data$requires <- c("parts", "tracks")
    data$parts[[1]]$at <- c(0, -60)
    expect_identical(character_format_parse(data)$parts[[1]]$at, list(0, -60))
  })

  it("rejects repeated decoded keys before jsonlite can discard an earlier value", {
    for (text in c('{"format_version":1,"format_version":1}', '{"format_version":1,"\\u0066ormat_version":1}')) {
      format_problem("input_type", "$.format_version", character_format_parse(text, "text"))
    }
    format_problem(
      "input_type",
      "$.ground.centre_height",
      character_format_parse('{"ground":{"centre_height":1,"centre_height":2}}', "text")
    )
    data <- format_recipe()
    names(data)[[2]] <- "format_version"
    format_problem("input_type", "$.format_version", character_format_parse(data))
  })

  it("does not count quoted braces or escaped quotes as containers", {
    data <- format_recipe()
    data$description <- paste0(strrep("[", 100), ' a "quoted" note ', strrep("}", 100))
    text <- as.character(jsonlite::toJSON(data, auto_unbox = TRUE, null = "null"))
    expect_identical(character_format_parse(text, "text")$description, data$description)
  })

  it("bounds bytes, lexical depth and nodes before constructing the input tree", {
    format_problem("budget", "$", character_format_parse(strrep(" ", 262145), "text"))
    format_problem("budget", "$", character_format_parse(paste0(strrep("[", 33), "0", strrep("]", 33)), "text"))
    format_problem(
      "budget",
      "$",
      character_format_parse(paste0("[", paste(rep("0", 10000), collapse = ","), "]"), "text")
    )
    schema <- character_format_schema()
    # Container depth includes the root; scalar leaves add no container level.
    nested <- character_format_json(charToRaw(paste0(strrep("[", 32), "0", strrep("]", 32))), schema$input)
    for (index in seq_len(32)) {
      nested <- nested[[1]]
    }
    expect_identical(nested, 0L)
    expect_length(
      character_format_json(charToRaw(paste0("[", paste(rep("0", 9999), collapse = ","), "]")), schema$input),
      9999
    )
    huge <- list(note = as.list(rep(0, 10000)))
    format_problem("budget", "$", character_format_parse(huge))
  })

  it("rejects invalid UTF-8, malformed JSON, non-finite and missing input values", {
    schema <- character_format_schema()
    format_problem("input_type", "$", character_format_json(as.raw(c(123, 255, 125)), schema$input))
    format_problem("input_type", "$", character_format_json(as.raw(c(123, 0, 125)), schema$input))
    for (text in c("", "{", '{"x":1,}', "[NaN]", "[Infinity]")) {
      format_problem("input_type", "$", character_format_parse(text, "text"))
    }
    format_problem(
      "non_finite",
      "$.ground.centre_height",
      character_format_parse('{"ground":{"centre_height":1e400}}', "text")
    )
    data <- format_recipe()
    data$parts[[1]]$at <- c(0, -Inf)
    format_problem("non_finite", "$.parts[0].at[1]", character_format_parse(data))
    data <- format_recipe()
    data$name <- NA_character_
    format_problem("input_type", "$.name", character_format_parse(data))
  })

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

  it("enforces closed nested schemas and local types/ranges", {
    data <- format_recipe()
    data$parts[[1]]$connector <- "other"
    format_problem("capability", "$.parts[0].connector", character_format_parse(data))
    data <- format_recipe()
    data$parts[[1]]$custom_behavior <- TRUE
    format_problem("unknown_key", "$.parts[0].custom_behavior", character_format_parse(data))
    data <- format_recipe()
    data$parts[[1]]$items[[1]]$width <- TRUE
    format_problem("input_type", "$.parts[0].items[0].width", character_format_parse(data))
    data <- format_recipe()
    data$gestures$rock$frames <- 151
    format_problem("budget", "$.gestures.rock.frames", character_format_parse(data))
    data <- format_recipe()
    data$parts[[1]]$items[[1]]$shape <- "particles"
    format_problem("capability", "$.parts[0].items[0].shape", character_format_parse(data))
    data <- format_recipe()
    data$face <- "none"
    format_problem("input_type", "$.face", character_format_parse(data))
    data <- format_recipe()
    data$family <- NULL
    format_problem("input_type", "$.family", character_format_parse(data))
  })

  it("leaves assembled references and core-mood completeness to R1c", {
    data <- format_recipe()
    data$anchors$badge$part <- "missing_arm"
    data$parts[[1]]$items[[1]]$fill <- "missing_colour"
    data$moods$celebrating <- NULL
    expect_identical(character_format_parse(data)$anchors$badge$part, "missing_arm")
  })

  it("reports file errors with the supplied path and operation", {
    missing <- file.path(tempdir(), "missing-character-file.json")
    error <- tryCatch(character_format_parse(missing, "file"), mascot_error_file = identity)
    expect_s3_class(error, "mascot_error_file")
    expect_identical(error$path, missing)
    expect_identical(error$operation, "read")
  })

  it("checks its internal arguments and typed-node boundary", {
    expect_error(character_format_parse(function() NULL))
    expect_error(character_format_parse(list(), from = "url"))
    expect_error(character_format_abort(1, "$"))
    expect_error(character_format_abort("input_type", 1))
    expect_error(character_format_abort("input_type", "$", fix = 1))
    expect_error(character_format_bounds(list(), max_depth = 0))
    expect_error(character_format_bounds(list(), max_nodes = 0))
    expect_error(character_format_json("{}", list()))
    expect_error(character_format_json(raw(), 1))
  })

  it("strips caller attributes from scalar fields and numeric_tree fields", {
    data <- format_recipe("tessa")
    attr(data$name, "custom") <- "custom_attribute"
    data$face$tune <- matrix(c(1, 2, 3, 4), nrow = 2L, dimnames = list(c("r1", "r2"), c("c1", "c2")))
    parsed <- character_format_parse(data)
    expect_null(attributes(parsed$name))
    expect_identical(parsed$name, "Tessa")
    expect_null(attributes(parsed$face$tune))
    expect_identical(parsed$face$tune, c(1, 2, 3, 4))
  })

  it("enforces utf8_bytes limit at boundary and one byte above", {
    data <- format_recipe()
    json <- as.character(jsonlite::toJSON(data, auto_unbox = TRUE, null = "null"))
    pad_ok <- paste0(json, strrep(" ", 262144L - nchar(json)))
    parsed <- character_format_parse(pad_ok, "text")
    expect_identical(parsed$id, data$id)
    pad_over <- paste0(json, strrep(" ", 262145L - nchar(json)))
    format_problem("budget", "$", character_format_parse(pad_over, "text"))
  })

  it("enforces declared_parts limit on parts array at boundary and one above", {
    data <- format_recipe()
    part_tmpl <- data$parts[[1]]
    data$parts <- lapply(seq_len(256L), function(i) {
      p <- part_tmpl
      p$id <- paste0("part_", i)
      p
    })
    parsed <- character_format_parse(data)
    expect_length(parsed$parts, 256L)
    data$parts[[257L]] <- part_tmpl
    data$parts[[257L]]$id <- "part_257"
    format_problem("budget", "$.parts", character_format_parse(data))
  })

  it("enforces moods limit at boundary and one above", {
    data <- format_recipe()
    mood_tmpl <- data$moods[[1]]
    moods_64 <- list()
    for (i in seq_len(64L)) {
      moods_64[[paste0("mood_", i)]] <- mood_tmpl
    }
    data$moods <- moods_64
    parsed <- character_format_parse(data)
    expect_length(parsed$moods, 64L)
    data$moods[["mood_65"]] <- mood_tmpl
    format_problem("budget", "$.moods", character_format_parse(data))
  })

  it("enforces gestures limit at boundary and one above", {
    data <- format_recipe()
    gesture_tmpl <- data$gestures[[1]]
    gestures_128 <- list()
    for (i in seq_len(128L)) {
      gestures_128[[paste0("gesture_", i)]] <- gesture_tmpl
    }
    data$gestures <- gestures_128
    parsed <- character_format_parse(data)
    expect_length(parsed$gestures, 128L)
    data$gestures[["gesture_129"]] <- gesture_tmpl
    format_problem("budget", "$.gestures", character_format_parse(data))
  })

  it("enforces keys_per_track limit at boundary and one above", {
    data <- format_recipe()
    keys_64 <- lapply(seq(0, 1, length.out = 64L), function(t) list(t, 0))
    data$gestures$rock$tracks <- list("panel.rotate" = keys_64)
    parsed <- character_format_parse(data)
    expect_length(parsed$gestures$rock$tracks$panel.rotate, 64L)
    keys_65 <- lapply(seq(0, 1, length.out = 65L), function(t) list(t, 0))
    data$gestures$rock$tracks <- list("panel.rotate" = keys_65)
    format_problem("budget", "$.gestures.rock.tracks.panel.rotate", character_format_parse(data))
  })

  it("enforces tracks_per_gesture limit at boundary and one above", {
    data <- format_recipe()
    tracks_256 <- list()
    for (i in seq_len(256L)) {
      tracks_256[[paste0("panel.rotate_", i)]] <- list(list(0, 0), list(1, 0))
    }
    data$gestures$rock$tracks <- tracks_256
    parsed <- character_format_parse(data)
    expect_length(parsed$gestures$rock$tracks, 256L)
    tracks_256[["panel.rotate_257"]] <- list(list(0, 0), list(1, 0))
    data$gestures$rock$tracks <- tracks_256
    format_problem("budget", "$.gestures.rock.tracks", character_format_parse(data))
  })

  it("reports the specific problem inside the matching union alternative", {
    data <- format_recipe()
    data$parts[[1]]$items[[1]]$fill <- list(paint = "glaze", bogus = 1)
    format_problem("unknown_key", "$.parts[0].items[0].fill.bogus", character_format_parse(data))
    data$parts[[1]]$items[[1]]$fill <- list(colour = "body")
    format_problem("input_type", "$.parts[0].items[0].fill.paint", character_format_parse(data))
    data$parts[[1]]$items[[1]]$fill <- TRUE
    format_problem("input_type", "$.parts[0].items[0].fill", character_format_parse(data))
  })

  it("enforces container depth, non-executable data, and UTF-8 string contracts", {
    # Non-list, non-atomic, non-null value (e.g. environment or symbol)
    data <- format_recipe()
    data$note <- as.symbol("executable_symbol")
    format_problem("input_type", "$.note", character_format_parse(data))

    # Container depth limit
    format_problem(
      "budget",
      "$",
      character_format_bounds(list(list(list(1))), max_depth = 2)
    )

    # Invalid UTF-8 text in character vector
    bad_utf8 <- rawToChar(as.raw(c(0xc0, 0xaf)))
    data <- format_recipe()
    data$description <- bad_utf8
    format_problem("input_type", "$.description", character_format_parse(data))
    format_problem("input_type", "$", character_format_parse(bad_utf8, "text"))

    # Data frame is rejected by checkmate before list parsing
    expect_error(character_format_parse(data.frame(id = "test")))

    # JSON array root instead of object
    format_problem("input_type", "$", character_format_parse("[1, 2, 3]", "text"))
  })

  it("checks discriminator operations, map key patterns, choices, and numeric trees", {
    # Discriminator field missing
    data <- format_recipe()
    data$parts[[1]]$items[[1]] <- list(id = "test_item", x = 0, y = 0)
    format_problem("input_type", "$.parts[0].items[0].shape", character_format_parse(data))

    # Map key pattern mismatch (colour role names must match regex)
    data <- format_recipe()
    data$colours[["Invalid-Colour-Key"]] <- "#ffffff"
    format_problem("input_type", "$.colours.Invalid-Colour-Key", character_format_parse(data))

    # Choices mismatch (e.g. track mode)
    data <- format_recipe()
    data$gestures$rock$tracks[[1]]$mode <- "invalid_mode"
    format_problem("input_type", "$.gestures.rock.tracks.root.rotate.mode", character_format_parse(data))

    # String pattern mismatch (character id format)
    data <- format_recipe()
    data$id <- "Invalid_ID_With_Caps"
    format_problem("input_type", "$.id", character_format_parse(data))
    data$id <- "invalid__id"
    error <- format_problem("input_type", "$.id", character_format_parse(data))
    expect_match(error$fix, "without consecutive underscores", fixed = TRUE)
    data <- format_recipe()
    data$colours[["invalid__role"]] <- "#ffffff"
    error <- format_problem("input_type", "$.colours.invalid__role", character_format_parse(data))
    expect_match(error$fix, "without consecutive underscores", fixed = TRUE)

    # Numeric tree containing nested lists for tuning
    data <- format_recipe("study_bot")
    data$face$tune <- list(eyes = list(open = list(rx = list(1, 2))))
    parsed <- character_format_parse(data)
    expect_identical(parsed$face$tune$eyes$open$rx, list(1, 2))
  })
})

describe("track structure and numeric-tree normalisation", {
  it("distinguishes too few track keys from exceeding the key budget", {
    for (keys in list(list(), list(list(0, 0)))) {
      data <- format_recipe()
      data$gestures$rock$tracks <- list("panel.rotate" = keys)
      format_problem("input_type", "$.gestures.rock.tracks.panel.rotate", character_format_parse(data))
      data$gestures$rock$tracks <- list("panel.rotate" = list(mode = "set", keys = keys))
      format_problem("input_type", "$.gestures.rock.tracks.panel.rotate.keys", character_format_parse(data))
      kit_data <- format_recipe("study_bot")
      kit_data$face$kit_definition <- character_format_kits()$classic
      kit_data$face$kit_definition$effects$sweat$mode <- "track"
      kit_data$face$kit_definition$effects$sweat$tracks <- list(x = keys)
      format_problem("input_type", "$.face.kit_definition.effects.sweat.tracks.x", character_format_parse(kit_data))
    }
    data$gestures$rock$tracks$panel.rotate$keys <- lapply(seq(0, 1, length.out = 65), function(t) list(t, 0))
    format_problem("budget", "$.gestures.rock.tracks.panel.rotate.keys", character_format_parse(data))
  })

  it("rejects data frames and strips custom list attributes in numeric tuning trees", {
    data <- format_recipe("study_bot")
    data$face$tune <- data.frame(eyes = 1)
    format_problem("input_type", "$.face.tune", character_format_parse(data))
    data$face$tune <- structure(
      list(eyes = structure(list(1, 2), class = "caller_array")),
      class = "caller_tree",
      caller_note = "discard"
    )
    parsed <- character_format_parse(data)
    expect_identical(parsed$face$tune, list(eyes = list(1, 2)))
    encoded <- as.character(jsonlite::toJSON(parsed, auto_unbox = TRUE, null = "null", digits = NA))
    expect_equal(character_format_parse(encoded, "text")$face$tune, parsed$face$tune)
  })
})


describe("character format diagnostics", {
  it("explains the colour forms and retains the bad colour", {
    plain <- format_recipe("study_bot")
    for (value in list("not-a-hex", 42)) {
      plain$colours$body <- value
      error <- format_problem("input_type", "$.colours.body", character_format_parse(plain))
      expect_identical(error$value, value)
      for (form in c("#RGB", "#RRGGBB", "rgba(r, g, b, a)", "#3F82FF")) {
        expect_match(conditionMessage(error), form, fixed = TRUE)
      }
    }
    for (value in c("#abc", "#3F82FF", "rgba(63, 130, 255, 0.5)")) {
      plain$colours$body <- value
      expect_identical(character_format_parse(plain)$colours$body, value)
    }
  })

  it("bounds reference choice lists without losing the bad value or stable fields", {
    for (choices in list(paste0("part", 1:9), strrep("p", 161))) {
      error <- format_problem(
        "missing_reference",
        "$.part",
        character_format_abort(
          "missing_reference",
          "$.part",
          "typo",
          "Name a declared part.",
          choices = choices
        )
      )
      expect_match(conditionMessage(error), "typo", fixed = TRUE)
      expect_false(grepl("Valid choices", conditionMessage(error), fixed = TRUE))
      expect_identical(error$value, "typo")
    }
    expect_error(character_format_abort("missing_reference", "$", choices = 1), "choices")
    expect_error(character_format_abort("missing_reference", "$", choices = NA_character_), "choices")
  })
})

describe("version 1 for files written by people and other tools", {
  it("accepts a top-level $schema string, keeps it, and refuses it elsewhere or as another type", {
    data <- format_recipe()
    data$`$schema` <- "https://example.org/mascot/character-v1.json"
    expect_identical(character_format_parse(data)$`$schema`, data$`$schema`)
    text <- as.character(jsonlite::toJSON(data, auto_unbox = TRUE, null = "null", digits = NA))
    expect_identical(character_format_parse(text, "text")$`$schema`, data$`$schema`)
    data$`$schema` <- 1
    format_problem("input_type", "$.$schema", character_format_parse(data))
    data <- format_recipe()
    data$parts[[1]]$`$schema` <- "https://example.org/part.json"
    format_problem("unknown_key", "$.parts[0].$schema", character_format_parse(data))
  })

  it("keeps an x_ key in any fixed-field object as written, whatever its value, without checking it", {
    data <- format_recipe()
    value <- format_extension_value()
    data$x_tool <- value
    data$parts[[1]]$x_layer <- "locked"
    data$parts[[1]]$items[[1]]$x_hint <- list(1, "two", TRUE, NULL)
    data$outline$x_editor <- 3.5
    data$moods$happy$x_mood <- list()
    parsed <- character_format_parse(data)
    expect_identical(parsed$x_tool, value)
    expect_identical(parsed$parts[[1]]$x_layer, "locked")
    expect_identical(parsed$parts[[1]]$items[[1]]$x_hint, list(1, "two", TRUE, NULL))
    expect_identical(parsed$outline$x_editor, 3.5)
    expect_identical(parsed$moods$happy$x_mood, list())
    # The same file read as JSON text keeps every extension key too (JSON reads 1 back as an integer).
    text <- as.character(jsonlite::toJSON(data, auto_unbox = TRUE, null = "null", digits = NA))
    expect_equal(format_extension_paths(character_format_parse(text, "text")), format_extension_paths(parsed))
  })

  it("adds an x_ key to every fixed-field object of a whole character and still reads it", {
    data <- format_recipe("tessa")
    probed <- format_with_extensions(data)
    paths <- names(format_extension_paths(probed))
    # Fixed-field objects at several depths: the character, a part, an item, a mood and a gesture track.
    expect_true(all(c("$.x_probe", "$.parts[0].x_probe", "$.parts[0].items[0].x_probe") %in% paths))
    expect_true(any(grepl("^[$][.]moods[.]happy[.]x_probe$", paths)))
    expect_identical(format_extension_paths(character_format_parse(probed)), format_extension_paths(probed))
  })

  it("treats an x_ key in a map as an ordinary id, which is checked like any other", {
    data <- format_recipe()
    data$colours$x_red <- "#ff0000"
    expect_identical(character_format_parse(data)$colours$x_red, "#ff0000")
    data$colours$x_red <- "red"
    format_problem("input_type", "$.colours.x_red", character_format_parse(data))
  })

  it("makes requires optional and names an unknown capability, with the way out", {
    data <- format_recipe()
    data$requires <- NULL
    expect_null(character_format_parse(data)$requires)
    data$requires <- list()
    expect_identical(character_format_parse(data)$requires, list())
    data["requires"] <- list(NULL)
    format_problem("input_type", "$.requires", character_format_parse(data))
    data$requires <- list("parts", "teleport")
    error <- format_problem("capability", "$.requires[1]", character_format_parse(data))
    expect_identical(error$value, "teleport")
    expect_identical(
      error$fix,
      paste0(
        "This file needs the capability \"teleport\", which is not supported by this version of mascot. ",
        "Update mascot, or remove it from requires."
      )
    )
    data$requires <- list("morph")
    error <- format_problem("capability", "$.requires[0]", character_format_parse(data))
    expect_match(error$fix, "needs the capability \"morph\"", fixed = TRUE)
  })

  it("gives the value and its choices or range when a value is out of bounds", {
    data <- format_recipe()
    data$outline$cap <- "pointy"
    error <- format_problem("input_type", "$.outline.cap", character_format_parse(data))
    expect_identical(error$value, "pointy")
    expect_identical(error$fix, "Choose one of \"butt\", \"round\" or \"square\", not \"pointy\".")
    data <- format_recipe()
    data$ground$centre_height <- -5
    error <- format_problem("input_type", "$.ground.centre_height", character_format_parse(data))
    expect_identical(error$value, -5)
    expect_identical(error$fix, "Use a value of at least 0, not -5.")
    data <- format_recipe()
    data$parts[[1]]$items[[1]]$alpha <- 1.5
    error <- format_problem("input_type", "$.parts[0].items[0].alpha", character_format_parse(data))
    expect_identical(error$fix, "Use a value from 0 to 1, not 1.5.")
    data <- format_recipe()
    data$parts[[1]]$items[[1]]$shape <- "star"
    error <- format_problem("capability", "$.parts[0].items[0].shape", character_format_parse(data))
    expect_match(error$fix, "^Use a supported operation, not \"star\": choose one of .*\"circle\"")
  })

  it("words every kind of number range from the rule itself", {
    expect_identical(character_format_range(list(min = 0, max = 1)), "a value from 0 to 1")
    expect_identical(character_format_range(list(min = 0, exclusive_max = 1)), "a value of at least 0 and below 1")
    expect_identical(character_format_range(list(exclusive_min = 0, max = 30)), "a value above 0 and at most 30")
    expect_identical(character_format_range(list(max = 0.5)), "a value of at most 0.5")
    expect_identical(character_format_shown(TRUE), "true")
    expect_identical(character_format_shown(0.1 + 0.2), "0.3")
    expect_identical(character_format_choices("only"), "\"only\"")
    expect_error(character_format_range(1))
    expect_error(character_format_shown(list()))
    expect_error(character_format_choices(list()))
  })

  it("refuses a kit effect fade_at of 1, which the engine cannot fade at", {
    schema <- character_format_schema()
    kit <- jsonlite::fromJSON(
      system.file("format", "kits", "classic.json", package = "mascot", mustWork = TRUE),
      simplifyVector = FALSE
    )
    effect <- kit$effects$sweat
    effect$fade_at <- 0.99
    expect_identical(
      character_format_node(effect, schema$definitions$kit_effect, "$.e", schema$definitions)$fade_at,
      0.99
    )
    effect$fade_at <- 1
    error <- format_problem(
      "input_type",
      "$.e.fade_at",
      character_format_node(effect, schema$definitions$kit_effect, "$.e", schema$definitions)
    )
    expect_identical(error$fix, "Use a value of at least 0 and below 1, not 1.")
  })
})

describe("the format policy file", {
  it("holds only limits and lists that the code reads", {
    policy <- character_format_policy()
    expect_named(
      policy,
      c("policy_version", "format_version", "status", "input", "capabilities", "reserved_unsupported", "bands"),
      ignore.order = TRUE
    )
    # Each input limit is read: the parser's three bounds, and the others through the schema's input_limit.
    schema_text <- paste(readLines(system.file("format", "character-v1.json", package = "mascot")), collapse = "\n")
    for (limit in setdiff(names(policy$input), c("utf8_bytes", "nesting_depth", "structural_nodes"))) {
      expect_match(schema_text, paste0("\"input_limit\": \"", limit, "\""), fixed = TRUE, info = limit)
    }
    # Each band lists exactly the drawing-work metrics that character_format_work() counts.
    data <- character_format_resolve(format_recipe())
    graph <- character_format_references(data)
    behaviour <- character_format_behaviour(data, graph)
    for (band in c("full", "small", "micro")) {
      expect_setequal(names(policy$bands[[band]]), names(character_format_work(data, graph, behaviour, band)))
    }
    expect_identical(
      attr(character_format_check(format_recipe()), "mascot_manifest")$policy_version,
      as.integer(policy$policy_version)
    )
  })
})
