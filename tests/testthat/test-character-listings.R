is_listing <- function(x, columns, types) {
  expect_identical(class(x), "data.frame")
  expect_identical(names(x), columns)
  expect_identical(unname(vapply(x, function(column) class(column)[1], character(1))), types)
  expect_identical(rownames(x), as.character(seq_len(nrow(x))))
}

describe("mascot_characters()", {
  it("lists all shipped characters with lifecycle and keeps Tessa as the default", {
    local_empty_registry()
    value <- mascot_characters()
    is_listing(
      value,
      c("id", "name", "description", "family", "is_default", "built_in", "lifecycle", "palettes"),
      c("character", "character", "character", "character", "logical", "logical", "character", "character")
    )
    expect_identical(value$id, c("tessa", "sela", "knurl", "neer"))
    expect_identical(value$name, c("Tessa", "Sela", "Knurl", "Neer"))
    expect_identical(value$family, c("hexonians", "hexonians", "visorfolk", "elementals"))
    expect_true(all(nzchar(value$description)))
    expect_identical(value$is_default, c(TRUE, FALSE, FALSE, FALSE))
    expect_identical(value$built_in, c(TRUE, TRUE, TRUE, TRUE))
    expect_identical(value$lifecycle, c("stable", "stable", "experimental", "experimental"))
    expect_identical(value$id[1], formals(mascot)$character)
  })
  it("adds registered characters after the shipped ones, as not built in and not default", {
    local_empty_registry()
    character_data_register(character_format_check(format_recipe("study_bot")))
    character_data_register(character_format_check(format_recipe("anchor_probe")))
    value <- mascot_characters()
    expect_identical(value$id, c("tessa", "sela", "knurl", "neer", "study_bot", "anchor_probe"))
    expect_identical(value$is_default, c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE))
    expect_identical(value$built_in, c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE))
    expect_identical(
      value$lifecycle,
      c("stable", "stable", "experimental", "experimental", NA_character_, NA_character_)
    )
    expect_identical(value$family, c("hexonians", "hexonians", "visorfolk", "elementals", "visorfolk", "test_helpers"))
  })
  it("filters by family and keeps the order and the column types", {
    local_empty_registry()
    character_data_register(character_format_check(format_recipe("study_bot")))
    expect_identical(mascot_characters(family = "visorfolk")$id, c("knurl", "study_bot"))
    expect_identical(mascot_characters(family = "hexonians")$id, c("tessa", "sela"))
    expect_identical(mascot_characters(family = "elementals")$id, "neer")
    expect_identical(names(mascot_characters(family = "visorfolk")), names(mascot_characters()))
  })
  it("names unknown families and rejects bad arguments", {
    local_empty_registry()
    expect_error(mascot_characters(family = "robots"), "must be one of", class = "mascot_error")
    for (x in list(1, "", NA_character_, c("a", "b"))) {
      expect_error(mascot_characters(family = x), "Assertion on 'family' failed", class = "mascot_error")
    }
  })
  it("keeps the agreed signature and rejects both forms of extra argument", {
    expect_identical(names(formals(mascot_characters)), c("...", "family"))
    expect_error(mascot_characters(typo = 1), "Unexpected arguments", class = "mascot_error")
    expect_error(mascot_characters("hexonians"), "Name the optional arguments", class = "mascot_error")
  })
})

describe("mascot_families()", {
  it("lists the family of the shipped character", {
    local_empty_registry()
    value <- mascot_families()
    is_listing(value, c("id", "name", "description", "character"), rep("character", 4))
    expect_identical(value$id, c("hexonians", "visorfolk", "elementals"))
    expect_identical(value$name, c("Hexonians", "Visorfolk", "Elementals"))
  })
  it("lists each registered family snapshot with its character, preserving built-in labels", {
    local_empty_registry()
    character_data_register(character_format_check(format_recipe("anchor_probe")))
    character_data_register(character_format_check(format_recipe("study_bot")))
    other <- format_recipe("study_bot")
    other$id <- "study_two"
    other$family_definition$name <- "Another name"
    character_data_register(character_format_check(other))
    value <- mascot_families()
    expect_identical(value$id, c("hexonians", "visorfolk", "elementals", "test_helpers", "visorfolk", "visorfolk"))
    expect_identical(value$name[2:6], c("Visorfolk", "Elementals", "Test Helpers", "Visorfolk", "Another name"))
    expect_identical(
      value$character,
      c(NA_character_, NA_character_, NA_character_, "anchor_probe", "study_bot", "study_two")
    )
    expect_identical(mascot_characters(family = "visorfolk")$id, c("knurl", "study_bot", "study_two"))
  })
  it("takes no arguments", {
    expect_length(formals(mascot_families), 0L)
  })
})

