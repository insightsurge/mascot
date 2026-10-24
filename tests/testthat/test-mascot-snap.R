describe("mascot()", {
  it("returns the accessible tag structure and a runtime dependency", {
    tag <- mascot(id = "helper")
    expect_s3_class(tag, "shiny.tag")
    expect_identical(tag$name, "div")
    expect_identical(
      tag$attribs[names(tag$attribs) != "data-mount-token"],
      list(
        class = "mascot",
        id = "helper",
        tabindex = "-1",
        `data-character` = "tessa",
        `data-mood` = "idle",
        `data-status` = "mood",
        `data-size` = 160,
        `data-small-screen` = "auto",
        `data-floating` = "true",
        `data-position` = "bottom-right",
        `data-minimise` = "true",
        `data-drag` = "false",
        `data-reduced` = "auto",
        `data-idle` = "true",
        `data-mood-change` = "true",
        `data-gestures` = "true",
        `data-swap` = "true",
        `data-minimising` = "true",
        `data-restoring` = "true",
        `data-messages` = "bubble,tooltip,menu",
        `data-others` = "true",
        `data-mascot-version` = as.character(utils::packageVersion("mascot"))
      )
    )
    html <- sub(
      '(?s)(<script[^>]*data-mascot-baseline[^>]*>).*?(</script>)',
      '\\1[UI baseline]\\2',
      as.character(tag),
      perl = TRUE
    )
    html <- sub('data-mount-token="[^"]+"', 'data-mount-token="[UI specification token]"', html)
    html <- sub('data-mascot-version="[^"]+"', 'data-mascot-version="[package version]"', html)
    expect_snapshot(cat(html))
    dependencies <- htmltools::findDependencies(tag)
    expect_identical(vapply(dependencies, function(d) d$name, character(1)), c("mascot", "mascot-character-tessa"))
    dep <- dependencies[[1]]
    expect_identical(dep$name, "mascot")
    expect_identical(dep$version, as.character(utils::packageVersion("mascot")))
    expect_identical(script_files(dep), engine_scripts)
    # Every listed file ships with the package, so a page works offline.
    expect_true(all(file.exists(file.path(system.file("www", package = "mascot"), script_files(dep)))))
    expect_identical(dep$stylesheet, "mascot.css")
    expect_identical(dep$package, "mascot")
    expect_false(dep$all_files)
  })
  it("attributes choice errors to mascot and rejects every invalid argument", {
    expect_snapshot(error = TRUE, mascot(id = "a", mood = "hapy"))
    expect_snapshot(error = TRUE, mascot(id = "a", mood = "ha!py"))
    expect_snapshot(error = TRUE, mascot("a", character = "missing"))
    expect_error(mascot(), "missing", class = "mascot_error")
    for (id in list("", "has space", "a\nb", 1, NA_character_)) {
      expect_error(mascot(id = id), "Assertion on 'id' failed")
    }
    for (x in list(NULL, 1, "", NA_character_, c("a", "b"))) {
      expect_error(mascot("a", character = x), "Assertion on 'character' failed")
      expect_error(mascot(id = "a", mood = x), "mood.*non-empty string")
    }
    for (x in list(1, "", NA_character_, c("a", "b"))) {
      expect_error(mascot(id = "a", status = x), "mascot_status", fixed = TRUE)
    }
    expect_error(mascot(id = "a", mood = "{oops"), "not a mood", fixed = TRUE)
  })
})

