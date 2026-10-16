describe("the authoring constructors", {
  it("builds the complete small character and matches the reference source fixture", {
    # Given the proposal's example written with the constructors
    draft <- author_study_bot()
    # When it is checked
    checked <- character_check(draft)
    # Then it equals the reference fixture, apart from the order of `requires`
    reference <- character_format_check(format_recipe("study_bot"))
    expect_s3_class(draft, "mascot_character_spec")
    expect_s3_class(checked, "mascot_character_data")
    expect_setequal(unlist(checked$requires), unlist(reference$requires))
    expect_identical(unlist(checked$requires), c("parts", "clip", "outline", "glow", "face_kit", "tracks", "lod"))
    checked$requires <- reference$requires
    expect_identical(character_format_identity(checked), character_format_identity(reference))
    expect_identical(attr(character_check(draft), "mascot_manifest")$playable$wave, "rock")
  })

  it("accepts a known family id when the caller supplies the family to the checker", {
    family <- author_visorfolk()
    draft <- author_study_bot("visorfolk")
    expect_null(draft$family_definition)
    expect_error(character_check(draft), class = "mascot_error_character")
    families <- list(visorfolk = family$value)
    expect_identical(character_check(draft, families = families)$id, "study_bot")
  })

  it("does not let a source specification pass the checked-data reader", {
    format_problem("capability", "$.requires", character_format_check(unclass(author_study_bot())))
  })

  it("rejects a mutated checked component at the next consuming boundary", {
    part <- character_author_part("head", list(character_author_shape("circle", list(r = 5))))
    part$value$items <- list(list(shape = "circle", r = -1))
    expect_error(
      character_author_build(
        "bot",
        "visorfolk",
        "Bot",
        "A bot.",
        list(body = "#3f82ff"),
        character_author_ground(60),
        list(part),
        list(character_author_mood("idle", "At rest.", "Ready"))
      ),
      class = "mascot_error_character"
    )
  })
})

describe("character_author_shape()", {
  it("writes only supplied optional fields and keeps format keys", {
    shape <- character_author_shape("circle", list(x = 0, y = 0, r = 5), fill = "accent")
    expect_s3_class(shape, "mascot_character_shape")
    expect_identical(shape$value, list(shape = "circle", x = 0, y = 0, r = 5, fill = "accent"))
  })

  it("maps transform, cap and join to the format when supplied", {
    shape <- character_author_shape(
      "ellipse",
      list(rx = 4, ry = 2),
      stroke = "outline",
      width = 3,
      cap = "butt",
      join = "miter",
      transform = c(1, 2, 0.5),
      lod = c("full", "small")
    )
    expect_identical(shape$value$cap, "butt")
    expect_identical(shape$value$join, "miter")
    expect_identical(shape$value$width, 3)
    expect_identical(unlist(shape$value$transform), c(1, 2, 0.5))
    expect_identical(unlist(shape$value$lod), c("full", "small"))
  })

  it("asserts every argument", {
    circle <- list(r = 1)
    expect_error(character_author_shape("blob", circle), "type")
    expect_error(character_author_shape("circle", list()), "geometry")
    expect_error(character_author_shape("circle", circle, id = "Bad Id"), "id")
    expect_error(character_author_shape("circle", circle, stroke = 1), "stroke")
    expect_error(character_author_shape("circle", circle, width = -1), "width")
    expect_error(character_author_shape("circle", circle, alpha = 2), "alpha")
    expect_error(character_author_shape("circle", circle, outline = "yes"), "outline")
    expect_error(character_author_shape("circle", circle, clip = "head"), "clip")
    expect_error(character_author_shape("circle", circle, lod = "tiny"), "lod")
    expect_error(character_author_shape("circle", circle, transform = c(1, 2)), "transform")
    expect_error(character_author_shape("circle", circle, cap = "flat"), "cap")
    expect_error(character_author_shape("circle", circle, join = "flat"), "join")
  })

  it("rejects unknown and positional optional arguments instead of ignoring them", {
    circle <- list(r = 1)
    format_problem("unknown_key", "$.shape", character_author_shape("circle", circle, colour = "red"))
    format_problem("unknown_key", "$.shape", character_author_shape("circle", circle, "accent"))
  })

  it("rejects painting keys hidden in geometry and incomplete geometry", {
    format_problem("unknown_key", "$.shape.geometry", character_author_shape("circle", list(r = 1, fill = "body")))
    expect_error(character_author_shape("circle", list(x = 0)), class = "mascot_error_character")
  })
})