describe("mascot_anchors()", {
  it("lists Tessa's anchors in authored order with part and side", {
    value <- mascot_anchors()
    is_listing(value, c("name", "description", "part", "side"), rep("character", 4))
    expect_identical(value, mascot_anchors("tessa"))
    expect_identical(value, mascot_anchors(mascot_character("tessa")))
    expect_identical(value$name, names(character_catalogue_builtin("tessa")$anchors))
    expect_identical(value$side[value$name == "hand_r"], "r")
    expect_true(is.na(value$side[value$name == "face"]))
    expect_identical(value$part[value$name == "hand_l"], "arm_l")
    expect_false(anyNA(value$description))
  })
  it("lists Neer's fourteen anchors in authored order", {
    value <- mascot_anchors("neer")
    is_listing(value, c("name", "description", "part", "side"), rep("character", 4))
    expect_identical(
      value$name,
      c(
        "crown",
        "crest",
        "forehead",
        "eyes",
        "face",
        "chest",
        "hand_l",
        "hand_r",
        "foot_l",
        "foot_r",
        "shell",
        "sweat",
        "sparkle",
        "wave_base"
      )
    )
  })
  it("lists a registered character by id and checked data alike, in authored order", {
    local_empty_registry()
    custom <- catalogue_alpha_two()
    from_object <- mascot_anchors(custom)
    expect_identical(from_object$name, names(custom$anchors))
    character_data_register(custom)
    expect_identical(mascot_anchors("alpha_two"), from_object)
  })
  it("returns no rows, with the same column types, for a character without anchors", {
    custom <- character_format_check(format_recipe("study_bot"))
    custom$anchors <- NULL
    custom <- character_format_check(unclass(custom))
    value <- mascot_anchors(custom)
    expect_identical(nrow(value), 0L)
    expect_identical(names(value), c("name", "description", "part", "side"))
    expect_identical(unname(vapply(value, typeof, character(1))), rep("character", 4))
  })
  it("names unknown characters and rejects other types", {
    expect_error(mascot_anchors("missing"), "must be one of", class = "mascot_error")
    for (x in list(NULL, 1, "", NA_character_, c("tessa", "tessa"))) {
      expect_error(mascot_anchors(x), "Assertion on 'character' failed", class = "mascot_error")
    }
  })
})

describe("built-in character listings", {
  it("resolves every built-in through the helper and all character listings", {
    local_empty_registry()
    for (id in builtin_characters()$id) {
      character <- mascot_character(id)
      expect_identical(character$id, id)
      expect_true(nrow(mascot_moods(id)) >= 5L)
      expect_true(nrow(mascot_gestures(id)) > 0L)
      expect_true(nrow(mascot_colour_roles(id)) > 0L)
      expect_identical(nrow(mascot_anchors(id)), length(character_catalogue_builtin(id)$anchors))
      expect_true(nrow(mascot_palettes(id)) > 0L)
    }
  })
})

