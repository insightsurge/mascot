# The studio's words are the package's help pages, read at run time, so they cannot drift from
# the roxygen comments. R/guide.R keeps only what a help page does not have (the category, which
# vignette section to read next, where an argument can be tried). Shiny sources every file in R/
# before app.R attaches mascot, so everything here is a function that runs later.

help_cache <- new.env(parent = emptyenv())

rd_tag <- function(x) {
  attr(x, "Rd_tag")
}

# The package's Rd database. An installed package is read with tools::Rd_db("mascot"). A package
# loaded from its source folder with pkgload::load_all() has no installed help (or an older copy),
# so there the man/ folder is read with tools::Rd_db(dir = find.package("mascot")).
help_db <- function() {
  if (is.null(help_cache$db)) {
    path <- find.package("mascot")
    installed <- function() tools::Rd_db("mascot")
    source_folder <- function() tools::Rd_db(dir = path)
    attempts <- if (file.exists(file.path(path, "Meta", "package.rds"))) {
      list(installed, source_folder)
    } else {
      list(source_folder, installed)
    }
    db <- list()
    for (attempt in attempts) {
      db <- tryCatch(attempt(), error = function(e) list())
      if (length(db)) {
        break
      }
    }
    if (!length(db)) {
      cli::cli_abort("Could not read the help pages of {.pkg mascot}.")
    }
    help_cache$db <- db
  }
  help_cache$db
}

# The Rd file whose \alias entries include the function.
help_rd <- function(fn) {
  checkmate::assert_string(fn)
  for (rd in help_db()) {
    aliases <- unlist(lapply(Filter(function(el) identical(rd_tag(el), "\\alias"), rd), unlist))
    if (fn %in% aliases) {
      return(rd)
    }
  }
  cli::cli_abort("{.fn {fn}} has no help page.")
}

rd_sections <- function(rd, tag) {
  Filter(function(el) identical(rd_tag(el), tag), rd)
}

# The text of an \item name such as "light, dark" or \dots, without markup.
rd_text <- function(x) {
  paste(
    vapply(
      x,
      function(piece) if (identical(rd_tag(piece), "\\dots")) "..." else paste(unlist(piece), collapse = ""),
      character(1)
    ),
    collapse = ""
  )
}

# One section or argument as HTML, made by tools::Rd2HTML(). The heading Rd2HTML adds is dropped.
# Links to other help pages cannot work inside the studio, so they become plain text. The help
# pages are the package's own, so the HTML is trusted.
rd_html <- function(content, tag = "\\description") {
  mini <- structure(list(structure(content, Rd_tag = tag)), class = "Rd")
  html <- paste(utils::capture.output(tools::Rd2HTML(mini, fragment = TRUE)), collapse = "\n")
  html <- sub("^\\s*<h3>.*?</h3>\\s*", "", html, perl = TRUE)
  html <- gsub("<a href=\"(?!https?:)[^\"]*\">(.*?)</a>", "\\1", html, perl = TRUE)
  html <- gsub("<a href=\"(https?:[^\"]*)\">", "<a href=\"\\1\" target=\"_blank\" rel=\"noopener\">", html)
  htmltools::HTML(trimws(html))
}

# Plain text of an HTML fragment, for one-line summaries.
html_text <- function(html) {
  text <- gsub("<[^>]*>", "", as.character(html))
  text <- gsub("&#8288;", "", text, fixed = TRUE)
  # Numeric references (&#39;), then the named ones Rd2HTML writes; &amp; last, so it cannot make a new one.
  numeric <- unique(regmatches(text, gregexpr("&#[0-9]+;", text))[[1]])
  for (entity in numeric) {
    text <- gsub(entity, intToUtf8(as.integer(gsub("[^0-9]", "", entity))), text, fixed = TRUE)
  }
  entities <- c(
    "&lt;" = "<",
    "&gt;" = ">",
    "&quot;" = "\"",
    "&nbsp;" = " ",
    "&ndash;" = "–",
    "&mdash;" = "—",
    "&lsquo;" = "‘",
    "&rsquo;" = "’",
    "&ldquo;" = "“",
    "&rdquo;" = "”",
    "&hellip;" = "…",
    "&amp;" = "&"
  )
  for (entity in names(entities)) {
    text <- gsub(entity, entities[[entity]], text, fixed = TRUE)
  }
  gsub("\\s+", " ", trimws(text))
}

