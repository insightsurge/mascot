describe("mascot_examples()", {
  it("lists the studio, its theme page and five scenario apps in order with readable metadata", {
    examples <- mascot_examples()
    expect_s3_class(examples, "data.frame")
    expect_named(examples, c("name", "title", "description"))
    expect_identical(examples$name, c("studio", "form-check", "long-task", "modules", "theme", "golem", "rhino"))
    expect_true(all(vapply(examples, is.character, logical(1))))
    expect_true(all(nzchar(unlist(examples))))
    expect_identical(anyDuplicated(examples$name), 0L)
    expect_identical(examples$title[examples$name == "theme"], "Theme a mascot")
    expect_match(examples$description[examples$name == "theme"], "Requires bslib")
    expect_match(examples$description[examples$name == "long-task"], "Requires promises and later", fixed = TRUE)
  })
  it("copies single-file scenarios and the studio and rhino folders, and builds it without a server", {
    # mascot is already attached by the test run; attaching it here would detach it on exit.
    withr::local_package("shiny")
    if (requireNamespace("bslib", quietly = TRUE)) {
      withr::local_package("bslib")
    }
    for (name in setdiff(mascot_examples()$name, "golem")) {
      file <- mascot_example(name, run = FALSE)
      expect_true(file.exists(file), info = name)
      # The studio and framework examples need their whole folder.
      sources <- list.files(dirname(file), recursive = TRUE)
      # The theme page is a view of the studio's app: the same folder.
      if (name == "theme") {
        expect_identical(file, mascot_example("studio", run = FALSE))
        next
      }
      if (name == "studio") {
        studio_dir <- dirname(file)
        expect_true(file.exists(file.path(studio_dir, "app.R")))
        for (folder in c("R", "guide", "www")) {
          expect_gt(length(list.files(file.path(studio_dir, folder))), 0, label = folder)
        }
        # Every R file in the folder is plain R (parsed below with the other examples) and nothing else ships
        # beside the app except the guide pages, their helpers and styles, and the web files (scripts, styles and
        # the logo mark).
        expect_true(all(
          grepl("^(app[.]R|R/[^/]+[.]R|guide/[^/]+[.](R|Rmd|css)|www/[^/]+[.](js|css|svg))$", sources)
        ))
        # One guide page for each exported function (the leading underscore marks a page that is only included).
        pages <- sub("[.]Rmd$", "", basename(grep("^guide/.*[.]Rmd$", sources, value = TRUE)))
        expect_setequal(setdiff(pages, "_palette-notes"), getNamespaceExports("mascot"))
        # Every web file is used by the app, so none is left behind.
        code <- unlist(lapply(
          list.files(studio_dir, pattern = "[.]R$", recursive = TRUE, full.names = TRUE),
          readLines
        ))
        for (asset in basename(grep("^(www|guide)/.*[.](js|css|svg)$", sources, value = TRUE))) {
          expect_true(any(grepl(asset, code, fixed = TRUE)), info = asset)
        }
      } else if (name == "rhino") {
        expect_setequal(sources, c("app.R", "app/view/main.R", "app/view/review.R"))
      } else {
        expect_identical(sources, "app.R", info = name)
      }
      copy <- withr::local_tempdir()
      expect_true(file.copy(dirname(file), copy, recursive = TRUE))
      dir <- file.path(copy, name)
      for (script in list.files(dir, pattern = "[.]R$", recursive = TRUE, full.names = TRUE)) {
        expect_type(parse(script), "expression")
      }
      # The studio's page needs knitr too (helper-studio.R); without it only its files are checked above.
      if (name == "studio" && requireNamespace("bslib", quietly = TRUE) && !requireNamespace("knitr", quietly = TRUE)) {
        next
      }
      if (name != "rhino" && !requireNamespace("bslib", quietly = TRUE)) {
        # shinyAppDir() reads app.R on the first request.
        expect_error(shiny::shinyAppDir(dir)$httpHandler(list(PATH_INFO = "/")), "example needs bslib")
      } else {
        app <- shiny::shinyAppDir(dir)
        expect_s3_class(app, "shiny.appobj")
        html <- as.character(app$httpHandler(list(PATH_INFO = "/"))$content)
        # bslib's inline icons name the SVG namespace, which is not a request.
        html <- gsub("http://www.w3.org/2000/svg", "", html, fixed = TRUE)
        # External navbar links are navigation only; assets must remain local.
        for (link in c("https://github.com/insightsurge/mascot", "https://insightsurge.github.io/mascot/")) {
          html <- gsub(paste0('href="', link, '"'), "", html, fixed = TRUE)
        }
        expect_false(any(grepl("https?://", html)), info = name)
      }
    }
  })
})

