describe("mascot()", {
  it("returns the accessible tag structure and a runtime dependency", {
    tag <- mascot(id = "helper")
    expect_s3_class(tag, "shiny.tag")
    expect_identical(tag$name, "div")
    expect_identical(
      tag$attribs,
      list(class = "mascot", id = "helper", `data-character` = "tessa", `data-mood` = "idle", `data-status` = "mood")
    )
    html <- sub('(?s)(<script[^>]*>).*?(</script>)', '\\1[character JSON]\\2', as.character(tag), perl = TRUE)
    expect_snapshot(cat(html))
    dep <- htmltools::findDependencies(tag)[[1]]
    expect_identical(dep$name, "mascot")
    expect_identical(dep$version, as.character(utils::packageVersion("mascot")))
    expect_identical(dep$script, c("mascot.js", "mascot-draw.js", "mascot-motion.js", "mascot-host.js"))
    expect_identical(dep$stylesheet, "mascot.css")
    expect_identical(dep$package, "mascot")
    expect_false(dep$all_files)
  })
  it("uses equivalent shortcuts and helpers and escapes custom text", {
    expect_identical(
      as.character(mascot(id = "a", mood = "happy", status = "Saved")),
      as.character(mascot(mascot_character(), "a", mascot_mood("happy"), mascot_status("Saved")))
    )
    expect_identical(as.character(mascot(id = "a")), as.character(mascot(id = "a", status = mascot_status())))
    html <- as.character(mascot(id = "a", status = htmltools::HTML("<b>Saved</b>")))
    expect_match(html, 'data-status="custom"', fixed = TRUE)
    expect_match(html, "&lt;b&gt;Saved&lt;/b&gt;", fixed = TRUE)
    expect_match(as.character(mascot(id = "a", mood = "thinking")), '>Thinking</div>', fixed = TRUE)
  })
  it("attributes choice errors to mascot and rejects every invalid argument", {
    expect_snapshot(error = TRUE, mascot(id = "a", mood = "hapy"))
    expect_snapshot(error = TRUE, mascot("missing", "a"))
    expect_error(mascot(), "missing")
    for (id in list("", "has space", "a\nb", 1, NA_character_)) {
      expect_error(mascot(id = id), "Assertion on 'id' failed")
    }
    for (x in list(NULL, 1, "", NA_character_, c("a", "b"))) {
      expect_error(mascot(x, "a"), "character.*non-empty string")
      expect_error(mascot(id = "a", mood = x), "mood.*non-empty string")
    }
    for (x in list(1, "", NA_character_, c("a", "b"))) {
      expect_error(mascot(id = "a", status = x), "mascot_status", fixed = TRUE)
    }
    expect_error(mascot(id = "a", mood = "{oops"), "not a mood", fixed = TRUE)
  })
})

describe("argument converters", {
  it("checks the internal call and argument contracts", {
    expect_error(as_character_arg("tessa", NULL), "'call'")
    expect_error(as_mood_arg("idle", NULL), "'call'")
    expect_error(as_status_arg(NULL, NULL), "'call'")
    expect_error(check_arg("idle", "other", environment()), "'arg'")
    expect_error(check_arg("idle", "mood", NULL), "'call'")
    expect_error(arg_problem("idle", "other"), "'arg'")
  })
})
