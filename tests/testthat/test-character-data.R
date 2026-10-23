describe("character_data_register() and character_data_get()", {
  it("registers, retrieves, and lists valid checked Anchor Probe with custom family preserved", {
    local_empty_registry()

    recipe <- format_recipe("anchor_probe")
    checked <- character_format_check(recipe)

    registered <- character_data_register(checked)
    expect_identical(registered$id, "anchor_probe")

    found <- character_data_get("anchor_probe")
    expect_s3_class(found, "mascot_character_data")
    expect_identical(found$id, "anchor_probe")
    expect_identical(found$name, "Anchor Probe")
    expect_identical(found$family, "test_helpers")
    expect_identical(found$family_definition$id, "test_helpers")
    expect_identical(found$family_definition$name, "Test Helpers")

    ids <- character_data_ids()
    expect_identical(ids, "anchor_probe")
  })

  it("treats differently ordered object keys as idempotent and retains array order in identity", {
    local_empty_registry()

    recipe1 <- format_recipe("anchor_probe")
    recipe2 <- recipe1[rev(names(recipe1))]

    checked1 <- character_format_check(recipe1)
    checked2 <- character_format_check(recipe2)

    expect_identical(
      attr(checked1, "mascot_manifest")$identity,
      attr(checked2, "mascot_manifest")$identity
    )

    character_data_register(checked1)
    character_data_register(checked2)
    expect_identical(character_data_ids(), "anchor_probe")

    recipe_array <- recipe1
    recipe_array$requires <- rev(recipe1$requires)
    checked_array <- character_format_check(recipe_array)

    expect_false(identical(
      attr(checked1, "mascot_manifest")$identity,
      attr(checked_array, "mascot_manifest")$identity
    ))

    format_problem("identity", "$.id", character_data_register(checked_array))
    expect_identical(character_data_ids(), "anchor_probe")
    expect_identical(character_data_get("anchor_probe")$requires, checked1$requires)
  })

  it("errors on same id with different valid content and leaves original intact", {
    local_empty_registry()

    recipe <- format_recipe("anchor_probe")
    checked <- character_format_check(recipe)
    character_data_register(checked)

    recipe_different <- recipe
    recipe_different$description <- "Different valid description."
    checked_different <- character_format_check(recipe_different)

    format_problem("identity", "$.id", character_data_register(checked_different))
    expect_identical(character_data_ids(), "anchor_probe")
    expect_identical(character_data_get("anchor_probe")$description, checked$description)
  })

  it("rejects replacing built-in character tessa while preserving public mascot_character()", {
    local_empty_registry()

    tessa_recipe <- format_recipe("tessa")
    checked_tessa <- character_format_check(tessa_recipe, builtin = TRUE)
    expect_identical(checked_tessa$id, "tessa")

    format_problem("identity", "$.id", character_data_register(checked_tessa))
    expect_false("tessa" %in% character_data_ids())
    format_problem("missing_reference", "$.id", character_data_get("tessa"))

    tessa_public <- mascot_character("tessa")
    expect_s3_class(tessa_public, "mascot_character")
    expect_identical(tessa_public$id, "tessa")
    expect_identical(tessa_public$name, "Tessa")
    expect_identical(mascot_character()$id, "tessa")
  })
})

describe("character store reserved ids and retrieved values", {
  it("refuses to register a built-in id", {
    local_empty_registry()
    for (id in c("neer", "knurl")) {
      recipe <- format_recipe()
      recipe$id <- id
      format_problem("identity", "$.id", character_data_register(character_format_check(recipe, builtin = TRUE)))
    }
    expect_identical(character_data_ids(), character())
  })

  it("isolates nested metadata and manifests edited by separate callers", {
    local_empty_registry()
    checked <- character_format_check(format_recipe())
    character_data_register(checked)
    first <- character_data_get("anchor_probe")
    second <- character_data_get("anchor_probe")
    first$family_definition$name <- "Changed by first caller"
    attr(second, "mascot_manifest")$work$full[[1]] <- 99999
    expect_identical(character_data_get("anchor_probe"), checked)
  })
})

