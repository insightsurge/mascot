# Guide pages written as R Markdown (guide/<function>.Rmd), shared with the package website: one place
# to maintain the explanation. studio_guide_page() knits one page for the studio; the website includes
# the same file with a knitr child chunk. A function without a page shows only its help and mistakes.
# Shiny sources this file with the others in R/, so it holds functions only.

# The page of `fn` for `character` as a list of pieces for selected_guide(), or NULL when the function has
# no page (yet). knitr is required by the app (app.R), so there is no fallback for a missing package.
studio_guide_page <- function(fn, character, dir = studio_guide_dir()) {
  checkmate::assert_string(fn, min.chars = 1)
  checkmate::assert_string(character, min.chars = 1)
  checkmate::assert_string(dir)
  file <- file.path(dir, paste0(fn, ".Rmd"))
  helpers <- file.path(dir, "guide-helpers.R")
  # `fn` becomes part of a file name: only function names are accepted.
  if (startsWith(fn, "_") || !grepl("^[A-Za-z0-9_.]+$", fn) || !file.exists(file) || !file.exists(helpers)) {
    return(NULL)
  }
  # Built afresh on every visit and never stored: a live demo on the page holds a mascot that belongs to the
  # session that built it, so a stored page would show another visitor's mascot that no update reaches.
  tryCatch(
    studio_guide_knit(file, helpers, character),
    error = function(e) {
      reason <- cli::ansi_strip(conditionMessage(e))
      cli::cli_warn(c("The guide page {.file {basename(file)}} could not be built.", "x" = reason))
      # The guide says so, rather than showing nothing.
      list(structure(
        shiny::HTML(as.character(htmltools::tags$div(
          class = "pg-callout pg-callout-warn",
          htmltools::tags$strong("This guide page could not be built. "),
          reason
        ))),
        guide_kind = "callout"
      ))
    }
  )
}

# Knit one page. Its chunks run in a new environment below the studio's, so they can call the studio's
# demos; there in_studio() is TRUE and studio_character is the selected character.
studio_guide_knit <- function(file, helpers, character) {
  checkmate::assert_file_exists(file)
  checkmate::assert_file_exists(helpers)
  checkmate::assert_string(character, min.chars = 1)
  env <- new.env(parent = parent.env(environment()))
  env$guide_dir <- dirname(helpers)
  sys.source(helpers, envir = env)
  env$in_studio <- function() TRUE
  env$studio_character <- character
  text <- readLines(file, warn = FALSE)
  # A page that also serves the website may start with YAML; the studio has no use for it.
  if (length(text) && identical(trimws(text[[1]]), "---")) {
    end <- which(trimws(text[-1]) %in% c("---", "..."))[1]
    if (!is.na(end)) {
      text <- text[-seq_len(end + 1L)]
    }
  }
  options <- knitr::opts_chunk$get()
  on.exit(knitr::opts_chunk$restore(options), add = TRUE)
  # Like rmarkdown::render(), stop at a chunk that fails (knit() alone would print the error into the page).
  knitr::opts_chunk$set(echo = FALSE, error = FALSE)
  markdown <- knitr::knit(text = paste(text, collapse = "\n"), envir = env, quiet = TRUE)
  dependencies <- knitr::knit_meta("html_dependency", clean = TRUE)
  pieces <- studio_guide_pieces(markdown)
  if (length(pieces) && length(dependencies)) {
    pieces[[1]] <- htmltools::attachDependencies(pieces[[1]], dependencies)
  }
  pieces
}

# knitted Markdown (with the HTML of tags between html_preserve comments) -> pieces for selected_guide():
# each starts at a "###" heading or at a block that begins with a heading; a callout stands alone.
# Tags go through Markdown as placeholders: Markdown must not rewrite their HTML.
studio_guide_pieces <- function(markdown) {
  checkmate::assert_string(markdown)
  pattern <- "(?s)<!--html_preserve-->(.*?)<!--/html_preserve-->"
  found <- gregexpr(pattern, markdown, perl = TRUE)[[1]]
  blocks <- character()
  if (found[[1]] > 0L) {
    blocks <- regmatches(markdown, list(found))[[1]]
    blocks <- sub("^<!--html_preserve-->", "", sub("<!--/html_preserve-->$", "", blocks))
    # A tag in the middle of a line (an inline `r guide_fn_link()`) stays in its paragraph; one on its own
    # becomes a block.
    ends <- as.integer(found) + attr(found, "match.length") - 1L
    inline <- vapply(
      seq_along(blocks),
      function(i) {
        before <- substr(markdown, 1L, as.integer(found)[[i]] - 1L)
        after <- substring(markdown, ends[[i]] + 1L)
        nzchar(trimws(sub("^.*\n", "", before))) || nzchar(trimws(sub("\n.*$", "", after)))
      },
      logical(1)
    )
    tokens <- paste0(ifelse(inline, "GUIDEINLINE", "GUIDEBLOCK"), seq_along(blocks), "X")
    regmatches(markdown, list(found)) <- list(ifelse(inline, tokens, paste0("\n\n", tokens, "\n\n")))
  }
  kind_of <- function(html) {
    if (grepl("^\\s*<div[^>]*class=\"pg-callout", html)) {
      "callout"
    } else if (grepl("^\\s*(<div[^>]*>\\s*)?<h3", html)) {
      "heading"
    } else {
      "other"
    }
  }
  pieces <- list()
  lines <- character()
  fenced <- FALSE
  flush <- function() {
    text <- paste(lines, collapse = "\n")
    lines <<- character()
    if (!nzchar(trimws(text))) {
      return(invisible())
    }
    html <- as.character(shiny::markdown(text))
    html <- gsub("<h3>", "<h3 class=\"pg-section-title\">", html, fixed = TRUE)
    html <- gsub("<table>", "<table class=\"table table-sm pg-table\">", html, fixed = TRUE)
    for (i in seq_along(blocks)) {
      for (token in c(paste0("<p>GUIDEBLOCK", i, "X</p>"), paste0("GUIDEINLINE", i, "X"))) {
        at <- regexpr(token, html, fixed = TRUE)
        if (at > 0L) {
          html <- paste0(substr(html, 1L, at - 1L), blocks[[i]], substring(html, at + attr(at, "match.length")))
        }
      }
    }
    pieces[[length(pieces) + 1L]] <<- structure(shiny::HTML(html), guide_kind = kind_of(html))
  }
  for (line in strsplit(markdown, "\n", fixed = TRUE)[[1]]) {
    if (grepl("^\\s*(```|~~~)", line)) {
      fenced <- !fenced
    }
    token <- if (!fenced) regmatches(line, regexec("^GUIDEBLOCK([0-9]+)X$", line))[[1]]
    kind <- if (length(token)) kind_of(blocks[[as.integer(token[[2]])]])
    if (!fenced && (grepl("^### ", line) || identical(kind, "heading") || identical(kind, "callout"))) {
      flush()
    }
    lines <- c(lines, line)
    if (identical(kind, "callout")) {
      flush()
    }
  }
  flush()
  pieces
}