describe("character_author_part()", {
  it("keeps variants, sets only what is supplied and rejects reserved or repeated ids", {
    dot <- character_author_shape("circle", list(r = 2), id = "dot", fill = "body")
    tucked <- character_author_shape("circle", list(r = 1), fill = "body")
    part <- character_author_part("foot", list(dot), variants = list(tuck = list(tucked)), layer = 4)
    expect_identical(part$id, "foot")
    expect_named(part$value, c("id", "layer", "variants", "items"))
    expect_named(part$value$variants, "tuck")
    format_problem("identity", "$.parts.id", character_author_part("root", list(dot)))
    format_problem("duplicate_id", "$.parts.foot.items", character_author_part("foot", list(dot, dot)))
  })

  it("asserts arguments and refuses non-shape items", {
    dot <- character_author_shape("circle", list(r = 2))
    expect_error(character_author_part("Head", list(dot)), "id")
    expect_error(character_author_part("head", dot), "items")
    expect_error(character_author_part("head", list(dot), at = c(1, 2, 3)), "at")
    expect_error(character_author_part("head", list(dot), scale = c(1, 2, 3)), "scale")
    expect_error(character_author_part("head", list(dot), opacity = 2), "opacity")
    expect_error(character_author_part("head", list(dot), keep_upright = "yes"), "keep_upright")
    expect_error(character_author_part("head", list(dot), colour = "red"), class = "mascot_error_character")
    format_problem("input_type", "$.parts.head.items[0]", character_author_part("head", list(list(shape = "circle"))))
  })
})

describe("character_author_anchor()", {
  it("accepts any snake_case name, defaults the description to the id and allows a point outside the body", {
    anchor <- character_author_anchor("tool_grip", "hand_r", at = c(900, -40), side = "r")
    expect_identical(anchor$id, "tool_grip")
    expect_identical(anchor$value$description, "tool_grip")
    expect_identical(anchor$value$part, "hand_r")
    expect_identical(unlist(anchor$value$at), c(900, -40))
    expect_false("scale" %in% names(anchor$value))
  })

  it("carries variants and asserts its arguments", {
    anchor <- character_author_anchor("badge", "head", variants = list(tuck = list(at = c(1, 2))))
    expect_named(anchor$value$variants, "tuck")
    expect_error(character_author_anchor("Badge", "head"), "id")
    expect_error(character_author_anchor("badge", "head", scale = 0), "scale")
    expect_error(character_author_anchor("badge", "head", side = "up"), "side")
    expect_error(character_author_anchor("badge", "head", at = 1), "at")
    format_problem("unknown_key", "$.anchors.badge", character_author_anchor("badge", "head", elsewhere = "x"))
  })

  it("is checked against the real owning part at final resolution", {
    draft <- author_study_bot()
    draft$anchors$stray <- list(part = "no_such_part", description = "Points nowhere.")
    expect_error(character_check(draft), class = "mascot_error_character")
  })
})

describe("character_author_face()", {
  it("embeds a kit definition when given one and omits empty blocks", {
    kit <- character_format_kits()$screen
    face <- character_author_face(kit, "head", eyes = list(y = -2))
    expect_identical(face$value$kit, "screen")
    expect_identical(face$value$kit_definition$id, "screen")
    expect_named(face$value, c("kit", "part", "eyes", "kit_definition"))
    expect_named(character_author_face("screen", "head")$value, c("kit", "part"))
  })

  it("asserts its arguments", {
    expect_error(character_author_face(1, "head"), "kit")
    expect_error(character_author_face("screen", "Head"), "part")
    expect_error(character_author_face("screen", "head", scale = 0), "scale")
    expect_error(character_author_face("screen", "head", clip = "head"), "clip")
    expect_error(character_author_face("screen", "head", eyes = 1), "eyes")
    expect_error(character_author_face(list(name = "no id"), "head"), class = "mascot_error_character")
    format_problem("unknown_key", "$.face", character_author_face("screen", "head", mood = "x"))
  })
})

