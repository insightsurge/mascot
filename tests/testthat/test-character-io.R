describe("character_save() and character_read()", {
  it("round-trips the complete small character unchanged", {
    # Given a character built in R and checked
    checked <- character_check(author_study_bot())
    path <- file.path(withr::local_tempdir(), "study_bot.json")
    # When it is saved, read and checked again
    expect_identical(character_save(checked, path), path)
    restored <- character_read(path)
    # Then values, identity, family metadata and palette provenance are unchanged
    expect_equal(unclass(restored), unclass(checked))
    expect_identical(attr(restored, "mascot_manifest")$identity, attr(checked, "mascot_manifest")$identity)
    expect_identical(restored$family_definition, checked$family_definition)
    expect_identical(restored$palette_sources, checked$palette_sources)
    expect_identical(restored$palette_sources$night_screen, "family")
    expect_identical(restored$palette_sources$sea_glass, "character")
    expect_identical(unclass(character_check(path, from = "file")), unclass(restored))
    # And saving the restored data again writes identical text
    again <- file.path(dirname(path), "again.json")
    character_save(restored, again)
    expect_identical(readLines(again), readLines(path))
  })

  it("keeps singleton arrays, empty objects and null endpoints in the saved text", {
    checked <- character_check(author_study_bot())
    path <- file.path(withr::local_tempdir(), "study_bot.json")
    character_save(checked, path)
    saved <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    expect_identical(saved$gestures$nod$needs, list("nod_joint"))
    expect_identical(saved$lod$micro$hide, list("badge_disc"))
    expect_true(saved$resolved)
    expect_identical(saved$family_definition$defaults, setNames(list(), character()))
    expect_identical(saved$face$kit_definition$id, "screen")
    expect_type(saved$palette_sources, "list")
  })

  it("round-trips a character with a null palette opt-out and a null track endpoint", {
    face_rows <- list(list(0, NULL), list(0.5, "wide", "step"), list(1, NULL))
    track <- character_author_track("face.mouth", face_rows)
    gesture <- character_author_gesture("talk", "Moves the mouth.", 18, list(track))
    draft <- author_study_bot()
    draft$gestures$talk <- gesture$value
    draft$palettes["night_screen"] <- list(NULL)
    checked <- character_check(draft)
    expect_false("night_screen" %in% names(checked$palettes))
    path <- file.path(withr::local_tempdir(), "talk.json")
    character_save(checked, path)
    restored <- character_read(path)
    expect_equal(unclass(restored), unclass(checked))
    keys <- restored$gestures$talk$tracks$face.mouth$keys
    expect_null(keys[[1]][[2]])
    expect_identical(keys[[2]][[3]], "step")
  })

  it("refuses to replace an existing file unless asked and leaves it untouched", {
    checked <- character_check(author_study_bot())
    path <- file.path(withr::local_tempdir(), "study_bot.json")
    writeLines("keep me", path)
    error <- tryCatch(character_save(checked, path), mascot_error_file = identity)
    expect_s3_class(error, "mascot_error_file")
    expect_s3_class(error, "mascot_error")
    expect_identical(error$path, path)
    expect_identical(error$operation, "save")
    expect_identical(readLines(path), "keep me")
    character_save(checked, path, overwrite = TRUE)
    expect_identical(character_read(path)$id, "study_bot")
    expect_identical(list.files(dirname(path)), "study_bot.json")
  })

  it("reports a denied write with the exact path and removes its temporary file", {
    skip_on_os("windows")
    skip_if(identical(Sys.info()[["user"]], "root"), "root can write to read-only folders")
    checked <- character_check(author_study_bot())
    folder <- withr::local_tempdir()
    Sys.chmod(folder, "555")
    withr::defer(Sys.chmod(folder, "755"))
    path <- file.path(folder, "study_bot.json")
    error <- tryCatch(character_save(checked, path), error = identity)
    expect_true(inherits(error, "mascot_error_file") || inherits(error, "simpleError"))
    expect_false(file.exists(path))
    expect_length(list.files(folder, all.files = TRUE, no.. = TRUE), 0)
  })

  it("refuses unchecked data and unwritable folders", {
    path <- file.path(withr::local_tempdir(), "study_bot.json")
    expect_error(character_save(unclass(author_study_bot()), path), "class")
    expect_error(character_save(character_check(author_study_bot()), file.path(path, "missing", "x.json")), "path")
    expect_error(character_save(character_check(author_study_bot()), path, overwrite = NA), "overwrite")
    format_problem("unknown_key", "$", character_save(character_check(author_study_bot()), path, "extra"))
  })

  it("rejects a hand-edited checked object instead of trusting its class", {
    checked <- character_check(author_study_bot())
    checked$moods$idle$status <- ""
    path <- file.path(withr::local_tempdir(), "study_bot.json")
    expect_error(character_save(checked, path), class = "mascot_error_character")
    expect_false(file.exists(path))
  })

  it("reads a registered character by id and never guesses between a file and an id", {
    before <- character_data_snapshot()
    withr::defer(character_data_reset(before))
    character_data_reset()
    checked <- character_check(author_study_bot())
    character_data_register(checked)
    expect_identical(character_read("study_bot", from = "id")$id, "study_bot")
    expect_error(character_read("study_bot"), class = "mascot_error_file")
    expect_error(character_read("study_bot", from = "path"), "from")
    expect_error(character_read("", from = "id"), "x")
    format_problem("missing_reference", "$.id", character_read("nobody", from = "id"))
  })
})

describe("character_check()", {
  it("accepts a source specification, raw list, JSON text, file and checked data", {
    checked <- character_check(author_study_bot())
    expect_s3_class(checked, "mascot_character_data")
    text <- character_json_write(checked)
    expect_identical(character_check(text, from = "text")$id, "study_bot")
    expect_identical(character_check(jsonlite::fromJSON(text, simplifyVector = FALSE))$id, "study_bot")
    expect_identical(
      attr(character_check(checked), "mascot_manifest")$identity,
      attr(checked, "mascot_manifest")$identity
    )
  })

  it("never fixes an invalid source silently", {
    draft <- author_study_bot()
    draft$colours$screen <- "#ffffff"
    format_problem("invalid_colour", "$.contrast[0]", character_check(draft))
  })

  it("rejects a built-in id from a custom source", {
    spec <- unclass(author_study_bot())
    spec$id <- "tessa"
    format_problem("identity", "$.id", character_check(spec))
  })

  it("asserts its arguments", {
    expect_error(character_check(1), "x")
    expect_error(character_check(list(), from = "xml"), "from")
    expect_error(character_check(list(), families = 1), "families")
    format_problem("unknown_key", "$", character_check(list(), mode = "fast"))
  })
})

describe("character_json_write()", {
  it("requires checked data", {
    expect_error(character_json_write(list()), "class")
  })
})