describe("mascot() size and placement", {
  it("writes data attributes without inline layout styles and normalises shortcuts", {
    tag <- mascot(
      id = "a",
      size = mascot_size("20%", small_screen = 48),
      placement = mascot_placement("top-left", minimise = TRUE)
    )
    expect_identical(tag$attribs$`data-size`, "20%")
    expect_identical(tag$attribs$`data-small-screen`, 48)
    expect_null(tag$attribs$`data-simplify-when-small`)
    expect_identical(tag$attribs$`data-floating`, "true")
    expect_identical(tag$attribs$`data-position`, "top-left")
    expect_identical(tag$attribs$`data-minimise`, "true")
    expect_null(tag$attribs$style)
    expect_identical(
      as.character(mascot(id = "a", size = 96, placement = "bottom-right")),
      as.character(mascot(id = "a", size = mascot_size(96), placement = mascot_placement("bottom-right")))
    )
    expect_error(mascot(id = "a", size = NULL), "size")
    expect_error(mascot(id = "a", size = "24px"), "size.*24px")
    expect_snapshot(error = TRUE, mascot(id = "a", placement = "fixed"))
    expect_identical(mascot("helper")$attribs$id, "helper")
    expect_snapshot(error = TRUE, mascot())
    expect_snapshot(error = TRUE, mascot("a", character = "typo"))
    expect_identical(mascot("{oops}")$attribs$id, "{oops}")
  })
  it("silently disables inline defaults and informs about explicit list controls", {
    for (placement in list("inline", mascot_placement("inline"), list(position = "inline"))) {
      expect_silent(tag <- mascot(id = "a", placement = placement))
      expect_identical(tag$attribs$`data-minimise`, "false")
      expect_identical(tag$attribs$`data-drag`, "false")
    }
    for (controls in list(
      list(minimise = TRUE),
      list(minimise = FALSE),
      list(drag = "snap"),
      list(drag = "free"),
      list(drag = "none")
    )) {
      expect_message(
        tag <- mascot(id = "a", placement = c(list(position = "inline"), controls)),
        paste0(names(controls), ".*no effect.*inline"),
        class = "mascot_placement_ignored"
      )
      expect_identical(tag$attribs$`data-minimise`, "false")
      expect_identical(tag$attribs$`data-drag`, "false")
    }
    expect_snapshot(invisible(mascot(id = "a", placement = list(position = "inline", minimise = TRUE))))
    expect_snapshot(invisible(mascot(id = "a", placement = list(position = "inline", drag = "snap"))))
    expect_snapshot(invisible(mascot(id = "a", placement = mascot_placement("inline", minimise = TRUE))))
    expect_snapshot(invisible(mascot(id = "a", placement = mascot_placement("inline", drag = "free"))))
    expect_identical(mascot(id = "a", placement = list(minimise = FALSE))$attribs$`data-minimise`, "false")
  })
})

describe("mascot() themes", {
  it("embeds both palettes with auto by default and preserves explicit modes", {
    theme <- mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"))
    tag <- mascot(id = "themed", theme = theme)
    scripts <- Filter(
      function(x) {
        inherits(x, "shiny.tag") && identical(x$name, "script") && !"data-mascot-baseline" %in% names(x$attribs)
      },
      tag$children
    )
    # Tessa's data travels in the page head, so the theme is the tag's only other script.
    expect_length(scripts, 1)
    wire <- jsonlite::fromJSON(as.character(scripts[[1]]$children[[1]]), simplifyVector = FALSE)
    expect_identical(wire$light, list(body = "#1F6FEB"))
    expect_identical(wire$dark, list(body = "#9EC5FE"))
    expect_identical(wire$mode, "auto")
    expect_false(grepl("data-mascot-theme", as.character(mascot(id = "own")), fixed = TRUE))
    expect_match(
      as.character(mascot(id = "light", theme = mascot_theme(mode = "light"))),
      '"mode":"light"',
      fixed = TRUE
    )
    expect_snapshot(error = TRUE, mascot(id = "bad", theme = list(bdoy = "blue")))
  })
})

describe("with_mascot_asserts()", {
  it("keeps the original assertion message once and adds mascot_error", {
    value <- 1
    original <- tryCatch(checkmate::assert_string(value), error = identity)
    wrapped <- tryCatch(
      with_mascot_asserts({
        checkmate::assert_string(value)
      }),
      error = identity
    )

    expect_s3_class(wrapped, "mascot_error")
    expect_s3_class(wrapped, "error")
    expect_identical(
      trimws(cli::ansi_strip(strsplit(conditionMessage(wrapped), "\n", fixed = TRUE)[[1]])),
      trimws(strsplit(conditionMessage(original), "\n", fixed = TRUE)[[1]])
    )
    expect_null(wrapped$parent)
    expect_snapshot(conditionMessage(wrapped))
  })
})

describe("construction diagnostics for mood ids and unnamed arguments", {
  it("counts unnamed arguments and keeps named arguments listed", {
    expect_error(mascot("helper", 1, 2, typo = 3), '2 unnamed arguments, "typo"', fixed = TRUE)
    expect_error(mascot("helper", 1), "Unexpected arguments: an unnamed argument.", fixed = TRUE)
    expect_snapshot(error = TRUE, mascot("helper", 1, 2, typo = 3))
    expect_snapshot(error = TRUE, mascot("helper", 1))
  })
})
