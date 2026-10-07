describe("mascot_theme()", {
  it("keeps omitted modes distinct from explicit modes and clears with an empty helper", {
    value <- mascot_theme()
    expect_s3_class(value, "mascot_theme")
    expect_true(value$mode_default)
    expect_identical(value$mode, "light")
    expect_false(mascot_theme(mode = "light")$mode_default)
    expect_identical(
      as_theme_arg(value, environment()),
      list(light = NULL, dark = NULL, mode = NULL, css = NULL, brand = NULL)
    )
    expect_null(as_theme_arg(NULL, environment()))
    expect_null(arg_problem(NULL, "theme"))
    expect_identical(as_theme_arg(mascot_theme(mode = "dark"), environment())$mode, "dark")
    expect_identical(as_theme_arg(mascot_theme(mode = "auto"), environment())$mode, "auto")
  })
  it("renames description roles and converts every supported colour input", {
    forms <- list(
      "#1f6feb",
      "#1F6FEB",
      grDevices::rgb(31, 111, 235, maxColorValue = 255),
      "rgb(31,111,235)",
      c(31, 111, 235)
    )
    for (x in forms) {
      expect_identical(theme_colour(x, "body"), "#1F6FEB")
    }
    expect_identical(theme_colour("orange", "rim"), "#FFA500")
    expect_identical(theme_colour("#abc", "body"), "#AABBCC")
    expect_identical(theme_colour("rgba(31,111,235,0.5)", "body"), "rgba(31.0,111.0,235.0,0.5)")
    expect_equal(theme_channels(theme_colour("#11223380", "body")), c(17, 34, 51, 128 / 255))
    expect_equal(theme_channels("RGB(1e2, 2, 3)"), c(100, 2, 3, 1))
    expect_equal(theme_channels(theme_colour(c(31.5, 111, 235), "body")), c(31.5, 111, 235, 1))
    wire <- suppressWarnings(as_theme_arg(list(eye_white = "white", body_highlight = "orange"), environment(), "tessa"))
    expect_named(wire$light, c("eyeWhite", "bodyHighlight"))
    expect_identical(wire$light, wire$dark)
    expect_identical(wire$light$eyeWhite, "#FFFFFF")
    expect_null(wire$mode)
    css <- as_theme_arg(mascot_theme(css = list(body_highlight = "--team-blue")), environment())
    expect_identical(css$css, list(bodyHighlight = "--team-blue"))
  })
  it("rejects malformed maps, reserved roles, colours and helper fields", {
    expect_snapshot(error = TRUE, mascot_theme(light = list(bdoy = "blue")))
    for (role in c("light", "dark", "default", "eyeWhite", "toString")) {
      expect_error(mascot_theme(light = stats::setNames(list("blue"), role)), "Valid roles:.*body_highlight")
    }
    for (arg in c("light", "dark", "css")) {
      for (x in list(1, "blue", list("blue"), stats::setNames(list("red", "blue"), c("body", "body")))) {
        expect_error(do.call(mascot_theme, stats::setNames(list(x), arg)), "list|names")
      }
    }
    for (x in list(NULL, "missing", c("light", "dark"), 1, NA_character_)) {
      expect_error(mascot_theme(mode = x), "'mode'")
    }
    for (x in list(NULL, 1, "team-blue", "--", "--bad name", NA_character_)) {
      expect_error(mascot_theme(css = list(body = x)), "CSS variable")
    }
    for (x in list(
      NULL,
      31,
      c(1, 2),
      c(0, 1, 256),
      c(1, NA, 3),
      c(Inf, 1, 2),
      TRUE,
      "",
      "not-a-colour",
      "rgb(1,2)",
      "rgb(1,2,3",
      "rgb(1,2,3,)",
      "rgb(1%,2,3)",
      "rgba(1,2,3,2)",
      "rgb(-1,2,3)",
      "rgb(1e999,2,3)",
      "rgb(256,2,3)"
    )) {
      expect_error(mascot_theme(light = list(body = x)), "body.*invalid")
    }
    value <- mascot_theme()
    for (field in names(value)) {
      bad <- value
      bad[[field]] <- if (field == "mode") {
        "bad"
      } else if (field == "mode_default") {
        NA
      } else {
        1
      }
      expect_type(theme_problem(bad), "character")
    }
    bad <- value
    bad$extra <- TRUE
    expect_match(theme_problem(bad), "fields")
    expect_match(theme_problem(structure(1, class = "mascot_theme")), "fields")
    expect_match(theme_problem(list("blue")), "named list")
    expect_match(theme_problem(1), "named list")
    expect_null(theme_problem(list()))
  })
  it("warns once per supplied role and mode without altering low-contrast colours", {
    expect_snapshot(
      value <- as_theme_arg(mascot_theme(light = list(body = "white"), dark = list(rim = "#212529")), environment())
    )
    expect_identical(value$light$body, "#FFFFFF")
    expect_identical(value$dark$rim, "#212529")
    expect_equal(theme_contrast("black", "white"), 21)
    expect_equal(theme_contrast("rgba(0,0,0,0)", "white"), 1)
    expect_equal(theme_contrast("#212529", "#212529"), 1)
    expect_no_warning(as_theme_arg(mascot_theme(), environment()))
  })
  it("maps a bslib theme through the character's slots and uses its background", {
    skip_if_not_installed("bslib")
    theme <- bslib::bs_theme(primary = "#1f6feb", secondary = "orange", bg = "#102030", fg = "white")
    expect_null(theme_problem(theme))
    value <- suppressWarnings(as_theme_arg(theme, environment(), "tessa"))
    expect_identical(value$brand, list(primary = "#1F6FEB", secondary = "#FFA500"))
    expect_identical(value$light, list(body = "#1F6FEB", rim = "#FFA500", accessory = "#FFA500"))
    expect_identical(value$light, value$dark)
    expect_identical(suppressWarnings(as_theme_arg(theme, environment()))$brand, value$brand)
    expect_snapshot(suppressWarnings(
      bslib_theme <- bslib::bs_theme(primary = "#102030", secondary = "white", bg = "#102030", fg = "white")
    ))
    warnings <- character()
    withCallingHandlers(as_theme_arg(bslib_theme, environment()), warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
    expect_length(warnings, 2)
    expect_true(all(grepl("#102030", warnings, fixed = TRUE)))
    expect_true(all(grepl("body", warnings, fixed = TRUE)))
  })
  it("explains an unavailable optional source and checks internal contracts", {
    local_mocked_bindings(theme_has_bslib = function() FALSE)
    expect_match(theme_problem(structure(list(), class = "bs_theme")), "needs the bslib package")
    expect_error(as_theme_arg(list(), NULL), "'call'")
    expect_error(as_theme_arg(list(), environment(), "missing"), "'character'")
    expect_error(theme_map_problem(NULL, 1, "body"), "'arg'")
    expect_error(theme_map_problem(NULL, "light", NA_character_), "'roles'")
    expect_error(theme_map_problem(NULL, "light", "body", NA), "'css'")
    expect_error(theme_colour("blue", 1), "'role'")
    expect_error(theme_contrast(1, "white"), "'colour'")
    expect_error(theme_contrast("black", 1), "'background'")
    expect_error(theme_tag(1), "'theme'")
  })
})

describe("theme_tag()", {
  it("serialises empty maps as null and escapes closing script tags", {
    expect_null(theme_tag(NULL))
    value <- as_theme_arg(mascot_theme(), environment())
    tag <- theme_tag(value)
    expect_identical(tag$attribs$type, "application/json")
    expect_identical(jsonlite::fromJSON(as.character(tag$children[[1]]), simplifyVector = FALSE), value)
    expect_match(as.character(theme_tag(list(text = "</script>"))), "<\\/script>", fixed = TRUE)
  })
})
