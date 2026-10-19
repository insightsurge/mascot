# The parts that every view of the studio app shares (inst/examples/studio/R/shared-*.R), tested without a browser.

# The shared files on their own, as a new view would load them.
studio_shared <- function(...) {
  env <- new.env()
  for (file in c(...)) {
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", file), envir = env)
  }
  env
}

describe("run_real_call()", {
  it("reports a call that runs cleanly as a changed mascot with nothing to say", {
    run <- studio_shared("shared-run.R")$run_real_call
    result <- run(quote(mascot_theme(palette = "coral_navy")), environment())
    expect_named(result, c("ok", "class", "message", "silencer", "condition_classes"))
    expect_true(result$ok)
    expect_identical(result$class, "ok")
    expect_null(result$message)
    expect_null(result$silencer)
    expect_identical(result$condition_classes, NULL)
  })
  it("evaluates the call where the caller says, so it sees the caller's objects", {
    run <- studio_shared("shared-run.R")$run_real_call
    caller <- new.env()
    caller$chosen <- "happy"
    expect_identical(run(quote(mascot_mood(chosen)), caller)$class, "ok")
    expect_identical(run(quote(mascot_mood(chosen)), new.env(parent = baseenv()))$class, "error")
  })
  it("reports an unknown palette as an error and offers nothing to silence", {
    run <- studio_shared("shared-run.R")$run_real_call
    result <- run(quote(mascot("helper", theme = "not_a_palette")), environment())
    expect_false(result$ok)
    expect_identical(result$class, "error")
    expect_match(result$message, 'Unknown palette "not_a_palette"', fixed = TRUE)
    expect_null(result$silencer)
    expect_true("mascot_error" %in% result$condition_classes)
  })
  it("counts a dropped palette as a changed mascot, with its warning and its silencing line", {
    run <- studio_shared("shared-run.R")$run_real_call
    shiny::testServer(function(input, output, session) NULL, {
      here <- environment()
      expect_true(run(quote(update_mascot("demo", character = "tessa", theme = "coral_navy")), here)$ok)
      # Knurl has no palette called coral_navy: the package keeps the swap and uses Knurl's own colours.
      result <- run(quote(update_mascot("demo", character = "knurl")), here)
      expect_true(result$ok)
      expect_identical(result$class, "warning")
      expect_match(result$message, 'Palette "coral_navy" dropped for character "knurl"', fixed = TRUE)
      expect_true("mascot_palette_dropped" %in% result$condition_classes)
      expect_match(result$silencer, 'mascot_palette_dropped = function(w) invokeRestart("muffleWarning")', fixed = TRUE)
      expect_false("mascot_update_ignored" %in% result$condition_classes)
    })
  })
  it("counts an ignored update as an unchanged mascot and never offers to silence it", {
    run <- studio_shared("shared-run.R")$run_real_call
    shiny::testServer(function(input, output, session) NULL, {
      here <- environment()
      # A mood is checked against the mascot's character, so the mascot gets one first.
      expect_true(run(quote(update_mascot("demo", character = "tessa")), here)$ok)
      result <- run(quote(update_mascot("demo", mood = "sleepy")), here)
      expect_false(result$ok)
      expect_identical(result$class, "warning")
      expect_match(result$message, "left mascot", fixed = TRUE)
      expect_true("mascot_update_ignored" %in% result$condition_classes)
      expect_null(result$silencer)
    })
  })
  it("reports a message, and silences low contrast the way ?mascot_theme shows", {
    run <- studio_shared("shared-run.R")$run_real_call
    shiny::testServer(function(input, output, session) NULL, {
      here <- environment()
      result <- run(quote(update_mascot("demo", placement = mascot_placement("inline", minimise = TRUE))), here)
      expect_true(result$ok)
      expect_identical(result$class, "message")
      expect_match(result$message, "no effect on an inline mascot", fixed = TRUE)
      expect_match(
        result$silencer,
        'mascot_placement_ignored = function(m) invokeRestart("muffleMessage")',
        fixed = TRUE
      )
      result <- run(quote(update_mascot("demo", theme = list(body = "#f8f9fa"))), here)
      expect_true(result$ok)
      expect_identical(result$class, "warning")
      expect_true("mascot_contrast" %in% result$condition_classes)
      # The silencing line runs the same call without the warning.
      withr::local_options(mascot.contrast_warnings = TRUE)
      expect_no_warning(eval(parse(text = result$silencer), here))
    })
  })
  it("turns contrast warnings on only while the call runs, and keeps the caller's choice", {
    run <- studio_shared("shared-run.R")$run_real_call
    call <- quote(mascot("helper", theme = list(body = "#f8f9fa")))
    withr::local_options(mascot.contrast_warnings = NULL)
    expect_true("mascot_contrast" %in% run(call, environment())$condition_classes)
    expect_null(getOption("mascot.contrast_warnings"))
    withr::local_options(mascot.contrast_warnings = FALSE)
    expect_identical(run(call, environment())$class, "ok")
    expect_false(getOption("mascot.contrast_warnings"))
    expect_identical(run(call, environment(), options = list())$class, "ok")
  })
  it("checks its arguments", {
    run <- studio_shared("shared-run.R")$run_real_call
    expect_error(run("mascot()", environment()), "call")
    expect_error(run(quote(mascot()), list()), "envir")
    expect_error(run(quote(mascot()), environment(), options = list(TRUE)), "options")
    expect_error(studio_shared("shared-run.R")$call_silencer(quote(mascot()), "x"), "conditions")
  })
})

