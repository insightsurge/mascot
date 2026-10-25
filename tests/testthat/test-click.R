describe("mascot_action()", {
  it("keeps a label, shows a tooltip and is enabled by default", {
    value <- mascot_action("Open help")
    expect_s3_class(value, "mascot_action")
    expect_identical(unclass(value), list(label = "Open help", tooltip = TRUE, disabled = FALSE))
    expect_identical(
      unclass(mascot_action("Open help", tooltip = FALSE, disabled = TRUE)),
      list(label = "Open help", tooltip = FALSE, disabled = TRUE)
    )
  })
  it("is an empty helper without a label, which removes the click", {
    expect_null(mascot_action()$label)
    expect_identical(as_click_arg(mascot_action(), environment()), list(type = "none"))
  })
  it("rejects every invalid label, tooltip and disabled value", {
    for (bad in list("", NA_character_, c("a", "b"), 1, TRUE)) {
      expect_error(mascot_action(bad), "Assertion on 'label' failed")
    }
    for (bad in list(NA, NULL, "yes", c(TRUE, FALSE), 1)) {
      expect_error(mascot_action("Open help", tooltip = bad), "Assertion on 'tooltip' failed")
      expect_error(mascot_action("Open help", disabled = bad), "Assertion on 'disabled' failed")
    }
  })
  it("rejects whitespace-only labels in the helper, shortcut and runtime validation", {
    for (label in c(" ", "   ", "\t", "\r\n", " \t\r\n ")) {
      expect_error(mascot_action(label), "Assertion on 'label' failed")
      expect_error(as_click_arg(label, environment()), "click.*one non-empty label")
      expect_error(mascot(id = "helper", click = label), "click.*one non-empty label")
      expect_match(click_problem(label), "click.*one non-empty label")
      value <- mascot_action("Open help")
      value$label <- label
      expect_match(click_problem(value), "click.*label, tooltip and disabled")
      expect_error(as_click_arg(value, environment()), "click.*label, tooltip and disabled")
    }
    expect_identical(mascot_action(" Open help ")$label, " Open help ")
  })

  it("rejects values caught by `...`, including a flag given by position", {
    expect_error(mascot_action("Open help", FALSE), "Unexpected arguments.*unnamed")
    expect_error(mascot_action("Open help", key = "h"), "Unexpected arguments.*key")
  })
  it("formats a helper without a label as a bare call", {
    expect_identical(format(mascot_action()), "mascot_action()")
  })
})

describe("the click argument", {
  it("warns and sends no update for whitespace-only shortcuts or helper labels", {
    captured <- new.env(parent = emptyenv())
    captured$patches <- list()
    local_mocked_bindings(
      send_update = function(session, id, patch) {
        captured$patches[[length(captured$patches) + 1L]] <- patch
      },
      dev_mode = function() FALSE
    )
    shiny::testServer(function(input, output, session) {}, {
      for (label in c("   ", " \t\r\n ")) {
        action <- mascot_action("Open help")
        action$label <- label
        menu <- mascot_popup_menu(c(help = "Help"))
        menu$label <- label
        for (value in list(label, action, menu)) {
          expect_warning(update_mascot("helper", mood = "happy", click = value), "unchanged")
        }
      }
    })
    expect_length(captured$patches, 0)
  })
  it("turns a label into an action and a helper into the browser's configuration", {
    expect_null(as_click_arg(NULL, environment()))
    expect_identical(
      as_click_arg("Open help", environment()),
      list(type = "action", label = "Open help", tooltip = TRUE, disabled = FALSE)
    )
    expect_identical(
      as_click_arg(mascot_action("Open help", tooltip = FALSE, disabled = TRUE), environment()),
      list(type = "action", label = "Open help", tooltip = FALSE, disabled = TRUE)
    )
    expect_identical(
      as_click_arg(mascot_popup_menu(c(a = "A"), direction = "left", label = "Menu"), environment()),
      list(type = "menu", items = list(a = "A"), direction = "left", label = "Menu", tooltip = TRUE, disabled = FALSE)
    )
    expect_identical(
      as_click_arg(mascot_popup_menu(c(a = "A"), direction = "left", label = "Menu", tooltip = FALSE), environment()),
      list(type = "menu", items = list(a = "A"), direction = "left", label = "Menu", tooltip = FALSE, disabled = FALSE)
    )
  })
  it("rejects a malformed action helper", {
    for (x in list(
      list(),
      list(label = "A", tooltip = TRUE),
      list(label = "A", tooltip = TRUE, disabled = FALSE, extra = 1),
      list(label = "", tooltip = TRUE, disabled = FALSE),
      list(label = "A", tooltip = NA, disabled = FALSE),
      list(label = "A", tooltip = TRUE, disabled = "no")
    )) {
      expect_error(
        as_click_arg(structure(x, class = "mascot_action"), environment()),
        "click.*label, tooltip and disabled"
      )
    }
  })
  it("checks its own arguments", {
    expect_error(as_click_arg("Open help", NULL), "Assertion on 'call' failed")
    expect_error(click_wire("Open help"), "Assertion on 'value' failed")
    expect_error(click_tag("Open help"), "Assertion on 'click' failed")
    expect_null(click_tag(NULL))
    expect_null(click_tag(list(type = "none")))
  })
  it("writes the action into a data-only script, escaped", {
    text <- "</script><b>Open help</b>"
    tag <- click_tag(as_click_arg(text, environment()))
    json <- as.character(tag$children[[1]])
    expect_false(grepl("</script>", json, fixed = TRUE))
    expect_identical(
      jsonlite::fromJSON(json),
      list(type = "action", label = text, tooltip = TRUE, disabled = FALSE)
    )
  })

  it("rejects a named vector of menu choices with a hint to wrap it in mascot_popup_menu()", {
    expect_error(as_click_arg(c(help = "Help"), environment()), "named vector.*mascot_popup_menu\\(\\)")
  })
  it("rejects anything but one non-empty label or a helper", {
    for (bad in list(TRUE, FALSE, 1, "", NA_character_, c("Help", "About"), list("Help"), character())) {
      expect_error(as_click_arg(bad, environment()), "click.*one non-empty label")
    }
  })
})

describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_action(label = 1), "label", class = "mascot_error")
    expect_error(mascot_action(tooltip = 1), "tooltip", class = "mascot_error")
    expect_error(mascot_action(disabled = 1), "disabled", class = "mascot_error")
  })
  it("adds mascot_error to the registered format and print methods", {
    expect_error(format.mascot_action(1), "x", class = "mascot_error")
    expect_error(print.mascot_action(1), "x", class = "mascot_error")
  })
})

describe("mascot_action() without a label", {
  it("requires a label whenever tooltip or disabled is explicitly supplied", {
    for (options in list(list(tooltip = TRUE), list(tooltip = FALSE), list(disabled = FALSE), list(disabled = TRUE))) {
      expect_error(do.call(mascot_action, options), "label.*NULL", class = "mascot_error")
      expect_error(do.call(mascot_action, c(list(label = NULL), options)), "label.*NULL", class = "mascot_error")
    }
    expect_identical(as_click_arg(mascot_action(NULL), environment()), list(type = "none"))
  })
})
