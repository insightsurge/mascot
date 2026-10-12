#' A recreating call containing only non-default public arguments
#' @noRd
helper_format <- function(x) {
  checkmate::assert_list(x, names = "unique")
  helper <- class(x)[[1]]
  constructor <- get(helper, envir = environment(helper_format), inherits = FALSE)
  defaults <- formals(constructor)
  args <- unclass(x)
  if (helper == "mascot_character") {
    args <- list(name = x$id)
  }
  if (helper == "mascot_bubble") {
    args$html <- NULL
    if (x$html && !is.null(x$text)) args$text <- as.call(list(quote(htmltools::HTML), x$text))
  }
  if (helper == "mascot_placement" && x$position == "inline") {
    # Inline controls are normalised internally, not supplied constructor options.
    args$minimise <- NULL
    args$drag <- NULL
  }
  args <- args[intersect(names(defaults), names(args))]
  keep <- vapply(
    names(args),
    function(arg) {
      checkmate::assert_string(arg)
      if (identical(defaults[[arg]], quote(expr = ))) {
        return(TRUE)
      }
      default <- defaults[[arg]]
      !identical(args[[arg]], eval(default, envir = environment(constructor)))
    },
    logical(1)
  )
  args <- args[keep]
  first <- setdiff(names(defaults), "...")[[1]]
  if (length(args) && names(args)[[1]] == first && names(defaults)[[1]] != "...") {
    names(args)[[1]] <- ""
  }
  expr <- as.call(c(list(as.name(helper)), args))
  paste(deparse(expr, width.cutoff = 80L), collapse = " ")
}
