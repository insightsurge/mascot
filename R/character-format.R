#' Shared versioned resource policy (not a performance measurement)
#' @noRd
character_format_policy <- function() {
  jsonlite::fromJSON(
    system.file("format", "policy-v1.json", package = "mascot", mustWork = TRUE),
    simplifyVector = FALSE
  )
}

#' Character format structure and input bounds
#'
#' Internal foundation; this returns structural data, never checked character
#' data. Family resolution and semantic validation belong to the next stage.
#' @noRd
character_format_schema <- function() {
  schema <- jsonlite::fromJSON(
    system.file("format", "character-v1.json", package = "mascot", mustWork = TRUE),
    simplifyVector = FALSE
  )
  policy <- character_format_policy()
  schema$input <- policy$input
  schema$capabilities <- policy$capabilities
  schema$reserved_unsupported <- policy$reserved_unsupported
  attr(schema$definitions, "input") <- policy$input
  attr(schema$definitions, "reserved") <- unlist(policy$reserved_unsupported, use.names = FALSE)
  schema
}

#' Report a stable character-description diagnostic
#' @noRd
character_format_abort <- function(code, path, value = NULL, fix = "Supply valid character data.") {
  checkmate::assert_string(code, min.chars = 1)
  checkmate::assert_string(path, min.chars = 1)
  checkmate::assert(checkmate::check_list(value, null.ok = TRUE), checkmate::check_atomic(value))
  checkmate::assert_string(fix, min.chars = 1)
  cli::cli_abort(
    "{path}: {fix}",
    class = c("mascot_error_character", "mascot_error"),
    code = code,
    path = path,
    value = value,
    fix = fix
  )
}

#' Walk an input iteratively before any recursive schema work
#' @noRd
character_format_bounds <- function(x, max_depth = 32L, max_nodes = 10000L) {
  checkmate::assert(checkmate::check_list(x, null.ok = TRUE), checkmate::check_atomic(x))
  checkmate::assert_count(max_depth, positive = TRUE)
  checkmate::assert_count(max_nodes, positive = TRUE)
  pending <- list(list(value = x, path = "$", depth = 0L))
  nodes <- 0L
  while (length(pending)) {
    current <- pending[[length(pending)]]
    pending <- pending[-length(pending)]
    value <- current$value
    if (!is.list(value) && !is.atomic(value) && !is.null(value)) {
      character_format_abort("input_type", current$path, NULL, "Use plain data rather than executable objects.")
    }
    nodes <- nodes + if (is.list(value)) 1L else max(1L, length(value))
    if (nodes > max_nodes) {
      character_format_abort("budget", "$", nodes, "Reduce the number of input nodes.")
    }
    if (is.numeric(value) && any(is.infinite(value) | is.nan(value))) {
      index <- which(is.infinite(value) | is.nan(value))[[1L]]
      path <- if (length(value) > 1L) paste0(current$path, "[", index - 1L, "]") else current$path
      character_format_abort("non_finite", path, NULL, "Use finite numbers.")
    }
    if (is.atomic(value) && anyNA(value)) {
      character_format_abort("input_type", current$path, NULL, "Replace missing values with explicit valid values.")
    }
    if (is.character(value) && any(!validUTF8(value))) {
      character_format_abort("input_type", current$path, NULL, "Use valid UTF-8 text.")
    }
    if (!is.list(value)) {
      next
    }
    depth <- current$depth + 1L
    if (depth > max_depth) {
      character_format_abort("budget", "$", depth, "Reduce container nesting depth.")
    }
    keys <- names(value)
    duplicate <- anyDuplicated(keys)
    if (duplicate) {
      character_format_abort(
        "input_type",
        paste0(current$path, ".", keys[[duplicate]]),
        NULL,
        "Keep each object key once."
      )
    }
    if (length(value) + length(pending) > max_nodes - nodes) {
      character_format_abort("budget", "$", nodes, "Reduce the number of input nodes.")
    }
    for (index in rev(seq_along(value))) {
      path <- if (is.null(keys)) {
        paste0(current$path, "[", index - 1L, "]")
      } else {
        paste0(current$path, ".", keys[[index]])
      }
      pending[[length(pending) + 1L]] <- list(value = value[[index]], path = path, depth = depth)
    }
  }
  invisible(nodes)
}

