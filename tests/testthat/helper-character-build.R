# The complete small character built in R (study_bot), written with the internal authoring constructors. `family`
# can be replaced to test a known-family id.
author_study_bot <- function(family = author_visorfolk(), ...) {
  rows <- list(list(0, 0), list(0.3, 0.08), list(1, 0))
  shell <- character_author_shape(
    "round_rect",
    list(x = -45, y = -40, w = 90, h = 80, r = 12),
    id = "shell",
    fill = "body",
    outline = TRUE
  )
  visor <- character_author_shape(
    "round_rect",
    list(x = -32, y = -25, w = 64, h = 36, r = 8),
    id = "visor",
    fill = "screen"
  )
  head <- character_author_part("head", list(shell, visor), at = c(0, -60), layer = 10)
  badge_pin <- character_author_anchor(
    "badge",
    "head",
    at = c(25, 24),
    description = "Attachment point for a small badge."
  )
  badge <- character_author_part(
    "badge_disc",
    list(character_author_shape("circle", list(x = 0, y = 0, r = 5), fill = "accent")),
    parent = "head",
    at = c(25, 24),
    layer = 11
  )
  mood <- function(id, description, status, eyes, mouth) {
    character_author_mood(id, description, status, face = list(eyes = eyes, mouth = mouth))
  }
  moods <- list(
    mood("idle", "At rest.", "Ready", "dot", "smile"),
    mood("thinking", "Working on a task.", "Working", "scan", "flat"),
    mood("happy", "A task went well.", "Done", "arc", "wide"),
    mood("worried", "Something needs attention.", "Check the result", "slant", "wavy"),
    mood("celebrating", "A large task finished.", "Finished", "star", "wide")
  )
  nod <- character_author_gesture(
    "nod",
    "A head-joint acknowledgement, or safe tilt.",
    18,
    list(character_author_track("nod_joint.rotate", rows)),
    needs = "nod_joint",
    fallback = "rock"
  )
  wave <- character_author_gesture(
    "wave",
    "A hand greeting, or safe tilt.",
    30,
    list(character_author_track(
      "hand_r.rotate",
      list(list(0, 0), list(0.3, 0.25), list(0.6, -0.25), list(1, 0))
    )),
    needs = "hand_r",
    fallback = "rock"
  )
  greet <- character_author_gesture(
    "greet",
    "A brief greeting tilt.",
    18,
    list(character_author_track("head.rotate", rows))
  )
  character_author_build(
    "study_bot",
    family,
    "Study Bot",
    "A small screen-faced study helper.",
    list(body = "#3f82ff", outline = "#1b1230", screen = "#06232a", feature = "#7cffe0", accent = "#ffc400"),
    character_author_ground(60),
    list(head, badge),
    moods,
    anchors = list(badge_pin),
    face = character_author_face(
      "screen",
      "head",
      at = c(0, -7),
      clip = "head.visor",
      eyes = list(y = -4, spacing = 13),
      mouth = list(y = 8)
    ),
    gestures = list(nod, wave, greet),
    palettes = list(character_author_palette("sea_glass", "My darker screen.", list(screen = "#051b20"))),
    outline = list(width = 2.5, colour = "outline"),
    contrast = list(list(fg = "feature", bg = "screen", min = 3, where = "screen face")),
    lod = list(micro = list(hide = "badge_disc", glow = FALSE)),
    ...
  )
}

# The shipped-style family the example starts from: whole-root gestures and two
# palettes, as in the reference fixture.
author_visorfolk <- function() {
  rows <- list(list(0, 0), list(0.3, 0.08), list(1, 0))
  tilt <- function(id, description, frames) {
    character_author_gesture(id, description, frames, list(character_author_track("root.rotate", rows)))
  }
  character_author_family(
    "visorfolk",
    "Visorfolk",
    "Characters with screen faces.",
    defaults = list(
      gestures = list(
        tilt("rock", "A brief whole-character tilt.", 18),
        tilt("nod", "A brief whole-character acknowledgement tilt.", 18),
        tilt("wave", "A brief whole-character greeting tilt.", 30)
      ),
      palettes = list(
        character_author_palette("sea_glass", "A cool screen.", c(screen = "#06232a")),
        character_author_palette("night_screen", "A deeper screen.", c(screen = "#03151a"))
      )
    )
  )
}