first_sentence <- function(text) {
  checkmate::assert_string(text)
  end <- regexpr("[.!?](?=\\s+[A-Z\"(*]|\\s*$)", text, perl = TRUE)
  if (end < 0) text else substr(text, 1, end)
}

# Everything the studio shows from a function's help page: its title, the description, the
# details (NULL when the page has none), the value and one HTML text per argument.
help_page <- function(fn) {
  checkmate::assert_string(fn)
  if (is.null(help_cache[[fn]])) {
    rd <- help_rd(fn)
    section <- function(tag) {
      found <- rd_sections(rd, tag)
      if (length(found)) rd_html(found[[1]], tag)
    }
    title <- rd_sections(rd, "\\title")[[1]]
    args <- list()
    block <- rd_sections(rd, "\\arguments")
    for (item in if (length(block)) rd_sections(block[[1]], "\\item")) {
      html <- rd_html(item[[2]])
      for (name in trimws(strsplit(rd_text(item[[1]]), ",", fixed = TRUE)[[1]])) {
        args[[name]] <- html
      }
    }
    help_cache[[fn]] <- list(
      title = gsub("\\s+", " ", trimws(paste(unlist(title), collapse = ""))),
      description = section("\\description"),
      details = section("\\details"),
      value = section("\\value"),
      args = args
    )
  }
  help_cache[[fn]]
}

help_arg <- function(fn, arg) {
  checkmate::assert_string(fn)
  checkmate::assert_string(arg)
  help_page(fn)$args[[arg]]
}

# The \examples of a help page as one text per top-level expression.
help_examples <- function(fn) {
  checkmate::assert_string(fn)
  file <- tempfile(fileext = ".R")
  on.exit(unlink(file), add = TRUE)
  tools::Rd2ex(help_rd(fn), out = file)
  if (!file.exists(file)) {
    return(character())
  }
  lines <- readLines(file, warn = FALSE)
  exprs <- parse(text = lines[!startsWith(lines, "###")], keep.source = TRUE)
  vapply(attr(exprs, "srcref"), function(ref) paste(as.character(ref), collapse = "\n"), character(1))
}

# The first example of the function's help page that supplies the argument, or NULL. Positional
# values count: match.call() names them.
help_arg_example <- function(fn, arg) {
  checkmate::assert_string(fn)
  checkmate::assert_string(arg)
  definition <- getExportedValue("mascot", fn)
  for (text in help_examples(fn)) {
    call <- str2lang(text)
    # An example may assign the result: page <- mascot_preview(mood = "happy").
    if (is.call(call) && as.character(call[[1]])[1] %in% c("<-", "=")) {
      call <- call[[3]]
    }
    if (!is.call(call) || !identical(utils::tail(as.character(call[[1]]), 1), fn)) {
      next
    }
    matched <- tryCatch(match.call(definition, call, expand.dots = FALSE), error = function(e) NULL)
    if (arg %in% names(matched)) {
      return(text)
    }
  }
  NULL
}

# The section of vignettes/mascot.Rmd ("Get started") that a Guide links to, never copies. The
# anchor is the heading as pkgdown and pandoc write it: lower case, spaces as hyphens, other
# punctuation removed.
vignette_anchor <- function(heading) {
  checkmate::assert_string(heading)
  gsub("[[:space:]]+", "-", gsub("[^[:alnum:] _-]", "", tolower(heading)))
}

vignette_url <- function(heading) {
  paste0("https://mascot-pkg.web.app/articles/mascot.html#", vignette_anchor(heading))
}
