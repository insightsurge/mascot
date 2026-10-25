describe("mascot()", {
  it("returns the accessible tag structure and a runtime dependency", {
    tag <- mascot(id = "helper")
    html <- sub(
      '(?s)(<script[^>]*data-mascot-baseline[^>]*>).*?(</script>)',
      '\\1[UI baseline]\\2',
      as.character(tag),
      perl = TRUE
    )
    html <- sub('data-mount-token="[^"]+"', 'data-mount-token="[UI specification token]"', html)
    html <- sub('data-mascot-version="[^"]+"', 'data-mascot-version="[package version]"', html)
    expect_snapshot(cat(html))
  })
  it("attributes choice errors to mascot and rejects every invalid argument", {
    expect_snapshot(error = TRUE, mascot(id = "a", mood = "hapy"))
    expect_snapshot(error = TRUE, mascot(id = "a", mood = "ha!py"))
    expect_snapshot(error = TRUE, mascot("a", character = "missing"))
  })
})

describe("mascot() size and placement", {
  it("writes data attributes without inline layout styles and normalises shortcuts", {
    expect_snapshot(error = TRUE, mascot(id = "a", placement = "fixed"))
    expect_snapshot(error = TRUE, mascot())
    expect_snapshot(error = TRUE, mascot("a", character = "typo"))
  })
  it("silently disables inline defaults and informs about explicit list controls", {
    expect_snapshot(invisible(mascot(id = "a", placement = list(position = "inline", minimise = TRUE))))
    expect_snapshot(invisible(mascot(id = "a", placement = list(position = "inline", drag = "snap"))))
    expect_snapshot(invisible(mascot(id = "a", placement = mascot_placement("inline", minimise = TRUE))))
    expect_snapshot(invisible(mascot(id = "a", placement = mascot_placement("inline", drag = "free"))))
  })
})

describe("mascot() themes", {
  it("embeds both palettes with auto by default and preserves explicit modes", {
    expect_snapshot(error = TRUE, mascot(id = "bad", theme = list(bdoy = "blue")))
  })
})

describe("with_mascot_asserts()", {
  it("keeps the original assertion message once and adds mascot_error", {
    value <- 1
    wrapped <- tryCatch(
      with_mascot_asserts({
        checkmate::assert_string(value)
      }),
      error = identity
    )
    expect_snapshot(conditionMessage(wrapped))
  })
})

describe("construction diagnostics for mood ids and unnamed arguments", {
  it("counts unnamed arguments and keeps named arguments listed", {
    expect_snapshot(error = TRUE, mascot("helper", 1, 2, typo = 3))
    expect_snapshot(error = TRUE, mascot("helper", 1))
  })
})
