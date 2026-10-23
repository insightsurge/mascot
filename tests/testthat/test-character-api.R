describe("character authoring arguments and internal helpers", {
  it("keeps register and save internal and supplies argument conditions", {
    fns <- c("mascot_register_character", "mascot_save_character")
    expect_false(any(fns %in% getNamespaceExports("mascot")))
    path <- file.path(withr::local_tempdir(), "out.json")
    checked <- mascot_read_character(system.file("examples", "characters", "study_bot.json", package = "mascot"))
    cases <- list(
      list(function(x) mascot_check_character(x), "x", list(NULL, 1, NA_character_, c("{}", "{}"))),
      list(function(x) mascot_read_character(x), "path", list(NULL, "", 1, NA_character_, c("x", "y"))),
      list(function(x) mascot_register_character(x), "x", list(NULL, list(), "bot")),
      list(function(x) mascot_save_character(x, path), "x", list(NULL, list(), "bot")),
      list(function(x) mascot_save_character(checked, x), "path", list(NULL, "", 1, c("x", "y"))),
      list(
        function(x) mascot_save_character(checked, path, overwrite = x),
        "overwrite",
        list(NULL, NA, 1, c(TRUE, FALSE))
      )
    )
    for (case in cases) {
      for (value in case[[3]]) {
        error <- tryCatch(case[[1]](value), error = identity)
        expect_s3_class(error, "mascot_error_argument")
        expect_s3_class(error, "mascot_error")
        expect_identical(error$argument, case[[2]])
        expect_identical(error$value, value)
        expect_identical(error$code, "argument")
        expect_match(conditionMessage(error), case[[2]], fixed = TRUE)
      }
    }
    expect_error(mascot_check_character(), class = "mascot_error_argument")
    expect_error(mascot_read_character(), class = "mascot_error_argument")
    expect_error(mascot_register_character(), class = "mascot_error_argument")
    expect_error(mascot_save_character(), class = "mascot_error_argument")
    expect_error(mascot_save_character(checked), class = "mascot_error_argument")
    expect_error(character_api_asserts(TRUE, NULL, NULL), "argument")
    error <- tryCatch(mascot_save_character(checked, path, extra = TRUE), error = identity)
    expect_s3_class(error, "mascot_error_dots")
    expect_s3_class(error, "mascot_error")
    expect_identical(error$names, "extra")
    unnamed <- tryCatch(mascot_save_character(checked, path, TRUE), error = identity)
    expect_s3_class(unnamed, "mascot_error_dots")
    expect_identical(unnamed$names, "unnamed")
    expect_match(conditionMessage(unnamed), "must be named", fixed = TRUE)
    expect_match(conditionMessage(unnamed), "overwrite = TRUE", fixed = TRUE)
  })
})

