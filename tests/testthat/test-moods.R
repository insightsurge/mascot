describe("mascot_moods()", {
  it("lists five moods with plain descriptions in the specified order", {
    moods <- mascot_moods()
    expect_s3_class(moods, "data.frame")
    expect_named(moods, c("name", "description"))
    expect_equal(nrow(moods), 5)
    expect_true(all(vapply(moods, is.character, logical(1))))
    expect_identical(moods$name, c("idle", "thinking", "happy", "worried", "celebrating"))
    expect_identical(
      moods$description,
      c(
        "At rest; the starting mood.",
        "Working on something, such as a long calculation.",
        "Something went well.",
        "Something needs attention, such as an invalid field.",
        "A big success, such as a finished task."
      )
    )
  })
})

describe("mascot_mood()", {
  it("chooses idle by default and accepts every mood", {
    expect_identical(mascot_mood(), mascot_mood("idle"))
    for (mood in mascot_moods()$name) {
      expect_identical(mascot_mood(mood), structure(list(name = mood), class = "mascot_mood"))
    }
  })
  it("names unknown moods and rejects invalid strings", {
    expect_snapshot(error = TRUE, mascot_mood("hapy"))
    for (x in list(1, NULL, NA_character_, character(), c("idle", "happy"), "")) {
      expect_error(mascot_mood(x), "Assertion on 'name' failed")
    }
  })
})

describe("mood_label()", {
  it("capitalises the mood word and checks the name", {
    expect_identical(
      vapply(mascot_moods()$name, mood_label, character(1), USE.NAMES = FALSE),
      c("Idle", "Thinking", "Happy", "Worried", "Celebrating")
    )
    expect_error(mood_label("bad"), "Assertion on 'name' failed")
  })
})


describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_mood(name = 1), "name", class = "mascot_error")
  })
  it("adds mascot_error to the registered format and print methods", {
    expect_error(format.mascot_mood(1), "x", class = "mascot_error")
    expect_error(print.mascot_mood(1), "x", class = "mascot_error")
  })
})