#' Bound JSON nesting lexically and reject repeated decoded object keys
#' @noRd
character_format_json <- function(bytes, limits) {
  checkmate::assert_raw(bytes)
  checkmate::assert_list(limits, names = "unique")
  if (length(bytes) > limits$utf8_bytes) {
    character_format_abort("budget", "$", length(bytes), "Reduce the UTF-8 input byte length.")
  }
  text <- tryCatch(rawToChar(bytes), error = function(error) {
    checkmate::assert_class(error, "error")
    character_format_abort("input_type", "$", NULL, "Use valid UTF-8 JSON without embedded zero bytes.")
  })
  if (!validUTF8(text)) {
    character_format_abort("input_type", "$", NULL, "Use valid UTF-8 JSON.")
  }
  # This pass never recurses, including for malformed or extremely deep JSON.
  quoted <- escaped <- FALSE
  depth <- 0L
  for (byte in as.integer(bytes)) {
    if (quoted) {
      if (escaped) {
        escaped <- FALSE
      } else if (byte == 92L) {
        escaped <- TRUE
      } else if (byte == 34L) {
        quoted <- FALSE
      }
    } else if (byte == 34L) {
      quoted <- TRUE
    } else if (byte %in% c(91L, 123L)) {
      depth <- depth + 1L
      if (depth > limits$nesting_depth) {
        character_format_abort("budget", "$", depth, "Reduce container nesting depth.")
      }
    } else if (byte %in% c(93L, 125L)) {
      depth <- depth - 1L
    }
  }
  if (!isTRUE(jsonlite::validate(text))) {
    character_format_abort("input_type", "$", NULL, "Supply syntactically valid JSON.")
  }
  # Syntax and lexical depth are now bounded. The cursor creates no value tree.
  cursor <- new.env(parent = emptyenv())
  cursor$position <- 1L
  cursor$nodes <- 0L
  integers <- as.integer(bytes)
  skip_space <- function() {
    while (cursor$position <= length(integers) && integers[[cursor$position]] %in% c(9L, 10L, 13L, 32L)) {
      cursor$position <- cursor$position + 1L
    }
  }
  string_token <- function() {
    start <- cursor$position
    cursor$position <- start + 1L
    while (integers[[cursor$position]] != 34L) {
      if (integers[[cursor$position]] == 92L) {
        cursor$position <- cursor$position + 1L
      }
      cursor$position <- cursor$position + 1L
    }
    end <- cursor$position
    cursor$position <- end + 1L
    jsonlite::fromJSON(rawToChar(bytes[start:end]))
  }
  scan_value <- function(path) {
    checkmate::assert_string(path)
    skip_space()
    cursor$nodes <- cursor$nodes + 1L
    if (cursor$nodes > limits$structural_nodes) {
      character_format_abort("budget", "$", cursor$nodes, "Reduce the number of input nodes.")
    }
    token <- integers[[cursor$position]]
    if (token == 34L) {
      string_token()
    } else if (token %in% c(91L, 123L)) {
      object <- token == 123L
      terminal <- if (object) 125L else 93L
      cursor$position <- cursor$position + 1L
      skip_space()
      keys <- new.env(hash = TRUE, parent = emptyenv())
      index <- 0L
      while (integers[[cursor$position]] != terminal) {
        if (object) {
          key <- string_token()
          child <- paste0(path, ".", key)
          if (exists(paste0("k", key), envir = keys, inherits = FALSE)) {
            character_format_abort("input_type", child, NULL, "Keep each decoded object key once.")
          }
          assign(paste0("k", key), TRUE, envir = keys)
          skip_space()
          cursor$position <- cursor$position + 1L
        } else {
          child <- paste0(path, "[", index, "]")
        }
        scan_value(child)
        index <- index + 1L
        skip_space()
        if (integers[[cursor$position]] == 44L) {
          cursor$position <- cursor$position + 1L
          skip_space()
        }
      }
      cursor$position <- cursor$position + 1L
    } else {
      while (
        cursor$position <= length(integers) && !integers[[cursor$position]] %in% c(9L, 10L, 13L, 32L, 44L, 93L, 125L)
      ) {
        cursor$position <- cursor$position + 1L
      }
    }
    invisible(NULL)
  }
  scan_value("$")
  data <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  character_format_bounds(data, limits$nesting_depth, limits$structural_nodes)
  data
}