describe("mascot_read_character() and mascot_check_character()", {
  it("reads the shipped starter character with its own wave and nod gestures, not fallbacks", {
    path <- system.file("examples", "characters", "study_bot.json", package = "mascot", mustWork = TRUE)
    playable <- attr(mascot_read_character(path), "mascot_manifest")$playable
    expect_identical(playable$wave, "wave")
    expect_identical(playable$nod, "nod")
  })

  it("accepts local files, JSON, lists and objects visibly without modifying input or registering", {
    local_empty_registry()
    path <- system.file("examples", "characters", "study_bot.json", package = "mascot", mustWork = TRUE)
    plain <- jsonlite::read_json(path)
    before <- serialize(plain, NULL)
    file <- withVisible(mascot_read_character(path))
    expect_true(file$visible)
    text <- paste(readLines(path), collapse = "\n")
    for (x in list(plain, text, file$value)) {
      checked <- withVisible(mascot_check_character(x))
      expect_true(checked$visible)
      expect_identical(attr(checked$value, "mascot_manifest")$identity, attr(file$value, "mascot_manifest")$identity)
    }
    expect_identical(serialize(plain, NULL), before)
    expect_length(character_data_ids(), 0)
    expect_error(mascot_check_character(path), class = "mascot_error_character")
    expect_error(mascot_read_character("https://example.invalid/bot.json"), class = "mascot_error_file")
    expect_error(mascot_read_character(file.path(dirname(path), "*.json")), class = "mascot_error_file")
  })

  it("points file inputs to the local reader without guessing that they are JSON", {
    dir <- withr::local_tempdir()
    existing <- file.path(dir, "recipe")
    writeLines("{}", existing)
    for (input in c(existing, file.path(dir, "missing.json"), "missing.JSON")) {
      error <- tryCatch(mascot_check_character(input), error = identity)
      expect_s3_class(error, "mascot_error_character")
      expect_identical(error$code, "input_type")
      expect_identical(error$path, "$")
      expect_identical(error$value, input)
      expect_match(conditionMessage(error), "mascot_read_character(path)", fixed = TRUE)
    }
  })

  it("explains reserved built-in ids at check time", {
    plain <- format_recipe("study_bot")
    plain$id <- "tessa"
    error <- tryCatch(mascot_check_character(plain), error = identity)
    expect_s3_class(error, "mascot_error_character")
    expect_identical(error$code, "identity")
    expect_identical(error$path, "$.id")
    expect_identical(error$value, "tessa")
    expect_match(
      conditionMessage(error),
      '"tessa" is a built-in character; give your character its own id.',
      fixed = TRUE
    )
  })

  it("reports missing files and directories with exact paths and file fields", {
    dir <- withr::local_tempdir()
    for (path in c(file.path(dir, "missing.json"), dir)) {
      error <- tryCatch(mascot_read_character(path), error = identity)
      expect_s3_class(error, "mascot_error_file")
      expect_s3_class(error, "mascot_error")
      expect_identical(error$path, path)
      expect_identical(error$operation, "read")
      expect_identical(error$code, "io")
      expect_match(conditionMessage(error), path, fixed = TRUE)
      expect_match(
        conditionMessage(error),
        if (identical(path, dir)) "is a directory" else "File does not exist",
        fixed = TRUE
      )
      expect_false(grepl("Assertion|doTryCatch|Caused by", conditionMessage(error)))
      expect_null(error$parent)
    }
  })

  it("rejects excessive bytes, bad JSON, duplicate keys, reserved capabilities and drawing budgets", {
    dir <- withr::local_tempdir()
    path <- file.path(dir, "input.json")
    plain <- format_recipe("study_bot")
    reserved <- plain
    reserved$requires <- c(reserved$requires, "wardrobe")
    budget <- character_format_resolve(format_recipe())
    budget$parts[[1]]$items <- rep(budget$parts[[1]]$items, 31)
    for (index in seq_along(budget$parts[[1]]$items)) {
      budget$parts[[1]]$items[[index]]$id <- paste0("item_", index)
    }
    budget$lod$micro$hide <- list()
    cases <- list(
      list(strrep(" ", character_format_policy()$input$utf8_bytes + 1L), "budget"),
      list("{", "input_type"),
      list('{"format_version":1,"format_version":1}', "input_type"),
      list(as.character(jsonlite::toJSON(reserved, auto_unbox = TRUE, null = "null")), "capability"),
      list(as.character(jsonlite::toJSON(budget, auto_unbox = TRUE, null = "null")), "budget")
    )
    for (case in cases) {
      writeLines(case[[1]], path)
      for (run in list(function() mascot_read_character(path), function() mascot_check_character(case[[1]]))) {
        error <- tryCatch(run(), error = identity)
        expect_s3_class(error, "mascot_error_character")
        expect_s3_class(error, "mascot_error")
        expect_identical(error$code, case[[2]], info = paste(error$path, error$fix))
        expect_match(error$path, "^\\$")
        expect_true("value" %in% names(error))
        expect_type(error$fix, "character")
        expect_true(nzchar(error$fix))
      }
    }
    # The same structural and byte ceilings apply before semantic checking.
    plain$description <- strrep("x", character_format_policy()$input$utf8_bytes + 1L)
    expect_error(mascot_check_character(plain), class = "mascot_error_character")
  })

  it("refuses valid edits and invalid edits to checked data at every consumer boundary", {
    bot <- mascot_check_character(format_recipe("study_bot"))
    bot$name <- "Edited but valid"
    for (fn in list(
      mascot_check_character,
      mascot_register_character,
      mascot_moods,
      mascot_gestures,
      mascot_colour_roles,
      mascot_anchors,
      mascot_palettes,
      mascot_preview,
      function(x) mascot("helper", character = x),
      function(x) mascot_save_character(x, file.path(withr::local_tempdir(), "out.json"))
    )) {
      expect_error(fn(bot), class = "mascot_error_character")
    }
    bot$moods$idle$status <- ""
    expect_error(mascot_check_character(bot), class = "mascot_error_character")
  })

  it("prints a compact summary, with provenance, without JSON", {
    path <- system.file("examples", "characters", "study_bot.json", package = "mascot")
    bot <- mascot_read_character(path)
    text <- paste(capture.output(print(bot)), collapse = "\n")
    for (label in c("study_bot", "Study Bot", "visorfolk", "idle", "greet", "Detail overrides: micro\nFrom:", path)) {
      expect_match(text, label, fixed = TRUE)
    }
    expect_false(grepl('"format_version"', text, fixed = TRUE))
    local_empty_registry()
    object <- mascot_check_character(format_recipe("study_bot"))
    expect_match(paste(capture.output(print(object)), collapse = "\n"), "From: object", fixed = TRUE)
    mascot_register_character(object)
    registered <- character_data_get("study_bot")
    expect_match(paste(capture.output(print(registered)), collapse = "\n"), "From: registry", fixed = TRUE)
    plain <- format_recipe("study_bot")
    plain$lod <- NULL
    no_overrides <- mascot_check_character(plain)
    expect_match(
      paste(capture.output(print(no_overrides)), collapse = "\n"),
      "Detail overrides: none\nFrom: object",
      fixed = TRUE
    )
    plain$lod <- list(small = list(glow = FALSE), micro = list(glow = FALSE))
    both_bands <- mascot_check_character(plain)
    expect_match(
      paste(capture.output(print(both_bands)), collapse = "\n"),
      "Detail overrides: small, micro\nFrom: object",
      fixed = TRUE
    )
    # A note or an extension key in lod is not a band
    plain$lod <- list(micro = list(glow = FALSE), note = "Small sizes.", x_tool = 1)
    noted <- mascot_check_character(plain)
    expect_match(
      paste(capture.output(print(noted)), collapse = "\n"),
      "Detail overrides: micro\nFrom: object",
      fixed = TRUE
    )
    expect_identical(withVisible(print.mascot_character_data(bot))$visible, FALSE)
    expect_error(print.mascot_character_data(list()), "class")
    expect_error(print.mascot_character_data(bot, extra = TRUE), class = "mascot_error_character")
  })
})

