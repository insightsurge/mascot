# The file of a format recipe. All ids are test fixtures. "study_bot" maps to study_bot_frozen.json, a frozen copy of the
# shipped example, so tests that check exact content do not change when the shipped example changes. Tests about the
# shipped file itself read it with system.file().
format_recipe_path <- function(id = "anchor_probe") {
  checkmate::assert_string(id)
  if (identical(id, "study_bot")) {
    return(test_path("fixtures", "format", "study_bot_frozen.json"))
  }
  test_path("fixtures", "format", paste0(id, ".json"))
}

format_recipe <- function(id = "anchor_probe") {
  jsonlite::fromJSON(format_recipe_path(id), simplifyVector = FALSE)
}

format_problem <- function(code, path, expression) {
  checkmate::assert_string(code)
  checkmate::assert_string(path)
  error <- tryCatch(force(expression), mascot_error_character = identity)
  expect_s3_class(error, "mascot_error_character")
  expect_s3_class(error, "mascot_error")
  expect_identical(error$code, code)
  expect_identical(error$path, path)
  expect_type(error$fix, "character")
  invisible(error)
}

# A valid recipe in which reserved names appear only as data: a colour role, a recolour role, a kit eye style id and
# a numeric tree key. Every checker must accept it.
format_data_named_recipe <- function() {
  data <- format_recipe("anchor_probe")
  data$colours$follow <- "#ffffff"
  data$moods$happy$recolour <- list(follow = "body")
  kit <- jsonlite::fromJSON(
    system.file("format", "kits", "classic.json", package = "mascot", mustWork = TRUE),
    simplifyVector = FALSE
  )
  kit$eye_styles$follow <- kit$eye_styles[[1]]
  data$face <- list(part = "panel", at = list(0, 0), kit = "classic", kit_definition = kit, tune = list(fit = 1))
  data
}

# The value every extension key gets in the tests: names a reader would act on (a reserved capability, an id with the
# reserved separator, an undeclared colour, a clip and an outline), so a checker that read it would fail.
format_extension_value <- function() {
  list(follow = 1, id = "not__an_id", fill = "undeclared", clip = "nowhere.nothing", outline = TRUE)
}

# The same character with an `x_probe` extension key added to every fixed-field object, found with the schema itself.
format_with_extensions <- function(x) {
  checkmate::assert_list(x, names = "unique")
  schema <- character_format_schema()
  value <- format_extension_value()
  character_format_node(
    x,
    schema$definitions$character,
    "$",
    schema$definitions,
    on_object = function(object) c(object, list(x_probe = value))
  )
}

# Every extension key in a plain list: its JSON path and value.
format_extension_paths <- function(x, path = "$") {
  checkmate::assert_string(path)
  if (!is.list(x)) {
    return(list())
  }
  keys <- names(x)
  found <- list()
  for (index in seq_along(x)) {
    key <- if (is.null(keys)) "" else keys[[index]]
    child <- if (is.null(keys)) paste0(path, "[", index - 1L, "]") else paste0(path, ".", key)
    if (startsWith(key, "x_")) {
      found[[child]] <- x[[index]]
    } else {
      found <- c(found, format_extension_paths(x[[index]], child))
    }
  }
  found
}
