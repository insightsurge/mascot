describe("mascot_popup_menu()", {
  it("accepts named plain text and defaults to no menu", {
    value <- mascot_popup_menu(c(about = "About", help = "<b>Help</b>"))
    expect_s3_class(value, "mascot_popup_menu")
    expect_identical(value$items, c(about = "About", help = "<b>Help</b>"))
    expect_identical(unclass(mascot_popup_menu()), list(items = NULL))
    expect_identical(as_popup_menu_arg(NULL, environment()), list(items = NULL))
    expect_identical(
      as_popup_menu_arg(c(about = "About"), environment()),
      list(items = list(about = "About"))
    )
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
  it("rejects malformed helpers and safely serialises script-like labels", {
    for (x in list(
      TRUE,
      list(),
      list(wrong = NULL),
      list(items = NULL, extra = 1),
      setNames(list(NULL, FALSE), c("items", "items"))
    )) {
      expect_error(
        as_popup_menu_arg(structure(x, class = "mascot_popup_menu"), environment()),
        "popup_menu.*items field"
      )
    }
    text <- "</script><b>Help</b>"
    tag <- popup_menu_tag(as_popup_menu_arg(c(help = text), environment()))
    json <- as.character(tag$children[[1]])
    expect_false(grepl("</script>", json, fixed = TRUE))
    expect_identical(jsonlite::fromJSON(json)$items$help, text)
  })
})