describe("mascot_register_character()", {
  it("registers idempotently by resolved content, lists snapshots, and rejects conflicts", {
    local_empty_registry()
    plain <- format_recipe("study_bot")
    bot <- mascot_check_character(plain)
    registered <- withVisible(mascot_register_character(bot))
    expect_false(registered$visible)
    expect_identical(registered$value, "study_bot")
    mascot_register_character(mascot_check_character(plain[rev(names(plain))]))
    expect_identical(character_data_ids(), "study_bot")
    expect_identical(mascot_characters()$id, c("tessa", "sela", "knurl", "neer", "study_bot"))
    expect_identical(mascot_characters()$built_in, c(TRUE, TRUE, TRUE, TRUE, FALSE))
    plain$name <- "Other content"
    expect_error(mascot_register_character(mascot_check_character(plain)), class = "mascot_error_character")
    expect_error(mascot_register_character(character_catalogue_builtin("tessa")), class = "mascot_error_character")
    plain$id <- "study_two"
    plain$family_definition$name <- "Second snapshot label"
    mascot_register_character(mascot_check_character(plain))
    listing <- mascot_families()
    rows <- listing[listing$id == "visorfolk", ]
    expect_identical(rows$name, c("Visorfolk", "Visorfolk", "Second snapshot label"))
    expect_identical(rows$character, c(NA_character_, "study_bot", "study_two"))
    embedded <- format_recipe("study_bot")
    embedded$id <- "study_hex"
    embedded$family <- "hexonians"
    embedded$family_definition$id <- "hexonians"
    embedded$family_definition$name <- "Uploaded Hexonians"
    mascot_register_character(mascot_check_character(embedded))
    families <- mascot_families()
    expect_identical(families$name[[1]], "Hexonians")
    expect_identical(families$name[families$character %in% "study_hex"], "Uploaded Hexonians")
    # A registered snapshot never becomes another source's family defaults.
    plain$id <- "no_snapshot"
    plain$family <- "visorfolk"
    plain$family_definition <- NULL
    expect_error(mascot_check_character(plain), class = "mascot_error_character")
  })

  it("refuses registration in an active Shiny domain and recommends passing the object", {
    local_empty_registry()
    bot <- mascot_check_character(format_recipe("study_bot"))
    shiny::testServer(function(input, output, session) {}, {
      error <- tryCatch(mascot_register_character(bot), error = identity)
      expect_s3_class(error, "mascot_error_character")
      expect_identical(error$code, "registry")
      expect_match(error$fix, "pass the checked object", fixed = TRUE)
      expect_identical(error$path, "$")
      expect_identical(conditionMessage(error), error$fix)
      expect_false(startsWith(conditionMessage(error), "$:"))
    })
    expect_length(character_data_ids(), 0)
  })
})

