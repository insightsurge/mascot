describe("mascot_popup_menu()", {
  it("accepts named plain text and defaults to no menu and no keyboard shortcuts", {
    value <- mascot_popup_menu(c(about = "About", help = "<b>Help</b>"), TRUE)
    expect_s3_class(value, "mascot_popup_menu")
    expect_identical(value$items, c(about = "About", help = "<b>Help</b>"))
    expect_identical(unclass(mascot_popup_menu()), list(items = NULL, key_bindings = FALSE))
    expect_identical(as_popup_menu_arg(NULL, environment()), list(items = NULL, key_bindings = FALSE))
    expect_identical(
      as_popup_menu_arg(c(about = "About"), environment()),
      list(items = list(about = "About"), key_bindings = FALSE)
    )
    expect_identical(as_popup_menu_arg(value, environment())$key_bindings, TRUE)
    expect_null(popup_menu_tag(as_popup_menu_arg(NULL, environment())))
    expect_null(popup_menu_problem(value))
  })
  it("rejects every invalid item, id and flag with the argument named", {
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
    for (x in list(NULL, NA, 1, "true", c(TRUE, FALSE))) {
      expect_error(mascot_popup_menu(key_bindings = x), "Assertion on 'key_bindings' failed")
      value <- mascot_popup_menu()
      value["key_bindings"] <- list(x)
      expect_error(as_popup_menu_arg(value, environment()), "key_bindings.*TRUE or FALSE")
    }
    expect_error(as_popup_menu_arg(NULL, NULL), "Assertion on 'call' failed")
    expect_error(popup_menu_tag(NULL), "Assertion on 'menu' failed")
    expect_snapshot(error = TRUE, mascot_popup_menu(c("bad id" = "Help")))
  })
  it("rejects malformed helpers and safely serialises script-like labels", {
    for (x in list(
      TRUE,
      list(),
      list(items = NULL),
      list(items = NULL, key_bindings = FALSE, extra = 1),
      setNames(list(NULL, FALSE), c("items", "items"))
    )) {
      expect_error(
        as_popup_menu_arg(structure(x, class = "mascot_popup_menu"), environment()),
        "popup_menu.*items and key_bindings"
      )
    }
    text <- "</script><b>Help</b>"
    tag <- popup_menu_tag(as_popup_menu_arg(c(help = text), environment()))
    json <- as.character(tag$children[[1]])
    expect_false(grepl("</script>", json, fixed = TRUE))
    expect_identical(jsonlite::fromJSON(json)$items$help, text)
  })
})