#' Validate and normalise one node against a closed structural definition
#' @noRd
character_format_node <- function(value, rule, path, definitions, json_source = FALSE) {
  checkmate::assert(checkmate::check_list(value, null.ok = TRUE), checkmate::check_atomic(value))
  checkmate::assert_list(rule, names = "unique")
  checkmate::assert_string(path)
  checkmate::assert_list(definitions, names = "unique")
  checkmate::assert_flag(json_source)
  if (!is.null(rule$ref)) {
    rule <- utils::modifyList(definitions[[rule$ref]], rule[setdiff(names(rule), "ref")], keep.null = TRUE)
  }
  if (is.null(value)) {
    if (isTRUE(rule$nullable)) {
      return(NULL)
    }
    character_format_abort("input_type", path, NULL, "Supply a non-null value of the declared type.")
  }
  maximum_length <- if (is.null(rule$input_limit)) rule$max_length else attr(definitions, "input")[[rule$input_limit]]
  kind <- rule$type
  fail <- function(code = "input_type", fix = "Supply a value of the declared type.") {
    checkmate::assert_string(code)
    checkmate::assert_string(fix)
    character_format_abort(code, path, NULL, fix)
  }
  if (kind == "union") {
    for (alternative in rule$alternatives) {
      attempt <- tryCatch(
        list(ok = TRUE, value = character_format_node(value, alternative, path, definitions, json_source)),
        mascot_error_character = function(error) {
          checkmate::assert_class(error, "mascot_error_character")
          list(ok = FALSE)
        }
      )
      if (attempt$ok) {
        return(attempt$value)
      }
    }
    fail()
  }
  if (kind == "discriminator") {
    key <- rule$field
    if (!is.list(value) || is.null(names(value)) || !is.character(value[[key]]) || length(value[[key]]) != 1L) {
      character_format_abort("input_type", paste0(path, ".", key), NULL, "Supply the operation name.")
    }
    variant <- rule$variants[[value[[key]]]]
    if (is.null(variant)) {
      character_format_abort("capability", paste0(path, ".", key), value[[key]], "Use a supported operation.")
    }
    return(character_format_node(value, definitions[[variant]], path, definitions, json_source))
  }
  if (kind == "numeric_tree") {
    if (is.numeric(value) && all(is.finite(value))) {
      return(value)
    }
    if (!is.list(value)) {
      fail()
    }
    result <- value
    for (index in seq_along(value)) {
      key <- if (is.null(names(value))) paste0("[", index - 1L, "]") else paste0(".", names(value)[[index]])
      result[index] <- list(character_format_node(value[[index]], rule, paste0(path, key), definitions, json_source))
    }
    return(result)
  }
  if (kind %in% c("object", "map")) {
    if (!is.list(value) || inherits(value, "data.frame") || (is.null(names(value)) && (length(value) || json_source))) {
      fail(fix = "Supply an object with named fields.")
    }
    if (is.null(names(value))) {
      names(value) <- character()
    }
    keys <- names(value)
    attributes(value) <- list(names = keys)
    if (anyNA(keys) || any(!nzchar(keys)) || anyDuplicated(keys)) {
      fail(fix = "Use unique, nonempty object keys.")
    }
    if (!is.null(maximum_length) && length(value) > maximum_length) {
      fail("budget", "Reduce the number of object entries.")
    }
    fields <- rule$fields
    if (kind == "object") {
      fields$note <- list(type = "string")
      for (key in unlist(rule$required, use.names = FALSE)) {
        if (!key %in% keys) {
          character_format_abort("input_type", paste0(path, ".", key), NULL, "Supply this required field.")
        }
      }
    }
    for (key in keys) {
      child <- paste0(path, ".", key)
      if (kind == "map") {
        if (!grepl(rule$key_pattern, key)) {
          character_format_abort("input_type", child, NULL, "Use a key with the documented spelling.")
        }
        next_rule <- rule$values
      } else {
        next_rule <- fields[[key]]
        if (is.null(next_rule)) {
          if (key %in% attr(definitions, "reserved")) {
            character_format_abort("capability", child, key, "This field is not supported by this version of mascot.")
          }
          character_format_abort("unknown_key", child, key, "Remove this unrecognised field.")
        }
      }
      value[key] <- list(character_format_node(value[[key]], next_rule, child, definitions, json_source))
    }
    return(value)
  }
  if (kind %in% c("array", "tuple")) {
    if (!json_source && is.atomic(value) && is.null(names(value))) {
      value <- as.list(value)
    }
    if (!is.list(value) || !is.null(names(value))) {
      fail(fix = "Supply an array, retaining empty and singleton arrays.")
    }
    attributes(value) <- NULL
    size <- length(value)
    if ((!is.null(rule$min_length) && size < rule$min_length) || (!is.null(maximum_length) && size > maximum_length)) {
      fail(if (is.null(rule$length_code)) "input_type" else rule$length_code, "Use the documented array length.")
    }
    if (isTRUE(rule$unique) && anyDuplicated(value)) {
      fail(fix = "Keep each array value once.")
    }
    for (index in seq_along(value)) {
      next_rule <- if (kind == "tuple") rule$elements[[index]] else rule$items
      value[index] <- list(character_format_node(
        value[[index]],
        next_rule,
        paste0(path, "[", index - 1L, "]"),
        definitions,
        json_source
      ))
    }
    return(value)
  }
  scalar <- length(value) == 1L && is.atomic(value) && !is.object(value) && !anyNA(value)
  valid <- switch(
    kind,
    string = scalar && is.character(value),
    number = scalar && is.numeric(value) && is.finite(value),
    integer = scalar && is.numeric(value) && is.finite(value) && value == floor(value),
    boolean = scalar && is.logical(value),
    scalar = scalar && (is.character(value) || is.logical(value) || (is.numeric(value) && is.finite(value))),
    FALSE
  )
  if (!valid) {
    fail()
  }
  if (!is.null(rule$choices) && !value %in% unlist(rule$choices, use.names = FALSE)) {
    fail(fix = "Choose one of the documented values.")
  }
  if (is.character(value)) {
    if (
      (!is.null(rule$min_chars) && nchar(value) < rule$min_chars) ||
        (!is.null(rule$pattern) && !grepl(rule$pattern, value))
    ) {
      fail(fix = "Use the documented string spelling or format.")
    }
  } else if (is.numeric(value)) {
    outside <- (!is.null(rule$min) && value < rule$min) ||
      (!is.null(rule$max) && value > rule$max) ||
      (!is.null(rule$exclusive_min) && value <= rule$exclusive_min)
    if (outside) {
      fail(if (is.null(rule$range_code)) "input_type" else rule$range_code, "Use a value in the documented range.")
    }
  }
  unname(value)
}