describe("character_author_mood()", {
  it("keeps the authored status and optional fallback, separate from the runtime selector", {
    mood <- character_author_mood("calm", "Quiet.", "Calm", fallback = "idle", effects = list(sparkle = TRUE))
    expect_identical(mood$value$fallback, "idle")
    expect_identical(mood$value$effects, list(sparkle = TRUE))
    expect_false("face" %in% names(mood$value))
  })

  it("asserts its arguments", {
    expect_error(character_author_mood("Calm", "Quiet.", "Calm"), "id")
    expect_error(character_author_mood("calm", "", "Calm"), "description")
    expect_error(character_author_mood("calm", "Quiet.", 1), "status")
    expect_error(character_author_mood("calm", "Quiet.", "Calm", fallback = 1), "fallback")
    format_problem("unknown_key", "$.moods.calm", character_author_mood("calm", "Quiet.", "Calm", "extra"))
  })
})

describe("character_author_track() and character_author_gesture()", {
  rows <- list(list(0, 0), list(0.5, 0.2), list(1, 0))

  it("derives add for numeric channels and set for discrete channels", {
    expect_identical(character_author_track("head.rotate", rows)$value$mode, "add")
    set_rows <- list(list(0, NULL), list(0.5, "open", "step"), list(1, NULL))
    expect_identical(character_author_track("face.mouth", set_rows)$value$mode, "set")
    expect_identical(character_author_track("head.variant", set_rows)$value$mode, "set")
  })

  it("preserves null endpoints and mixed row types", {
    rows <- list(list(0, NULL), list(0.5, "open", "step"), list(1, NULL))
    keys <- character_author_track("face.mouth", rows)$value$keys
    expect_null(keys[[1]][[2]])
    expect_length(keys[[1]], 2)
    expect_identical(keys[[2]][[2]], "open")
    expect_identical(keys[[2]][[3]], "step")
  })

  it("rejects an explicit incompatible mode and malformed rows", {
    expect_error(character_author_track("face.mouth", rows, mode = "add"), class = "mascot_error_character")
    expect_error(character_author_track("head.rotate", rows, mode = "multiply"), "mode")
    expect_error(character_author_track("rotate", rows), "channel")
    expect_error(character_author_track("head.rotate", list(list(0, 0))), "keys")
    expect_error(character_author_track("head.rotate", list(c(0, 0), c(1, 0))), "row")
    expect_error(character_author_track("head.rotate", list(list(0, 0), list(2, 0))), class = "mascot_error_character")
    format_problem("unknown_key", "$.tracks.head.rotate", character_author_track("head.rotate", rows, "add"))
  })

  it("keeps a single need as an array and rejects repeated channels", {
    track <- character_author_track("hand_r.rotate", rows)
    gesture <- character_author_gesture("wave", "Waves.", 30, list(track), needs = "hand_r", fallback = "rock")
    expect_identical(gesture$value$needs, list("hand_r"))
    expect_named(gesture$value$tracks, "hand_r.rotate")
    format_problem(
      "duplicate_id",
      "$.gestures.wave.tracks",
      character_author_gesture("wave", "Waves.", 30, list(track, track))
    )
  })

  it("asserts its arguments", {
    track <- character_author_track("head.rotate", rows)
    expect_error(character_author_gesture("Wave", "Waves.", 30, list(track)), "id")
    expect_error(character_author_gesture("wave", "Waves.", 0, list(track)), "frames")
    expect_error(character_author_gesture("wave", "Waves.", 30, track), "tracks")
    expect_error(character_author_gesture("wave", "Waves.", 30, list(track), needs = "Hand"), "needs")
    expect_error(character_author_gesture("wave", "Waves.", 151, list(track)), class = "mascot_error_character")
    format_problem(
      "input_type",
      "$.gestures.wave.tracks[0]",
      character_author_gesture("wave", "Waves.", 30, list(rows))
    )
    format_problem(
      "unknown_key",
      "$.gestures.wave",
      character_author_gesture("wave", "Waves.", 30, list(track), loop = TRUE)
    )
  })
})

