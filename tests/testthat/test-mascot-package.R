describe("the mascot package", {
  it("names Harsh Verma as author, maintainer and copyright holder", {
    # Given the installed package's metadata
    authors <- eval(parse(
      text = utils::packageDescription("mascot")[["Authors@R"]]
    ))

    # When we look for Harsh Verma
    harsh <- authors[authors$given == "Harsh" & authors$family == "Verma"]

    # Then there is exactly one entry, with all three roles
    expect_length(harsh, 1)
    expect_setequal(harsh$role, c("aut", "cre", "cph"))
    expect_identical(harsh$email, "analyticswithharsh@gmail.com")
  })

  it("is MIT licensed", {
    # Given / When
    licence <- utils::packageDescription("mascot")[["License"]]

    # Then
    expect_identical(licence, "MIT + file LICENSE")
  })

  it("carries a release version (x.y.z) or a development version (x.y.z.9000, .9001, ...)", {
    # Given / When
    version <- as.character(utils::packageVersion("mascot"))

    # Then
    expect_match(version, "^[0-9]+\\.[0-9]+\\.[0-9]+(\\.9[0-9]{3})?$")
  })
})

describe("mascot exports", {
  it("avoids names exported by base packages, shiny and htmltools", {
    exports <- getNamespaceExports("mascot")
    for (package in c("base", "stats", "utils", "graphics", "grDevices", "methods", "shiny", "htmltools")) {
      expect_equal(length(intersect(exports, getNamespaceExports(package))), 0, info = package)
    }
    expect_setequal(
      exports,
      c(
        "mascot",
        "update_mascot",
        "mascot_preview",
        "mascot_examples",
        "mascot_example",
        "mascot_studio",
        "mascot_character",
        "mascot_mood",
        "mascot_status",
        "mascot_size",
        "mascot_placement",
        "mascot_theme",
        "mascot_motion_settings",
        "mascot_popup_menu",
        "mascot_action",
        "mascot_colour_roles",
        "mascot_moods",
        "mascot_bubble",
        "mascot_gesture",
        "mascot_gestures",
        "mascot_characters",
        "mascot_families",
        "mascot_anchors",
        "mascot_palettes"
      )
    )
    expect_true(all(startsWith(setdiff(exports, c("mascot", "update_mascot")), "mascot_")))
  })
})
describe("B2 condition reference", {
  it("documents every condition callers can handle", {
    root <- test_path("..", "..")
    db <- if (dir.exists(file.path(root, "man"))) tools::Rd_db(dir = root) else tools::Rd_db("mascot")
    text <- paste(capture.output(tools::Rd2txt(db[["mascot-package.Rd"]])), collapse = "\n")
    for (class in c(
      "mascot_error",
      "mascot_warning",
      "mascot_message",
      "mascot_error_choice",
      "mascot_error_dots",
      "mascot_error_argument",
      "mascot_error_character",
      "mascot_error_file",
      "mascot_palette_dropped",
      "mascot_gesture_dropped",
      "mascot_click_dropped",
      "mascot_template_evicted",
      "mascot_update_ignored",
      "mascot_contrast",
      "mascot_placement_ignored"
    )) {
      expect_match(text, class, fixed = TRUE)
    }
  })
})
