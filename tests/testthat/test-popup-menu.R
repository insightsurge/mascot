describe("mascot_popup_menu()", {
  it("accepts named plain text and defaults to no menu, auto direction and no label", {
    value <- mascot_popup_menu(c(about = "About", help = "<b>Help</b>"))
    expect_s3_class(value, "mascot_popup_menu")
    expect_identical(value$items, c(about = "About", help = "<b>Help</b>"))
    expect_identical(value$direction, "auto")
    expect_null(value$label)
    expect_identical(unclass(mascot_popup_menu()), list(items = NULL, direction = "auto", label = NULL))
    expect_identical(mascot_popup_menu(c(about = "About"), label = "Help and settings")$label, "Help and settings")
    for (dir in c("auto", "top", "bottom", "left", "right")) {
      val <- mascot_popup_menu(c(about = "About"), direction = dir)
      expect_identical(val$direction, dir)
      expect_identical(
        as_click_arg(val, environment()),
        list(type = "menu", items = list(about = "About"), direction = dir, label = NULL)
      )
    }
    expect_null(popup_menu_problem(value))
  })
  it("is an empty helper without items, which removes the click", {
    expect_identical(as_click_arg(mascot_popup_menu(), environment()), list(type = "none"))
    expect_identical(as_click_arg(mascot_popup_menu(direction = "top"), environment()), list(type = "none"))
    expect_null(click_tag(as_click_arg(mascot_popup_menu(), environment())))
  })
  it("rejects every invalid item, id and label with the argument named", {
    for (x in list(character(), 1, NA_character_, "", c(a = NA_character_))) {
      expect_error(mascot_popup_menu(x), "Assertion on 'items' failed")
    }
    for (x in list(
      "About",
      setNames("About", ""),
      setNames("About", NA_character_),
      c("a b" = "About"),
      c("a\tb" = "About"),
      c(a = "One", a = "Two")
    )) {
      expect_error(mascot_popup_menu(x), "names must be unique, non-empty ids without whitespace")
    }
    for (bad in list("", NA_character_, c("a", "b"), 1, TRUE)) {
      expect_error(mascot_popup_menu(c(a = "A"), label = bad), "Assertion on 'label' failed")
    }
    expect_snapshot(error = TRUE, mascot_popup_menu(c("bad id" = "Help")))
  })
  it("rejects values caught by `...`, including a direction given by position", {
    expect_error(mascot_popup_menu(c(a = "A"), "top"), "Unexpected arguments.*unnamed")
    expect_error(mascot_popup_menu(key_bindings = TRUE), "Unexpected arguments.*key_bindings")
    expect_snapshot(error = TRUE, mascot_popup_menu(c(a = "A"), "top", extra = TRUE))
  })
  it("rejects whitespace-only button labels in the helper and runtime validation", {
    for (label in c(" ", "   ", "\t", "\r\n", " \t\r\n ")) {
      expect_error(mascot_popup_menu(c(help = "Help"), label = label), "Assertion on 'label' failed")
      value <- mascot_popup_menu(c(help = "Help"))
      value$label <- label
      expect_match(popup_menu_problem(value), "click.*items, direction and label")
      expect_error(as_click_arg(value, environment()), "click.*items, direction and label")
    }
    expect_identical(mascot_popup_menu(c(help = "Help"), label = " Help menu ")$label, " Help menu ")
  })
  it("rejects invalid directions and malformed helpers with snapshots", {
    for (bad in list(1, NULL, c("top", "bottom"), NA_character_, TRUE)) {
      expect_error(mascot_popup_menu(direction = bad), "Assertion on 'direction' failed")
    }
    for (bad in c("center", "middle", "diagonal", "up", "down")) {
      expect_error(mascot_popup_menu(direction = bad), "direction.*must be one of")
    }
    expect_snapshot(error = TRUE, mascot_popup_menu(direction = "center"))
    for (x in list(
      TRUE,
      list(),
      list(wrong = NULL),
      list(items = NULL, extra = 1),
      list(items = NULL, direction = "auto"),
      list(items = NULL, direction = "auto", label = NULL, extra = 1),
      list(items = NULL, direction = "auto", label = ""),
      setNames(list(NULL, "auto", NULL), c("items", "items", "label"))
    )) {
      expect_error(
        as_click_arg(structure(x, class = "mascot_popup_menu"), environment()),
        "click.*items, direction and label"
      )
    }
    expect_error(
      as_click_arg(
        structure(list(items = NULL, direction = "center", label = NULL), class = "mascot_popup_menu"),
        environment()
      ),
      "direction.*must be one of"
    )
    expect_error(
      as_click_arg(
        structure(list(items = c(a = NA_character_), direction = "auto", label = NULL), class = "mascot_popup_menu"),
        environment()
      ),
      "items.*non-empty named character"
    )
  })
  it("escapes labels in the browser's configuration and keeps the direction and label", {
    text <- "</script><b>Help</b>"
    tag <- click_tag(as_click_arg(mascot_popup_menu(c(help = text), label = text), environment()))
    json <- as.character(tag$children[[1]])
    expect_false(grepl("</script>", json, fixed = TRUE))
    expect_identical(jsonlite::fromJSON(json)$items$help, text)
    expect_identical(jsonlite::fromJSON(json)$label, text)
    expect_identical(jsonlite::fromJSON(json)$direction, "auto")
    tag_dir <- click_tag(as_click_arg(mascot_popup_menu(c(about = "About"), direction = "left"), environment()))
    parsed <- jsonlite::fromJSON(as.character(tag_dir$children[[1]]))
    expect_identical(parsed$direction, "left")
    expect_null(parsed$label)
  })
})
