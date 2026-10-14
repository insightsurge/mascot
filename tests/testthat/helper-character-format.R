format_recipe <- function(id = "anchor_probe") {
  checkmate::assert_string(id)
  jsonlite::fromJSON(test_path("fixtures", "format", paste0(id, ".json")), simplifyVector = FALSE)
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