describe("mascot_save_character()", {
  it("round-trips resolved identity, metadata and palette sources, invisibly", {
    path <- file.path(withr::local_tempdir(), "bot.json")
    bot <- mascot_check_character(format_recipe("study_bot"))
    saved <- withVisible(mascot_save_character(bot, path))
    expect_false(saved$visible)
    expect_identical(saved$value, path)
    again <- mascot_read_character(path)
    expect_identical(attr(again, "mascot_manifest")$identity, attr(bot, "mascot_manifest")$identity)
    expect_identical(again$family_definition, bot$family_definition)
    expect_identical(again$palette_sources, bot$palette_sources)
    expect_identical(again$face$kit_definition, bot$face$kit_definition)
    expect_true(again$resolved)
  })

  it("refuses overwrite, reports exact paths, and cleans failed atomic writes", {
    dir <- withr::local_tempdir()
    path <- file.path(dir, "bot.json")
    writeLines("original", path)
    bot <- mascot_check_character(format_recipe("study_bot"))
    error <- tryCatch(mascot_save_character(bot, path), error = identity)
    expect_s3_class(error, "mascot_error_file")
    expect_s3_class(error, "mascot_error")
    expect_identical(error$path, path)
    expect_identical(error$operation, "save")
    expect_identical(error$code, "exists")
    expect_identical(readLines(path), "original")
    mascot_save_character(bot, path, overwrite = TRUE)
    expect_identical(mascot_read_character(path)$id, bot$id)
    before <- readBin(path, "raw", file.info(path)$size)
    testthat::local_mocked_bindings(character_file_replace = function(temporary, path) FALSE)
    error <- tryCatch(mascot_save_character(bot, path, overwrite = TRUE), error = identity)
    expect_s3_class(error, "mascot_error_file")
    expect_identical(error$path, path)
    expect_identical(error$code, "io")
    expect_identical(readBin(path, "raw", file.info(path)$size), before)
    expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE), "bot.json")
  })

  it("checks serialised output before replacement and retains the original on validation failure", {
    dir <- withr::local_tempdir()
    path <- file.path(dir, "bot.json")
    writeLines("original", path)
    bot <- mascot_check_character(format_recipe("study_bot"))
    testthat::local_mocked_bindings(character_json_write = function(x) "{}")
    expect_error(mascot_save_character(bot, path, overwrite = TRUE), class = "mascot_error_character")
    expect_identical(readLines(path), "original")
    expect_identical(list.files(dir), "bot.json")
  })

  it("refuses serialised valid content with a different identity before replacing a file", {
    dir <- withr::local_tempdir()
    path <- file.path(dir, "bot.json")
    writeLines("original", path)
    bot <- mascot_check_character(format_recipe("study_bot"))
    other <- format_recipe("study_bot")
    other$name <- "Different valid content"
    text <- character_json_write(mascot_check_character(other))
    testthat::local_mocked_bindings(character_json_write = function(x) text)
    error <- tryCatch(mascot_save_character(bot, path, overwrite = TRUE), error = identity)
    expect_s3_class(error, "mascot_error_character")
    expect_identical(error$code, "identity")
    expect_identical(readLines(path), "original")
    expect_identical(list.files(dir), "bot.json")
  })

  it("classifies output path failures as file problems", {
    bot <- mascot_check_character(format_recipe("study_bot"))
    path <- file.path(withr::local_tempdir(), "missing", "out.json")
    error <- tryCatch(mascot_save_character(bot, path), error = identity)
    expect_s3_class(error, "mascot_error_file")
    expect_identical(error$path, path)
    expect_identical(error$operation, "save")
    expect_identical(error$code, "path")
  })
})

