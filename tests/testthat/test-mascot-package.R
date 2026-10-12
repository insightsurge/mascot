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
        "mascot_motion",
        "mascot_popup_menu",
        "mascot_action",
        "mascot_colour_roles",
        "mascot_moods",
        "mascot_bubble",
        "mascot_gesture",
        "mascot_gestures"
      )
    )
    expect_true(all(startsWith(setdiff(exports, c("mascot", "update_mascot")), "mascot_")))
  })
})