describe("character_author_palette(), character_author_accessory() and character_author_ground()", {
  it("keeps light and optional dark colour maps", {
    palette <- character_author_palette("sea", "Cool.", c(screen = "#06232a"), dark = list(screen = "#000"))
    expect_identical(palette$value$light, list(screen = "#06232a"))
    expect_identical(palette$value$dark, list(screen = "#000"))
    expect_false("dark" %in% names(character_author_palette("sea", "Cool.", c(screen = "#06232a"))$value))
    expect_error(character_author_palette("sea", "Cool.", c("#06232a")), "light")
    expect_error(character_author_palette("sea", "Cool.", c(screen = "teal")), class = "mascot_error_character")
    expect_error(character_author_palette("sea", "", c(screen = "#000")), "description")
  })

  it("defaults the accessory slot to its id and checks its parts", {
    cap <- character_author_part("cap_top", list(character_author_shape("circle", list(r = 3), fill = "accent")))
    accessory <- character_author_accessory("cap", "A small cap.", "crown", list(cap))
    expect_identical(accessory$value$slot, "cap")
    expect_identical(accessory$value$anchor, "crown")
    expect_length(accessory$value$parts, 1)
    expect_error(character_author_accessory("cap", "A small cap.", "crown", list()), "parts")
    format_problem(
      "input_type",
      "$.accessories.cap.parts[0]",
      character_author_accessory("cap", "A cap.", "crown", list(1))
    )
    format_problem(
      "duplicate_id",
      "$.accessories.cap.parts",
      character_author_accessory("cap", "A cap.", "crown", list(cap, cap))
    )
  })

  it("maps the ground block and rejects a bad shadow", {
    expect_identical(character_author_ground(60)$value, list(centre_height = 60))
    shadow <- list(rx = 20, ry = 4, alpha = 0.4)
    expect_identical(character_author_ground(60, shadow = shadow)$value$shadow, shadow)
    expect_error(character_author_ground(-1), "centre_height")
    expect_error(character_author_ground(60, shadow = list(rx = 0, ry = 1)), class = "mascot_error_character")
    format_problem("unknown_key", "$.ground", character_author_ground(60, "x"))
  })
})

describe("character_author_family()", {
  it("turns component lists in defaults into keyed maps", {
    family <- author_visorfolk()
    expect_named(family$value$defaults$gestures, c("rock", "nod", "wave"))
    expect_named(family$value$defaults$palettes, c("sea_glass", "night_screen"))
    format_problem(
      "duplicate_id",
      "$.family_definition.defaults.palettes",
      character_author_family(
        "dup",
        "Dup",
        "Repeats a palette.",
        defaults = list(
          palettes = list(
            character_author_palette("a", "A.", c(x = "#000")),
            character_author_palette("a", "B.", c(x = "#000"))
          )
        )
      )
    )
  })

  it("asserts its arguments", {
    expect_error(character_author_family("Folk", "Folk", "Folk."), "id")
    expect_error(character_author_family("folk", "", "Folk."), "name")
    expect_error(character_author_family("folk", "Folk", "Folk.", defaults = 1), "defaults")
    format_problem("unknown_key", "$.family_definition", character_author_family("folk", "Folk", "Folk.", parts = 1))
  })
})