describe("one character resolver at all authoring consumers", {
  it("supports ids, helpers and checked objects, with target-specific names", {
    local_empty_registry()
    plain <- format_recipe("study_bot")
    plain$moods$reviewing <- plain$moods$thinking
    plain$moods$reviewing$fallback <- "thinking"
    bot <- mascot_check_character(plain)
    mascot_register_character(bot)
    for (fn in list(mascot_moods, mascot_gestures, mascot_colour_roles, mascot_anchors, mascot_palettes)) {
      expected <- fn(bot)
      for (form in list("study_bot", mascot_character("study_bot"), bot)) {
        expect_identical(fn(form), expected)
      }
      expect_error(fn("missing_character"), "study_bot")
    }
    for (form in list("study_bot", mascot_character("study_bot"), bot)) {
      tag <- mascot("helper", character = form, mood = mascot_mood("reviewing"), theme = list(screen = "#051b20"))
      expect_identical(tag$attribs$`data-character`, "study_bot")
      page <- as.character(mascot_preview(form))
      expect_match(page, "reviewing", fixed = TRUE)
      expect_match(page, "Study Bot preview", fixed = TRUE)
      expect_match(page, "#051b20", fixed = TRUE) # character's authored palette remains in resolved JSON
      expect_error(mascot("bad", character = form, mood = "missing"), "reviewing")
    }
    unknown <- tryCatch(mascot_preview("missing_character"), error = identity)
    expect_s3_class(unknown, "mascot_error_choice")
    expect_s3_class(unknown, "mascot_error")
    expect_identical(unknown$argument, "character")
    expect_identical(unknown$choices, c("tessa", "sela", "knurl", "neer", "study_bot"))
    expect_identical(unknown$value, "missing_character")
    session <- shiny::MockShinySession$new()
    withr::defer(session$close())
    for (form in list("study_bot", mascot_character("study_bot"), bot)) {
      update_mascot(
        "helper",
        character = form,
        mood = "reviewing",
        gesture = mascot_gesture("greet"),
        session = session
      )
      expect_identical(mascot_id_state(session, "helper")$desired$mood, "reviewing")
    }
    update_mascot("helper", theme = list(screen = "#051b20"), session = session)
    expect_identical(mascot_id_state(session, "helper")$desired$theme$light$screen, "#051B20")
    edited <- plain
    edited$name <- "Different content under the same id"
    expect_warning(update_mascot("helper", character = mascot_check_character(edited), session = session), "unchanged")
    expect_identical(mascot_id_state(session, "helper")$context$data$name, "Study Bot")
    bot$name <- "Mutated"
    expect_warning(
      update_mascot("helper", character = bot, session = session),
      "unchanged",
      class = "mascot_update_ignored"
    )
    expect_identical(mascot_id_state(session, "helper")$context$data$name, "Study Bot")
  })

  it("runs the offline authoring examples and has an installed format guide", {
    local_empty_registry()
    # Source tree during development; the installed help database under R CMD check and coverage (no man/ there).
    root <- test_path("..", "..")
    db <- if (dir.exists(file.path(root, "man"))) tools::Rd_db(dir = root) else tools::Rd_db("mascot")
    for (fn in c(
      "mascot_check_character",
      "mascot_read_character"
    )) {
      rd <- db[[paste0(fn, ".Rd")]]
      expect_false(is.null(rd), info = fn)
      code <- paste(capture.output(tools::Rd2ex(rd)), collapse = "\n")
      expect_no_error(eval(parse(text = code), new.env(parent = globalenv())))
    }
    expect_true("mascot_character_format.Rd" %in% names(db))
  })
})

describe("printing a checked character", {
  it("formats compactly and wraps print assertion failures", {
    x <- mascot_check_character(format_recipe("study_bot"))
    text <- format(x)
    expect_type(text, "character")
    expect_length(text, 5)
    expect_match(text[[1]], "study_bot: Study Bot", fixed = TRUE)
    expect_identical(capture.output(print(x)), text)
    expect_error(print.mascot_character_data(list()), class = "mascot_error")
    expect_error(format.mascot_character_data(list()), class = "mascot_error")
  })
})


describe("public character readers", {
  it("exports only read and check and runs the offline public route", {
    exports <- readLines(system.file("NAMESPACE", package = "mascot", mustWork = TRUE))
    for (fn in c("mascot_read_character", "mascot_check_character")) {
      expect_true(paste0("export(", fn, ")") %in% exports)
    }
    path <- system.file("examples", "characters", "study_bot.json", package = "mascot")
    bot <- mascot::mascot_read_character(path)
    checked <- mascot::mascot_check_character(jsonlite::read_json(path))
    expect_s3_class(bot, "mascot_character_data")
    expect_identical(bot$id, checked$id)
    expect_false(any(c("mascot_register_character", "mascot_save_character") %in% getNamespaceExports("mascot")))
  })
})
