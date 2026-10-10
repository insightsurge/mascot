describe("mascot_popup_menu()", {
  it("accepts named plain text and defaults to no menu and auto direction", {
    value <- mascot_popup_menu(c(about = "About", help = "<b>Help</b>"))
    expect_s3_class(value, "mascot_popup_menu")
    expect_identical(value$items, c(about = "About", help = "<b>Help</b>"))
    expect_identical(value$direction, "auto")
    expect_identical(unclass(mascot_popup_menu()), list(items = NULL, direction = "auto"))
    expect_identical(as_popup_menu_arg(NULL, environment()), list(items = NULL, direction = "auto"))
    expect_identical(
      as_popup_menu_arg(c(about = "About"), environment()),
      list(items = list(about = "About"), direction = "auto")
    )
    for (dir in c("auto", "top", "bottom", "left", "right")) {
      val <- mascot_popup_menu(c(about = "About"), direction = dir)
      expect_identical(val$direction, dir)
      expect_identical(
        as_popup_menu_arg(val, environment()),
        list(items = list(about = "About"), direction = dir)
      )
    }
    expect_null(popup_menu_tag(as_popup_menu_arg(NULL, environment())))
    expect_null(popup_menu_problem(value))
  })
  it("rejects every invalid item and id with the argument named", {
    for (x in list(character(), 1, NA_character_, "", c(a = NA_character_))) {
      expect_error(mascot_popup_menu(x), "Assertion on 'items' failed")
      expect_error(as_popup_menu_arg(x, environment()), "items.*non-empty named character")
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
    expect_error(mascot_popup_menu(key_bindings = TRUE), "unused argument")
    expect_error(mascot_popup_menu(extra = TRUE), "unused argument")
    expect_error(as_popup_menu_arg(NULL, NULL), "Assertion on 'call' failed")
    expect_error(popup_menu_tag(NULL), "Assertion on 'menu' failed")
    expect_snapshot(error = TRUE, mascot_popup_menu(c("bad id" = "Help")))
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
      list(items = NULL, direction = "auto", extra = 1),
      setNames(list(NULL, "auto"), c("items", "items"))
    )) {
      expect_error(
        as_popup_menu_arg(structure(x, class = "mascot_popup_menu"), environment()),
        "popup_menu.*items"
      )
    }
    expect_error(
      as_popup_menu_arg(
        structure(list(items = NULL, direction = "center"), class = "mascot_popup_menu"),
        environment()
      ),
      "direction.*must be one of"
    )
    text <- "</script><b>Help</b>"
    tag <- popup_menu_tag(as_popup_menu_arg(c(help = text), environment()))
    json <- as.character(tag$children[[1]])
    expect_false(grepl("</script>", json, fixed = TRUE))
    expect_identical(jsonlite::fromJSON(json)$items$help, text)
    expect_identical(jsonlite::fromJSON(json)$direction, "auto")
    tag_dir <- popup_menu_tag(as_popup_menu_arg(
      mascot_popup_menu(c(about = "About"), direction = "left"),
      environment()
    ))
    json_dir <- as.character(tag_dir$children[[1]])
    expect_identical(jsonlite::fromJSON(json_dir)$direction, "left")
  })
})
