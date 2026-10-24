describe("public CSS styling hooks", {
  it("documents every public property used by the engine, leaving defaults private", {
    rd <- unlist(local_help_page("mascot_styling"))
    public <- unique(unlist(regmatches(rd, gregexpr("--mascot-[[:alnum:]_-]+", rd))))
    files <- list.files(system.file("www", package = "mascot"), full.names = TRUE)
    source <- unlist(lapply(files, readLines))
    used <- unique(unlist(regmatches(source, gregexpr("--mascot-[[:alnum:]_-]+", source))))
    # Dynamic source copies must also name only documented properties.
    host <- readLines(file.path(system.file("www", package = "mascot"), "mascot-host.js"))
    start <- which(grepl("const stylingHooks =", host, fixed = TRUE))
    end <- start + which(grepl("];", host[(start + 1L):length(host)], fixed = TRUE))[[1]]
    hooks <- paste(host[start:end], collapse = "\n")
    dynamic <- regmatches(hooks, gregexpr("'[a-z-]+'", hooks))[[1]]
    used <- unique(c(used, paste0("--mascot-", gsub("'", "", dynamic, fixed = TRUE))))
    expect_setequal(paste0("--mascot-", gsub("'", "", dynamic, fixed = TRUE)), public)
    expect_setequal(used, public)
    expect_length(public, 7L)
    expect_false(any(grepl("--mascot-[[:alnum:]_-]+\\s*:", source)))
    expect_true(all(vapply(
      c("mascot", "mascot-status", "mascot-bubble", "mascot-menu", "mascot-tooltip"),
      function(class) any(grepl(paste0(".", class), rd, fixed = TRUE)),
      logical(1)
    )))
  })
})
