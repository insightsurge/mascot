describe("mascot_theme()", {
  it("defaults to following the page and clears with an empty helper", {
    value <- mascot_theme()
    expect_s3_class(value, "mascot_theme")
    expect_identical(value$mode, "auto")
    expect_identical(
      as_theme_arg(value, environment()),
      list(light = NULL, dark = NULL, mode = "auto", css = NULL, brand = NULL)
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
    expect_named(wire$light, c("eye_white", "body_highlight"))
    expect_identical(wire$light, wire$dark)
    expect_identical(wire$light$eye_white, "#FFFFFF")
    expect_identical(wire$mode, "auto")
    css <- as_theme_arg(mascot_theme(css = list(body_highlight = "--team-blue")), environment())
    expect_identical(css$css, list(body_highlight = "--team-blue"))
  })
  it("suggests the closest colour role for a misspelt one, and nothing when no role is close", {
    roles <- colour_role_registry("tessa")
    expect_match(theme_map_problem(list(bdoy = "blue"), "light", roles), 'Did you mean "body"?', fixed = TRUE)
    far <- theme_map_problem(list(zzzzzzzz = "blue"), "light", roles)
    expect_no_match(far, "Did you mean", fixed = TRUE)
    expect_match(far, "mascot_colour_roles()", fixed = TRUE)
  })

  it("rejects malformed maps, reserved roles, colours and helper fields", {
    expect_error(
      mascot("helper", theme = list(bdoy = "blue")),
      'Did you mean "body"?',
      fixed = TRUE,
      class = "mascot_error"
    )
    for (role in c("light", "dark", "default", "eyeWhite", "toString")) {
      expect_error(mascot_theme(light = stats::setNames(list("blue"), role)), "unknown or reserved colour roles")
    }
    for (arg in c("light", "dark", "css")) {
      for (x in list(1, "blue", list("blue"), stats::setNames(list("red", "blue"), c("body", "body")))) {
        expect_error(do.call(mascot_theme, stats::setNames(list(x), arg)), "list|names")
      }
    }
    for (x in list(NULL, "missing", c("light", "dark"), 1, NA_character_)) {
      expect_error(mascot_theme(mode = x), "mode")
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
    withr::local_options(mascot.contrast_warnings = TRUE)
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
  it("sends only brand colours and checks distinct light and dark backgrounds", {
    withr::local_options(mascot.contrast_warnings = TRUE)
    skip_if_not_installed("bslib")
    theme <- bslib::bs_theme(version = 5, primary = "#1f6feb", secondary = "orange", bg = "#102030", fg = "white")
    value <- suppressWarnings(as_theme_arg(theme, environment(), "tessa"))
    expect_identical(value$brand, list(primary = "#1F6FEB", secondary = "#FFA500"))
    expect_null(value$light)
    expect_null(value$dark)
    expect_identical(value$mode, "auto")
    expect_identical(suppressWarnings(as_theme_arg(theme, environment())), value)
    # A primary equal to the theme's own dark background must warn for dark mode only.
    dark <- bslib::bs_get_variables(bslib::bs_theme(version = 5), "body-bg-dark")[[1]]
    dark_theme <- bslib::bs_theme(version = 5, primary = dark, secondary = "white")
    warnings <- list()
    withCallingHandlers(as_theme_arg(dark_theme, environment()), warning = function(w) {
      warnings[[length(warnings) + 1L]] <<- w
      invokeRestart("muffleWarning")
    })
    expect_true(all(vapply(warnings, inherits, logical(1), "mascot_contrast")))
    messages <- vapply(warnings, conditionMessage, character(1))
    expect_true(any(grepl("primary.*dark mode", messages)))
    expect_false(any(grepl("primary.*light mode", messages)))
    expect_warning(as_theme_arg(list(body = "white"), environment()), class = "mascot_contrast")
  })
  it("needs bslib 0.6.0 or later for a bs_theme(), and says so for an older bslib", {
    skip_if_not_installed("bslib", "0.6.0")
    expect_true(theme_has_bslib())
    local_mocked_bindings(bslib_version = function() numeric_version("0.5.0"))
    expect_false(theme_has_bslib())
    expect_match(
      theme_problem(structure(list(), class = "bs_theme")),
      "`theme` needs bslib 0.6.0 or later for a bs_theme() object.",
      fixed = TRUE
    )
  })
  it("accepts bslib 0.6.0 itself as the first supported version", {
    skip_if_not_installed("bslib")
    local_mocked_bindings(bslib_version = function() numeric_version("0.6.0"))
    expect_true(theme_has_bslib())
    expect_null(theme_problem(structure(list(), class = "bs_theme")))
  })
  it("treats bslib 0.10.0 as newer than 0.6.0", {
    skip_if_not_installed("bslib")
    local_mocked_bindings(bslib_version = function() numeric_version("0.10.0"))
    expect_true(theme_has_bslib())
  })
  it("explains an unavailable optional source and checks internal contracts", {
    local_mocked_bindings(theme_has_bslib = function() FALSE)
    expect_match(theme_problem(structure(list(), class = "bs_theme")), "needs bslib 0.6.0 or later", fixed = TRUE)
    expect_error(as_theme_arg(list(), NULL), "'call'")
    expect_error(as_theme_arg(list(), environment(), "missing"), "must be one of", class = "mascot_error_choice")
    expect_error(theme_problem(NULL, NA_character_), "roles")
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

describe("theme_channels()", {
  it("reads short hex colours, as bslib returns them, on every supported R version", {
    expect_identical(theme_channels("#000"), c(red = 0, green = 0, blue = 0, alpha = 1))
    expect_identical(theme_channels("#f80"), theme_channels("#ff8800"))
    expect_identical(theme_channels("#f80c"), theme_channels("#ff8800cc"))
  })
})

describe("theme_colour()", {
  it("accepts short hex colours (#000, #fff, #abc) and returns the same result as the six-digit form", {
    for (short in c("#000", "#fff", "#abc")) {
      long <- paste0("#", paste(rep(strsplit(substring(short, 2), "")[[1]], each = 2), collapse = ""))
      expect_identical(theme_colour(short, "body"), theme_colour(long, "body"))
    }
  })
})

describe("mascot_theme() named arguments", {
  it("keeps the agreed signature and rejects both forms of extra argument", {
    expect_identical(names(formals(mascot_theme)), c("...", "palette", "light", "dark", "mode", "css"))
    expect_error(mascot_theme(typo = 1), "Unexpected arguments", class = "mascot_error")
    expect_error(mascot_theme(1), "Name the optional arguments", class = "mascot_error")
  })
})


describe("R contrast warning policy", {
  it("is silent outside development mode and warns in development mode", {
    withr::local_options(mascot.contrast_warnings = NULL)
    local_mocked_bindings(in_devmode = function() FALSE, .package = "shiny")
    expect_silent(mascot("helper", theme = mascot_theme(light = list(body = "white"))))
    local_mocked_bindings(in_devmode = function() TRUE, .package = "shiny")
    expect_warning(mascot("helper", theme = mascot_theme(light = list(body = "white"))), class = "mascot_contrast")
  })
  it("lets the option override development mode in either direction", {
    local_mocked_bindings(in_devmode = function() FALSE, .package = "shiny")
    withr::local_options(mascot.contrast_warnings = TRUE)
    expect_warning(mascot("helper", theme = mascot_theme(light = list(body = "white"))), class = "mascot_warning")
    local_mocked_bindings(in_devmode = function() TRUE, .package = "shiny")
    withr::local_options(mascot.contrast_warnings = FALSE)
    expect_silent(mascot("helper", theme = mascot_theme(light = list(body = "white"))))
    expect_error(contrast_warnings(always = NA), "always")
  })
})


describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_theme(light = 1), "light", class = "mascot_error")
    expect_error(mascot_theme(dark = 1), "dark", class = "mascot_error")
    expect_error(mascot_theme(mode = 1), "mode", class = "mascot_error")
    expect_error(mascot_theme(css = 1), "css", class = "mascot_error")
  })
  it("adds mascot_error to the registered format and print methods", {
    expect_error(format.mascot_theme(1), "x", class = "mascot_error")
    expect_error(print.mascot_theme(1), "x", class = "mascot_error")
  })
})

describe("named palette themes", {
  it("resolves a reusable palette only when it meets a character and prints its id", {
    value <- mascot_theme(palette = "coral_navy")
    expect_identical(capture.output(print(value)), 'mascot_theme(palette = "coral_navy")')
    expect_identical(eval(parse(text = format(value))), value)
    expect_identical(as_theme_arg(value, environment(), "tessa")$palette_colours$light$body, "#FFE5D9")
    expect_identical(as_theme_arg(value, environment(), "sela")$palette_colours$light$hair_purple, "#1D3557")
    expect_identical(as_theme_arg("orbit", environment(), "knurl")$palette, "orbit")
    expect_identical(as_theme_arg("original", environment(), "knurl")$palette_colours, list(light = NULL, dark = NULL))
    expect_identical(as_theme_arg(value, environment())$palette, "coral_navy")
    expect_error(
      mascot("helper", character = "knurl", theme = "oribt"),
      'oribt.*knurl.*original.*orbit.*carbon.*cobalt_droid.*crimson.*Did you mean "orbit"',
      class = "mascot_error"
    )
    expect_error(mascot("helper", character = "knurl", theme = "zzzzzz"), "zzzzzz.*knurl.*orbit")
    # A palette that exists on another character says which one (#358); a made-up name adds no hint.
    expect_error(
      mascot("helper", character = "tessa", theme = "azure"),
      'Unknown palette "azure" for character "tessa".*Choose "night_teal".*Character "sela" has a palette called "azure"',
      class = "mascot_error"
    )
    message <- tryCatch(mascot("helper", character = "tessa", theme = "zzzzzz"), error = conditionMessage)
    expect_false(grepl("has a palette called", message, fixed = TRUE))
    expect_error(
      mascot("helper", character = "tessa", theme = "orchid"),
      'Unknown palette "orchid" for character "tessa".*Character "sela" has a palette called "orchid"',
      class = "mascot_error"
    )
    peach <- theme_palette_problem("peach", character_catalogue_get("knurl"))
    expect_match(peach, 'Character "tessa" has a palette called "peach"', fixed = TRUE)
    both <- theme_palette_problem("coral_navy", character_catalogue_get("knurl"))
    expect_match(both, 'Characters "tessa", "sela" have a palette called "coral_navy"', fixed = TRUE)
    expect_no_error(mascot("helper", character = "knurl", theme = "original"))
  })
  it("accepts Tessa's own name for her colours, night_teal, and original alike", {
    for (palette in c("night_teal", "original")) {
      expect_no_error(mascot("helper", character = "tessa", theme = palette))
      expect_identical(
        as_theme_arg(palette, environment(), "tessa")$palette_colours,
        list(light = NULL, dark = NULL),
        info = palette
      )
    }
    data <- character_catalogue_get("tessa")
    expect_null(theme_palette_problem("night_teal", data))
    expect_null(theme_palette_problem("original", data))
    expect_identical(
      character_format_colours(data, preset = "night_teal"),
      character_format_colours(data, preset = "original")
    )
    expect_identical(character_format_colours(data, preset = "night_teal")$body, character_colour("#079C9B"))
    expect_false(identical(
      character_format_colours(data, preset = "forest")$body,
      character_format_colours(data, preset = "original")$body
    ))
  })
  it("keeps explicit roles and CSS above the palette and checks only supplied colours", {
    withr::local_options(mascot.contrast_warnings = TRUE)
    for (id in builtin_characters()$id) {
      for (palette in mascot_palettes(id)$name) {
        expect_no_warning(mascot("helper", character = id, theme = palette))
      }
    }
    value <- mascot_theme(
      palette = "orbit",
      light = list(body = "#ffffff"),
      dark = list(body = "#212529"),
      css = list(body = "--team-body")
    )
    warnings <- list()
    wire <- withCallingHandlers(as_theme_arg(value, environment(), "knurl"), warning = function(warning) {
      warnings[[length(warnings) + 1L]] <<- warning
      invokeRestart("muffleWarning")
    })
    expect_length(warnings, 2)
    expect_true(all(vapply(warnings, inherits, logical(1), "mascot_contrast")))
    expect_identical(wire$palette_colours$light$body, "#F8FAFC")
    expect_identical(wire$light$body, "#FFFFFF")
    expect_identical(wire$dark$body, "#212529")
    expect_identical(wire$css$body, "--team-body")
    expect_identical(wire$palette_colours$light, wire$palette_colours$dark)
    data <- character_colour_data("knurl")
    data$palettes$orbit$dark <- list(body = "#123456")
    expect_identical(theme_palette_colours("orbit", data)$dark, list(body = "#123456"))
  })
  it("checks palette argument types, shortcut shapes and internal assertions", {
    for (value in list(1, "", NA_character_, c("a", "b"), list())) {
      expect_error(mascot_theme(palette = value), "palette", class = "mascot_error")
    }
    expect_error(mascot("helper", theme = c("orbit", "carbon")), "one palette id")
    expect_error(mascot("helper", theme = NA_character_), "one palette id")
    for (fn in list(theme_palette_problem, theme_palette_colours)) {
      expect_error(fn(1, list()), "palette")
      expect_error(fn("original", 1), "data")
    }
    expect_error(theme_palette_colours("absent", character_colour_data("knurl")), "absent.*knurl.*orbit")
    expect_error(mascot_theme(palette = "orbit", brand = list()), "Unexpected arguments")
  })
})


describe("cold-start palette validation", {
  it("names malformed palette ids without wire assertion text or accepting other fields", {
    for (palette in c("Orbit", "peach-ink")) {
      for (theme in list(palette, mascot_theme(palette = palette))) {
        f <- protocol_fixture()
        withr::defer(f$session$close())
        warning <- expect_warning(
          update_mascot("helper", theme = theme, status = "Not accepted", session = f$session),
          paste0("lowercase palette id.*", palette),
          class = "mascot_warning"
        )
        expect_false(grepl("Assertion|patch\\$theme", conditionMessage(warning)))
        expect_null(f$session$userData$mascot_protocol)
        expect_length(f$messages$values, 0L)
      }
    }
  })
})

describe("B2 theme diagnostics", {
  it("lists valid roles and classifies invalid mode choices", {
    problem <- theme_map_problem(list(typo = "red"), "theme", c("body", "rim"))
    expect_match(problem, "body", fixed = TRUE)
    expect_match(problem, "rim", fixed = TRUE)
    expect_error(mascot_theme(mode = "night"), class = "mascot_error_choice")
  })
  it("warns once for a non-flag contrast option and uses the default", {
    old <- contrast_warning_state$warned
    withr::defer(contrast_warning_state$warned <- old)
    contrast_warning_state$warned <- FALSE
    withr::local_options(mascot.contrast_warnings = "yes")
    expect_warning(expect_true(contrast_warnings(always = TRUE)), "mascot.contrast_warnings", class = "mascot_warning")
    expect_no_warning(expect_true(contrast_warnings(always = TRUE)))
  })
})


describe("mascot_theme() custom roles", {
  it("checks role form first and membership against the selected character", {
    withr::local_options(mascot.contrast_warnings = FALSE)
    local_empty_registry()
    source <- jsonlite::read_json(system.file("examples", "characters", "study_bot.json", package = "mascot"))
    source$colours$signal_lamp <- "#112233"
    bot <- mascot_check_character(source)
    theme <- mascot_theme(
      light = list(signal_lamp = "#123456"),
      dark = list(signal_lamp = "#234567"),
      css = list(signal_lamp = "--signal")
    )
    expect_null(theme_problem(theme))
    expect_match(as.character(mascot("bot", character = bot, theme = theme)), "signal_lamp", fixed = TRUE)
    session <- shiny::MockShinySession$new()
    withr::defer(session$close())
    update_mascot("bot", character = bot, theme = theme, session = session)
    expect_identical(mascot_id_state(session, "bot")$desired$theme$light$signal_lamp, "#123456")
    expect_error(mascot("helper", theme = theme), "mascot_colour_roles", class = "mascot_error")
    expect_warning(update_mascot("other", character = "tessa", theme = theme, session = session), "unknown or reserved")
    for (role in c("a-b", "a__b", "A", "1role", "light", "dark", "default")) {
      expect_error(mascot_theme(light = stats::setNames(list("blue"), role)), "unknown or reserved")
    }
    expect_s3_class(mascot_theme(light = list(signal2_ = "blue")), "mascot_theme")
    for (field in c("light", "dark", "css")) {
      map <- if (field == "css") list(signal_lamp = "--signal") else list(signal_lamp = "#123456")
      single <- do.call(mascot_theme, stats::setNames(list(map), field))
      wire <- as_theme_arg(single, environment())
      expect_named(wire[[field]], "signal_lamp")
      expect_match(as.character(mascot_preview(bot, mood = "idle", theme = single)), "signal_lamp", fixed = TRUE)
      problem <- theme_problem(single, colour_role_registry("tessa"))
      error <- tryCatch(mascot("invalid", theme = single), error = identity)
      expect_s3_class(error, "mascot_error")
      expect_identical(gsub("[[:space:]]+", " ", conditionMessage(error)), gsub("[[:space:]]+", " ", problem))
    }
    expect_length(character_data_ids(), 0)
  })
})


describe("theme role naming before a character is chosen", {
  it("explains the naming rule without suggesting built-in roles", {
    for (role in c("Bdoy", "a__b", "light", "dark", "default")) {
      problem <- theme_map_problem(stats::setNames(list("blue"), role), "light", NULL)
      expect_match(problem, "lowercase snake case", fixed = TRUE)
      expect_match(problem, "optional final underscore", fixed = TRUE)
      expect_match(problem, "`light`, `dark` and `default` are reserved", fixed = TRUE)
      expect_match(problem, "mascot_colour_roles()", fixed = TRUE)
      expect_false(grepl("Did you mean|Valid roles:", problem))
    }
  })
  it("caches the schema's colour-map key pattern for repeated checks", {
    schema <- character_format_schema()
    expect_identical(schema$definitions$colour_map$key_pattern, schema$definitions$id$pattern)
    # An empty cache makes the read count independent of preceding tests.
    local_mocked_bindings(theme_role_pattern_cache = new.env(parent = emptyenv()))
    reads <- new.env(parent = emptyenv())
    reads$n <- 0L
    local_mocked_bindings(character_format_schema = function() {
      reads$n <- reads$n + 1L
      schema
    })
    expect_null(theme_map_problem(list(signal2_ = "blue"), "light", NULL))
    expect_null(theme_map_problem(list(signal_lamp = "blue"), "light", NULL))
    expect_identical(reads$n, 1L)
  })
})


describe("theme_map_problem() message", {
  it("names the unknown role, suggests the closest one and lists the character's roles in order", {
    roles <- colour_role_registry("tessa")
    expected <- paste0(
      '`theme` has unknown or reserved colour roles: "bdoy". Did you mean "body"? Valid roles: ',
      paste0('"', roles, '"', collapse = ", "),
      ". See `mascot_colour_roles()` for each character's roles."
    )
    expect_identical(theme_map_problem(list(bdoy = "blue"), "theme", roles), expected)
  })
})
