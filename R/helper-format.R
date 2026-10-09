#' A compact representation shared by helper methods
#' @noRd
helper_format <- function(x) {
  checkmate::assert_list(x, names = "unique")
  fields <- vapply(
    x,
    function(value) {
      # Field values are unions already checked by each helper constructor.
      if (is.null(value)) {
        return("NULL")
      }
      paste(deparse(value, width.cutoff = 80L), collapse = " ")
    },
    character(1)
  )
  paste0(class(x)[[1]], "(", paste(paste0(names(x), " = ", fields), collapse = ", "), ")")
}
