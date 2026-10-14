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
    data$format_version <- 2
    format_problem("version", "$.format_version", character_format_parse(data))
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
    expect_error(character_format_node(1, 1, "$", list()))
    expect_error(character_format_node(1, list(), 1, list()))
    expect_error(character_format_node(1, list(), "$", 1))
    expect_error(character_format_node(1, list(), "$", list(), json_source = NA))
  })
})
