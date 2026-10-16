describe("character_format_check()", {
  it("promotes only complete checked reference recipes and records derived evidence", {
    for (id in c("tessa", "alpha_visor", "study_bot", "anchor_probe")) {
      checked <- character_format_check(format_recipe(id), builtin = id %in% c("tessa", "alpha_visor"))
      expect_s3_class(checked, "mascot_character_data")
      manifest <- attr(checked, "mascot_manifest")
      expect_identical(manifest$identity, character_format_identity(checked))
      expect_identical(manifest$format_version, 1L)
      expect_named(manifest$work, c("full", "small", "micro"))
      expect_true(all(vapply(manifest$fit, function(proof) proof$verified, logical(1))))
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