#' Read structural character input without resolving or registering it
#' @noRd
character_format_parse <- function(x, from = "list") {
  checkmate::assert(checkmate::check_list(x), checkmate::check_character(x, any.missing = FALSE))
  checkmate::assert_choice(from, c("list", "text", "file"))
  schema <- character_format_schema()
  if (from == "list") {
    if (!is.list(x) || inherits(x, "data.frame")) {
      character_format_abort("input_type", "$", NULL, "Supply a character-description list.")
    }
    character_format_bounds(x, schema$input$nesting_depth, schema$input$structural_nodes)
    data <- x
  } else {
    checkmate::assert_string(x)
    if (from == "file") {
      connection <- tryCatch(
        {
          checkmate::assert_file_exists(x)
          suppressWarnings(file(x, open = "rb"))
        },
        error = function(error) {
          checkmate::assert_class(error, "error")
          cli::cli_abort(
            "Cannot read {.path {x}}.",
            class = c("mascot_error_file", "mascot_error"),
            path = x,
            operation = "read",
            parent = error
          )
        }
      )
      on.exit(close(connection), add = TRUE)
      bytes <- readBin(connection, "raw", n = schema$input$utf8_bytes + 1L)
    } else {
      if (!validUTF8(x)) {
        character_format_abort("input_type", "$", NULL, "Use valid UTF-8 text.")
      }
      bytes <- charToRaw(enc2utf8(x))
    }
    data <- character_format_json(bytes, schema$input)
  }
  if (!is.list(data) || is.null(names(data))) {
    character_format_abort("input_type", "$", NULL, "Supply one JSON object describing one character.")
  }
  version <- data$format_version
  if (!is.numeric(version) || length(version) != 1L || !is.finite(version) || version != floor(version)) {
    character_format_abort("input_type", "$.format_version", NULL, "Supply an integer format_version.")
  }
  if (version != schema$format_version) {
    character_format_abort("version", "$.format_version", version, "Use a supported character-format version.")
  }
  required <- character_format_node(
    data$requires,
    schema$definitions$character$fields$requires,
    "$.requires",
    schema$definitions,
    from != "list"
  )
  for (index in seq_along(required)) {
    if (!required[[index]] %in% unlist(schema$capabilities, use.names = FALSE)) {
      character_format_abort(
        "capability",
        paste0("$.requires[", index - 1L, "]"),
        required[[index]],
        "Use supported engine capabilities."
      )
    }
  }
  data <- character_format_node(data, schema$definitions$character, "$", schema$definitions, from != "list")
  character_format_bounds(data, schema$input$nesting_depth, schema$input$structural_nodes)
  data
}
