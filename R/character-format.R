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
#' data. Family resolution and semantic checks happen in `character_format_check()`.
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
character_format_abort <- function(
  code,
  path,
  value = NULL,
  fix = "Supply valid character data.",
  choices = character()
) {
  checkmate::assert_string(code, min.chars = 1)
  checkmate::assert_string(path, min.chars = 1)
  checkmate::assert(checkmate::check_list(value, null.ok = TRUE), checkmate::check_atomic(value))
  checkmate::assert_string(fix, min.chars = 1)
  checkmate::assert_character(choices, any.missing = FALSE, null.ok = TRUE)
  message <- if (code == "registry" && path == "$") "{fix}" else "{path}: {fix}"
  if (code == "missing_reference") {
    if (length(value)) {
      message <- c(message, "x" = "Unknown reference: {.val {value}}.")
    }
    if (length(choices) && length(choices) <= 8L && sum(nchar(choices)) <= 160L) {
      message <- c(message, "i" = "Valid choices: {.or {.val {choices}}}.")
    }
  }
  cli::cli_abort(
    message,
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
  stack <- vector("list", max_nodes + 1L)
  stack[[1L]] <- list(value = x, path = "$", depth = 0L)
  top <- 1L
  nodes <- 0L
  while (top > 0L) {
    current <- stack[[top]]
    stack[top] <- list(NULL)
    top <- top - 1L
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
    if (length(value) + top > max_nodes - nodes) {
      character_format_abort("budget", "$", nodes, "Reduce the number of input nodes.")
    }
    for (index in rev(seq_along(value))) {
      path <- if (is.null(keys)) {
        paste0(current$path, "[", index - 1L, "]")
      } else {
        paste0(current$path, ".", keys[[index]])
      }
      top <- top + 1L
      stack[[top]] <- list(value = value[[index]], path = path, depth = depth)
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
  # jsonlite preserves repeated decoded keys as duplicate names on list elements;
  # character_format_bounds() walks the parsed tree to enforce node budgets and
  # duplicate-key rejection with the exact JSON path.
  data <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  character_format_bounds(data, limits$nesting_depth, limits$structural_nodes)
  data
}

#' Validate and normalise one node against a closed structural definition
#'
#' A key that starts with `x_` in a fixed-field object is an extension key: its
#' value is any plain data, kept as it is and never checked or read. `on_object`,
#' when given, is applied to every fixed-field object after it is checked (the
#' semantic checks use it to drop the extension keys).
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_format_node <- function(value, rule, path, definitions, json_source = FALSE, on_object = NULL) {
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
  fail <- function(code = "input_type", fix = "Supply a value of the declared type.", shown = NULL) {
    if (!is.null(rule$pattern) && identical(rule$pattern, definitions$colour_map$values$pattern)) {
      character_format_abort(code, path, value, "Use #RGB, #RRGGBB or rgba(r, g, b, a), for example #3F82FF.")
    }
    character_format_abort(code, path, shown, fix)
  }
  if (kind == "union") {
    # Only alternatives of the value's kind can match, so a string never meets an
    # object rule. One candidate reports its own specific problem; when several
    # remain, the first candidate's problem is reported.
    shape <- character_format_value_kind(value)
    candidates <- Filter(
      function(alternative) any(shape %in% character_format_rule_kinds(alternative, definitions)),
      rule$alternatives
    )
    if (!length(candidates)) {
      fail()
    }
    first <- NULL
    for (alternative in candidates) {
      attempt <- tryCatch(
        list(ok = TRUE, value = character_format_node(value, alternative, path, definitions, json_source, on_object)),
        mascot_error_character = function(error) list(ok = FALSE, error = error)
      )
      if (attempt$ok) {
        return(attempt$value)
      }
      if (is.null(first)) {
        first <- attempt$error
      }
    }
    stop(first)
  }
  if (kind == "discriminator") {
    key <- rule$field
    if (!is.list(value) || is.null(names(value)) || !is.character(value[[key]]) || length(value[[key]]) != 1L) {
      character_format_abort("input_type", paste0(path, ".", key), NULL, "Supply the operation name.")
    }
    variant <- rule$variants[[value[[key]]]]
    if (is.null(variant)) {
      character_format_abort(
        "capability",
        paste0(path, ".", key),
        value[[key]],
        paste0(
          "Use a supported operation, not ",
          character_format_shown(value[[key]]),
          ": choose one of ",
          character_format_choices(names(rule$variants)),
          "."
        )
      )
    }
    return(character_format_node(value, definitions[[variant]], path, definitions, json_source, on_object))
  }
  if (kind == "numeric_tree") {
    if (is.numeric(value) && all(is.finite(value))) {
      attributes(value) <- NULL
      return(value)
    }
    if (!is.list(value) || is.data.frame(value)) {
      fail()
    }
    result <- value
    attributes(result) <- if (is.null(names(value))) NULL else list(names = names(value))
    for (index in seq_along(value)) {
      key <- if (is.null(names(value))) paste0("[", index - 1L, "]") else paste0(".", names(value)[[index]])
      result[index] <- list(character_format_node(
        value[[index]],
        rule,
        paste0(path, key),
        definitions,
        json_source,
        on_object
      ))
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
      if (kind == "object" && startsWith(key, "x_")) {
        # An extension key for other tools: kept as it is, never checked or read.
        next
      }
      if (kind == "map") {
        if (!grepl(rule$key_pattern, key, perl = TRUE)) {
          fix <- if (grepl("__", key, fixed = TRUE)) {
            "Use an id without consecutive underscores."
          } else {
            "Use a key with the documented spelling."
          }
          character_format_abort("input_type", child, NULL, fix)
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
      value[key] <- list(character_format_node(value[[key]], next_rule, child, definitions, json_source, on_object))
    }
    if (kind == "object") {
      for (key in setdiff(names(fields), keys)) {
        if ("default" %in% names(fields[[key]])) {
          value[key] <- list(character_format_node(
            fields[[key]]$default,
            fields[[key]],
            paste0(path, ".", key),
            definitions
          ))
        }
      }
      if (!is.null(on_object)) {
        value <- on_object(value)
      }
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
    if (!is.null(rule$min_length) && size < rule$min_length) {
      fail("input_type", "Use the documented minimum array length.")
    }
    if (!is.null(maximum_length) && size > maximum_length) {
      fail(
        if (is.null(rule$length_code)) "input_type" else rule$length_code,
        "Use the documented maximum array length."
      )
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
        json_source,
        on_object
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
    fail(
      fix = paste0(
        "Choose one of ",
        character_format_choices(unlist(rule$choices, use.names = FALSE)),
        ", not ",
        character_format_shown(value),
        "."
      ),
      shown = value
    )
  }
  if (is.character(value)) {
    if (!is.null(rule$forbid) && grepl(rule$forbid, value, fixed = TRUE)) {
      fail(fix = "Use an id without consecutive underscores.")
    }
    if (
      (!is.null(rule$min_chars) && nchar(value) < rule$min_chars) ||
        (!is.null(rule$pattern) && !grepl(rule$pattern, value, perl = TRUE))
    ) {
      fix <- if (grepl("__", value, fixed = TRUE)) {
        "Use an id without consecutive underscores."
      } else {
        "Use the documented string spelling or format."
      }
      fail(fix = fix)
    }
  } else if (is.numeric(value)) {
    outside <- (!is.null(rule$min) && value < rule$min) ||
      (!is.null(rule$max) && value > rule$max) ||
      (!is.null(rule$exclusive_min) && value <= rule$exclusive_min) ||
      (!is.null(rule$exclusive_max) && value >= rule$exclusive_max)
    if (outside) {
      fail(
        if (is.null(rule$range_code)) "input_type" else rule$range_code,
        paste0("Use ", character_format_range(rule), ", not ", character_format_shown(value), "."),
        shown = value
      )
    }
  }
  attributes(value) <- NULL
  value
}

#' One value as an author wrote it, for a message: quoted text or a plain number
#' @noRd
character_format_shown <- function(value) {
  checkmate::assert_atomic(value, len = 1L)
  if (is.character(value)) {
    return(encodeString(value, quote = '"'))
  }
  if (is.logical(value)) {
    return(tolower(as.character(value)))
  }
  format(value, digits = 15L, scientific = FALSE, trim = TRUE)
}

#' The allowed values of a choice, for a message
#' @noRd
character_format_choices <- function(choices) {
  checkmate::assert_atomic(choices, min.len = 1L)
  shown <- vapply(choices, character_format_shown, character(1), USE.NAMES = FALSE)
  if (length(shown) == 1L) {
    return(shown)
  }
  paste(paste(shown[-length(shown)], collapse = ", "), "or", shown[[length(shown)]])
}

#' The allowed range of a number rule, for a message
#' @noRd
character_format_range <- function(rule) {
  checkmate::assert_list(rule)
  low <- if (!is.null(rule$min)) rule$min else rule$exclusive_min
  high <- if (!is.null(rule$max)) rule$max else rule$exclusive_max
  if (!is.null(rule$min) && !is.null(rule$max)) {
    return(paste("a value from", character_format_shown(low), "to", character_format_shown(high)))
  }
  parts <- c(
    if (!is.null(rule$min)) paste("at least", character_format_shown(low)),
    if (!is.null(rule$exclusive_min)) paste("above", character_format_shown(low)),
    if (!is.null(rule$max)) paste("at most", character_format_shown(high)),
    if (!is.null(rule$exclusive_max)) paste("below", character_format_shown(high))
  )
  sub("^a value at ", "a value of at ", paste("a value", paste(parts, collapse = " and ")))
}

#' Kinds of JSON value a plain R value can stand for: scalar, object or array
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_format_value_kind <- function(value) {
  if (is.atomic(value)) {
    return(if (length(value) == 1L) "scalar" else "array")
  }
  if (!is.null(names(value))) {
    return("object")
  }
  if (length(value)) "array" else c("object", "array")
}

#' Kinds of JSON value a grammar rule accepts, following refs and unions
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_format_rule_kinds <- function(rule, definitions) {
  if (!is.null(rule$ref)) {
    rule <- utils::modifyList(definitions[[rule$ref]], rule[setdiff(names(rule), "ref")], keep.null = TRUE)
  }
  switch(
    rule$type,
    union = unique(unlist(lapply(rule$alternatives, character_format_rule_kinds, definitions = definitions))),
    object = ,
    map = ,
    discriminator = "object",
    array = ,
    tuple = "array",
    numeric_tree = c("scalar", "array", "object"),
    "scalar"
  )
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
      fail_read <- function(message) {
        checkmate::assert_string(message)
        cli::cli_abort(
          message,
          class = c("mascot_error_file", "mascot_error"),
          path = x,
          operation = "read",
          code = "io",
          call = NULL
        )
      }
      if (!file.exists(x)) {
        fail_read("File does not exist: {.path {x}}.")
      }
      if (dir.exists(x)) {
        fail_read("{.path {x}} is a directory.")
      }
      connection <- tryCatch(
        suppressWarnings(file(x, open = "rb")),
        error = function(error) {
          checkmate::assert_class(error, "error")
          fail_read("Cannot read {.path {x}}.")
        }
      )
      on.exit(close(connection), add = TRUE)
      bytes <- tryCatch(
        readBin(connection, "raw", n = schema$input$utf8_bytes + 1L),
        error = function(error) {
          checkmate::assert_class(error, "error")
          fail_read("Cannot read {.path {x}}.")
        }
      )
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
    shown <- format(version, scientific = FALSE, trim = TRUE)
    fix <- if (version > schema$format_version) {
      paste0(
        "This file is format version ",
        shown,
        "; this mascot version supports ",
        schema$format_version,
        ". Update the package, or use a version-",
        schema$format_version,
        " file."
      )
    } else {
      paste0(
        "Format version ",
        shown,
        " is not a supported version; this mascot version supports ",
        schema$format_version,
        ". Use a version-",
        schema$format_version,
        " file."
      )
    }
    character_format_abort("version", "$.format_version", version, fix)
  }
  # The version-1 capabilities are implicit: `requires` is optional and names
  # only capabilities beyond version 1. It is read before the full walk, so a
  # file that needs a newer mascot stops here with the capability named. A
  # version-1 name in the list is accepted, so older files keep loading.
  required <- if ("requires" %in% names(data)) {
    character_format_node(
      data$requires,
      schema$definitions$character$fields$requires,
      "$.requires",
      schema$definitions,
      from != "list"
    )
  }
  for (index in seq_along(required)) {
    if (!required[[index]] %in% unlist(schema$capabilities, use.names = FALSE)) {
      character_format_abort(
        "capability",
        paste0("$.requires[", index - 1L, "]"),
        required[[index]],
        paste0(
          "This file needs the capability ",
          character_format_shown(required[[index]]),
          ", which is not supported by this version of mascot. Update mascot, or remove it from requires."
        )
      )
    }
  }
  data <- character_format_node(data, schema$definitions$character, "$", schema$definitions, from != "list")
  character_format_bounds(data, schema$input$nesting_depth, schema$input$structural_nodes)
  if (from == "list" && nchar(character_format_identity(data), type = "bytes") > schema$input$utf8_bytes) {
    character_format_abort("budget", "$", NULL, "Reduce the UTF-8 input byte length.")
  }
  data
}