describe("mascot_palettes()", {
  it("lists every character with its id last and retains single-character columns", {
    local_empty_registry()
    value <- mascot_palettes()
    is_listing(value, c("name", "description", "source", "character"), rep("character", 4))
    expect_identical(unique(value$character), c("tessa", "sela", "knurl", "neer"))
    expected <- list(
      # Tessa's own colours lead the list under their own name, night_teal; "original" still selects them (#358).
      tessa = c(
        "night_teal",
        "sea_green",
        "forest",
        "spring",
        "peach",
        "coral_navy",
        "desert_coral",
        "rose_soft",
        "lilac_soft",
        "mist_navy"
      ),
      sela = c(
        "lilac_violet",
        "orchid",
        "coral_navy",
        "azure",
        "peach_ink",
        "lilac_soft",
        "mist_navy",
        "desert_clay",
        "forest",
        "apricot_navy",
        "blush_plum",
        "lilac_dusk",
        "sea_green"
      ),
      knurl = c("original", "orbit", "carbon", "cobalt_droid", "crimson"),
      neer = c("original", "lagoon", "glacier", "coral_reef", "night_bay", "monsoon")
    )
    characters <- mascot_characters()
    for (id in names(expected)) {
      one <- mascot_palettes(id)
      expect_named(one, c("name", "description", "source"))
      expect_identical(one$name, expected[[id]])
      expect_identical(one$source, c("native", rep("character", length(expected[[id]]) - 1L)))
      expect_identical(characters$palettes[characters$id == id], paste(expected[[id]], collapse = ", "))
      expect_false(anyNA(one$description))
      expect_true(all(nzchar(one$description)))
    }
  })
  it("lists Tessa's own colours as night_teal, not original, and still accepts original", {
    value <- mascot_palettes("tessa")
    expect_identical(value$name[[1]], "night_teal")
    expect_identical(value$source[[1]], "native")
    expect_false("original" %in% value$name)
    expect_length(value$name, 10L)
    expect_identical(sort(character_palettes("tessa") |> names()), sort(value$name[-1]))
    expect_identical(character_catalogue_builtin("tessa")$native_palette, "night_teal")
    for (id in c("knurl", "neer")) {
      expect_identical(mascot_palettes(id)$name[[1]], "original")
    }
  })
  it("lists Sela's own colours as lilac_violet followed by her twelve palettes", {
    value <- mascot_palettes("sela")
    expect_identical(value$name[[1]], "lilac_violet")
    expect_false("original" %in% value$name)
    expect_length(value$name, 13L)
    expect_identical(value$source, c("native", rep("character", 12L)))
    expect_identical(character_catalogue_builtin("sela")$native_palette, "lilac_violet")
  })
  it("adds the character's palettes after original, with their checked origin", {
    value <- mascot_palettes(character_format_check(format_recipe("study_bot")))
    expect_identical(value$name, c("original", "sea_glass", "night_screen"))
    expect_identical(value$source, c("native", "character", "family"))
    expect_identical(value$description[2], "My darker screen.")
    expect_false(anyNA(value$description))
  })
  it("reports the origin recorded in the checked data, never today's family defaults", {
    custom <- character_format_check(format_recipe("study_bot"))
    custom$palette_sources[["night_screen"]] <- "character"
    custom$family_definition$defaults <- character_object()
    custom <- character_format_check(unclass(custom))
    expect_identical(mascot_palettes(custom)$source, c("native", "character", "character"))
  })
  it("names unknown characters and rejects other types", {
    expect_error(mascot_palettes("missing"), "must be one of", class = "mascot_error")
    for (value in list(1, "", NA_character_, c("tessa", "sela"))) {
      expect_error(mascot_palettes(value), "character", class = "mascot_error")
    }
  })
})

describe("mascot_moods(character =)", {
  it("keeps the shared listing as the first columns and appends status, shared and fallback", {
    value <- mascot_moods()
    is_listing(
      value,
      c("name", "description", "status", "shared", "fallback"),
      c("character", "character", "character", "logical", "character")
    )
    expect_identical(value$name[1], "idle")
    expect_identical(value$status, c("Idle", "Thinking", "Happy", "Worried", "Celebrating"))
    expect_true(all(value$shared))
    expect_true(all(is.na(value$fallback)))
  })
  it("lists a character's moods with the core five first and extras in authored order", {
    value <- mascot_moods(catalogue_alpha_two())
    expect_identical(value$name, c("idle", "thinking", "happy", "worried", "celebrating", "processing"))
    expect_identical(value$shared, c(rep(TRUE, 5), FALSE))
    expect_identical(value$fallback, c(rep(NA_character_, 5), "thinking"))
    expect_identical(value$status[6], "Processing")
    expect_identical(value$description[6], "Working through a queue.")
  })
  it("puts the core five first even when an author wrote an extra mood first", {
    recipe <- format_recipe("alpha_visor")
    recipe$id <- "alpha_three"
    recipe$moods <- c(recipe$moods["processing"], recipe$moods[names(recipe$moods) != "processing"])
    value <- mascot_moods(character_format_check(recipe))
    expect_identical(value$name, c("idle", "thinking", "happy", "worried", "celebrating", "processing"))
  })
  it("reports Tessa's moods with the shared names and her own status lines", {
    value <- mascot_moods("tessa")
    expect_identical(value[c("name", "description")], mascot_moods()[c("name", "description")])
    # Tessa's voice (#142); the shared vocabulary keeps the plain labels.
    expect_identical(
      value$status,
      c(
        "Resting, ready for the next piece.",
        "Working out how the parts fit.",
        "That came together nicely.",
        "One part needs a closer look.",
        "Finished, and built to last."
      )
    )
    expect_identical(mascot_moods()$status, c("Idle", "Thinking", "Happy", "Worried", "Celebrating"))
    expect_identical(value, mascot_moods(mascot_character("tessa")))
  })
  it("names unknown characters and rejects other types", {
    expect_error(mascot_moods("missing"), "must be one of", class = "mascot_error")
    for (x in list(1, "", NA_character_, c("tessa", "tessa"))) {
      expect_error(mascot_moods(x), "Assertion on 'character' failed", class = "mascot_error")
    }
  })
})