describe("mascot_example()", {
  it("returns the installed app.R path without writing or running anything", {
    path <- mascot_example("studio", run = FALSE)
    expect_identical(path, system.file("examples", "studio", "app.R", package = "mascot"))
    expect_identical(basename(path), "app.R")
    expect_true(file.exists(path))
  })
  it("explains how to locate an app in a non-interactive session", {
    expect_false(interactive())
    expect_error(mascot_example("studio"), "needs an interactive R session")
  })
  it("delegates the selected directory to Shiny when running interactively", {
    # Restore both bindings at teardown; no browser or server is started here.
    local_mocked_bindings(example_interactive = function() TRUE)
    captured <- NULL
    local_mocked_bindings(
      runApp = function(appDir) {
        captured <<- appDir
        "app stopped"
      },
      .package = "shiny"
    )
    expect_identical(mascot_example("modules"), "app stopped")
    expect_identical(captured, dirname(mascot_example("modules", run = FALSE)))
  })
  it("opens the studio's app on its theme page for \"theme\"", {
    skip_without_studio_packages("theme")
    # Given an interactive session where running an app only records it
    local_mocked_bindings(example_interactive = function() TRUE)
    captured <- NULL
    local_mocked_bindings(
      runApp = function(appDir) {
        captured <<- appDir
        "app stopped"
      },
      .package = "shiny"
    )
    # Then run = FALSE gives the studio's app.R, and run = TRUE runs that app on the theme page
    expect_identical(mascot_example("theme", run = FALSE), mascot_example("studio", run = FALSE))
    expect_identical(mascot_example("theme"), "app stopped")
    expect_s3_class(captured, "shiny.appobj")
    page <- captured$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = ""))$content
    expect_match(as.character(page), "<title>Theme a mascot</title>", fixed = TRUE)
  })

  it("checks every argument and names valid examples for unknown names", {
    for (bad in list(NULL, NA_character_, "", 1, c("studio", "modules"))) {
      expect_error(mascot_example(bad, run = FALSE), "Assertion on 'name' failed")
    }
    for (bad in list(NULL, NA, 1, "FALSE", c(TRUE, FALSE))) {
      expect_error(mascot_example("studio", run = bad), "Assertion on 'run' failed")
    }
  })
})

describe("mascot_example() named arguments", {
  it("keeps the agreed signature and rejects both forms of extra argument", {
    expect_identical(names(formals(mascot_example)), c("name", "...", "run"))
    expect_error(mascot_example("studio", run = FALSE, typo = 1), "Unexpected arguments", class = "mascot_error")
    expect_error(mascot_example("studio", run = FALSE, 1), "Name the optional arguments", class = "mascot_error")
  })
})

describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_example(name = 1, run = FALSE), "name", class = "mascot_error")
    expect_error(mascot_example("studio", run = 1), "run", class = "mascot_error")
  })
})

describe("framework examples", {
  it("copies the golem folder and retains its runtime options", {
    skip_if_not_installed("golem")
    file <- mascot_example("golem", run = FALSE)
    expect_setequal(
      list.files(dirname(file), recursive = TRUE),
      c("app.R", "R/app_ui.R", "R/app_server.R", "R/mod-review.R")
    )
    copy <- withr::local_tempdir()
    expect_true(file.copy(dirname(file), copy, recursive = TRUE))
    dir <- file.path(copy, "golem")
    withr::local_dir(dir)
    for (script in list.files(dir, pattern = "[.]R$", recursive = TRUE, full.names = TRUE)) {
      expect_type(parse(script), "expression")
    }
    app <- source("app.R", local = new.env())$value
    expect_s3_class(app, "shiny.appobj")
    expect_identical(app$appOptions$golem_options, list(title = "Reviews in golem", complete = "Review complete"))
  })
})