describe("changed_colours()", {
  it("keeps only the values that differ from each role's listed colour, by role and in lower case", {
    changed <- studio_shared("shared-colours.R")$changed_colours
    roles <- data.frame(role = c("body", "rim", "shine"), colour = c("#AABBCC", "#112233", "rgba(0, 0, 0, 0.5)"))
    values <- list(shine = "rgba(0, 0, 0, 0.5)", body = "#aabbcc", rim = "#FF0000", beak = "#123456")
    expect_identical(changed(values, roles), c(rim = "#ff0000"))
    # A role with no picker yet has not changed.
    expect_identical(changed(list(body = NULL, rim = "#112233"), roles), stats::setNames(character(), character()))
    expect_identical(changed(list(), roles), stats::setNames(character(), character()))
  })
  it("checks its arguments", {
    changed <- studio_shared("shared-colours.R")$changed_colours
    roles <- data.frame(role = "body", colour = "#ffffff")
    expect_error(changed(list(body = 1), roles), "values")
    expect_error(changed(list("#ffffff", "#000000"), roles), "names")
    expect_error(changed(list(), data.frame(role = "body")), "colour")
  })
})

describe("colour_groups()", {
  it("puts the brand roles and the leaders a palette changes first, then the rest grouped by name", {
    shared <- studio_shared("shared-colours.R")
    for (id in mascot_characters()$id) {
      roles <- mascot_colour_roles(id)
      groups <- shared$colour_groups(roles, id)
      expect_named(groups, c("Main colours", "More parts"))
      main <- groups$`Main colours`
      brand <- roles$role[!is.na(roles$brand)]
      # Brand roles lead, in the listing's order.
      expect_identical(main[seq_along(brand)], brand, info = id)
      # Every other main role is a leader that at least one of the character's palettes colours differently.
      listed <- mascot_palettes(id)
      listings <- lapply(listed$name[listed$source != "native"], function(p) mascot_colour_roles(id, palette = p))
      for (role in setdiff(main, brand)) {
        expect_true(is.na(roles$follows[roles$role == role]), info = paste(id, role))
        colours <- vapply(listings, function(palette) tolower(palette$colour[palette$role == role]), character(1))
        expect_true(any(colours != tolower(roles$colour[roles$role == role])), info = paste(id, role))
      }
      # Every role appears once; the rest are grouped by the name before the first underscore.
      more <- groups$`More parts`
      expect_setequal(c(main, unlist(more, use.names = FALSE)), roles$role)
      expect_false(anyDuplicated(c(main, unlist(more, use.names = FALSE))) > 0)
      for (group in names(more)) {
        expect_identical(sub("_.*$", "", more[[group]]), rep(group, length(more[[group]])), info = paste(id, group))
      }
    }
  })
  it("groups parts a character adds by their own name, and checks its arguments", {
    shared <- studio_shared("shared-colours.R")
    roles <- rbind(
      mascot_colour_roles("neer")[, c("role", "colour")],
      data.frame(role = c("beak", "beak_tip"), colour = "#000000")
    )
    expect_identical(shared$colour_groups(roles, "neer")$`More parts`$beak, c("beak", "beak_tip"))
    expect_error(shared$colour_groups(list(), "neer"), "roles")
    expect_error(shared$colour_groups(roles, 1), "character")
  })
})

describe("palette_cards()", {
  it("gives one card per palette with its value, description and swatches from the listings", {
    cards <- studio_shared("shared-colours.R")$palette_cards
    for (id in mascot_characters()$id) {
      listed <- mascot_palettes(id)
      result <- cards(id)
      expect_identical(vapply(result, `[[`, "", "name"), listed$name, info = id)
      expect_identical(vapply(result, `[[`, "", "description"), listed$description, info = id)
      expect_identical(result[[1]]$value, "original")
      own <- mascot_colour_roles(id)
      brand <- own$role[!is.na(own$brand)]
      for (card in result[-1]) {
        roles <- mascot_colour_roles(id, palette = card$value)
        expect_identical(card$value, card$name)
        # Brand roles first, then leaders whose colour the palette changes, each with the palette's colour.
        expect_identical(names(card$swatches)[seq_along(brand)], brand, info = card$name)
        expect_identical(unname(card$swatches), roles$colour[match(names(card$swatches), roles$role)])
        for (role in setdiff(names(card$swatches), brand)) {
          expect_true(is.na(own$follows[own$role == role]))
          expect_false(identical(tolower(card$swatches[[role]]), tolower(own$colour[own$role == role])))
        }
      }
      expect_gt(length(result[[1]]$swatches), 0)
    }
    expect_error(cards(1), "character")
  })
})