describe("character_author_build()", {
  base <- function(...) {
    shape <- character_author_shape("circle", list(r = 5), fill = "body")
    character_author_build(
      "bot",
      "visorfolk",
      "Bot",
      "A bot.",
      list(body = "#3f82ff"),
      character_author_ground(60),
      list(character_author_part("head", list(shape))),
      list(character_author_mood("idle", "At rest.", "Ready")),
      ...
    )
  }

  it("builds a plain format-shaped list with only supplied optional fields", {
    spec <- base()
    expect_s3_class(spec, "mascot_character_spec")
    expect_named(
      spec,
      c("format_version", "id", "name", "family", "description", "requires", "colours", "ground", "parts", "moods")
    )
    expect_identical(spec$requires, list())
    expect_identical(spec$ground, list(centre_height = 60))
  })

  it("writes source-only null opt-outs and refuses to define and omit the same palette", {
    spec <- base(omit_family_palettes = "night_screen")
    expect_true("night_screen" %in% names(spec$palettes))
    expect_null(spec$palettes$night_screen)
    palette <- character_author_palette("night_screen", "Mine.", c(screen = "#000"))
    format_problem(
      "duplicate_id",
      "$.palettes",
      base(palettes = list(palette), omit_family_palettes = "night_screen")
    )
  })

  it("detects duplicate part, anchor, mood, gesture and palette ids", {
    shape <- character_author_shape("circle", list(r = 5))
    part <- character_author_part("head", list(shape))
    mood <- character_author_mood("idle", "At rest.", "Ready")
    build <- function(parts = list(part), moods = list(mood), ...) {
      character_author_build(
        "bot",
        "visorfolk",
        "Bot",
        "A bot.",
        list(body = "#3f82ff"),
        character_author_ground(60),
        parts,
        moods,
        ...
      )
    }
    format_problem("duplicate_id", "$.parts", build(parts = list(part, part)))
    format_problem("duplicate_id", "$.moods", build(moods = list(mood, mood)))
    anchor <- character_author_anchor("badge", "head")
    format_problem("duplicate_id", "$.anchors", build(anchors = list(anchor, anchor)))
    palette <- character_author_palette("sea", "Cool.", c(screen = "#000"))
    format_problem("duplicate_id", "$.palettes", build(palettes = list(palette, palette)))
    gesture <- character_author_gesture(
      "greet",
      "Greets.",
      18,
      list(character_author_track("head.rotate", list(list(0, 0), list(1, 0))))
    )
    format_problem("duplicate_id", "$.gestures", build(gestures = list(gesture, gesture)))
  })

  it("rejects the wrong component kind in each list", {
    mood <- character_author_mood("idle", "At rest.", "Ready")
    format_problem(
      "input_type",
      "$.parts[0]",
      character_author_build(
        "bot",
        "visorfolk",
        "Bot",
        "A bot.",
        list(body = "#3f82ff"),
        character_author_ground(60),
        list(mood),
        list(mood)
      )
    )
  })

  it("asserts its arguments and rejects unknown or positional optional ones", {
    expect_error(base(wear = "Hat"), "wear")
    expect_error(base(outline = 1), "outline")
    expect_error(base(pronouns = 1), "pronouns")
    expect_error(base(face = list()), "face")
    expect_error(base(requires = 1), "requires")
    format_problem("unknown_key", "$", base(feature_flag = TRUE))
    format_problem("unknown_key", "$", base(list()))
    expect_error(
      character_author_build("Bot", "visorfolk", "Bot", "A bot.", list(), character_author_ground(60), list(), list()),
      "id"
    )
  })

  it("computes requires at check time and honours extras, reporting unknown capabilities", {
    expect_identical(
      unlist(character_check(author_study_bot())$requires),
      c("parts", "clip", "outline", "glow", "face_kit", "tracks", "lod")
    )
    extra <- character_check(author_study_bot(requires = "paints"))
    expect_true("paints" %in% unlist(extra$requires))
    format_problem("capability", "$.requires[7]", character_check(author_study_bot(requires = "teleport")))
  })
})

