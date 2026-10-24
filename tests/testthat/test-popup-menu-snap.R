describe("mascot_popup_menu()", {
  it("rejects every invalid item, id, label and tooltip value with the argument named", {
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
    for (bad in list(NA, NULL, "yes", c(TRUE, FALSE), 1)) {
      expect_error(mascot_popup_menu(c(a = "A"), tooltip = bad), "Assertion on 'tooltip' failed")
    }
    expect_snapshot(error = TRUE, mascot_popup_menu(c("bad id" = "Help")))
  })
  it("rejects values caught by `...`, including a direction given by position", {
    expect_error(mascot_popup_menu(c(a = "A"), "top"), "Unexpected arguments.*unnamed")
    expect_error(mascot_popup_menu(key_bindings = TRUE), "Unexpected arguments.*key_bindings")
    expect_snapshot(error = TRUE, mascot_popup_menu(c(a = "A"), "top", extra = TRUE))
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
      list(items = NULL, direction = "auto", label = NULL),
      list(items = NULL, direction = "auto", label = NULL, tooltip = TRUE, extra = 1),
      list(items = NULL, direction = "auto", label = "", tooltip = TRUE),
      list(items = NULL, direction = "auto", label = NULL, tooltip = NA),
      setNames(list(NULL, "auto", NULL, TRUE), c("items", "items", "label", "tooltip"))
    )) {
      expect_error(
        as_click_arg(structure(x, class = "mascot_popup_menu"), environment()),
        "click.*items, direction, label, tooltip and disabled"
      )
    }
    expect_error(
      as_click_arg(
        structure(
          list(items = NULL, direction = "center", label = NULL, tooltip = TRUE, disabled = FALSE),
          class = "mascot_popup_menu"
        ),
        environment()
      ),
      "direction.*must be one of"
    )
    expect_error(
      as_click_arg(
        structure(
          list(items = c(a = NA_character_), direction = "auto", label = NULL, tooltip = TRUE, disabled = FALSE),
          class = "mascot_popup_menu"
        ),
        environment()
      ),
      "items.*non-empty named character"
    )
  })
})
