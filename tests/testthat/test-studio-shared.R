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