describe("#494 verified objects are not checked again", {
  it("returns an unchanged object's result without parsing it again, and checks an edited one", {
    saved <- as.list(character_data_verified)
    withr::defer(list2env(saved, envir = character_data_verified))
    character_data_verified$seen <- character_data_verified$texts <- list()
    checked <- character_format_check(format_recipe("anchor_probe"))
    first <- character_data_verify(checked)
    original <- character_format_parse
    calls <- new.env(parent = emptyenv())
    calls$n <- 0L
    local_mocked_bindings(character_format_parse = function(...) {
      calls$n <- calls$n + 1L
      original(...)
    })
    for (i in 1:5) {
      expect_identical(character_data_verify(checked), first)
    }
    expect_identical(calls$n, 0L)
    edited <- checked
    edited$anchors$badge$part <- "missing_owner"
    format_problem("missing_reference", "$.anchors.badge.part", character_data_verify(edited))
    expect_gt(calls$n, 0L)
    renamed <- checked
    renamed$name <- "Renamed"
    format_problem("identity", "$", character_data_verify(renamed))
    expect_lte(length(character_data_verified$seen), 16L)
    expect_error(character_data_seen(list(), first), "Assertion")
    expect_error(character_data_seen(checked, list()), "Assertion")
  })

  it("keeps 16 objects and 16 texts, and checks the oldest object again once it has left", {
    saved <- as.list(character_data_verified)
    withr::defer(list2env(saved, envir = character_data_verified))
    character_data_verified$seen <- character_data_verified$texts <- list()
    checked <- character_format_check(format_recipe("anchor_probe"))
    character_data_verify(checked)
    original_write <- character_json_write
    original_parse <- character_format_parse
    calls <- new.env(parent = emptyenv())
    calls$write <- calls$parse <- 0L
    local_mocked_bindings(
      character_json_write = function(x) {
        calls$write <- calls$write + 1L
        if (identical(x, checked)) original_write(x) else "{}"
      },
      character_format_parse = function(...) {
        calls$parse <- calls$parse + 1L
        original_parse(...)
      }
    )
    character_data_json(checked)
    for (i in 1:16) {
      other <- structure(list(id = paste0("other_", i)), class = "mascot_character_data")
      character_data_seen(other, other)
      character_data_json(other)
    }
    expect_length(character_data_verified$seen, 16L)
    expect_length(character_data_verified$texts, 16L)
    expect_identical(calls$write, 17L)
    character_data_verify(checked)
    expect_gt(calls$parse, 0L)
    character_data_json(checked)
    expect_identical(calls$write, 18L)
  })

  it("writes a verified object's JSON text once and gives the same text as writing it", {
    saved <- as.list(character_data_verified)
    withr::defer(list2env(saved, envir = character_data_verified))
    character_data_verified$texts <- list()
    checked <- character_format_check(format_recipe("anchor_probe"))
    expected <- character_json_write(checked)
    original <- character_json_write
    calls <- new.env(parent = emptyenv())
    calls$n <- 0L
    local_mocked_bindings(character_json_write = function(...) {
      calls$n <- calls$n + 1L
      original(...)
    })
    for (i in 1:3) {
      expect_identical(character_data_json(checked), expected)
    }
    expect_identical(calls$n, 1L)
    expect_error(character_data_json(list()), "Assertion")
  })
})

describe("character store validation and isolation", {
  it("prevents unchecked lists, forged classes, and mutated anchors from poisoning the store", {
    local_empty_registry()

    raw_recipe <- format_recipe("anchor_probe")
    expect_error(character_data_register(raw_recipe))
    expect_error(character_data_verify(raw_recipe))

    forged <- format_recipe("anchor_probe")
    forged$moods$happy <- NULL
    class(forged) <- c("mascot_character_data", "list")
    attr(forged, "mascot_manifest") <- list(identity = "spoofed")
    format_problem("missing_reference", "$.moods.happy", character_data_register(forged))
    format_problem("missing_reference", "$.moods.happy", character_data_verify(forged))

    mutated <- character_format_check(format_recipe("anchor_probe"))
    mutated$anchors$badge$part <- "missing_owner"
    format_problem("missing_reference", "$.anchors.badge.part", character_data_register(mutated))
    format_problem("missing_reference", "$.anchors.badge.part", character_data_verify(mutated))

    checked <- character_format_check(format_recipe("anchor_probe"))
    character_data_register(checked)

    retrieved <- character_data_get("anchor_probe")
    retrieved$anchors$badge$part <- "poisoned_owner"
    retrieved$name <- "Poisoned Name"

    clean <- character_data_get("anchor_probe")
    expect_identical(clean$anchors$badge$part, "panel")
    expect_identical(clean$name, "Anchor Probe")
    format_problem("missing_reference", "$.anchors.badge.part", character_data_register(retrieved))
  })

  it("reports unknown custom ids and validates all arguments", {
    local_empty_registry()

    format_problem("missing_reference", "$.id", character_data_get("unknown_custom_id"))

    expect_error(character_data_verify(1))
    expect_error(character_data_verify(list()))
    expect_error(character_data_verify(NULL))

    expect_error(character_data_register(1))
    expect_error(character_data_register(list()))
    expect_error(character_data_register("anchor_probe"))
    expect_error(character_data_register(NULL))

    expect_error(character_data_get(1))
    expect_error(character_data_get(NULL))
    expect_error(character_data_get(""))
    expect_error(character_data_get("a"))
    expect_error(character_data_get(strrep("a", 33)))
    expect_error(character_data_get("Invalid_Case"))
    expect_error(character_data_get("kebab-case"))
    expect_error(character_data_get("1leading_digit"))
    expect_error(character_data_get(c("a", "b")))
  })

  it("rejects registration inside an active reactive domain while allowing retrieval", {
    local_empty_registry()

    probe <- character_format_check(format_recipe("anchor_probe"))
    character_data_register(probe)

    session <- shiny::MockShinySession$new()
    withr::defer(session$close())

    shiny::withReactiveDomain(session, {
      retrieved <- character_data_get("anchor_probe")
      expect_identical(retrieved$id, "anchor_probe")

      visor <- character_format_check(format_recipe("alpha_visor"), builtin = TRUE)
      format_problem("registry", "$", character_data_register(visor))
    })

    expect_identical(character_data_ids(), "anchor_probe")
    format_problem("missing_reference", "$.id", character_data_get("alpha_visor"))
  })

  it("restores entries that existed before a test-local registry change", {
    local_empty_registry()
    recipe <- format_recipe()
    recipe$id <- "sentinel"
    character_data_register(character_format_check(recipe))
    trial <- function() {
      local_empty_registry()
      character_data_register(character_format_check(format_recipe()))
    }
    trial()
    expect_identical(character_data_ids(), "sentinel")
    expect_identical(character_data_get("sentinel")$id, "sentinel")
  })

  it("leaves no global option state or leaked entries across tests", {
    opts_before <- options()
    local_empty_registry()
    probe <- character_format_check(format_recipe("anchor_probe"))
    character_data_register(probe)
    expect_identical(character_data_ids(), "anchor_probe")
    local_empty_registry()
    expect_identical(character_data_ids(), character())
    expect_identical(options(), opts_before)
  })
})