describe("review fixes: family component lists, positive bounds, keyed ids and dots order", {
  track <- character_author_track("root.rotate", list(list(0, 0), list(1, 0)))
  tilt <- character_author_gesture("tilt", "A tilt.", 18, list(track))

  it("accepts a list of components named by their own ids and rejects a mismatched name", {
    family <- character_author_family("folk", "Folk", "Folk.", defaults = list(gestures = list(tilt = tilt)))
    expect_named(family$value$defaults$gestures, "tilt")
    expect_identical(family$value$defaults$gestures$tilt$frames, 18L)
    format_problem(
      "identity",
      "$.family_definition.defaults.gestures",
      character_author_family("folk", "Folk", "Folk.", defaults = list(gestures = list(spin = tilt)))
    )
  })

  it("requires a strictly positive width and scale and says so", {
    expect_error(character_author_shape("circle", list(r = 1), width = 0), "width > 0")
    expect_error(character_author_anchor("badge", "head", scale = 0), "scale > 0")
    expect_error(character_author_face("screen", "head", scale = 0), "scale > 0")
    expect_error(character_author_anchor("badge", "head", scale = -1), "scale > 0")
  })

  it("reports a missing component id as input_type, not as a repeated empty id", {
    mood <- character_author_mood("idle", "At rest.", "Ready")
    mood$id <- NULL
    part <- character_author_part("head", list(character_author_shape("circle", list(r = 5))))
    format_problem(
      "input_type",
      "$.moods[0]",
      character_author_build(
        "bot",
        "folk",
        "Bot",
        "A bot.",
        list(body = "#3f82ff"),
        character_author_ground(60),
        list(part),
        list(mood, mood)
      )
    )
  })

  it("reports an invalid optional argument before an unknown one", {
    part <- character_author_part("head", list(character_author_shape("circle", list(r = 5))))
    mood <- character_author_mood("idle", "At rest.", "Ready")
    expect_error(
      character_author_build(
        "bot",
        "folk",
        "Bot",
        "A bot.",
        list(body = "#3f82ff"),
        character_author_ground(60),
        list(part),
        list(mood),
        wear = "Hat",
        extra = 1
      ),
      "wear"
    )
  })
})

