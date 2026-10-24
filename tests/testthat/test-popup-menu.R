describe("mascot_popup_menu()", {
  it("accepts named plain text and defaults to no menu, auto direction, no label and tooltip", {
    value <- mascot_popup_menu(c(about = "About", help = "<b>Help</b>"))
    expect_s3_class(value, "mascot_popup_menu")
    expect_identical(value$items, c(about = "About", help = "<b>Help</b>"))
    expect_identical(value$direction, "auto")
    expect_null(value$label)
    expect_true(value$tooltip)
    expect_identical(
      unclass(mascot_popup_menu()),
      list(items = NULL, direction = "auto", label = NULL, tooltip = TRUE, disabled = FALSE)
    )
    expect_identical(mascot_popup_menu(c(about = "About"), label = "Help and settings")$label, "Help and settings")
    expect_false(mascot_popup_menu(c(about = "About"), tooltip = FALSE)$tooltip)
    for (dir in c("auto", "top", "bottom", "left", "right")) {
      val <- mascot_popup_menu(c(about = "About"), direction = dir)
      expect_identical(val$direction, dir)
      expect_identical(
        as_click_arg(val, environment()),
        list(
          type = "menu",
          items = list(about = "About"),
          direction = dir,
          label = NULL,
          tooltip = TRUE,
          disabled = FALSE
        )
      )
    }
    expect_null(popup_menu_problem(value))
  })
  it("is an empty helper without items, which removes the click", {
    expect_identical(as_click_arg(mascot_popup_menu(), environment()), list(type = "none"))
    expect_null(click_tag(as_click_arg(mascot_popup_menu(), environment())))
  })
  it("rejects whitespace-only button labels in the helper and runtime validation", {
    for (label in c(" ", "   ", "\t", "\r\n", " \t\r\n ")) {
      expect_error(mascot_popup_menu(c(help = "Help"), label = label), "Assertion on 'label' failed")
      value <- mascot_popup_menu(c(help = "Help"))
      value$label <- label
      expect_match(popup_menu_problem(value), "click.*items, direction, label, tooltip and disabled")
      expect_error(as_click_arg(value, environment()), "click.*items, direction, label, tooltip and disabled")
    }
    expect_identical(mascot_popup_menu(c(help = "Help"), label = " Help menu ")$label, " Help menu ")
  })
  it("escapes labels in the browser's configuration and keeps the direction and label", {
    text <- "</script><b>Help</b>"
    tag <- click_tag(as_click_arg(mascot_popup_menu(c(help = text), label = text), environment()))
    json <- as.character(tag$children[[1]])
    expect_false(grepl("</script>", json, fixed = TRUE))
    expect_identical(jsonlite::fromJSON(json)$items$help, text)
    expect_identical(jsonlite::fromJSON(json)$label, text)
    expect_identical(jsonlite::fromJSON(json)$direction, "auto")
    expect_true(jsonlite::fromJSON(json)$tooltip)
    tag_dir <- click_tag(as_click_arg(mascot_popup_menu(c(about = "About"), direction = "left"), environment()))
    parsed <- jsonlite::fromJSON(as.character(tag_dir$children[[1]]))
    expect_identical(parsed$direction, "left")
    expect_null(parsed$label)
    expect_true(parsed$tooltip)
  })

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
  })
  it("rejects values caught by `...`, including a direction given by position", {
    expect_error(mascot_popup_menu(c(a = "A"), "top"), "Unexpected arguments.*unnamed")
    expect_error(mascot_popup_menu(key_bindings = TRUE), "Unexpected arguments.*key_bindings")
  })
  it("rejects invalid directions and malformed helpers", {
    for (bad in list(1, NULL, c("top", "bottom"), NA_character_, TRUE)) {
      expect_error(mascot_popup_menu(direction = bad), "Assertion on 'direction' failed")
    }
    for (bad in c("center", "middle", "diagonal", "up", "down")) {
      expect_error(mascot_popup_menu(direction = bad), "direction.*must be one of")
    }
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

describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_popup_menu(items = 1), "items", class = "mascot_error")
    expect_error(mascot_popup_menu(direction = 1), "direction", class = "mascot_error")
    expect_error(mascot_popup_menu(label = 1), "label", class = "mascot_error")
    expect_error(mascot_popup_menu(tooltip = 1), "tooltip", class = "mascot_error")
  })
  it("adds mascot_error to the registered format and print methods", {
    expect_error(format.mascot_popup_menu(1), "x", class = "mascot_error")
    expect_error(print.mascot_popup_menu(1), "x", class = "mascot_error")
  })
})

describe("mascot_popup_menu() argument safeguards", {
  it("requires items whenever direction, label or tooltip is explicitly supplied", {
    for (options in list(
      list(direction = "auto"),
      list(direction = "top"),
      list(label = NULL),
      list(label = "Help"),
      list(tooltip = TRUE),
      list(tooltip = FALSE)
    )) {
      expect_error(do.call(mascot_popup_menu, options), "items.*NULL", class = "mascot_error")
      expect_error(do.call(mascot_popup_menu, c(list(items = NULL), options)), "items.*NULL", class = "mascot_error")
    }
    expect_identical(as_click_arg(mascot_popup_menu(NULL), environment()), list(type = "none"))
  })
  it("includes tooltip among the valid names in an unexpected argument error", {
    expect_error(
      mascot_popup_menu(c(help = "Help"), tooltp = FALSE),
      "Name the optional arguments.*tooltip",
      class = "mascot_error"
    )
  })
})

describe("disabled popup menus", {
  it("validates and sends the disabled flag, including the empty-helper safeguard", {
    expect_false(mascot_popup_menu(c(help = "Help"))$disabled)
    expect_true(as_click_arg(mascot_popup_menu(c(help = "Help"), disabled = TRUE), environment())$disabled)
    for (bad in list(NA, NULL, 1, "yes", c(TRUE, FALSE))) {
      expect_error(mascot_popup_menu(c(help = "Help"), disabled = bad), "disabled", class = "mascot_error")
    }
    for (flag in c(TRUE, FALSE)) {
      expect_error(mascot_popup_menu(disabled = flag), "items.*NULL", class = "mascot_error")
    }
    expect_error(mascot_popup_menu(c(help = "Help"), disbled = TRUE), "optional arguments.*disabled")
    state <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    state$click <- as_click_arg(mascot_popup_menu(c(help = "Help"), disabled = TRUE), environment())
    expect_no_error(mascot_baseline_check(state))
    value <- mascot_popup_menu(c(help = "Help"))
    value$disabled <- "yes"
    expect_match(popup_menu_problem(value), "disabled")
  })
})
