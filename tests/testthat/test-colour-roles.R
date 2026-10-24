describe("mascot_colour_roles()", {
  it("lists description colours in order with snake case and follow rules", {
    value <- mascot_colour_roles()
    expect_identical(value, mascot_colour_roles("tessa"))
    expect_s3_class(value, "data.frame")
    expect_named(value, c("role", "colour", "follows", "shade", "description", "brand"))
    expect_equal(nrow(value), 33)
    expect_identical(value$role[3], "eye_white")
    expect_identical(value$role[9], "body_highlight")
    expect_identical(value$colour[value$role == "body"], "#079C9B")
    expect_identical(value$follows[value$role == "limb"], "rim, body")
    expect_identical(value$shade[value$role == "body_highlight"], "lighter")
    expect_identical(value$shade[value$role == "accessory_detail"], "darker")
    expect_identical(value$shade[value$role == "sleeve"], "same")
    expect_true(all(is.na(value$follows[value$role %in% c("body", "rim", "outline")])))
    # Rows read by hand from inst/format/characters/tessa.json: the first and last roles in file order, a follower
    # with its rule, and the brand leaders.
    expect_identical(head(value$role, 5), c("outline", "feature", "eye_white", "shine", "teeth"))
    expect_identical(head(value$colour, 5), c("#14221B", "#14221B", "#FFFDF4", "#FFFDF4", "#FFFDF4"))
    expect_identical(
      as.list(value[value$role == "iris_tint", c("colour", "follows", "shade")]),
      list(colour = "#43A89E", follows = "iris", shade = "lighter")
    )
    expect_identical(value$brand[match(c("body", "rim"), value$role)], c("primary", "secondary"))
    expect_identical(colour_role_registry("tessa")[c(1, 33)], c("outline", "iris_tint"))
  })
  it("gives no built-in character a role named like a theme mode, so every role can be themed", {
    for (id in builtin_characters()$id) {
      expect_false(any(colour_role_registry(id) %in% c("light", "dark", "default")), info = id)
    }
    expect_true("lamp" %in% mascot_colour_roles("knurl")$role)
    expect_no_error(mascot_theme(light = list(lamp = "#ff0000"), dark = list(lamp_happy = "#00ff00")))
  })
})

describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_colour_roles(character = 1), "character", class = "mascot_error")
  })
})

describe("mascot_colour_roles(palette =)", {
  it("shows palette leaders and derives followers from them", {
    roles <- mascot_colour_roles("tessa", palette = "mist_navy")
    expect_identical(roles$colour[roles$role == "body"], "#DCE5EC")
    # The arms follow the body shade, which this palette supplies; the feet follow the ring.
    expect_identical(roles$colour[roles$role == "sleeve"], "#C9D1D8")
    expect_identical(roles$colour[roles$role == "limb"], "#8FAAC0")
    expect_identical(roles$colour[roles$role == "feature"], "#1A2740")
    expect_identical(roles$colour[roles$role == "accessory"], "#E9B84A")
    expect_identical(mascot_colour_roles("tessa", palette = "original"), mascot_colour_roles("tessa"))
    expect_error(mascot_colour_roles("knurl", palette = "oribt"), "oribt.*knurl.*orbit.*Did you mean")
  })
  it("treats Tessa's own name for her colours, night_teal, exactly like original", {
    expect_identical(
      mascot_colour_roles("tessa", palette = "night_teal"),
      mascot_colour_roles("tessa", palette = "original")
    )
    expect_identical(mascot_colour_roles("tessa", palette = "night_teal"), mascot_colour_roles("tessa"))
  })
  it("treats Sela's own name for her colours, lilac_violet, exactly like original", {
    expect_identical(
      mascot_colour_roles("sela", palette = "lilac_violet"),
      mascot_colour_roles("sela", palette = "original")
    )
    expect_identical(mascot_colour_roles("sela", palette = "lilac_violet"), mascot_colour_roles("sela"))
    roles <- mascot_colour_roles("sela", palette = "original")
    expect_identical(roles$colour[roles$role == "body"], "#D9C8F5")
    expect_identical(roles$colour[roles$role == "hair_purple"], "#4B2A8C")
  })
  it("preserves untouched native colour strings including alpha and hex case", {
    for (id in c("neer", "knurl", "tessa")) {
      palette <- c(neer = "lagoon", knurl = "orbit", tessa = "coral_navy")[[id]]
      role <- c(neer = "shell_rib", knurl = "shine_translucent", tessa = "eye_white")[[id]]
      native <- mascot_colour_roles(id)
      themed <- mascot_colour_roles(id, palette = palette)
      expect_identical(themed$colour[themed$role == role], native$colour[native$role == role])
      expect_true(all(vapply(themed$colour, function(colour) !is.null(theme_channels(colour)), logical(1))))
    }
    data <- character_catalogue_get("tessa")
    data$palettes$coral_navy$light$body <- "rgba(255,229,217,0.5)"
    # The catalogue is restored after this test, including any caller-owned entries.
    saved <- character_catalogue_cache$tessa
    withr::defer(character_catalogue_cache$tessa <- saved)
    character_catalogue_cache$tessa <- data
    colours <- mascot_colour_roles("tessa", palette = "coral_navy")
    eyelid <- colours$colour[colours$role == "eyelid"]
    expect_match(eyelid, "^rgba\\(")
    expect_equal(theme_channels(eyelid), c(255, 229, 217, 0.5))
  })
  it("checks palette types and requires it to be named", {
    expect_identical(names(formals(mascot_colour_roles)), c("character", "...", "palette"))
    for (value in list(1, "", NA_character_, c("coral_navy", "peach"))) {
      expect_error(mascot_colour_roles(palette = value), "palette", class = "mascot_error")
    }
    expect_error(mascot_colour_roles("tessa", "coral_navy"), "Name the optional arguments", class = "mascot_error")
    expect_error(mascot_colour_roles(typo = 1), "Unexpected arguments", class = "mascot_error")
  })
})

describe("mascot_colour_roles()", {
  it("names unknown characters and checks internal contracts", {
    for (x in list(NULL, 1, "", NA_character_, c("tessa", "tessa"))) {
      expect_error(mascot_colour_roles(x), "Assertion on 'character' failed")
    }
    expect_error(character_colour_data("missing"), "must be one of", class = "mascot_error_choice")
    expect_error(colour_role_registry("missing"), "must be one of", class = "mascot_error_choice")
  })
})