describe("remaining constructor assertions", {
  circle <- list(r = 1)
  shape <- character_author_shape("circle", circle)
  part <- character_author_part("head", list(shape))
  mood <- character_author_mood("idle", "At rest.", "Ready")
  build <- function(...) {
    character_author_build(
      "bot",
      "folk",
      "Bot",
      "A bot.",
      list(body = "#3f82ff"),
      character_author_ground(60),
      list(part),
      list(mood),
      ...
    )
  }

  it("checks shape fill", {
    expect_error(character_author_shape("circle", circle, fill = 1), "fill")
    expect_error(character_author_shape("circle", circle, fill = "Body"), "fill")
    expect_identical(
      character_author_shape("circle", circle, fill = list(paint = "sky"))$value$fill,
      list(paint = "sky")
    )
  })

  it("checks every part argument", {
    expect_error(character_author_part("head", list(shape), parent = "Root"), "parent")
    expect_error(character_author_part("head", list(shape), rotate = "a"), "rotate")
    expect_error(character_author_part("head", list(shape), layer = Inf), "layer")
    expect_error(character_author_part("head", list(shape), variants = 1), "variants")
    expect_error(character_author_part("head", list(shape), switch = 1), "switch")
    expect_error(character_author_part("head", list(shape), visible = NA), "visible")
    expect_error(character_author_part("head", list(shape), glow = 1), "glow")
    expect_error(character_author_part("head", list(shape), no_flip = 1), "no_flip")
    expect_error(character_author_part("head", list(shape), lod = "tiny"), "lod")
  })

  it("checks the remaining anchor, face, mood, palette, accessory and ground arguments", {
    expect_error(character_author_anchor("badge", "Head"), "part")
    expect_error(character_author_anchor("badge", "head", rotate = "a"), "rotate")
    expect_error(character_author_anchor("badge", "head", description = ""), "description")
    expect_error(character_author_anchor("badge", "head", variants = 1), "variants")
    expect_error(character_author_face("screen", "head", at = 1), "at")
    expect_error(character_author_face("screen", "head", mouth = 1), "mouth")
    expect_error(character_author_face("screen", "head", blush = 1), "blush")
    expect_error(character_author_face("screen", "head", colours = 1), "colours")
    expect_error(character_author_face("screen", "head", tune = 1), "tune")
    expect_error(character_author_face("screen", "head", styles = 1), "styles")
    expect_error(character_author_face("screen", "head", caps = 1), "caps")
    expect_error(character_author_face("screen", "head", layer = "a"), "layer")
    expect_error(character_author_mood("idle", "At rest.", "Ready", pose = 1), "pose")
    expect_error(character_author_mood("idle", "At rest.", "Ready", face = 1), "face")
    expect_error(character_author_mood("idle", "At rest.", "Ready", channels = 1), "channels")
    expect_error(character_author_mood("idle", "At rest.", "Ready", recolour = 1), "recolour")
    expect_error(character_author_mood("idle", "At rest.", "Ready", items = 1), "items")
    expect_error(character_author_mood("idle", "At rest.", "Ready", effects = 1), "effects")
    expect_error(character_author_mood("idle", "At rest.", "Ready", reduced = 1), "reduced")
    expect_error(character_author_palette("Sea", "Cool.", c(a = "#000")), "id")
    expect_error(character_author_palette("sea", "Cool.", c(a = "#000"), dark = 1), "dark")
    expect_error(character_author_accessory("Cap", "A cap.", "crown", list(part)), "id")
    expect_error(character_author_accessory("cap", "", "crown", list(part)), "description")
    expect_error(character_author_accessory("cap", "A cap.", "Crown", list(part)), "anchor")
    expect_error(character_author_accessory("cap", "A cap.", "crown", list(part), slot = "Hat"), "slot")
    expect_error(character_author_accessory("cap", "A cap.", "crown", list(part), colours = 1), "colours")
    expect_error(character_author_accessory("cap", "A cap.", "crown", list(part), lod = "tiny"), "lod")
    expect_error(character_author_ground(60, shadow = 1), "shadow")
    expect_error(character_author_track("head.rotate", list(list(0, 0), list(1, 0)), mode = 1), "mode")
    expect_error(character_author_gesture("wave", "Waves.", 30, list(), fallback = 1), "fallback")
    expect_error(character_author_gesture("wave", "Waves.", 30, list(), effects = 1), "effects")
  })

  it("checks every character_author_build() argument", {
    expect_error(build(anchors = 1), "anchors")
    expect_error(build(face = 1), "face")
    expect_error(build(gestures = 1), "gestures")
    expect_error(build(poses = 1), "poses")
    expect_error(build(palettes = 1), "palettes")
    expect_error(build(follows = 1), "follows")
    expect_error(build(brand = 1), "brand")
    expect_error(build(contrast = 1), "contrast")
    expect_error(build(modes = 1), "modes")
    expect_error(build(motion = 1), "motion")
    expect_error(build(effects = 1), "effects")
    expect_error(build(accessories = 1), "accessories")
    expect_error(build(lod = 1), "lod")
    expect_error(build(paints = 1), "paints")
    expect_error(build(shapes = 1), "shapes")
    expect_error(build(colour_descriptions = 1), "colour_descriptions")
    expect_error(build(omit_family_palettes = "Night"), "omit_family_palettes")
    expect_error(
      character_author_build(
        "bot",
        1,
        "Bot",
        "A bot.",
        list(a = "#000"),
        character_author_ground(60),
        list(part),
        list(mood)
      ),
      "family"
    )
    expect_error(
      character_author_build(
        "bot",
        "folk",
        "",
        "A bot.",
        list(a = "#000"),
        character_author_ground(60),
        list(part),
        list(mood)
      ),
      "name"
    )
    expect_error(
      character_author_build(
        "bot",
        "folk",
        "Bot",
        "",
        list(a = "#000"),
        character_author_ground(60),
        list(part),
        list(mood)
      ),
      "description"
    )
    expect_error(
      character_author_build(
        "bot",
        "folk",
        "Bot",
        "A bot.",
        list(),
        character_author_ground(60),
        list(part),
        list(mood)
      ),
      "colours"
    )
    expect_error(
      character_author_build("bot", "folk", "Bot", "A bot.", list(a = "#000"), list(), list(part), list(mood)),
      "ground"
    )
  })
})
