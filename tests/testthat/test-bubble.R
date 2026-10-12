describe("mascot_bubble()", {
  it("keeps defaults, an explicit lifetime and an empty clear helper", {
    expect_identical(
      mascot_bubble(),
      structure(
        list(text = NULL, html = FALSE, duration = 5, closable = TRUE),
        class = "mascot_bubble"
      )
    )
    expect_identical(
      mascot_bubble("Ready", duration = Inf, closable = FALSE),
      structure(
        list(text = "Ready", html = FALSE, duration = Inf, closable = FALSE),
        class = "mascot_bubble"
      )
    )
    expect_identical(mascot_bubble("Ready", duration = 0.01)$duration, 0.01)
  })
  it("recognises explicit HTML and stores a plain string", {
    bubble <- mascot_bubble(htmltools::HTML("<b>Ready</b>"))
    expect_true(bubble$html)
    expect_identical(bubble$text, "<b>Ready</b>")
    expect_false(mascot_bubble("<b>Ready</b>")$html)
  })
  it("rejects each invalid argument with a clear message", {
    for (x in list("", 1, NA_character_, character(), c("a", "b"))) {
      expect_error(mascot_bubble(x), "Assertion on 'text' failed")
    }
    for (x in list("5", NA_real_, NaN, -Inf, -1, c(1, 2))) {
      expect_error(mascot_bubble("Ready", duration = x), "Assertion on 'duration' failed")
    }
    expect_error(mascot_bubble("Ready", duration = 0), "duration.*greater than zero", class = "mascot_error")
    for (x in list(NULL, 1, NA, c(TRUE, FALSE))) {
      expect_error(mascot_bubble("Ready", closable = x), "Assertion on 'closable' failed")
    }
  })
})

describe("bubble internals", {
  it("checks converters and markup arguments", {
    expect_error(as_bubble_arg(NULL, NULL), "'call'")
    expect_error(bubble_tag(NULL), "'bubble'")
    expect_identical(as_bubble_arg("Ready", environment()), mascot_bubble("Ready"))
    expect_identical(as_bubble_arg(mascot_bubble(), environment()), mascot_bubble())
  })
})

describe("bubble review regressions", {
  it("rejects NULL duration with a hint to use Inf", {
    expect_error(mascot_bubble("Ready", duration = NULL), "duration = Inf", class = "mascot_error")
  })
  it("G6 renders tags and tag lists as HTML and rejects dependencies clearly", {
    bubble <- mascot_bubble(shiny::tags$strong("Saved"))
    expect_identical(bubble$text, "<strong>Saved</strong>")
    expect_true(bubble$html)
    tags <- htmltools::tagList(shiny::tags$strong("Saved"), " & ready")
    expect_match(mascot_bubble(tags)$text, "<strong>Saved</strong>", fixed = TRUE)
    expect_match(mascot_bubble(tags)$text, " &amp; ready", fixed = TRUE)
    expect_true(mascot_bubble(tags)$html)
    dependency <- htmltools::htmlDependency("bubble-test", "1.0", src = c(file = tempdir()))
    dependent <- htmltools::attachDependencies(shiny::tags$strong("Saved"), dependency)
    expect_error(mascot_bubble(dependent), "text.*dependencies.*not supported")
    expect_error(mascot_bubble(htmltools::tagList(dependent)), "text.*dependencies.*not supported")
  })
})


describe("render_bubble_text()", {
  it("rejects non-tags, empty tag lists and head content clearly", {
    expect_error(render_bubble_text("Saved"), "'text'")
    expect_error(mascot_bubble(htmltools::tagList()), "'text'")
    expect_error(
      mascot_bubble(htmltools::tagList(shiny::tags$head(shiny::tags$title("Title")), shiny::tags$p("Saved"))),
      "text.*head content.*not supported"
    )
  })
})

describe("mascot_bubble() named arguments", {
  it("keeps the agreed signature and rejects both forms of extra argument", {
    expect_identical(names(formals(mascot_bubble)), c("text", "...", "duration", "closable"))
    expect_error(mascot_bubble("Hi", typo = 1), "Unexpected arguments", class = "mascot_error")
    expect_error(mascot_bubble("Hi", 1), "Name the optional arguments", class = "mascot_error")
  })
})


describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_bubble(text = 1), "text", class = "mascot_error")
    expect_error(mascot_bubble(duration = "five"), "duration", class = "mascot_error")
    expect_error(mascot_bubble(closable = 1), "closable", class = "mascot_error")
  })
  it("adds mascot_error to the registered format and print methods", {
    expect_error(format.mascot_bubble(1), "x", class = "mascot_error")
    expect_error(print.mascot_bubble(1), "x", class = "mascot_error")
  })
})