describe("mascot_gestures(character =)", {
  it("keeps the shared listing as the first columns and appends fallback and frames", {
    value <- mascot_gestures()
    is_listing(
      value,
      c("name", "description", "fallback", "frames"),
      c("character", "character", "character", "integer")
    )
    expect_identical(value$name, c("nod", "wave"))
    expect_identical(value$frames, c(18L, 30L))
    expect_true(all(is.na(value$fallback)))
  })
  it("lists nod and wave first, then extras, with the effective playable length", {
    value <- mascot_gestures(catalogue_alpha_two())
    expect_identical(value$name, c("nod", "wave", "beep", "hat_hop", "rock"))
    expect_identical(value$fallback, c(NA, "rock", NA, NA, NA))
    expect_identical(value$frames, c(18L, 30L, 20L, 24L, 18L))
  })
  it("reports the fallback's length, not the declared one, when a needed part is absent", {
    checked <- character_format_check(format_recipe("study_bot"))
    value <- mascot_gestures(checked)
    declared <- checked$gestures
    expect_identical(value$fallback[value$name == "wave"], "rock")
    expect_identical(value$frames[value$name == "wave"], as.integer(declared$rock$frames))
    expect_false(identical(value$frames[value$name == "wave"], 30L))
    expect_false(any(value$name == value$fallback, na.rm = TRUE))
  })
  it("lists Tessa's own wave and nod at their shared lengths", {
    value <- mascot_gestures("tessa")
    expect_identical(value$name[1:2], c("nod", "wave"))
    expect_identical(value$frames[1:2], mascot_gestures()$frames)
    expect_identical(value$description[1:2], mascot_gestures()$description)
  })
  it("names unknown characters and rejects other types", {
    expect_error(mascot_gestures("missing"), "must be one of", class = "mascot_error")
    for (x in list(1, "", NA_character_, c("tessa", "tessa"))) {
      expect_error(mascot_gestures(x), "Assertion on 'character' failed", class = "mascot_error")
    }
  })
})

describe("mascot_colour_roles(character =)", {
  it("appends description and brand and keeps the first four columns as before", {
    value <- mascot_colour_roles()
    is_listing(value, c("role", "colour", "follows", "shade", "description", "brand"), rep("character", 6))
    expect_identical(value$description[value$role == "body_highlight"], "Body highlight")
    expect_identical(value$brand[value$role == "body"], "primary")
    expect_identical(value$brand[value$role == "rim"], "secondary")
    expect_identical(sum(!is.na(value$brand)), 2L)
  })
  it("uses the author's role description and joins two brand slots on one role", {
    custom <- character_format_check(format_recipe("study_bot"))
    custom$colour_descriptions <- list(body = "The whole shell.")
    custom$brand <- list(primary = "body", secondary = "body")
    custom <- character_format_check(unclass(custom))
    value <- mascot_colour_roles(custom)
    expect_identical(value$description[value$role == "body"], "The whole shell.")
    expect_identical(value$brand[value$role == "body"], "primary, secondary")
  })
  it("lists a registered character by id", {
    local_empty_registry()
    custom <- catalogue_alpha_two()
    character_data_register(custom)
    expect_identical(mascot_colour_roles("alpha_two"), mascot_colour_roles(custom))
    expect_identical(mascot_colour_roles("alpha_two")$role, names(custom$colours))
  })
})

describe("humanised role descriptions", {
  it("capitalise the first word and replace underscores", {
    expect_identical(colour_role_description("eye_white"), "Eye white")
    expect_identical(colour_role_description("body"), "Body")
    expect_error(colour_role_description(""), "Assertion on 'role' failed")
  })
})


describe("public listing documentation", {
  it("keeps checked and registered forms off the listing pages and documents every family column", {
    # mascot_character() documents checked character data from 0.1.0 (#339), so it is not listed here.
    pages <- c(
      "mascot",
      "update_mascot",
      "mascot_preview",
      "mascot_characters",
      "mascot_families",
      "mascot_moods",
      "mascot_gestures",
      "mascot_colour_roles",
      "mascot_anchors",
      "mascot_palettes"
    )
    for (page in pages) {
      file <- system.file("man", paste0(page, ".Rd"), package = "mascot")
      rd <- if (nzchar(file)) tools::parse_Rd(file) else tools::Rd_db("mascot")[[paste0(page, ".Rd")]]
      text <- paste(unlist(rd), collapse = " ")
      expect_false(grepl("checked character data|mascot_character_data|registered character", text), info = page)
      if (page == "mascot_families") {
        value <- Filter(function(node) identical(attr(node, "Rd_tag"), "\\value"), rd)[[1]]
        value <- paste(unlist(value), collapse = "")
        for (fact in c("character", "NA", "built-in family")) {
          expect_match(value, fact, fixed = TRUE)
        }
      }
    }
  })
})
