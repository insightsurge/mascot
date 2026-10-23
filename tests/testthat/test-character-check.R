describe("character_format_check()", {
  it("requires wave and nod tracks whose keyed values change", {
    data <- format_recipe()
    expect_s3_class(character_format_check(data), "mascot_character_data")

    missing_wave <- unserialize(serialize(data, NULL))
    missing_wave$gestures$wave <- NULL
    error <- format_problem("missing_reference", "$.gestures.wave", character_format_check(missing_wave))
    expect_match(conditionMessage(error), "required 'wave' gesture", fixed = TRUE)

    missing_nod <- unserialize(serialize(data, NULL))
    missing_nod$gestures$nod <- NULL
    error <- format_problem("missing_reference", "$.gestures.nod", character_format_check(missing_nod))
    expect_match(conditionMessage(error), "required 'nod' gesture", fixed = TRUE)

    root_wave <- format_recipe("study_bot")
    root_wave$gestures$wave$tracks <- list("root.rotate" = list(list(0, 0), list(0.5, 0.2), list(1, 0)))
    error <- format_problem("invalid_channel", "$.gestures.wave.tracks", character_format_check(root_wave))
    expect_match(conditionMessage(error), "wave' gesture must move at least one non-root part channel", fixed = TRUE)

    static_nod <- unserialize(serialize(data, NULL))
    static_nod$gestures$nod$tracks <- list("root.rotate" = list(list(0, 0), list(0.5, 0), list(1, 0)))
    error <- format_problem("invalid_channel", "$.gestures.nod.tracks", character_format_check(static_nod))
    expect_match(
      conditionMessage(error),
      "nod' gesture must move at least one track with changing keyed values",
      fixed = TRUE
    )
  })

  it("promotes only complete checked reference recipes and records derived evidence", {
    for (id in c("tessa", "alpha_visor", "study_bot", "anchor_probe")) {
      checked <- character_format_check(format_recipe(id), builtin = id %in% c("tessa", "alpha_visor"))
      expect_s3_class(checked, "mascot_character_data")
      manifest <- attr(checked, "mascot_manifest")
      expect_identical(manifest$identity, character_format_identity(checked))
      expect_identical(manifest$format_version, 1L)
      expect_named(manifest$work, c("full", "small", "micro"))
      expect_true(all(vapply(manifest$fit, function(proof) proof$verified, logical(1))))
      # fixtures/format/study_bot.json keeps the older gestures on purpose, to test the fallback route.
      if (id == "study_bot") expect_identical(manifest$playable$wave, "rock")
    }
  })

  it("checks and rereads omitted glow alpha with the same evidence as explicit one", {
    data <- format_recipe("alpha_visor")
    index <- which(vapply(data$parts, function(part) !is.null(part$glow), logical(1)))[[1]]
    data$parts[[index]]$glow$alpha <- 1
    data$face$kit_definition$glow$alpha <- 1
    explicit <- character_format_check(data, builtin = TRUE)
    data$parts[[index]]$glow$alpha <- NULL
    data$face$kit_definition$glow$alpha <- NULL
    implicit <- character_format_check(data, builtin = TRUE)
    expect_identical(character_format_identity(implicit), character_format_identity(explicit))
    expect_identical(attr(implicit, "mascot_manifest"), attr(explicit, "mascot_manifest"))
    plain <- character_format_parse(implicit)
    text <- as.character(jsonlite::toJSON(plain, auto_unbox = TRUE, null = "null", digits = NA))
    file <- withr::local_tempfile(fileext = ".json")
    writeLines(text, file)
    reread <- character_format_check(file, from = "file", builtin = TRUE)
    expect_identical(character_format_identity(character_format_parse(reread)), character_format_identity(plain))
    expect_identical(attr(reread, "mascot_manifest")$work, attr(explicit, "mascot_manifest")$work)
  })

  it("reproduces the selected first diagnostic on all twenty-four invalid recipes", {
    cases <- jsonlite::fromJSON(test_path("fixtures", "format", "diagnostic-expected.json"), simplifyVector = FALSE)
    expect_length(cases, 24)
    for (case in cases) {
      format_problem(
        case$code,
        case$path,
        character_format_check(test_path("fixtures", "format", case$file), from = "file")
      )
    }
  })

  it("rejects every reserved capability with code capability, its path and the version message", {
    cases <- jsonlite::fromJSON(test_path("fixtures", "format", "diagnostic-expected.json"), simplifyVector = FALSE)
    reserved <- Filter(function(case) identical(case$code, "capability"), cases)
    # One fixture per reserved name (particles keeps its original fixture); a new reserved name needs one too.
    fixture_names <- sub("^unsupported_", "", vapply(reserved, function(case) case$id, character(1)))
    expect_setequal(fixture_names, unlist(character_format_schema()$reserved_unsupported))
    for (case in reserved) {
      error <- format_problem(
        case$code,
        case$path,
        character_format_check(test_path("fixtures", "format", case$file), from = "file")
      )
      expect_match(conditionMessage(error), "not supported by this version of mascot", fixed = TRUE, info = case$id)
    }
  })

  it("keeps data-named keys such as a colour role called follow, which are not fields", {
    data <- format_recipe()
    data$colours$follow <- "#78c8a0"
    expect_identical(character_format_parse(data)$colours$follow, "#78c8a0")
  })

  it("verifies that invalid format fixtures isolate defects without accidental drift", {
    extract_leaves <- function(x, path = "$") {
      if (is.list(x) && length(x) > 0) {
        nms <- names(x)
        is_named <- !is.null(nms)
        unlist(
          lapply(seq_along(x), function(i) {
            child_path <- if (is_named) paste0(path, ".", nms[[i]]) else paste0(path, "[", i - 1L, "]")
            extract_leaves(x[[i]], child_path)
          }),
          recursive = FALSE
        )
      } else {
        res <- list(x)
        names(res) <- path
        res
      }
    }

    cases <- jsonlite::fromJSON(test_path("fixtures", "format", "diagnostic-expected.json"), simplifyVector = FALSE)
    ref_names <- c("anchor_probe.json", "alpha_visor.json", "study_bot.json", "study_bot-resolved.json", "tessa.json")
    ref_leaves <- lapply(ref_names, function(nm) {
      extract_leaves(jsonlite::fromJSON(test_path("fixtures", "format", nm), simplifyVector = FALSE))
    })
    names(ref_leaves) <- ref_names

    for (case in cases) {
      # duplicate_key.json is one line of raw text, not a copy of a reference recipe.
      if (case$id == "duplicate_key") {
        next
      }

      inv_data <- jsonlite::fromJSON(test_path("fixtures", "format", case$file), simplifyVector = FALSE)

      inv_leaves <- extract_leaves(inv_data)

      # Find the base fixture with the fewest differing leaf nodes
      scores <- vapply(
        ref_leaves,
        function(rleaves) {
          all_keys <- union(names(inv_leaves), names(rleaves))
          sum(vapply(all_keys, function(k) !identical(inv_leaves[[k]], rleaves[[k]]), logical(1)))
        },
        integer(1)
      )

      best_ref <- names(which.min(scores))
      best_leaves <- ref_leaves[[best_ref]]
      all_keys <- union(names(inv_leaves), names(best_leaves))
      diff_keys <- all_keys[vapply(all_keys, function(k) !identical(inv_leaves[[k]], best_leaves[[k]]), logical(1))]

      exp_path <- case$path
      # Assert each differing leaf lies under the expected diagnostic path.
      # Exception: unknown_track_target replaces the root.rotate track with ghost.rotate,
      # so the removed root.rotate leaves are an expected defect-introduction removal.
      is_under <- vapply(
        diff_keys,
        function(d) {
          d == exp_path || startsWith(d, paste0(exp_path, ".")) || startsWith(d, paste0(exp_path, "["))
        },
        logical(1)
      )

      if (case$id == "unknown_track_target") {
        is_removal_exception <- vapply(
          diff_keys,
          function(d) {
            startsWith(d, "$.gestures.rock.tracks.root.rotate")
          },
          logical(1)
        )
        is_under <- is_under | is_removal_exception
      }

      # The anchor probe now has the required non-root wave track; invalid
      # recipes based on it inherit that shared valid-track change.
      is_under <- is_under | startsWith(diff_keys, "$.gestures.wave.tracks.panel.rotate")

      expect_true(
        all(is_under),
        info = paste("File:", case$file, "Unexpected diff paths:", paste(diff_keys[!is_under], collapse = ", "))
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
    format_problem("capability", "$.requires", character_format_check(data, builtin = TRUE))
    data <- format_recipe()
    data$parts[[1]]$at <- list(180, -60)
    error <- format_problem("budget", "$.frame_fit.full", character_format_check(data))
    expect_identical(error$fix, "Keep every part, movement and effect inside the 300 by 300 frame at this size.")
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

describe("checked character provenance and first diagnostics", {
  it("rejects reserved ids on direct objects, text, files and forged checked objects", {
    for (id in character_data_reserved()) {
      data <- format_recipe("study_bot")
      data$id <- id
      format_problem("identity", "$.id", character_format_check(data))
    }
    data <- format_recipe("study_bot")
    data$id <- "neer"
    text <- as.character(jsonlite::toJSON(data, auto_unbox = TRUE, null = "null", digits = NA))
    format_problem("identity", "$.id", character_format_check(text, from = "text"))
    path <- withr::local_tempfile(fileext = ".json")
    writeLines(text, path)
    format_problem("identity", "$.id", character_format_check(path, from = "file"))
    class(data) <- c("mascot_character_data", "list")
    attr(data, "builtin") <- TRUE
    format_problem("identity", "$.id", character_format_check(data))
    expect_error(character_format_check(data, builtin = NA))
    expect_error(character_format_check(data, builtin = "yes"))
  })

  it("checks fit budgets before built-in contrast promises when both are broken", {
    data <- format_recipe("tessa")
    data$parts[[1]]$at <- list(1000, 1000)
    data$contrast <- list()
    format_problem("budget", "$.frame_fit.full", character_format_check(data, builtin = TRUE))
    data$parts[[1]]$at <- format_recipe("tessa")$parts[[1]]$at
    format_problem("invalid_colour", "$.contrast", character_format_check(data, builtin = TRUE))
  })

  it("rejects malformed nested inputs before callbacks can consume checked data", {
    data <- format_recipe()
    data$parts[[1]]$at <- list("bad", 0)
    format_problem("input_type", "$.parts[0].at[0]", character_format_check(data))
    data <- format_recipe()
    data$contrast <- list(list(fg = TRUE, bg = "body", min = 3))
    format_problem("input_type", "$.contrast[0].fg", character_format_check(data))
  })
})

describe("reserved names in fixed and data positions", {
  it("accepts reserved names used as data keys: a colour, a recolour role, a kit style id and a numeric tree key", {
    expect_no_error(character_format_parse(format_data_named_recipe()))
  })

  it("rejects a reserved key in a palette preset, not a palette id called colours", {
    data <- format_recipe()
    data$palettes <- list(
      colours = list(description = "A palette called colours.", light = list(body = "#000000"), vividness = 1)
    )
    format_problem("capability", "$.palettes.colours.vividness", character_format_parse(data))
  })

  it("reports the earlier structural error when a reserved key sits in a later part", {
    data <- format_recipe()
    bad <- list(id = "Bad Id", at = list(0, 0), layer = 1, items = list())
    data$parts <- c(list(bad), data$parts)
    data$parts[[2]]$follow <- list(target = "badge")
    format_problem("input_type", "$.parts[0].id", character_format_parse(data))
  })

  it("reports the structural error first when a top-level reserved key is written after it (JS differs here)", {
    # Documented difference: R walks every key in document order. compile() checks the top-level object first, so
    # the browser engine reports `$.extends` instead (test-engine-parts.R).
    data <- format_recipe()
    bad <- list(id = "Bad Id", at = list(0, 0), layer = 1, items = list())
    data$parts <- c(list(bad), data$parts)
    data$extends <- "tessa"
    format_problem("input_type", "$.parts[0].id", character_format_parse(data))
  })

  it("rejects a reserved key in a family default mood, where the family defaults are fixed", {
    data <- format_recipe()
    data$family_definition$defaults$moods <- list(
      happy = list(description = "Done.", status = "Done", channels = list(), follow = 1)
    )
    format_problem(
      "capability",
      "$.family_definition.defaults.moods.happy.follow",
      character_format_parse(data)
    )
  })
})

describe("released character files", {
  it("keeps every golden character file loading unchanged", {
    root <- test_path("fixtures", "golden")
    folders <- list.dirs(root, recursive = FALSE, full.names = TRUE)
    expect_gt(length(folders), 0L)
    for (folder in folders) {
      files <- list.files(folder, pattern = "\\.json$", full.names = TRUE)
      expect_gt(length(files), 0L)
      for (file in files) {
        # Built-in ids are reserved, so only the shipped built-ins use the internal admission route.
        built_in <- tools::file_path_sans_ext(basename(file)) %in% builtin_characters()$id
        expect_no_error(character_format_check(file, from = "file", builtin = built_in))
      }
    }
  })
})
